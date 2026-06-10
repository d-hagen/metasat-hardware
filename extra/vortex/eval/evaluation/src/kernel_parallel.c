// Parallel multi-warp proof-of-concept kernel.
//
// Bypasses vx_spawn_threads (currently hangs at a compiler-emitted vx_join
// inside the divergence-handling path) and uses raw intrinsics instead:
//
//   warp 0 main():
//     vx_wspawn(NUM_WARPS, worker_stub)  --> activates warps 1..N-1
//     vx_tmc(-1)                          --> widens warp 0 to all 4 threads
//     (every thread of warp 0 computes dest[mhartid] = src[mhartid] * 2)
//     vx_tmc(1)                           --> back to single thread
//     vx_wspawn_wait()                    --> spin on ACTIVE_WARPS == 1
//     vx_tmc_zero()                       --> warp 0 deactivates
//
//   worker_stub() (warps 1..N-1):
//     vx_tmc(-1)                          --> widen this warp to 4 threads
//     (every thread computes dest[mhartid] = src[mhartid] * 2)
//     vx_tmc_zero()                       --> warp deactivates
//
// All 4 warps * 4 threads = 16 threads each write a distinct slot of dest,
// so the existing host verifier (dest[i] == 2*i for i in 0..15) passes.
//
// Why this avoids the vx_join hang: nothing in this kernel branches on
// per-thread state, and we don't link any code from vx_spawn.c. The only
// SIMT-divergent code that gets linked is __wrap_memset (called from
// __init_tls during _start), and its vx_split/vx_join works -- the trace
// shows _start completing.

#include <stdint.h>
#include <vx_intrinsics.h>
#include <VX_types.h>

extern "C" void vx_wspawn_wait(void);

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
    // Activate all 4 threads of this worker warp.
    vx_tmc(-1);

    // Read the args pointer from mscratch (set by the host at reset, single
    // shared register per core in v2.2 RTL so workers and warp 0 see the same
    // value).
    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg  = (uint64_t *)arg_addr;
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];

    // Each thread gets a unique global thread id from mhartid.
    uint32_t gtid;
    __asm__ volatile ("csrr %0, mhartid" : "=r"(gtid));
    dest[gtid] = (uint8_t)(src[gtid] * 2);

    // Deactivate this warp -- active_warps[wid] = (tmask != 0) drops to 0.
    vx_tmc_zero();
}

int main(void) {
    // [A1] main entered (warp 0, thread 0, mask=1).
    *((volatile uint32_t*)0x70000000) = 0xAAAA0001;

    // Spawn warps 1..3 at worker_stub. For vx_wspawn(N, pc) from wid=0 the
    // RTL builds wmask[i] = (i<N) && (i!=0), so with NUM_WARPS=4 we get
    // wmask = 4'b1110.
    vx_wspawn(4, worker_stub);

    // Warp 0: widen to all 4 threads and do the same computation as workers.
    vx_tmc(-1);

    uint64_t arg_addr;
    __asm__ volatile ("csrr %0, mscratch" : "=r"(arg_addr));
    uint64_t *arg  = (uint64_t *)arg_addr;
    uint8_t  *src  = (uint8_t *)arg[1];
    uint8_t  *dest = (uint8_t *)arg[2];

    uint32_t gtid;
    __asm__ volatile ("csrr %0, mhartid" : "=r"(gtid));
    dest[gtid] = (uint8_t)(src[gtid] * 2);

    // Back to single thread (mask=1) for post-spawn coordination.
    vx_tmc(1);

    // [A2] warp 0 finished its slice of the work.
    *((volatile uint32_t*)0x70000004) = 0xAAAA0002;

    // Wait until ACTIVE_WARPS == 1 (workers have all called vx_tmc_zero).
    vx_wspawn_wait();

    // [A3] all warps drained, about to exit.
    *((volatile uint32_t*)0x70000008) = 0xAAAA0003;

    vx_tmc_zero();
    __builtin_unreachable();
}
