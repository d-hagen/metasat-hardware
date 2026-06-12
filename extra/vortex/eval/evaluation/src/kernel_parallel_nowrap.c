// parallel (no memset/memcpy wraps)
#include <stdint.h>
#include <vx_intrinsics.h>
#include <VX_types.h>

static void __attribute__((noinline)) worker_stub(void) {
    vx_tmc(-1);
    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg  = (uint64_t *)arg_addr;
    uint32_t n     = (uint32_t)arg[0];
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];
    uint32_t gtid;
    __asm__ volatile ("csrr %0, mhartid" : "=r"(gtid));
    uint32_t stride = vx_num_warps() * vx_num_threads();
    for (uint32_t i = gtid; i < n; i += stride) {
        dest[i] = (uint8_t)(src[i] * 2);
    }
    vx_tmc_zero();
}

int main() {
    vx_wspawn(4, worker_stub);

    vx_tmc(-1);
    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg  = (uint64_t *)arg_addr;
    uint32_t n     = (uint32_t)arg[0];
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];
    uint32_t gtid;
    __asm__ volatile ("csrr %0, mhartid" : "=r"(gtid));
    uint32_t stride = vx_num_warps() * vx_num_threads();
    for (uint32_t i = gtid; i < n; i += stride) {
        dest[i] = (uint8_t)(src[i] * 2);
    }

    vx_tmc(1);

    uint32_t aw;
    do {
        __asm__ volatile ("csrr %0, %1" : "=r"(aw) : "i"(VX_CSR_ACTIVE_WARPS));
    } while (aw != 1);

    vx_tmc_zero();
    __builtin_unreachable();
}
