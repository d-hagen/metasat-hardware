// Test 1: bare minimum — GPU starts and immediately deactivates.
// Pass: vx_busy falls within a few cycles of reset deassertion.
// Fail: vx_busy stays high forever.
// Diagnoses: can the GPU start and stop at all?
#include <vx_intrinsics.h>

int main()
{
    vx_tmc_zero();
    __builtin_unreachable();
}
