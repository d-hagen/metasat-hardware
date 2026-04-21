#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <vortex.h>

#define KERNEL_ARG_DEV_MEM_ADDR 0x5ffff000

#ifndef VERBOSE
#define VERBOSE 0
#endif

#ifndef SIZE
#define SIZE 1024
#endif

extern const uint8_t vx_kernel_start[];
extern const uint8_t vx_kernel_end[];

int main()
{
    uint64_t num_points = SIZE;
    uint8_t *input = (uint8_t*) malloc(num_points * sizeof(uint8_t));
    uint8_t *output = (uint8_t*) malloc(num_points * sizeof(uint8_t));
    for (int i = 0; i < num_points; ++i) input[i] = i;
    for (int i = 0; i < num_points; ++i) output[i] = 0;
    vx_device_h device;
    puts("Start connection with the GPU");
    vx_dev_open(&device);
    puts("Retrieving GPU configuration:");
    uint64_t nwarps, nthreads, ncores;
    vx_dev_caps(device, VX_CAPS_NUM_THREADS, &nthreads);
    vx_dev_caps(device, VX_CAPS_NUM_WARPS, &nwarps);
    vx_dev_caps(device, VX_CAPS_NUM_CORES, &ncores);
    printf("    - %ld cores\n    - %ld warps\n    - %ld threads\n", ncores, nwarps, nthreads);
    size_t vx_kernel_size = vx_kernel_end - vx_kernel_start;
    printf("Upload kernel to the device (%d bytes)\n", vx_kernel_size);
    vx_upload_kernel_bytes(device, vx_kernel_start, vx_kernel_size);
    printf("Allocate device memory (%d bytes)\n", num_points * sizeof(uint8_t) * 2);
    uint64_t src, dest;
    vx_mem_alloc(device, num_points * sizeof(uint8_t), VX_MEM_TYPE_GLOBAL, &src);
    vx_mem_alloc(device, num_points * sizeof(uint8_t), VX_MEM_TYPE_GLOBAL, &dest);
    puts("Upload kernel arguments");
    uint64_t arg[3] = {num_points, src, dest};
    vx_copy_to_dev(device, KERNEL_ARG_DEV_MEM_ADDR, arg, 3*sizeof(uint64_t));
    printf("Send input data to the device (%d bytes)\n", num_points * sizeof(uint8_t));
    vx_copy_to_dev(device, src, input, num_points * sizeof(uint8_t));
    puts("Clear destination memory");
    vx_copy_to_dev(device, dest, output, num_points * sizeof(uint8_t));
    puts("Start execution");
    vx_start(device);
    puts("Waiting for execution to complete");
    vx_ready_wait(device, VX_MAX_TIMEOUT);
    printf("Retrieving data from the device (%d bytes)\n", num_points * sizeof(uint8_t));
    vx_copy_from_dev(device, output, dest, num_points * sizeof(uint8_t));
    printf("Free allocated memory (%d bytes)\n", 2 * num_points * sizeof(uint8_t));
    vx_mem_free(device, src);
    vx_mem_free(device, dest);
    puts("Close connection with the GPU");
    vx_dev_close(device);
    for (int i = 0; i < num_points; ++i) {
        uint8_t expected = (uint8_t)(2 * i);
        if(output[i] != expected) {
            if (VERBOSE) printf("Error in position %d, expected %d, got %d\n", i, expected, output[i]);
            puts("Test failed!");
            goto cleanup;
        }
    }
    puts("Test passed!");
cleanup:
    free(input);
    free(output);
}
