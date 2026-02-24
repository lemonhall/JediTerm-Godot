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

#ifdef CONFIG_SLIRP
#include "slirp/libslirp.h"
#endif
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

#ifdef CONFIG_SLIRP
static void slirp_write_packet(EthernetDevice *net, const uint8_t *buf, int len) {
	if (net == nullptr || buf == nullptr || len <= 0) {
		return;
	}
	auto *slirp_state = static_cast<Slirp *>(net->opaque);
	if (slirp_state == nullptr) {
		return;
	}
	slirp_input(slirp_state, buf, len);
}

extern "C" int slirp_can_output(void *opaque) {
	auto *net = static_cast<EthernetDevice *>(opaque);
	if (net == nullptr || net->device_can_write_packet == nullptr) {
		return 0;
	}
	return net->device_can_write_packet(net) ? 1 : 0;
}

extern "C" void slirp_output(void *opaque, const uint8_t *pkt, int pkt_len) {
	auto *net = static_cast<EthernetDevice *>(opaque);
	if (net == nullptr || net->device_write_packet == nullptr || pkt == nullptr || pkt_len <= 0) {
		return;
	}
	net->device_write_packet(net, pkt, pkt_len);
}

#if defined(_WIN32)
// Windows Winsock does not provide inet_aton().
extern "C" int inet_aton(const char *cp, struct in_addr *ia) {
	if (cp == nullptr || ia == nullptr) {
		return 0;
	}
	return InetPtonA(AF_INET, cp, ia) == 1 ? 1 : 0;
}
#endif

#if !defined(EMSCRIPTEN)
static void slirp_select_fill1(EthernetDevice *net, int *pfd_max, fd_set *rfds, fd_set *wfds, fd_set *efds, int *pdelay) {
	auto *slirp_state = static_cast<Slirp *>(net->opaque);
	if (slirp_state == nullptr) {
		return;
	}
	slirp_select_fill(slirp_state, pfd_max, rfds, wfds, efds);
	(void)pdelay;
}

static void slirp_select_poll1(EthernetDevice *net, fd_set *rfds, fd_set *wfds, fd_set *efds, int select_ret) {
	auto *slirp_state = static_cast<Slirp *>(net->opaque);
	if (slirp_state == nullptr) {
		return;
	}
	slirp_select_poll(slirp_state, rfds, wfds, efds, (select_ret <= 0));
}
#endif

static EthernetDevice *slirp_open_local() {
	auto *net = static_cast<EthernetDevice *>(mallocz(sizeof(EthernetDevice)));
	if (net == nullptr) {
		return nullptr;
	}

	struct in_addr net_addr;
	struct in_addr mask;
	struct in_addr host;
	struct in_addr dhcp;
	struct in_addr dns;
	net_addr.s_addr = htonl(0x0a000200); // 10.0.2.0
	mask.s_addr = htonl(0xffffff00); // 255.255.255.0
	host.s_addr = htonl(0x0a000202); // 10.0.2.2
	dhcp.s_addr = htonl(0x0a00020f); // 10.0.2.15
	dns.s_addr = htonl(0x0a000203); // 10.0.2.3

	const char *bootfile = nullptr;
	const char *vhostname = nullptr;
	const int restricted = 0;

	Slirp *slirp_state = slirp_init(restricted, net_addr, mask, host, vhostname, "", bootfile, dhcp, dns, net);
	if (slirp_state == nullptr) {
		free(net);
		return nullptr;
	}

	net->mac_addr[0] = 0x02;
	net->mac_addr[1] = 0x00;
	net->mac_addr[2] = 0x00;
	net->mac_addr[3] = 0x00;
	net->mac_addr[4] = 0x00;
	net->mac_addr[5] = 0x01;

	net->opaque = slirp_state;
	net->write_packet = slirp_write_packet;
#if !defined(EMSCRIPTEN)
	net->select_fill = slirp_select_fill1;
	net->select_poll = slirp_select_poll1;
#endif

	return net;
}
#endif // CONFIG_SLIRP

void TinyEmuVM::_console_write_cb(void *opaque, const uint8_t *buf, int len) {
	if (opaque == nullptr || buf == nullptr || len <= 0) {
		return;
	}
	auto *self = static_cast<TinyEmuVM *>(opaque);
        fprintf(stderr, "_console_write_cb: len=%d first=0x%02x\n", len, buf[0]);
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
	ClassDB::bind_method(D_METHOD("create_from_disk_images", "bios_path", "kernel_path", "rootfs_path", "ram_size_mb"), &TinyEmuVM::create_from_disk_images, DEFVAL(128));
	ClassDB::bind_method(D_METHOD("destroy"), &TinyEmuVM::destroy);
	ClassDB::bind_method(D_METHOD("is_running"), &TinyEmuVM::is_running);

	ClassDB::bind_method(D_METHOD("write_console", "data"), &TinyEmuVM::write_console);
	ClassDB::bind_method(D_METHOD("poll_console"), &TinyEmuVM::poll_console);

	ClassDB::bind_method(D_METHOD("set_exec_cycles_per_tick", "cycles"), &TinyEmuVM::set_exec_cycles_per_tick);
	ClassDB::bind_method(D_METHOD("resize_console", "cols", "rows"), &TinyEmuVM::resize_console);
	ClassDB::bind_method(D_METHOD("get_vm_info"), &TinyEmuVM::get_vm_info);

	ClassDB::bind_method(D_METHOD("set_network_enabled", "enabled"), &TinyEmuVM::set_network_enabled);
	ClassDB::bind_method(D_METHOD("set_proxy_url", "url"), &TinyEmuVM::set_proxy_url);

	// ConPTY-like aliases
	ClassDB::bind_method(D_METHOD("open", "cols", "rows", "kernel_path", "rootfs_path", "ram_size_mb"), &TinyEmuVM::open, DEFVAL(128));
	ClassDB::bind_method(D_METHOD("open_from_images", "cols", "rows", "bios_path", "kernel_path", "initrd_path", "ram_size_mb"), &TinyEmuVM::open_from_images, DEFVAL(128));
	ClassDB::bind_method(D_METHOD("open_from_disk_images", "cols", "rows", "bios_path", "kernel_path", "rootfs_path", "ram_size_mb"), &TinyEmuVM::open_from_disk_images, DEFVAL(128));
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

Error TinyEmuVM::create_from_disk_images(const String &bios_path, const String &kernel_path, const String &rootfs_path, int ram_size_mb) {
	if (_running.load()) {
		return ERR_ALREADY_IN_USE;
	}
	if (bios_path.is_empty() || kernel_path.is_empty() || rootfs_path.is_empty()) {
		return ERR_INVALID_PARAMETER;
	}
	_bios_path = bios_path;
	_kernel_path = kernel_path;
	_rootfs_path = rootfs_path;
	_initrd_path = "";
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
	info += "network_enabled=" + String(_network_enabled ? "true" : "false") + "\n";
	info += "proxy_url=" + _proxy_url + "\n";
	info += "bios_path=" + _bios_path + "\n";
	info += "kernel_path=" + _kernel_path + "\n";
	info += "initrd_path=" + _initrd_path + "\n";
	info += "rootfs_path=" + _rootfs_path + "\n";
	return info;
}

void TinyEmuVM::set_network_enabled(bool enabled) {
	if (_running.load()) {
		return;
	}
	_network_enabled = enabled;
}

void TinyEmuVM::set_proxy_url(const String &url) {
	if (_running.load()) {
		return;
	}
	_proxy_url = url;
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

int TinyEmuVM::open_from_disk_images(int cols, int rows, const String &bios_path, const String &kernel_path, const String &rootfs_path, int ram_size_mb) {
	if (cols <= 0 || rows <= 0) {
		return ERR_INVALID_PARAMETER;
	}
	_cols = cols;
	_rows = rows;
	return create_from_disk_images(bios_path, kernel_path, rootfs_path, ram_size_mb);
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
				"Call create_from_images(bios,kernel,initrd) OR create_from_disk_images(bios,kernel,rootfs) to boot a VM.\r\n"
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
	std::vector<uint8_t> rootfs_bytes;

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
	if (!_rootfs_path.is_empty()) {
		if (!read_file_bytes(_rootfs_path, rootfs_bytes, err)) {
			const String msg = "[TinyEmuVM] failed to read rootfs: " + err + "\r\n";
			const CharString c = msg.utf8();
			_out.push(reinterpret_cast<const uint8_t *>(c.get_data()), static_cast<size_t>(c.length()));
			return;
		}
	}

	struct MemBlockDeviceState {
		BlockDevice bs = {};
		std::vector<uint8_t> data;
	};

	auto mem_get_sector_count = [](BlockDevice *bs) -> int64_t {
		auto *st = static_cast<MemBlockDeviceState *>(bs->opaque);
		const int64_t sz = static_cast<int64_t>(st->data.size());
		if (sz <= 0) {
			return 0;
		}
		// 512-byte sectors.
		return (sz + 511) / 512;
	};
	auto mem_read_async = [](BlockDevice *bs, uint64_t sector_num, uint8_t *buf, int n, BlockDeviceCompletionFunc *cb, void *opaque) -> int {
		auto *st = static_cast<MemBlockDeviceState *>(bs->opaque);
		const uint64_t offset = sector_num * 512ULL;
		const uint64_t len = static_cast<uint64_t>(n) * 512ULL;
		(void)cb;
		(void)opaque;
		if (buf == nullptr || n <= 0) {
			return 0;
		}

		const uint64_t size = static_cast<uint64_t>(st->data.size());
		if (offset >= size) {
			memset(buf, 0, static_cast<size_t>(len));
			return 0;
		}

		const uint64_t avail = size - offset;
		const uint64_t copy_len = avail < len ? avail : len;
		memcpy(buf, st->data.data() + static_cast<size_t>(offset), static_cast<size_t>(copy_len));
		if (copy_len < len) {
			memset(buf + static_cast<size_t>(copy_len), 0, static_cast<size_t>(len - copy_len));
		}
		return 0;
	};
	auto mem_write_async = [](BlockDevice *bs, uint64_t sector_num, const uint8_t *buf, int n, BlockDeviceCompletionFunc *cb, void *opaque) -> int {
		auto *st = static_cast<MemBlockDeviceState *>(bs->opaque);
		const uint64_t offset = sector_num * 512ULL;
		const uint64_t len = static_cast<uint64_t>(n) * 512ULL;
		(void)cb;
		(void)opaque;
		if (buf == nullptr || n <= 0) {
			return 0;
		}

		const uint64_t size = static_cast<uint64_t>(st->data.size());
		if (offset >= size) {
			return -1;
		}

		const uint64_t avail = size - offset;
		const uint64_t copy_len = avail < len ? avail : len;
		memcpy(st->data.data() + static_cast<size_t>(offset), buf, static_cast<size_t>(copy_len));
		return copy_len < len ? -1 : 0;
	};

        // Use persistent member instead of stack-local variable
        _console_dev_storage.opaque = this;
        _console_dev_storage.write_data = &TinyEmuVM::_console_write_cb;
        _console_dev_storage.read_data = &TinyEmuVM::_console_read_cb;

	EthernetDevice *net_dev = nullptr;
	if (_network_enabled) {
#ifdef CONFIG_SLIRP
		net_dev = slirp_open_local();
		if (net_dev == nullptr) {
			const char *msg = "[TinyEmuVM] network enabled but slirp_open failed\r\n";
			_out.push(reinterpret_cast<const uint8_t *>(msg), strlen(msg));
		}
#else
		const char *msg = "[TinyEmuVM] network requested but CONFIG_SLIRP is disabled at build time\r\n";
		_out.push(reinterpret_cast<const uint8_t *>(msg), strlen(msg));
#endif
	}

	VirtMachineParams p = {};
	p.vmc = &riscv_machine_class;
	p.machine_name = dup_cstr("riscv64");
	p.ram_size = static_cast<uint64_t>(_ram_mb) << 20;
	p.rtc_real_time = true;
        p.console = &_console_dev_storage;
	if (net_dev != nullptr) {
		p.eth_count = 1;
		p.tab_eth[0].net = net_dev;
	}
	if (!_rootfs_path.is_empty()) {
		p.cmdline = dup_cstr("earlycon=sbi console=hvc0 root=/dev/vda rw");
	} else {
		p.cmdline = dup_cstr("earlycon=sbi console=hvc0");
	}

	{
		String boot_mode = "[TinyEmuVM] boot mode: ";
		if (!_rootfs_path.is_empty()) {
			boot_mode += "disk rootfs (/dev/vda)";
		} else if (!_initrd_path.is_empty()) {
			boot_mode += "initrd (cpio)";
		} else {
			boot_mode += "kernel-only";
		}
		boot_mode += "\r\n";
		const CharString c = boot_mode.utf8();
		_out.push(reinterpret_cast<const uint8_t *>(c.get_data()), static_cast<size_t>(c.length()));
	}

	p.files[VM_FILE_BIOS].buf = bios_bytes.data();
	p.files[VM_FILE_BIOS].len = static_cast<int>(bios_bytes.size());
	p.files[VM_FILE_KERNEL].buf = kernel_bytes.data();
	p.files[VM_FILE_KERNEL].len = static_cast<int>(kernel_bytes.size());
	if (!initrd_bytes.empty()) {
		p.files[VM_FILE_INITRD].buf = initrd_bytes.data();
		p.files[VM_FILE_INITRD].len = static_cast<int>(initrd_bytes.size());
	}
	MemBlockDeviceState *mem_drive = nullptr;
	if (!rootfs_bytes.empty()) {
		mem_drive = new MemBlockDeviceState();
		mem_drive->data = std::move(rootfs_bytes);
		mem_drive->bs.opaque = mem_drive;
		mem_drive->bs.get_sector_count = mem_get_sector_count;
		mem_drive->bs.read_async = mem_read_async;
		mem_drive->bs.write_async = mem_write_async;

		p.drive_count = 1;
		p.tab_drive[0].block_dev = &mem_drive->bs;
	}

	VirtMachine *vm = p.vmc->virt_machine_init(&p);
	std::free(p.machine_name);
	std::free(p.cmdline);
	p.machine_name = nullptr;
	p.cmdline = nullptr;

	if (vm == nullptr) {
		if (mem_drive) {
			delete mem_drive;
			mem_drive = nullptr;
		}
		const char *msg = "[TinyEmuVM] virt_machine_init failed\r\n";
		_out.push(reinterpret_cast<const uint8_t *>(msg), strlen(msg));
		return;
	}

	int last_cols = _cols;
	int last_rows = _rows;

	const char *msg = "[TinyEmuVM] VM started\r\n";
	_out.push(reinterpret_cast<const uint8_t *>(msg), strlen(msg));

	if (vm->net && vm->net->device_set_carrier) {
		vm->net->device_set_carrier(vm->net, true);
	}

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

		fd_set rfds;
		fd_set wfds;
		fd_set efds;
		FD_ZERO(&rfds);
		FD_ZERO(&wfds);
		FD_ZERO(&efds);
		int fd_max = -1;

		int delay_ms = vm->vmc->virt_machine_get_sleep_duration(vm, 10);
		if (delay_ms < 0) {
			delay_ms = 0;
		}

		// Feed stdin to guest when virtio console queue is ready.
		if (vm->console_dev && virtio_console_can_write_data(vm->console_dev)) {
			const int write_len = virtio_console_get_write_len(vm->console_dev);
			if (write_len > 0) {
				const int want = write_len < static_cast<int>(tmp_in.size()) ? write_len : static_cast<int>(tmp_in.size());
				const int got = _console_read_cb(this, tmp_in.data(), want);
				if (got > 0) {
					virtio_console_write_data(vm->console_dev, tmp_in.data(), got);
				}
			}
		}

		int select_ret = 0;
		if (vm->net && vm->net->select_fill && vm->net->select_poll) {
			vm->net->select_fill(vm->net, &fd_max, &rfds, &wfds, &efds, &delay_ms);
			struct timeval tv;
			tv.tv_sec = delay_ms / 1000;
			tv.tv_usec = (delay_ms % 1000) * 1000;
			if (fd_max >= 0) {
				select_ret = select(fd_max + 1, &rfds, &wfds, &efds, &tv);
			} else if (delay_ms > 0) {
				std::this_thread::sleep_for(std::chrono::milliseconds(delay_ms));
			}
			vm->net->select_poll(vm->net, &rfds, &wfds, &efds, select_ret);
		} else if (delay_ms > 0) {
			std::this_thread::sleep_for(std::chrono::milliseconds(delay_ms));
		}

		vm->vmc->virt_machine_interp(vm, _exec_cycles_per_tick);
	}

	vm->vmc->virt_machine_end(vm);

	if (net_dev != nullptr) {
#ifdef CONFIG_SLIRP
		auto *slirp_state = static_cast<Slirp *>(net_dev->opaque);
		if (slirp_state != nullptr) {
			slirp_cleanup(slirp_state);
			net_dev->opaque = nullptr;
		}
#endif
		std::free(net_dev);
		net_dev = nullptr;
	}

	if (mem_drive) {
		delete mem_drive;
		mem_drive = nullptr;
	}
}
