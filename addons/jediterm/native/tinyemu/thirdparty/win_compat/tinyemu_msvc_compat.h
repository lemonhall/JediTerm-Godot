#pragma once

// Compatibility layer for building upstream TinyEMU (riscv-emu) C sources with MSVC.
// Keep this header lightweight and safe to force-include for both C and C++.

#if defined(_MSC_VER)

// GCC/Clang attributes used by upstream headers.
#ifndef __attribute__
#define __attribute__(x)
#endif

// Branch prediction hint.
#ifndef __builtin_expect
#define __builtin_expect(x, y) (x)
#endif

// Some code assumes __func__ exists.
#ifndef __func__
#define __func__ __FUNCTION__
#endif

#endif // _MSC_VER

#if defined(_WIN32)

// Provide clock_gettime(CLOCK_MONOTONIC, ...) used by riscv_machine.c.
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <time.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stddef.h>

#ifdef SEVERITY_WARNING
#undef SEVERITY_WARNING
#endif
#ifdef SEVERITY_ERROR
#undef SEVERITY_ERROR
#endif

#if defined(_MSC_VER)
#include <intrin.h>

static __forceinline int __builtin_clz(unsigned int x) {
	unsigned long index;
	if (_BitScanReverse(&index, x)) {
		return 31 - (int)index;
	}
	return 32;
}

static __forceinline int __builtin_clzll(unsigned long long x) {
	unsigned long index;
	if (_BitScanReverse64(&index, x)) {
		return 63 - (int)index;
	}
	return 64;
}
#endif

#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC 1
#endif

static int clock_gettime(int clk_id, struct timespec *ts) {
	(void)clk_id;
	static LARGE_INTEGER s_freq;
	static BOOL s_has_freq = FALSE;
	LARGE_INTEGER counter;

	if (!s_has_freq) {
		s_has_freq = QueryPerformanceFrequency(&s_freq);
	}
	QueryPerformanceCounter(&counter);

	if (!s_has_freq || s_freq.QuadPart == 0) {
		ts->tv_sec = 0;
		ts->tv_nsec = 0;
		return 0;
	}

	const double seconds = (double)counter.QuadPart / (double)s_freq.QuadPart;
	ts->tv_sec = (time_t)seconds;
	ts->tv_nsec = (long)((seconds - (double)ts->tv_sec) * 1000000000.0);
	return 0;
}

// slirp/ socket.c uses iovec even on Windows builds.
// Provide a minimal definition so MSVC can compile the SLIRP sources.
struct iovec {
	void *iov_base;
	size_t iov_len;
};

#endif // _WIN32
