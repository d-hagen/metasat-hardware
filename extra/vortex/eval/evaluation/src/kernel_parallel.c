// parallel
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
    vx_wspawn(4, worker_stub);

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
    __builtin_unreachable();
}
