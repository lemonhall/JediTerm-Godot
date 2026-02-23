#pragma once

#if defined(_WIN32)

#include <io.h>
#include <process.h>
#include <stdint.h>

// Minimal POSIX surface used by upstream includes.
#ifndef ssize_t
typedef intptr_t ssize_t;
#endif

// Map common POSIX names to MSVC CRT names when they appear.
#ifndef STDIN_FILENO
#define STDIN_FILENO 0
#endif
#ifndef STDOUT_FILENO
#define STDOUT_FILENO 1
#endif
#ifndef STDERR_FILENO
#define STDERR_FILENO 2
#endif

#ifndef close
#define close _close
#endif
#ifndef read
#define read _read
#endif
#ifndef write
#define write _write
#endif
#ifndef lseek
#define lseek _lseek
#endif

#endif // _WIN32

