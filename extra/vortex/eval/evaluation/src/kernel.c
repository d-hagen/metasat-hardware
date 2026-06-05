#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <vx_print.h>

#include <VX_types.h>

void kernel(void *arg)
{
    uint64_t *karg = (uint64_t *)arg;
    uint8_t *src = (uint8_t *)karg[1];
    uint8_t *dest = (uint8_t *)karg[2];

    uint32_t tid = blockIdx.x;
    vx_printf("[GPU kernel] tid=%d start\n", tid);
    dest[tid] = (uint8_t)(src[tid] * 2);
    vx_printf("[GPU kernel] tid=%d done\n", tid);
}

int main()
{
    vx_printf("[GPU main] entered\n");
    uint64_t *arg = (uint64_t *)csr_read(VX_CSR_MSCRATCH);
    uint32_t num_tasks = (uint32_t)arg[0];
    vx_printf("[GPU main] num_tasks=%d src=0x%x dest=0x%x\n",
              num_tasks, (unsigned int)arg[1], (unsigned int)arg[2]);
    vx_printf("[GPU main] calling vx_spawn_threads\n");
    int ret = vx_spawn_threads(1, &num_tasks, 0, (vx_kernel_func_cb)kernel, arg);
    vx_printf("[GPU main] vx_spawn_threads returned %d\n", ret);
    return ret;
}
