#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <atomic>
#include <mutex>
#include <thread>
#include <vector>

namespace godot {

class PosixPTY : public RefCounted {
	GDCLASS(PosixPTY, RefCounted)

public:
	PosixPTY();
	~PosixPTY();

	int open(int cols, int rows, const String &command);
	int write(const PackedByteArray &data);
	int resize(int cols, int rows);
	void close();
	PackedByteArray poll_data();

protected:
	static void _bind_methods();

private:
	bool _is_opened = false;

	int _master_fd = -1;
	std::atomic<int> _child_pid{-1};

	std::thread *_reader_thread = nullptr;
	std::atomic<bool> _stop_requested;

	std::mutex _buffer_mutex;
	std::vector<uint8_t> _pending_buffer;
	std::atomic<int> _pending_exit_code{-1};
	std::atomic<bool> _process_exited_flag{false};

	void _start_reader_thread();
	void _stop_reader_thread();
};

} // namespace godot
