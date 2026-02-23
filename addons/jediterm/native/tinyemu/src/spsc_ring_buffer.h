#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace jediterm_tinyemu {

// Single-producer / single-consumer ring buffer for bytes.
// - Not thread-safe for multiple producers or multiple consumers.
// - Capacity is fixed; on overflow, push() writes as much as possible and returns bytes written.
class SpscRingBuffer final {
public:
	explicit SpscRingBuffer(size_t capacity) : _buf(capacity), _capacity(capacity) {}

	size_t capacity() const { return _capacity; }

	size_t size() const {
		const size_t head = _head.load(std::memory_order_acquire);
		const size_t tail = _tail.load(std::memory_order_acquire);
		return (tail + _capacity - head) % _capacity;
	}

	size_t free_space() const {
		// Keep one slot empty to distinguish full vs empty.
		return (_capacity - 1) - size();
	}

	size_t push(const uint8_t *data, size_t len) {
		if (!data || len == 0 || _capacity < 2) {
			return 0;
		}
		size_t written = 0;
		size_t head = _head.load(std::memory_order_acquire);
		size_t tail = _tail.load(std::memory_order_relaxed);

		const size_t max_writable = (_capacity - 1) - ((tail + _capacity - head) % _capacity);
		const size_t to_write = (len < max_writable) ? len : max_writable;
		for (; written < to_write; written++) {
			_buf[tail] = data[written];
			tail = (tail + 1) % _capacity;
		}
		_tail.store(tail, std::memory_order_release);
		return written;
	}

	size_t pop(uint8_t *out, size_t len) {
		if (!out || len == 0 || _capacity < 2) {
			return 0;
		}
		size_t read = 0;
		size_t head = _head.load(std::memory_order_relaxed);
		const size_t tail = _tail.load(std::memory_order_acquire);
		const size_t available = (tail + _capacity - head) % _capacity;
		const size_t to_read = (len < available) ? len : available;
		for (; read < to_read; read++) {
			out[read] = _buf[head];
			head = (head + 1) % _capacity;
		}
		_head.store(head, std::memory_order_release);
		return read;
	}

private:
	std::vector<uint8_t> _buf;
	size_t _capacity = 0;
	std::atomic<size_t> _head{0};
	std::atomic<size_t> _tail{0};
};

} // namespace jediterm_tinyemu

