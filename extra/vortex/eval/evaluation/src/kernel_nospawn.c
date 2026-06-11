// nospawn: single-thread compute, no spawn. Warp 0 reads the args pointer
// from mscratch (set by host vx_start via DCRs) and writes one byte.
// Pass condition: dest[0] == src[0]*2 (host initialises src[0]=0, so 0).
// Proves: args buffer is GPU-AXI reachable, mscratch CSR works, basic
//         load/store path is functional. If the host args allocator gives
//         an unreachable address (pre-ALLOC_BASE_ADDR-fix), the args load
//         here wedges with warp 0 stalled.

#include <stdint.h>
#include <vx_intrinsics.h>

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
    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg  = (uint64_t *)arg_addr;
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];
    dest[0] = (uint8_t)(src[0] * 2);
    vx_tmc_zero();
    __builtin_unreachable();
}
