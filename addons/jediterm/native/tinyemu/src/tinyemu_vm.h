#pragma once

#include "spsc_ring_buffer.h"

// CharacterDevice lives as long as the VM
extern "C" {
#include "virtio.h"
}

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <atomic>
#include <thread>

namespace godot {

class TinyEmuVM : public RefCounted {
	GDCLASS(TinyEmuVM, RefCounted)

public:
	TinyEmuVM();
	~TinyEmuVM();

	// PRD API
	Error create(const String &kernel_path, const String &rootfs_path, int ram_size_mb = 128);
	Error create_from_images(const String &bios_path, const String &kernel_path, const String &initrd_path, int ram_size_mb = 128);
	Error create_from_disk_images(const String &bios_path, const String &kernel_path, const String &rootfs_path, int ram_size_mb = 128);
	void destroy();
	bool is_running() const;

	void write_console(const PackedByteArray &data);
	PackedByteArray poll_console();

	void set_exec_cycles_per_tick(int cycles);
	void resize_console(int cols, int rows);

	String get_vm_info() const;

	// PRD-0006A: networking toggles (call before create/open).
	void set_network_enabled(bool enabled);
	void set_proxy_url(const String &url);

	// ConPTY-like convenience aliases (for TerminalControl integration)
	int open(int cols, int rows, const String &kernel_path, const String &rootfs_path, int ram_size_mb = 128);
	int open_from_images(int cols, int rows, const String &bios_path, const String &kernel_path, const String &initrd_path, int ram_size_mb = 128);
	int open_from_disk_images(int cols, int rows, const String &bios_path, const String &kernel_path, const String &rootfs_path, int ram_size_mb = 128);
	int write(const PackedByteArray &data);
	int resize(int cols, int rows);
	void close();
	PackedByteArray poll_data();

protected:
	static void _bind_methods();

private:
	static void _console_write_cb(void *opaque, const uint8_t *buf, int len);
	static int _console_read_cb(void *opaque, uint8_t *buf, int len);

	void _start_worker();
	void _stop_worker();
	void _worker_main();

	std::atomic<bool> _running{false};
	std::atomic<bool> _stop_requested{false};
	std::thread *_worker = nullptr;

	int _cols = 80;
	int _rows = 24;
	int _ram_mb = 128;
	int _exec_cycles_per_tick = (1 << 20);

	bool _network_enabled = false;
	String _proxy_url;

	String _kernel_path;
	String _rootfs_path;
	String _bios_path;
	String _initrd_path;

	jediterm_tinyemu::SpscRingBuffer _in{1 << 16}; // 64KiB
	jediterm_tinyemu::SpscRingBuffer _out{1 << 20}; // 1MiB
        CharacterDevice _console_dev_storage{};
};

} // namespace godot
