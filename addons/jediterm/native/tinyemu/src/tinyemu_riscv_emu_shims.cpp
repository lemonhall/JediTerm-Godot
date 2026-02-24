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

#if defined(_MSC_VER)
// slirp/ defines insque/remque macros to slirp_* and expects an external definition.
// Upstream misc.c marks them inline, which MSVC may not emit as linkable symbols.
extern "C" {
struct slirp_quehead {
	slirp_quehead *qh_link;
	slirp_quehead *qh_rlink;
};

void slirp_insque(void *a, void *b) {
	auto *element = static_cast<slirp_quehead *>(a);
	auto *head = static_cast<slirp_quehead *>(b);
	element->qh_link = head->qh_link;
	head->qh_link = element;
	element->qh_rlink = head;
	static_cast<slirp_quehead *>(element->qh_link)->qh_rlink = element;
}

void slirp_remque(void *a) {
	auto *element = static_cast<slirp_quehead *>(a);
	static_cast<slirp_quehead *>(element->qh_link)->qh_rlink = element->qh_rlink;
	static_cast<slirp_quehead *>(element->qh_rlink)->qh_link = element->qh_link;
	element->qh_rlink = nullptr;
}
}
#endif
