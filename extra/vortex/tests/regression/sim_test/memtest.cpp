#include<stdio.h>
#include<stdlib.h>

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
    int input[16], output[16] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    puts("Start");
    for (int i = 1; i<16; i++) input[i] = shuffle(i, 0x2badf00d);
    write_mem(0x40, input, 16);
    read_mem(0x40, output, 16);
    for (int i = 0; i<16; i++){
        if (input[i] != output[i]) printf("ERROR %d: expected %x got %x\n",i, input[i], output[i]);
    }
    puts("DONE");
    return 0;
}
