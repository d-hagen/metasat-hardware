#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>

#include <VX_types.h>

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
    uint64_t *arg = (uint64_t *)csr_read(VX_CSR_MSCRATCH);
    uint32_t num_tasks = (uint32_t)arg[0];
    return vx_spawn_threads(1, &num_tasks, 0, (vx_kernel_func_cb)kernel, arg);
}
