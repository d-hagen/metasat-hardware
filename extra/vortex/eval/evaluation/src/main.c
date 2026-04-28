#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <vortex.h>


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
    vx_device_h device = NULL;
    vx_buffer_h src_buffer = NULL;
    vx_buffer_h dst_buffer = NULL;
    vx_buffer_h krnl_buffer = NULL;
    vx_buffer_h args_buffer = NULL;
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
    vx_upload_kernel_bytes(device, vx_kernel_start, vx_kernel_size, &krnl_buffer);
    printf("Allocate device memory (%d bytes)\n", num_points * sizeof(uint8_t) * 2);
    uint64_t src_addr, dest_addr;
    vx_mem_alloc(device, num_points * sizeof(uint8_t), VX_MEM_READ, &src_buffer);
    vx_mem_address(src_buffer, &src_addr);
    vx_mem_alloc(device, num_points * sizeof(uint8_t), VX_MEM_WRITE, &dst_buffer);
    vx_mem_address(dst_buffer, &dest_addr);
    puts("Upload kernel arguments");
    uint64_t arg[3] = {num_points, src_addr, dest_addr};
    vx_upload_bytes(device, arg, sizeof(arg), &args_buffer);
    printf("Send input data to the device (%d bytes)\n", num_points * sizeof(uint8_t));
    vx_copy_to_dev(src_buffer, input, 0, num_points * sizeof(uint8_t));
    puts("Clear destination memory");
    vx_copy_to_dev(dst_buffer, output, 0, num_points * sizeof(uint8_t));
    puts("Start execution");
    vx_start(device, krnl_buffer, args_buffer);
    puts("Waiting for execution to complete");
    vx_ready_wait(device, VX_MAX_TIMEOUT);
    printf("Retrieving data from the device (%d bytes)\n", num_points * sizeof(uint8_t));
    vx_copy_from_dev(output, dst_buffer, 0, num_points * sizeof(uint8_t));
    printf("Free allocated memory (%d bytes)\n", 2 * num_points * sizeof(uint8_t));
    vx_mem_free(src_buffer);
    vx_mem_free(dst_buffer);
    vx_mem_free(krnl_buffer);
    vx_mem_free(args_buffer);
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
