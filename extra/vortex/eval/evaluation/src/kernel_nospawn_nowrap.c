// nospawn (no memset/memcpy wraps)
#include <stdint.h>
#include <vx_intrinsics.h>

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
