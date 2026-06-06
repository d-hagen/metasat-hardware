// Test 2: single-thread computation, no spawn.
// Warp 0 does the work directly then deactivates.
// Pass: vx_busy falls after dest[0] is written.
// Fail: vx_busy stays high.
// Diagnoses: can warp 0 execute a memory read/write and complete?
#include <stdint.h>
#include <vx_intrinsics.h>

#define KERNEL_ARG_DEV_MEM_ADDR 0x5ffff000

int main()
{
    uint64_t *arg  = (uint64_t *)KERNEL_ARG_DEV_MEM_ADDR;
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];
    dest[0] = (uint8_t)(src[0] * 2);
    vx_tmc_zero();
    __builtin_unreachable();
}
