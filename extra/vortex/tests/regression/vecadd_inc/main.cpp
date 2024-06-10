#include <iostream>
#include <chrono>
#include <unistd.h>
#include <string.h>
#include <vortex.h>
#include <vector>
#include "common.h"

#define RT_CHECK(_expr)                                         \
   do {                                                         \
     int _ret = _expr;                                          \
     if (0 == _ret)                                             \
       break;                                                   \
     printf("Error: '%s' returned %d!\n", #_expr, (int)_ret);   \
	 cleanup();			                                              \
     exit(-1);                                                  \
   } while (false)

///////////////////////////////////////////////////////////////////////////////

#ifndef ARG_K
#define ARG_K "kernel.bin"
#endif

#ifndef ARG_N
#define ARG_N 0
#endif

#ifdef NFILESYS
#include "kernel.h"
#else
const char* kernel_file = ARG_K;
#endif

double elapsed_cpu, elapsed_gpu;
uint32_t count = ARG_N;

std::vector<TYPE> src1_data;
std::vector<TYPE> src2_data;
std::vector<TYPE> ref_data;

vx_device_h device = nullptr;
std::vector<uint8_t> staging_buf;
kernel_arg_t kernel_arg = {};

#ifndef NFILESYS
static void show_usage() {
   std::cout << "Vortex Test." << std::endl;
   std::cout << "Usage: [-k: kernel] [-n words] [-h: help]" << std::endl;
}

static void parse_args(int argc, char **argv) {
  int c;
  while ((c = getopt(argc, argv, "n:k:h?")) != -1) {
    switch (c) {
    case 'n':
      count = atoi(optarg);
      break;
    case 'k':
      kernel_file = optarg;
      break;
    case 'h':
    case '?': {
      show_usage();
      exit(0);
    } break;
    default:
      show_usage();
      exit(-1);
    }
  }
}
#endif

void cleanup() {
  if (device) {
    vx_mem_free(device, kernel_arg.src1_addr);
    vx_mem_free(device, kernel_arg.src2_addr);
    vx_mem_free(device, kernel_arg.dst_addr);
    vx_dev_close(device);
  }
}

void gen_input_data(uint32_t num_points) {
  src1_data.resize(num_points);
  src2_data.resize(num_points);

  for (uint32_t i = 0; i < num_points; ++i) {
    float r = static_cast<float>(std::rand()) / RAND_MAX;
    TYPE value = r * num_points;
    src1_data[i] = value;
  }  
  for (uint32_t i = 0; i < num_points; ++i) {
    float r = static_cast<float>(std::rand()) / RAND_MAX;
    TYPE value = r * num_points;
    src2_data[i] = value;
  }  
}

void gen_ref_data(uint32_t num_points) {
  ref_data.resize(num_points);
  auto t0 = std::chrono::high_resolution_clock::now();
  for (uint32_t i = 0; i < num_points; ++i) {
    TYPE ref_value = src1_data.at(i) + src2_data.at(i);
    ref_data.at(i) = ref_value;
  }
  auto t1 = std::chrono::high_resolution_clock::now();
  elapsed_cpu = std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count();  
}

int run_test(const kernel_arg_t& kernel_arg,
             uint32_t buf_size, 
             uint32_t num_points) {
  // start device
  //std::cout << "start device" << std::endl;
    auto t2 = std::chrono::high_resolution_clock::now();
  RT_CHECK(vx_start(device));

  // wait for completion
  //std::cout << "wait for completion" << std::endl;
  RT_CHECK(vx_ready_wait(device, VX_MAX_TIMEOUT));
    auto t3 = std::chrono::high_resolution_clock::now();
  elapsed_gpu = std::chrono::duration_cast<std::chrono::microseconds>(t3 - t2).count();  

  // download destination buffer
  //std::cout << "download destination buffer" << std::endl;
    auto t4 = std::chrono::high_resolution_clock::now();
  RT_CHECK(vx_copy_from_dev(device, staging_buf.data(), kernel_arg.dst_addr, buf_size));
    auto t5 = std::chrono::high_resolution_clock::now();

  // verify result
  //std::cout << "verify result" << std::endl;  
  {
    int errors = 0;
    auto buf_ptr = (TYPE*)staging_buf.data();
    for (uint32_t i = 0; i < num_points; ++i) {
      TYPE ref = ref_data.at(i);
      TYPE cur = buf_ptr[i];
      if (cur != ref) {
        std::cout << "error at result #" << std::dec << i
                  << std::hex << ": actual=" << cur << ", expected=" << ref << std::endl;
        ++errors;
      }
    }
    if (errors != 0) {
      std::cout << "Found " << std::dec << errors << " errors!" << std::endl;
      std::cout << "FAILED!" << std::endl;
      return 1;  
    }
  }

  return 0;
}

int main(int argc, char *argv[]) {  
  // parse command arguments
#ifndef NFILESYS
  parse_args(argc, argv);
#endif

  if (count == 0) {
    count = 1;
  }
  while(1){

      std::srand(50);

      // open device connection
      //std::cout << "open device connection" << std::endl;  
      RT_CHECK(vx_dev_open(&device));

      uint32_t num_points = count;

      // generate input data
      gen_input_data(num_points);

      // generate reference data
      gen_ref_data(num_points);

      uint32_t src1_buf_size = src1_data.size() * sizeof(int32_t);  
      uint32_t src2_buf_size = src2_data.size() * sizeof(int32_t);  
      uint32_t dst_buf_size = ref_data.size() * sizeof(int32_t);

      //std::cout << "Number of points: " << std::dec << num_points << std::endl;
      std::cout << "Vector size: " << std::dec << dst_buf_size << " bytes" << std::endl;

      // upload program
      //std::cout << "upload program" << std::endl;  
#ifdef NFILESYS
      RT_CHECK(vx_upload_kernel_bytes(device, kernel_bin, kernel_bin_len));
#else
      RT_CHECK(vx_upload_kernel_file(device, kernel_file));
#endif

      // allocate device memory
      //std::cout << "allocate device memory" << std::endl;
      RT_CHECK(vx_mem_alloc(device, src1_buf_size, VX_MEM_TYPE_GLOBAL, &kernel_arg.src1_addr));
      RT_CHECK(vx_mem_alloc(device, src2_buf_size, VX_MEM_TYPE_GLOBAL, &kernel_arg.src2_addr));
      RT_CHECK(vx_mem_alloc(device, dst_buf_size, VX_MEM_TYPE_GLOBAL, &kernel_arg.dst_addr));

      kernel_arg.num_points = num_points;

      //std::cout << "dev_src1=0x" << std::hex << kernel_arg.src1_addr << std::endl;
      //std::cout << "dev_src2=0x" << std::hex << kernel_arg.src2_addr << std::endl;
      //std::cout << "dev_dst=0x" << std::hex << kernel_arg.dst_addr << std::endl;

      // allocate staging buffer  
      {
          //std::cout << "allocate staging buffer" << std::endl;    
          uint32_t staging_buf_size = std::max<uint32_t>(src1_buf_size,
                  std::max<uint32_t>(src2_buf_size, 
                      std::max<uint32_t>(dst_buf_size, 
                          sizeof(kernel_arg_t))));
          staging_buf.resize(staging_buf_size);
      }

      // upload kernel argument  
      {
          //std::cout << "upload kernel argument" << std::endl;
          auto buf_ptr = staging_buf.data();
          memcpy(buf_ptr, &kernel_arg, sizeof(kernel_arg_t));
          RT_CHECK(vx_copy_to_dev(device, KERNEL_ARG_DEV_MEM_ADDR, staging_buf.data(), sizeof(kernel_arg_t)));
      }

      // upload source buffer
      {
          //std::cout << "upload source buffer" << std::endl;
          auto buf_ptr = staging_buf.data();
          memcpy(buf_ptr, src1_data.data(), num_points * sizeof(TYPE));      
          RT_CHECK(vx_copy_to_dev(device, kernel_arg.src1_addr, staging_buf.data(), src1_buf_size));
          buf_ptr = staging_buf.data();
          memcpy(buf_ptr, src2_data.data(), num_points * sizeof(TYPE));      
          RT_CHECK(vx_copy_to_dev(device, kernel_arg.src2_addr, staging_buf.data(), src2_buf_size));
      }

      // clear destination buffer
      {
          //std::cout << "clear destination buffer" << std::endl;
          auto buf_ptr = (int32_t*)staging_buf.data();
          for (uint32_t i = 0; i < num_points; ++i) {
              buf_ptr[i] = 0xdeadbeef;
          }    
          RT_CHECK(vx_copy_to_dev(device, kernel_arg.dst_addr, staging_buf.data(), dst_buf_size));  
      }

      // run tests
      //std::cout << "run tests" << std::endl;
      RT_CHECK(run_test(kernel_arg, dst_buf_size, num_points));

      // cleanup
      //std::cout << "cleanup" << std::endl;  
      cleanup();
      printf("CPU time: %lg us\n", elapsed_cpu);
      printf("GPU time: %lg us\n", elapsed_gpu);

      //std::cout << "PASSED!" << std::endl;
      count*=10;
      if (count > 1000000) count = 10;
      auto wait0 = std::chrono::high_resolution_clock::now();
      double elapsed_wait = 0;
      while(elapsed_wait < 1000)
      {
          auto wait1 = std::chrono::high_resolution_clock::now();
          elapsed_wait = std::chrono::duration_cast<std::chrono::milliseconds>(wait1 - wait0).count();  
      }

      
      puts("\n");
}

  return 0;
}
