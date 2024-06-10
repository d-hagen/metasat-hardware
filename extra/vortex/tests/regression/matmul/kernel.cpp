#include <stdint.h>
#include <vx_intrinsics.h>
#include <vx_spawn.h>
#include "common.h"


#define get_global_id(i) id[i]
#define get_local_size(n) ctx->local_size[n]
#define get_global_size(n) ctx->num_groups[n]

context_t* ctx;

uint32_t get_local_id(int n){
    if (n == 0) return (vx_thread_id() + vx_warp_id() * vx_num_threads()) % get_local_size(0); 
    else if (n == 1) return ((vx_thread_id() + vx_warp_id() * vx_num_threads()) / get_local_size(0)) % get_local_size(1);
    else if (n == 2) return (vx_thread_id() + vx_warp_id() * vx_num_threads()) / (get_local_size(0) * get_local_size(1));
    else return 0;
}

void kernel_body(uint32_t id[3], kernel_arg_t* __UNIFORM__ arg) 
{
    int N = arg->N;
    int *A = (int*) arg->src1_addr;
    int *B = (int*) arg->src2_addr;
    int *C = (int*) arg->dst_addr;
    int *localA = (int*) arg->loc1_addr;
    int *localB = (int*) arg->loc2_addr;

    uint32_t row = get_global_id(1);
    uint32_t col = get_global_id(0);
    uint32_t localRow = get_local_id(1);
    uint32_t localCol = get_local_id(0);
    uint32_t localSize = get_local_size(0);


    int sum = 0;

    for (int k = 0; k < N; k += localSize) {
        // Load block of matrix A to local memory
        localA[localRow * localSize + localCol] = A[row * N + k + localCol];

        // Load block of matrix B to local memory, adjusting for column-major access
        localB[localRow * localSize + localCol] = B[(k + localRow) * N + col];

        // Synchronize to make sure the tiles are loaded
        vx_barrier(vx_core_id()*2, vx_num_warps());

        // Multiply the two matrix blocks and accumulate result
        for (int j = 0; j < localSize; j++) {
            sum += localA[localRow * localSize + j] * localB[j * localSize + localCol];
        }

        // Synchronize before loading the next block
        vx_barrier(vx_core_id()*2+1, vx_num_warps());
    }

    C[row * N + col] = localCol;
 }

void vx_id_3D(uint32_t task_id, kernel_arg_t* __UNIFORM__ arg)
{
    uint32_t id[3], block[3];
    uint32_t row, col, dep, block_id;
    uint32_t nb[3] = {get_global_size(0)/get_local_size(0), get_global_size(1)/get_local_size(1), get_global_size(2)/get_local_size(2)};
    //uint32_t nb = (ctx->num_groups[0]*ctx->num_groups[1]*ctx->num_groups[2])/(ctx->local_size[0] * ctx->local_size[1] * ctx->local_size[2]);
    block_id = task_id / (nb[0] * nb[1] * nb[2]);
    block[2] = block_id / (nb[0] * nb[1]);
    block[1] = (block_id / nb[0]) % nb[1];
    block[0] = block_id % nb[0];

    id[2] = get_local_id(2) + block[2] * get_local_size(2);
    id[1] = get_local_id(1) + block[1] * get_local_size(1);
    id[0] = get_local_id(0) + block[0] * get_local_size(0);
    kernel_body(block, arg);
}

int main() {
        ctx = (context_t*) KERNEL_ARG_DEV_MEM_ADDR;
	kernel_arg_t* arg = (kernel_arg_t*) (KERNEL_ARG_DEV_MEM_ADDR + ALIGNED_CTX_SIZE);
	uint32_t ntasks = ctx->num_groups[0] * ctx->num_groups[1] * ctx->num_groups[2];
	vx_spawn_tasks(ntasks, (vx_spawn_tasks_cb)kernel_body, arg);
	return 0;
}
