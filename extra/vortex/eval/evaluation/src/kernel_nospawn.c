// Test 2: single-thread computation, no spawn.
// Warp 0 does the work directly then deactivates.
// Pass: vx_busy falls after dest[0] is written.
// Fail: vx_busy stays high.
// Diagnoses: can warp 0 execute a memory read/write and complete?
#include <stdint.h>
#include <vx_intrinsics.h>
#include <VX_types.h>

int main()
{
    uint64_t *arg  = (uint64_t *)csr_read(VX_CSR_MSCRATCH);
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];
    dest[0] = (uint8_t)(src[0] * 2);
    vx_tmc_zero();
    __builtin_unreachable();
}
