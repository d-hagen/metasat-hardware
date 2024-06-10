#ifndef _COMMON_H_
#define _COMMON_H_

#define KERNEL_ARG_DEV_MEM_ADDR 0x5ffff000

typedef struct {
  uint32_t N;
  uint64_t src1_addr;
  uint64_t src2_addr;
  uint64_t dst_addr;  
  uint64_t loc1_addr;
  uint64_t loc2_addr;
} kernel_arg_t;

typedef struct {
  uint32_t num_groups[3];
  uint32_t global_offset[3];
  uint32_t local_size[3];
  char * printf_buffer;
  uint32_t *printf_buffer_position;
  uint32_t printf_buffer_capacity;
  uint32_t work_dim;
} kernel_ctx_t;

static size_t ALIGNED_CTX_SIZE = (4 * ((0x40 + 3) / 4));

#endif
