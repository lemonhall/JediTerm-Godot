#include "tinyemu_vm.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/global_constants.hpp>

#include <chrono>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

using namespace godot;

TinyEmuVM::TinyEmuVM() {}

TinyEmuVM::~TinyEmuVM() {
	destroy();
}

void TinyEmuVM::_bind_methods() {
	ClassDB::bind_method(D_METHOD("create", "kernel_path", "rootfs_path", "ram_size_mb"), &TinyEmuVM::create, DEFVAL(128));
	ClassDB::bind_method(D_METHOD("destroy"), &TinyEmuVM::destroy);
	ClassDB::bind_method(D_METHOD("is_running"), &TinyEmuVM::is_running);

	ClassDB::bind_method(D_METHOD("write_console", "data"), &TinyEmuVM::write_console);
	ClassDB::bind_method(D_METHOD("poll_console"), &TinyEmuVM::poll_console);

	ClassDB::bind_method(D_METHOD("set_exec_cycles_per_tick", "cycles"), &TinyEmuVM::set_exec_cycles_per_tick);
	ClassDB::bind_method(D_METHOD("resize_console", "cols", "rows"), &TinyEmuVM::resize_console);
	ClassDB::bind_method(D_METHOD("get_vm_info"), &TinyEmuVM::get_vm_info);

	// ConPTY-like aliases
	ClassDB::bind_method(D_METHOD("open", "cols", "rows", "kernel_path", "rootfs_path", "ram_size_mb"), &TinyEmuVM::open, DEFVAL(128));
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
	info += "kernel_path=" + _kernel_path + "\n";
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
	// Stub implementation: echo loop to validate I/O plumbing.
	{
		const char *banner =
				"[TinyEmuVM] WIP stub (not booting Linux yet)\r\n"
				"Type anything; bytes are echoed back via poll_data().\r\n\r\n";
		_out.push(reinterpret_cast<const uint8_t *>(banner), strlen(banner));
	}

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
}

