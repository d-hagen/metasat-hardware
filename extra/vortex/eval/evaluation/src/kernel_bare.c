// bare: minimal sanity test. Warp 0 enters main, deactivates immediately.
// Pass condition: vx_busy falls within a few cycles of reset deassert and
// the host's verification loop passes (with SIZE=1 and host-cleared dest,
// "no-op kernel" trivially passes the dest[0]==2*0 check).
// Proves: _start, init_regs, __init_tls, BSS memset, libc_init_array, main
//         call, vx_tmc_zero all work end-to-end.

#include <stdint.h>
#include <vx_intrinsics.h>

int main() {
    vx_tmc_zero();
    __builtin_unreachable();
}
