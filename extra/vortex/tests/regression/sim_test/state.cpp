#include<stdio.h>

void print_regs() {
    for (int i = 0; i <= 0x24; i+=4){
        const int* target_address = reinterpret_cast<const int*>(0xfff80000+i);
        volatile int value_1 = *target_address;
        printf("0x%08x\n", value_1);
    }
}

void write_reg(int addr, int value) {
    volatile int* target_address = reinterpret_cast<int*>(0xfff80000+addr);
    *target_address = value;
}

int main() {
    write_reg(0x8, 0x123);
    write_reg(0x4, 0xfff80000);
    write_reg(0xC, 4);
    write_reg(0x0, 3);
    write_reg(0xC, 0);
    print_regs();
    return 0;
}
