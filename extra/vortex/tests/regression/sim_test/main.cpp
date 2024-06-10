#include <stdio.h>
#include <stdlib.h>
#include "kernel.h"

int read_reg(int addr) {
    const volatile int* target_address = reinterpret_cast<const int*>(0xfff80000+addr);
    return *target_address;
}

void write_reg(int addr, int value) {
    volatile int* target_address = reinterpret_cast<int*>(0xfff80000+addr);
    *target_address = value;
}

void write_mem(int addr, int *data, int size){
    for (int i = 0; i < size; i++) {
        write_reg(0x4, addr+i*4);
        write_reg(0x8, data[i]);
        write_reg(0xC, 4);
        write_reg(0x0, 2);
        while((read_reg(0x14) & 0x07) != 0);
    }
}

void read_mem(int addr, int *data, int size){
    for (int i =0; i < size; i++) {
        write_reg(0x4, addr+i*4);
        write_reg(0xC, 4);
        write_reg(0x0, 1);
        while((read_reg(0x14) & 0x07) != 0);
        data[i] = read_reg(0x10);
    }
}

int shuffle(int i, int value) {
  return (value << i) | (value & ((1 << i)-1));
}

int main() {
    puts("dcr");
    //dcr initialize
    write_reg(0x8, 0x80000000);
    write_reg(0x4, 0x1);
    write_reg(0x0, 0x4);
    write_reg(0x8, 0x00000000);
    write_reg(0x4, 0x2);
    write_reg(0x0, 0x4);
    write_reg(0x8, 0x00000000);
    write_reg(0x4, 0x3);
    write_reg(0x0, 0x4);

    puts("upload");
    //upload program
    write_mem(0x80000000, (int*)kernel_bin, kernel_bin_len/4);
    long arg[3] = {10, 0x20, 0x100};
    write_mem(0x7ffff000, (int*) arg, 6);

    puts("start");
    write_reg(0x0, 0x3);
    while((read_reg(0x14) & 0x07) != 0);
    puts("DONE");
    return 0;
}
