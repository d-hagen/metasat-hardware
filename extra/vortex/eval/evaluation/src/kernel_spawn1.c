// Test 3: spawn exactly 1 task on 1 thread.
// Uses vx_spawn_threads with num_tasks=1.
// Pass: vx_busy falls after spawn completes.
// Fail: vx_busy stays high.
// Diagnoses: does vx_spawn_threads work at all? Does the barrier release?
#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <VX_types.h>

void kernel(void *arg)
{
    uint64_t *karg = (uint64_t *)arg;
    uint8_t  *dest = (uint8_t *)karg[2];
    uint32_t  tid  = blockIdx.x;
    dest[tid] = 0xAB;  // write sentinel value
}

int main()
{
    uint64_t *arg       = (uint64_t *)0x5ffff000;
    uint32_t  num_tasks = 1;
    vx_spawn_threads(1, &num_tasks, 0, (vx_kernel_func_cb)kernel, arg);
    // bypass _Exit (hangs at fence in simulation)
    vx_tmc_zero();
    __builtin_unreachable();
}
