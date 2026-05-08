/* Bare-metal heap initialization for BCC/newlib.
 * The Gaisler BCC startup expects __bcc_heap_min and __bcc_heap_max
 * to be set by the boot loader (GRMON). In simulation there is no
 * boot loader, so these BSS variables stay 0 and malloc fails.
 * This constructor runs before main() and sets them. */

#include <stdint.h>

extern uint64_t __bcc_heap_min;
extern uint64_t __bcc_heap_max;
extern char __BSS_END__[];

__attribute__((constructor))
static void init_heap(void) {
    if (__bcc_heap_min == 0)
        __bcc_heap_min = (uint64_t)__BSS_END__;
    if (__bcc_heap_max == 0)
        __bcc_heap_max = 0x10000000;  /* 256 MB */
}
