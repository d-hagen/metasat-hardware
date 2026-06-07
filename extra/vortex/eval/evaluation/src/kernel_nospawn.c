// Test 2: single-thread computation, no spawn.
// Warp 0 does the work directly then deactivates.
// Pass: vx_busy falls after dest[0] is written.
// Fail: vx_busy stays high.
// Diagnoses: can warp 0 execute a memory read/write and complete?
#include <stdint.h>
#include <vx_intrinsics.h>

#define KERNEL_ARG_DEV_MEM_ADDR 0x5ffff000

extern "C" __attribute__((used)) void *__wrap_memcpy(void *d, const void *s, __SIZE_TYPE__ n) {
    char *dp = (char *)d; const char *sp = (const char *)s;
    while (n--) *dp++ = *sp++; return d;
}
extern "C" __attribute__((used)) void *__wrap_memset(void *s, int c, __SIZE_TYPE__ n) {
    unsigned char *p = (unsigned char *)s;
    while (n--) *p++ = (unsigned char)c;
    return s;
}

int main()
{
    uint64_t *arg  = (uint64_t *)KERNEL_ARG_DEV_MEM_ADDR;
    volatile uint8_t *src  = (volatile uint8_t *)arg[1];
    volatile uint8_t *dest = (volatile uint8_t *)arg[2];
    dest[0] = (uint8_t)(src[0] * 2);
    // Force a real memory read from a different cache line than the prior
    // store. Same-address volatile reload was forwarded from the store
    // buffer and did not drain the write. Reading the arg block at
    // KERNEL_ARG_DEV_MEM_ADDR (different page from dest) cannot be
    // store-forwarded and forces an AXI round-trip, which back-pressures
    // until the prior store leaves the LSU.
    volatile uint8_t *flush = (volatile uint8_t *)KERNEL_ARG_DEV_MEM_ADDR;
    uint8_t sink = flush[0];
    (void)sink;
    vx_tmc_zero();
    __builtin_unreachable();
}
