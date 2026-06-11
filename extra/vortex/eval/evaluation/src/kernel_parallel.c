// parallel: multi-warp PoC using raw vx_wspawn + vx_tmc intrinsics. Bypasses
// vx_spawn_threads entirely (the library has compiler-emitted vx_split/vx_join
// around uniform branches that the RTL join stalls on). Each of 4 warps
// activates all 4 threads via vx_tmc(-1); each of 16 threads reads its own
// mhartid and writes dest[mhartid] = src[mhartid] * 2.
// Pass condition: dest[i] == 2*i for i=0..15.
// Proves: real multi-warp parallel compute on the SoC.

#include <stdint.h>
#include <vx_intrinsics.h>

extern "C" __attribute__((used)) void *__wrap_memcpy(void *d, const void *s, __SIZE_TYPE__ n) {
    char *dp = (char *)d; const char *sp = (const char *)s;
    while (n--) *dp++ = *sp++; return d;
}
extern "C" __attribute__((used)) void *__wrap_memset(void *s, int c, __SIZE_TYPE__ n) {
    unsigned char *p = (unsigned char *)s;
    while (n--) *p++ = (unsigned char)c;
    return s;
}

static void __attribute__((noinline)) worker_stub(void) {
    vx_tmc(-1);
    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg  = (uint64_t *)arg_addr;
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];
    uint32_t gtid;
    __asm__ volatile ("csrr %0, mhartid" : "=r"(gtid));
    dest[gtid] = (uint8_t)(src[gtid] * 2);
    vx_tmc_zero();
}

int main() {
    // Spawn warps 1..3 at worker_stub. wmask formula (i<rs1)&&(i!=wid) with
    // rs1=4, wid=0 yields wmask=4'b1110.
    vx_wspawn(4, worker_stub);

    // Warp 0 does the same work as workers.
    vx_tmc(-1);
    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg  = (uint64_t *)arg_addr;
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];
    uint32_t gtid;
    __asm__ volatile ("csrr %0, mhartid" : "=r"(gtid));
    dest[gtid] = (uint8_t)(src[gtid] * 2);

    // Warp 0 deactivates. Workers deactivate themselves via their tmc_zero.
    // vx_busy stays high until active_warps reaches 0, which is when the
    // last (any) warp's tmc_zero commits -- no explicit wait needed here.
    vx_tmc_zero();
    __builtin_unreachable();
}
