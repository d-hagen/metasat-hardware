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
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];
    dest[0] = (uint8_t)(src[0] * 2);
    return 0;
}
