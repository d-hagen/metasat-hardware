#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>

#define KERNEL_ARG_DEV_MEM_ADDR 0x5ffff000

void kernel(uint8_t task_id, uint64_t* __UNIFORM__ arg)
{
    uint8_t *src = (uint8_t *) arg[1];
    uint8_t *dest = (uint8_t *) arg[2];

    dest[task_id] = (uint8_t)(src[task_id] * 2);
}

int main()
{
    uint64_t* arg = (uint64_t*) (KERNEL_ARG_DEV_MEM_ADDR);
    vx_spawn_tasks(arg[0], (vx_spawn_tasks_cb)kernel, arg);
}
