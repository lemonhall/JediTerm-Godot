#pragma once

#if defined(_WIN32)

#include <stdint.h>

struct timeval {
	long tv_sec;
	long tv_usec;
};

// Minimal stub. Upstream currently only includes <sys/time.h> for portability;
// TinyEMU core we compile on Windows does not depend on gettimeofday().
static int gettimeofday(struct timeval *tv, void *tz) {
	(void)tv;
	(void)tz;
	return -1;
}

#endif // _WIN32
