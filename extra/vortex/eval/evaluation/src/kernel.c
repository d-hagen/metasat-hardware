#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include <vx_print.h>

#include <VX_types.h>

// Fine-grained diagnostic prints for sim-branch debugging.
// Each print tells us a different stage of GPU execution:
//   M.entry         Vortex booted; reached C main()
//   M.csr           CSR read worked
//   M.spawn.n=NN    About to dispatch NN tasks
//   K.t=NN          Per-task: kernel() function actually executed for task NN
//   M.spawn.done    All tasks finished and synced back to master
//
// Comparing the LAST visible print to where execution gets stuck pinpoints
// the failure stage (boot, dispatch, mid-task, mid-wave, or sync).

void kernel(void *arg)
{
    uint64_t *karg = (uint64_t *)arg;
    uint8_t *src = (uint8_t *)karg[1];
    uint8_t *dest = (uint8_t *)karg[2];

    uint32_t tid = blockIdx.x;
    vx_printf("K.t=%d\n", tid);
    dest[tid] = (uint8_t)(src[tid] * 2);
}

int main()
{
    vx_printf("M.entry\n");
    uint64_t *arg = (uint64_t *)csr_read(VX_CSR_MSCRATCH);
    vx_printf("M.csr\n");
    uint32_t num_tasks = (uint32_t)arg[0];
    vx_printf("M.spawn.n=%d\n", num_tasks);
    int rc = vx_spawn_threads(1, &num_tasks, 0, (vx_kernel_func_cb)kernel, arg);
    vx_printf("M.spawn.done.rc=%d\n", rc);
    return rc;
}
