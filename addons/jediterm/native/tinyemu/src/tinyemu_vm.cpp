#include "tinyemu_vm.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/global_constants.hpp>

#include <chrono>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

using namespace godot;

// TinyEMU upstream headers are C and use GCC/Clang extensions (e.g. __attribute__, __builtin_expect).
// Keep the compatibility surface local and DO NOT include <windows.h> here (it breaks godot-cpp due to macro collisions).
#if defined(_MSC_VER)
#ifndef __attribute__
#define __attribute__(x)
#endif
#ifndef __builtin_expect
#define __builtin_expect(x, y) (x)
#endif
#endif

extern "C" {
#ifdef likely
#undef likely
#endif
#ifdef unlikely
#undef unlikely
#endif

#include "cutils.h"
#include "iomem.h"
#include "virtio.h"
#include "machine.h"

extern const VirtMachineClass riscv_machine_class;
}

static char *dup_cstr(const char *s) {
	if (s == nullptr) {
		return nullptr;
	}
#if defined(_MSC_VER)
	return _strdup(s);
#else
	return strdup(s);
#endif
}

static bool read_file_bytes(const godot::String &path, std::vector<uint8_t> &out, godot::String &err) {
	out.clear();
	if (path.is_empty()) {
		err = "path is empty";
		return false;
	}
	const CharString p = path.utf8();
	std::ifstream f(p.get_data(), std::ios::binary);
	if (!f) {
		err = "failed to open: " + path;
		return false;
	}
	f.seekg(0, std::ios::end);
	const std::streamoff size = f.tellg();
	if (size < 0) {
		err = "failed to stat: " + path;
		return false;
	}
	f.seekg(0, std::ios::beg);
	out.resize(static_cast<size_t>(size));
	if (size > 0) {
		f.read(reinterpret_cast<char *>(out.data()), size);
		if (!f) {
			err = "failed to read: " + path;
			return false;
		}
	}
	return true;
}

void TinyEmuVM::_console_write_cb(void *opaque, const uint8_t *buf, int len) {
	if (opaque == nullptr || buf == nullptr || len <= 0) {
		return;
	}
	auto *self = static_cast<TinyEmuVM *>(opaque);
	self->_out.push(buf, static_cast<size_t>(len));
}

int TinyEmuVM::_console_read_cb(void *opaque, uint8_t *buf, int len) {
	if (opaque == nullptr || buf == nullptr || len <= 0) {
		return 0;
	}
	auto *self = static_cast<TinyEmuVM *>(opaque);
	const size_t n = self->_in.pop(buf, static_cast<size_t>(len));
	return static_cast<int>(n);
}

TinyEmuVM::TinyEmuVM() {}

TinyEmuVM::~TinyEmuVM() {
	destroy();
}

void TinyEmuVM::_bind_methods() {
	ClassDB::bind_method(D_METHOD("create", "kernel_path", "rootfs_path", "ram_size_mb"), &TinyEmuVM::create, DEFVAL(128));
	ClassDB::bind_method(D_METHOD("create_from_images", "bios_path", "kernel_path", "initrd_path", "ram_size_mb"), &TinyEmuVM::create_from_images, DEFVAL(128));
	ClassDB::bind_method(D_METHOD("destroy"), &TinyEmuVM::destroy);
	ClassDB::bind_method(D_METHOD("is_running"), &TinyEmuVM::is_running);

	ClassDB::bind_method(D_METHOD("write_console", "data"), &TinyEmuVM::write_console);
	ClassDB::bind_method(D_METHOD("poll_console"), &TinyEmuVM::poll_console);

	ClassDB::bind_method(D_METHOD("set_exec_cycles_per_tick", "cycles"), &TinyEmuVM::set_exec_cycles_per_tick);
	ClassDB::bind_method(D_METHOD("resize_console", "cols", "rows"), &TinyEmuVM::resize_console);
	ClassDB::bind_method(D_METHOD("get_vm_info"), &TinyEmuVM::get_vm_info);

	// ConPTY-like aliases
	ClassDB::bind_method(D_METHOD("open", "cols", "rows", "kernel_path", "rootfs_path", "ram_size_mb"), &TinyEmuVM::open, DEFVAL(128));
	ClassDB::bind_method(D_METHOD("open_from_images", "cols", "rows", "bios_path", "kernel_path", "initrd_path", "ram_size_mb"), &TinyEmuVM::open_from_images, DEFVAL(128));
	ClassDB::bind_method(D_METHOD("write", "data"), &TinyEmuVM::write);
	ClassDB::bind_method(D_METHOD("resize", "cols", "rows"), &TinyEmuVM::resize);
	ClassDB::bind_method(D_METHOD("close"), &TinyEmuVM::close);
	ClassDB::bind_method(D_METHOD("poll_data"), &TinyEmuVM::poll_data);

	ADD_SIGNAL(MethodInfo("data_received", PropertyInfo(Variant::PACKED_BYTE_ARRAY, "data")));
	ADD_SIGNAL(MethodInfo("process_exited", PropertyInfo(Variant::INT, "exit_code")));
}

Error TinyEmuVM::create(const String &kernel_path, const String &rootfs_path, int ram_size_mb) {
	if (_running.load()) {
		return ERR_ALREADY_IN_USE;
	}
	_kernel_path = kernel_path;
	_rootfs_path = rootfs_path;
	_bios_path = "";
	_initrd_path = "";
	_ram_mb = ram_size_mb > 0 ? ram_size_mb : 128;
	_stop_requested.store(false);
	_start_worker();
	return OK;
}

Error TinyEmuVM::create_from_images(const String &bios_path, const String &kernel_path, const String &initrd_path, int ram_size_mb) {
	if (_running.load()) {
		return ERR_ALREADY_IN_USE;
	}
	if (bios_path.is_empty() || kernel_path.is_empty()) {
		return ERR_INVALID_PARAMETER;
	}
	_bios_path = bios_path;
	_kernel_path = kernel_path;
	_initrd_path = initrd_path;
	_rootfs_path = "";
	_ram_mb = ram_size_mb > 0 ? ram_size_mb : 128;
	_stop_requested.store(false);
	_start_worker();
	return OK;
}

void TinyEmuVM::destroy() {
	_stop_worker();
}

bool TinyEmuVM::is_running() const {
	return _running.load();
}

void TinyEmuVM::write_console(const PackedByteArray &data) {
	if (!_running.load()) {
		return;
	}
	if (data.is_empty()) {
		return;
	}
	_in.push(data.ptr(), static_cast<size_t>(data.size()));
}

PackedByteArray TinyEmuVM::poll_console() {
	return poll_data();
}

void TinyEmuVM::set_exec_cycles_per_tick(int cycles) {
	if (cycles <= 0) {
		return;
	}
	_exec_cycles_per_tick = cycles;
}

void TinyEmuVM::resize_console(int cols, int rows) {
	if (cols > 0) {
		_cols = cols;
	}
	if (rows > 0) {
		_rows = rows;
	}
}

String TinyEmuVM::get_vm_info() const {
	String info;
	info += "TinyEmuVM (WIP)\n";
	info += "running=" + String(_running.load() ? "true" : "false") + "\n";
	info += "cols=" + String::num_int64(_cols) + " rows=" + String::num_int64(_rows) + "\n";
	info += "ram_mb=" + String::num_int64(_ram_mb) + "\n";
	info += "exec_cycles_per_tick=" + String::num_int64(_exec_cycles_per_tick) + "\n";
	info += "bios_path=" + _bios_path + "\n";
	info += "kernel_path=" + _kernel_path + "\n";
	info += "initrd_path=" + _initrd_path + "\n";
	info += "rootfs_path=" + _rootfs_path + "\n";
	return info;
}

int TinyEmuVM::open(int cols, int rows, const String &kernel_path, const String &rootfs_path, int ram_size_mb) {
	if (cols <= 0 || rows <= 0) {
		return ERR_INVALID_PARAMETER;
	}
	_cols = cols;
	_rows = rows;
	return create(kernel_path, rootfs_path, ram_size_mb);
}

int TinyEmuVM::open_from_images(int cols, int rows, const String &bios_path, const String &kernel_path, const String &initrd_path, int ram_size_mb) {
	if (cols <= 0 || rows <= 0) {
		return ERR_INVALID_PARAMETER;
	}
	_cols = cols;
	_rows = rows;
	return create_from_images(bios_path, kernel_path, initrd_path, ram_size_mb);
}

int TinyEmuVM::write(const PackedByteArray &data) {
	write_console(data);
	return static_cast<int>(data.size());
}

int TinyEmuVM::resize(int cols, int rows) {
	if (cols <= 0 || rows <= 0) {
		return ERR_INVALID_PARAMETER;
	}
	resize_console(cols, rows);
	return OK;
}

void TinyEmuVM::close() {
	destroy();
}

PackedByteArray TinyEmuVM::poll_data() {
	PackedByteArray result;
	if (!_running.load()) {
		return result;
	}

	std::vector<uint8_t> tmp;
	tmp.resize(64 * 1024);
	const size_t n = _out.pop(tmp.data(), tmp.size());
	if (n == 0) {
		return result;
	}
	result.resize(static_cast<int>(n));
	memcpy(result.ptrw(), tmp.data(), n);

	// Emit for compatibility with ConPTY-style consumption.
	emit_signal("data_received", result);
	return result;
}

void TinyEmuVM::_start_worker() {
	if (_worker != nullptr) {
		return;
	}
	_running.store(true);
	_worker = new std::thread(&TinyEmuVM::_worker_main, this);
}

void TinyEmuVM::_stop_worker() {
	if (_worker == nullptr) {
		_running.store(false);
		return;
	}
	_stop_requested.store(true);
	_worker->join();
	delete _worker;
	_worker = nullptr;
	_running.store(false);
	_stop_requested.store(false);

	// Parity signal name; exit_code=-1 means "stopped".
	emit_signal("process_exited", -1);
}

void TinyEmuVM::_worker_main() {
	// Default behavior: keep existing stub echo loop unless create_from_images() was used.
	if (_bios_path.is_empty()) {
		const char *banner =
				"[TinyEmuVM] WIP stub (not booting Linux yet)\r\n"
				"Call create_from_images(bios,kernel,initrd) to boot a VM.\r\n"
				"Type anything; bytes are echoed back via poll_data().\r\n\r\n";
		_out.push(reinterpret_cast<const uint8_t *>(banner), strlen(banner));

		std::vector<uint8_t> in_tmp;
		in_tmp.resize(16 * 1024);

		while (!_stop_requested.load()) {
			const size_t n = _in.pop(in_tmp.data(), in_tmp.size());
			if (n > 0) {
				_out.push(in_tmp.data(), n);
				continue;
			}

			std::this_thread::sleep_for(std::chrono::milliseconds(1));
		}
		return;
	}

	String err;
	std::vector<uint8_t> bios_bytes;
	std::vector<uint8_t> kernel_bytes;
	std::vector<uint8_t> initrd_bytes;

	if (!read_file_bytes(_bios_path, bios_bytes, err)) {
		const String msg = "[TinyEmuVM] failed to read bios: " + err + "\r\n";
		const CharString c = msg.utf8();
		_out.push(reinterpret_cast<const uint8_t *>(c.get_data()), static_cast<size_t>(c.length()));
		return;
	}
	if (!read_file_bytes(_kernel_path, kernel_bytes, err)) {
		const String msg = "[TinyEmuVM] failed to read kernel: " + err + "\r\n";
		const CharString c = msg.utf8();
		_out.push(reinterpret_cast<const uint8_t *>(c.get_data()), static_cast<size_t>(c.length()));
		return;
	}
	if (!_initrd_path.is_empty()) {
		if (!read_file_bytes(_initrd_path, initrd_bytes, err)) {
			const String msg = "[TinyEmuVM] failed to read initrd: " + err + "\r\n";
			const CharString c = msg.utf8();
			_out.push(reinterpret_cast<const uint8_t *>(c.get_data()), static_cast<size_t>(c.length()));
			return;
		}
	}

	CharacterDevice console_dev = {};
	console_dev.opaque = this;
	console_dev.write_data = &TinyEmuVM::_console_write_cb;
	console_dev.read_data = &TinyEmuVM::_console_read_cb;

	VirtMachineParams p = {};
	p.vmc = &riscv_machine_class;
	p.machine_name = dup_cstr("riscv64");
	p.ram_size = static_cast<uint64_t>(_ram_mb) << 20;
	p.rtc_real_time = true;
	p.console = &console_dev;
	p.cmdline = dup_cstr("console=hvc0");

	p.files[VM_FILE_BIOS].buf = bios_bytes.data();
	p.files[VM_FILE_BIOS].len = static_cast<int>(bios_bytes.size());
	p.files[VM_FILE_KERNEL].buf = kernel_bytes.data();
	p.files[VM_FILE_KERNEL].len = static_cast<int>(kernel_bytes.size());
	if (!initrd_bytes.empty()) {
		p.files[VM_FILE_INITRD].buf = initrd_bytes.data();
		p.files[VM_FILE_INITRD].len = static_cast<int>(initrd_bytes.size());
	}

	VirtMachine *vm = p.vmc->virt_machine_init(&p);
	std::free(p.machine_name);
	std::free(p.cmdline);
	p.machine_name = nullptr;
	p.cmdline = nullptr;

	if (vm == nullptr) {
		const char *msg = "[TinyEmuVM] virt_machine_init failed\r\n";
		_out.push(reinterpret_cast<const uint8_t *>(msg), strlen(msg));
		return;
	}

	int last_cols = _cols;
	int last_rows = _rows;

	const char *msg = "[TinyEmuVM] VM started\r\n";
	_out.push(reinterpret_cast<const uint8_t *>(msg), strlen(msg));

	std::vector<uint8_t> tmp_in;
	tmp_in.resize(64 * 1024);

	while (!_stop_requested.load()) {
		// Resize event (best-effort).
		const int cols = _cols;
		const int rows = _rows;
		if (cols != last_cols || rows != last_rows) {
			if (vm->console_dev) {
				virtio_console_resize_event(vm->console_dev, cols, rows);
			}
			last_cols = cols;
			last_rows = rows;
		}

		int delay_ms = 10;

		// Feed stdin to guest when virtio console queue is ready.
		if (vm->console_dev && virtio_console_can_write_data(vm->console_dev)) {
			delay_ms = 0;
			const int write_len = virtio_console_get_write_len(vm->console_dev);
			if (write_len > 0) {
				const int want = write_len < static_cast<int>(tmp_in.size()) ? write_len : static_cast<int>(tmp_in.size());
				const int got = _console_read_cb(this, tmp_in.data(), want);
				if (got > 0) {
					virtio_console_write_data(vm->console_dev, tmp_in.data(), got);
				}
			}
		}

		vm->vmc->virt_machine_interp(vm, _exec_cycles_per_tick);

		const int suggested = vm->vmc->virt_machine_get_sleep_duration(vm, delay_ms);
		if (suggested > 0) {
			std::this_thread::sleep_for(std::chrono::milliseconds(suggested));
		}
	}

	vm->vmc->virt_machine_end(vm);
}
