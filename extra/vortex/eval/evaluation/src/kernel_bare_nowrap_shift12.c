// bare (no wraps, 12-byte text shift so newlib memset's jr lands at line offset 0x4)
#include <stdint.h>
#include <vx_intrinsics.h>

extern "C" __attribute__((retain, noinline)) void __shift12(void) {
    __asm__ volatile ("nop\n\tnop\n\t");
}
__attribute__((used)) void (*const __shift12_ref)(void) = __shift12;

int main() {
    vx_tmc_zero();
    __builtin_unreachable();
}
