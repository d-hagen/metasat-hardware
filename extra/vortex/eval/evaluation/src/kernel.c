#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <VX_types.h>

#define KERNEL_ARG_DEV_MEM_ADDR 0x5ffff000

// Override newlib memset: the optimized version uses jump tables (jalr with
// per-thread targets) causing SIMT divergence that Vortex cannot handle.
// This plain byte loop has no indirect jumps and is fully SIMT-safe.
void *memset(void *s, int c, __SIZE_TYPE__ n) {
    unsigned char *p = (unsigned char *)s;
    while (n--) *p++ = (unsigned char)c;
    return s;
}

void kernel(void *arg)
{
    uint64_t *karg = (uint64_t *)arg;
    uint8_t *src = (uint8_t *)karg[1];
    uint8_t *dest = (uint8_t *)karg[2];
    uint32_t tid = blockIdx.x;
    dest[tid] = (uint8_t)(src[tid] * 2);
}

int main()
{
    // main.c writes args to KERNEL_ARG_DEV_MEM_ADDR via vx_copy_to_dev.
    // vx_start(device) never sets MSCRATCH, so reading MSCRATCH gives 0.
    // Use the fixed address directly instead.
    uint64_t *arg = (uint64_t *)KERNEL_ARG_DEV_MEM_ADDR;
    uint32_t num_tasks = (uint32_t)arg[0];
    return vx_spawn_threads(1, &num_tasks, 0, (vx_kernel_func_cb)kernel, arg);
}
