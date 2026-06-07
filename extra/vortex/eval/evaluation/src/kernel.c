// Args are passed via the v2.2 mechanism: vx_start writes the args buffer
// address to VX_DCR_BASE_STARTUP_ARG0/1, which the GPU latches into mscratch
// at reset. The kernel reads mscratch to get the args pointer. Reading from
// a hardcoded address would yield garbage because vx_upload_bytes allocates
// the buffer dynamically, not at any fixed location.
#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <VX_types.h>

// Override newlib memset/memcpy: the optimized versions use jump tables
// (jalr with per-thread targets) causing SIMT divergence that Vortex cannot
// handle. These plain byte loops have no indirect jumps and are fully SIMT-safe.
extern "C" __attribute__((used)) void *__wrap_memcpy(void *d, const void *s, __SIZE_TYPE__ n) {
    char *dp = (char *)d; const char *sp = (const char *)s;
    while (n--) *dp++ = *sp++; return d;
}
extern "C" __attribute__((used)) void *__wrap_memset(void *s, int c, __SIZE_TYPE__ n) {
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
    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg = (uint64_t *)arg_addr;
    uint32_t num_tasks = (uint32_t)arg[0];
    vx_spawn_threads(1, &num_tasks, 0, (vx_kernel_func_cb)kernel, arg);
    vx_tmc_zero();
    __builtin_unreachable();
}
