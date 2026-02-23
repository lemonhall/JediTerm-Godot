#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <atomic>
#include <mutex>
#include <thread>
#include <vector>

namespace godot {

class ConPTY : public RefCounted {
	GDCLASS(ConPTY, RefCounted)

public:
	ConPTY();
	~ConPTY();

	int open(int cols, int rows, const String &command);
	int write(const PackedByteArray &data);
	int resize(int cols, int rows);
	void close();
	PackedByteArray poll_data();

protected:
	static void _bind_methods();

private:
	bool _is_opened = false;

#if defined(_WIN32) && !defined(_CONPTY_DISABLED)
	void *_hpc = nullptr; // HPCON (opaque)
	void *_h_in_read = nullptr; // input read handle passed to ConPTY (may need to stay open)
	void *_h_out_write = nullptr; // output write handle passed to ConPTY (may need to stay open)
	void *_h_in_write = nullptr;
	void *_h_out_read = nullptr;
	void *_h_process = nullptr;
	void *_h_thread = nullptr;

	std::thread *_reader_thread = nullptr;
	std::atomic<bool> _stop_requested;

	// Poll-mode buffer (replaces call_deferred signal emission)
	std::mutex _buffer_mutex;
	std::vector<uint8_t> _pending_buffer;
	std::atomic<int> _pending_exit_code{-1};
	std::atomic<bool> _process_exited_flag{false};

	void _start_reader_thread();
	void _stop_reader_thread();
#endif
};

} // namespace godot
