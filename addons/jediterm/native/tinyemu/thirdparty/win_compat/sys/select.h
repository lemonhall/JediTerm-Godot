#pragma once

#if defined(_WIN32)

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

// Provide fd_set/timeval for builds that include <sys/select.h>.
#include <winsock2.h>
#include <ws2tcpip.h>

#endif // _WIN32

