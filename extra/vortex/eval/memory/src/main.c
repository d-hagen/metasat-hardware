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

int main()
{
    uint64_t num_points = SIZE;
    uint8_t *input = (uint8_t*) malloc(num_points * sizeof(uint8_t));
    uint8_t *output = (uint8_t*) malloc(num_points * sizeof(uint8_t));
    for (int i = 0; i < num_points; ++i) input[i] = 0;
    for (int i = 0; i < num_points; ++i) output[i] = 0;
    vx_device_h device= NULL;
    vx_buffer_h src_buffer = NULL;
    puts("Start connection with the GPU");
    vx_dev_open(&device);
    puts("Retrieving GPU configuration:");
    uint64_t nwarps, nthreads, ncores;
    vx_dev_caps(device, VX_CAPS_NUM_THREADS, &nthreads);
    vx_dev_caps(device, VX_CAPS_NUM_WARPS, &nwarps);
    vx_dev_caps(device, VX_CAPS_NUM_CORES, &ncores);
    printf("    - %ld cores\n    - %ld warps\n    - %ld threads\n", ncores, nwarps, nthreads);
    printf("Allocate device memory (%d bytes)\n", num_points * sizeof(uint8_t));
    uint64_t src_addr;
    vx_mem_alloc(device, num_points * sizeof(uint8_t), VX_MEM_READ, &src_buffer);
    vx_mem_address(src_buffer, &src_addr);
    puts("Clear device memory");
    vx_copy_to_dev(src_buffer, input,0, num_points * sizeof(uint8_t));
    puts("Verify memory cleaned");
    uint8_t is_vx_cleaned = 0;
    vx_copy_from_dev(output, src_buffer, 0, num_points * sizeof(uint8_t));
    for (int i = 0; i < num_points; ++i) if(output[i] != 0) goto error_print;
    for (int i = 0; i < num_points; ++i) input[i] = i;
    printf("Send data to the device (%d bytes)\n", num_points * sizeof(uint8_t));
    vx_copy_to_dev(src_buffer, input, 0, num_points * sizeof(uint8_t));
    printf("Retrieving data from the device (%d bytes)\n", num_points * sizeof(uint8_t));
    vx_copy_from_dev(output, src_buffer, 0, num_points * sizeof(uint8_t));
    printf("Free allocated memory (%d bytes)\n", 1 * num_points * sizeof(uint8_t));
    vx_mem_free(src_buffer);
    puts("Close connection with the GPU");
    vx_dev_close(device);
    is_vx_cleaned = 1;
    for (int i = 0; i < num_points; ++i) {
        if(output[i] != input[i]) {
error_print:
            if (VERBOSE) printf("Error in position %d, expected %d, got %d\n", i, input[i], output[i]);
            puts("Test failed!");
            goto cleanup;
        }
    }
    puts("Test passed!");

cleanup:

    if (!is_vx_cleaned) {
        vx_mem_free(src_buffer);
        vx_dev_close(device);
    }

    free(input);
    free(output);
}
