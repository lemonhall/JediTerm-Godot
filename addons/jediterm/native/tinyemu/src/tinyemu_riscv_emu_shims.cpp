#include <cstdarg>
#include <cstdio>

extern "C" {
void vm_error(const char *fmt, ...);
}

void vm_error(const char *fmt, ...) {
	va_list ap;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}

