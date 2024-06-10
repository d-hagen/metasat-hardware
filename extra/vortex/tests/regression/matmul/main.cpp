#include <iostream>
#include <sstream>
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
	 cleanup();			                        \
     exit(-1);                                                  \
   } while (false)



#define RT_ERROR(_expr, _msg, _val)                             \
   do {                                                         \
     int _ret = _expr;                                          \
     if (0 == _ret)                                             \
       break;                                                   \
     printf(_msg,_val);                                         \
	 cleanup();			                        \
     exit(-1);                                                  \
   } while (false)

///////////////////////////////////////////////////////////////////////////////


#ifndef ARG_K
#define ARG_K "kernel.bin"
#endif

#define LOCAL_SIZE 4

#ifndef ARG_N
#define ARG_N 0
#endif

#ifdef NFILESYS
#include "kernel.h"
#else
const char* kernel_file = ARG_K;
#endif

uint32_t count = ARG_N;

std::vector<int> src1_data;
std::vector<int> src2_data;
std::vector<int> ref_data;

vx_device_h device = nullptr;
std::vector<uint8_t> staging_buf;
kernel_arg_t kernel_arg = {};
kernel_ctx_t kernel_ctx = {};

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
    vx_mem_free(device, kernel_arg.loc1_addr);
    vx_mem_free(device, kernel_arg.loc2_addr);
    vx_dev_close(device);
  }
}

void gen_input_data(uint32_t n) {
  uint32_t num_points = n * n;
  src1_data.resize(num_points);
  src2_data.resize(num_points);

  for (uint32_t i = 0; i < num_points; ++i) {
    float r = static_cast<float>(std::rand()) / RAND_MAX;
    int value = r * num_points;
    src1_data[i] = value;
  }  
  for (uint32_t i = 0; i < num_points; ++i) {
    float r = static_cast<float>(std::rand()) / RAND_MAX;
    int value = r * num_points;
    src2_data[i] = value;
  }  
}

void gen_ref_data(uint32_t n) {
  ref_data.resize(n*n);

  for (uint32_t i = 0; i < n; i++){
      for (uint32_t j = 0; j < n; j++){
          int sum = 0;
          for (uint32_t k = 0; k < n; k++){
              sum += src1_data.at(i*n+k) * src2_data.at(k*n+j);
          }
          ref_data.at(i*n+j) = sum;
      }
  }
}

int run_test(const kernel_arg_t& kernel_arg,
             uint32_t buf_size, 
             uint32_t num_points) {
  // start device
  //std::cout << "start device" << std::endl;
  RT_CHECK(vx_start(device));

  // wait for completion
  //std::cout << "wait for completion" << std::endl;
  RT_CHECK(vx_ready_wait(device, VX_MAX_TIMEOUT));

  // download destination buffer
  //std::cout << "download destination buffer" << std::endl;
  RT_CHECK(vx_copy_from_dev(device, staging_buf.data(), kernel_arg.dst_addr, buf_size));

  // verify result
  //std::cout << "verify result" << std::endl;  
  {
    int errors = 0;
    auto buf_ptr = (int*)staging_buf.data();
    for (uint32_t i = 0; i < num_points; ++i) {
      int ref = ref_data.at(i);
      int cur = buf_ptr[i];
      if (cur != ref) {
        std::cout << "error at result #" << std::dec << i << std::hex << ": actual=" << cur << ", expected=" << ref << std::endl;
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

  std::srand(50);

  // open device connection
  //std::cout << "open device connection" << std::endl;  
  RT_CHECK(vx_dev_open(&device));

  uint64_t nwarps, nthreads, lmemsize;
  RT_CHECK(vx_dev_caps(device, VX_CAPS_NUM_THREADS, &nthreads));
  RT_CHECK(vx_dev_caps(device, VX_CAPS_NUM_WARPS, &nwarps));
  RT_CHECK(vx_dev_caps(device, VX_CAPS_LOCAL_MEM_SIZE, &lmemsize));

  RT_ERROR(nthreads * nwarps < LOCAL_SIZE * LOCAL_SIZE,
          "ERROR: Not enough resources available local size configuration.\n%ld threads avialable.", nthreads*nwarps);

  uint32_t n = count;
  RT_ERROR(n % LOCAL_SIZE != 0, "ERROR: Matrix size must be multiple of %d", LOCAL_SIZE);

  // generate input data
  gen_input_data(n);

  // generate reference data
  gen_ref_data(n);

  uint32_t src1_buf_size = src1_data.size() * sizeof(int32_t);  
  uint32_t src2_buf_size = src2_data.size() * sizeof(int32_t);  
  uint32_t dst_buf_size = ref_data.size() * sizeof(int32_t);
  uint32_t local_buf_size = LOCAL_SIZE * LOCAL_SIZE * sizeof(int32_t);  

  RT_ERROR(lmemsize < local_buf_size, "ERROR: Not enough local memory available, maximum bytes: %d", LOCAL_SIZE);

  std::cout << "matrix size: " << n <<" x " << n << std::endl;

  // upload program
  //std::cout << "upload program" << std::endl;  
#ifdef NFILESYS
    RT_CHECK(vx_upload_kernel_bytes(device, kernel_bin, kernel_bin_len));
#else
    RT_CHECK(vx_upload_kernel_file(device, kernel_file));
#endif

  // allocate device memory
  //std::cout << "allocate global device memory" << std::endl;
  RT_CHECK(vx_mem_alloc(device, src1_buf_size, VX_MEM_TYPE_GLOBAL, &kernel_arg.src1_addr));
  RT_CHECK(vx_mem_alloc(device, src2_buf_size, VX_MEM_TYPE_GLOBAL, &kernel_arg.src2_addr));
  RT_CHECK(vx_mem_alloc(device, dst_buf_size, VX_MEM_TYPE_GLOBAL,  &kernel_arg.dst_addr));
  //std::cout << "allocate local device memory" << std::endl;
  RT_CHECK(vx_mem_alloc(device, local_buf_size, VX_MEM_TYPE_LOCAL, &kernel_arg.loc1_addr));
  RT_CHECK(vx_mem_alloc(device, local_buf_size, VX_MEM_TYPE_LOCAL, &kernel_arg.loc2_addr));

  kernel_arg.N = n;


  //std::cout << "init context" << std::endl;
  kernel_ctx.num_groups[0] = n;
  kernel_ctx.num_groups[1] = n;
  kernel_ctx.num_groups[2] = 1;
  kernel_ctx.local_size[0] = LOCAL_SIZE;
  kernel_ctx.local_size[1] = LOCAL_SIZE;
  kernel_ctx.local_size[2] = 1;
  
  //std::cout << "allocate staging buf" << std::endl;
  // allocate staging buffer  
  {
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
    RT_CHECK(vx_copy_to_dev(device, KERNEL_ARG_DEV_MEM_ADDR+ALIGNED_CTX_SIZE, staging_buf.data(), sizeof(kernel_arg_t)));
  }
  {
    //std::cout << "upload kernel context" << std::endl;
    auto buf_ptr = staging_buf.data();
    memcpy(buf_ptr, &kernel_ctx, sizeof(kernel_ctx_t));
    RT_CHECK(vx_copy_to_dev(device, KERNEL_ARG_DEV_MEM_ADDR, staging_buf.data(), sizeof(kernel_ctx_t)));
  }

  // upload source buffer
  {
    //std::cout << "upload source buffer" << std::endl;
    auto buf_ptr = staging_buf.data();
    memcpy(buf_ptr, src1_data.data(), n*n * sizeof(int));      
    RT_CHECK(vx_copy_to_dev(device, kernel_arg.src1_addr, staging_buf.data(), src1_buf_size));
    buf_ptr = staging_buf.data();
    memcpy(buf_ptr, src2_data.data(), n*n * sizeof(int));      
    RT_CHECK(vx_copy_to_dev(device, kernel_arg.src2_addr, staging_buf.data(), src2_buf_size));
  }

  // clear destination buffer
  {
    //std::cout << "clear destination buffer" << std::endl;
    auto buf_ptr = (int32_t*)staging_buf.data();
    for (uint32_t i = 0; i < n*n; ++i) {
      buf_ptr[i] = 0xdeadbeef;
    }    
    RT_CHECK(vx_copy_to_dev(device, kernel_arg.dst_addr, staging_buf.data(), dst_buf_size));  
  }

  // run tests
  //std::cout << "run tests" << std::endl;
  RT_CHECK(run_test(kernel_arg, dst_buf_size, n*n));

  // cleanup
  //std::cout << "cleanup" << std::endl;  
  cleanup();

  std::cout << "PASSED!" << std::endl;

  return 0;
}
