#pragma once

#if defined(_WIN32)

#include <stdint.h>
// Prefer Winsock's timeval definition to avoid duplicate types across headers.
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>

// Minimal stub. Upstream currently only includes <sys/time.h> for portability;
// TinyEMU core we compile on Windows does not depend on gettimeofday().
static int gettimeofday(struct timeval *tv, void *tz) {
	(void)tv;
	(void)tz;
	return -1;
}

#endif // _WIN32
