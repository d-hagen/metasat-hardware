// spawn1: vx_spawn_threads with exactly one task. With num_tasks=1 the
// spawn library takes the remaining-tasks path (single thread, no full
// multi-warp spawn), which is the simplest exercise of the library.
// Pass condition: dest[0] sentinel.
// Proves: vx_spawn_threads + remaining-tasks path work.

#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <VX_types.h>

void kernel(void *arg) {
    uint64_t *karg = (uint64_t *)arg;
    uint8_t  *dest = (uint8_t *)karg[2];
    dest[0] = 0xAB;
}

int main() {
    uint64_t  arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg       = (uint64_t *)arg_addr;
    uint32_t  num_tasks = 1;
    vx_spawn_threads(1, &num_tasks, 0, (vx_kernel_func_cb)kernel, arg);
    vx_tmc_zero();
    __builtin_unreachable();
}
