// bare: minimal sanity test. Warp 0 enters main, deactivates immediately.
// Pass condition: vx_busy falls within a few cycles of reset deassert and
// the host's verification loop passes (with SIZE=1 and host-cleared dest,
// "no-op kernel" trivially passes the dest[0]==2*0 check).
// Proves: _start, init_regs, __init_tls, BSS memset, libc_init_array, main
//         call, vx_tmc_zero all work end-to-end.

#include <stdint.h>
#include <vx_intrinsics.h>

// SIMT-safe memset/memcpy. newlib's default versions use jalr jump tables
// which Vortex cannot handle SIMT-divergently. These plain byte loops are
// pulled in via -Wl,--wrap=memset,--wrap=memcpy at link time.
extern "C" __attribute__((used)) void *__wrap_memcpy(void *d, const void *s, __SIZE_TYPE__ n) {
    char *dp = (char *)d; const char *sp = (const char *)s;
    while (n--) *dp++ = *sp++; return d;
}
extern "C" __attribute__((used)) void *__wrap_memset(void *s, int c, __SIZE_TYPE__ n) {
    unsigned char *p = (unsigned char *)s;
    while (n--) *p++ = (unsigned char)c;
    return s;
}

int main() {
    vx_tmc_zero();
    __builtin_unreachable();
}
