#pragma once

#include "spsc_ring_buffer.h"

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
	void destroy();
	bool is_running() const;

	void write_console(const PackedByteArray &data);
	PackedByteArray poll_console();

	void set_exec_cycles_per_tick(int cycles);
	void resize_console(int cols, int rows);

	String get_vm_info() const;

	// ConPTY-like convenience aliases (for TerminalControl integration)
	int open(int cols, int rows, const String &kernel_path, const String &rootfs_path, int ram_size_mb = 128);
	int write(const PackedByteArray &data);
	int resize(int cols, int rows);
	void close();
	PackedByteArray poll_data();

protected:
	static void _bind_methods();

private:
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

	String _kernel_path;
	String _rootfs_path;

	jediterm_tinyemu::SpscRingBuffer _in{1 << 16}; // 64KiB
	jediterm_tinyemu::SpscRingBuffer _out{1 << 20}; // 1MiB
};

} // namespace godot

