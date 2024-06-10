#include<stdio.h>

void print_regs() {
    for (int i = 0; i <= 0x24; i+=4){
        const int* target_address = reinterpret_cast<const int*>(0xfff80000+i);
        volatile int value_1 = *target_address;
        printf("0x%08x\n", value_1);
    }
}

void write_regs() {
    for (int i = 0; i <= 0x24; i+=4){
        int* target_address = reinterpret_cast<int*>(0xfff80000+i);
        *target_address = i+4;
    }
}

int main() {
    print_regs();
    write_regs();
    print_regs();
    return 0;
}
