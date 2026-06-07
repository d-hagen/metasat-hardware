// Test 3: spawn exactly 1 task on 1 thread.
// Uses vx_spawn_threads with num_tasks=1.
// Pass: vx_busy falls after spawn completes.
// Fail: vx_busy stays high.
// Diagnoses: does vx_spawn_threads work at all? Does the barrier release?
#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <VX_types.h>

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
    uint8_t  *dest = (uint8_t *)karg[2];
    uint32_t  tid  = blockIdx.x;
    dest[tid] = 0xAB;  // write sentinel value
}

int main()
{
    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg       = (uint64_t *)arg_addr;
    uint32_t  num_tasks = 1;
    vx_spawn_threads(1, &num_tasks, 0, (vx_kernel_func_cb)kernel, arg);
    vx_tmc_zero();
    __builtin_unreachable();
}
