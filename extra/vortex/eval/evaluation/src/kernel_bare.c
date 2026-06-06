// Test 1: bare minimum — GPU starts and immediately deactivates.
// Pass: vx_busy falls within a few cycles of reset deassertion.
// Fail: vx_busy stays high forever.
// Diagnoses: can the GPU start and stop at all?
#include <stdint.h>
#include <vx_intrinsics.h>

// SIMT-safe memset — overrides newlib's jump-table version
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
    vx_tmc_zero();
    __builtin_unreachable();
}
