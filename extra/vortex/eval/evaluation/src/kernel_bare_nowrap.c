// bare (no memset/memcpy wraps)
#include <stdint.h>
#include <vx_intrinsics.h>

int main() {
    vx_tmc_zero();
    __builtin_unreachable();
}
