// Copyright © 2019-2023
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#include <vortex.h>
#include <common.h>
#include <malloc.h>
#include "axictrl.h"
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <assert.h>
#include <cmath>
#include <sstream>
#include <unordered_map>
#include <algorithm>
#include <memory>
#include <list>
#include <time.h>

#include <VX_config.h>
#include <VX_types.h>
#include <vortex_afu.h>

#ifdef SCOPE
#include "scope.h"
#endif

#ifndef __rtems__
#include "baremetal.h"
#endif

///////////////////////////////////////////////////////////////////////////////

#define CMD_MEM_READ        AFU_IMAGE_CMD_MEM_READ    
#define CMD_MEM_WRITE       AFU_IMAGE_CMD_MEM_WRITE
#define CMD_RUN             AFU_IMAGE_CMD_RUN
#define CMD_DCR_WRITE       AFU_IMAGE_CMD_DCR_WRITE

#define MMIO_BASE_ADDR      AFU_IMAGE_MMIO_BASE_ADDR
#define MMIO_CMD_TYPE       AFU_IMAGE_MMIO_CMD_TYPE
#define MMIO_CMD_ADDR       AFU_IMAGE_MMIO_CMD_ADDR
#define MMIO_CMD_DATA       AFU_IMAGE_MMIO_CMD_DATA
#define MMIO_CMD_SIZE       AFU_IMAGE_MMIO_CMD_SIZE
#define MMIO_DATA_READ      AFU_IMAGE_MMIO_DATA_READ
#define MMIO_STATUS         AFU_IMAGE_MMIO_STATUS  
#define MMIO_DEV_CAPS       AFU_IMAGE_MMIO_DEV_CAPS
#define MMIO_DEV_CAPS_S     AFU_IMAGE_MMIO_DEV_CAPS_S
#define MMIO_ISA_CAPS       AFU_IMAGE_MMIO_ISA_CAPS
#define MMIO_ISA_CAPS_H     AFU_IMAGE_MMIO_ISA_CAPS_S
#define MMIO_SCOPE_READ     AFU_IMAGE_MMIO_SCOPE_READ
#define MMIO_SCOPE_WRITE    AFU_IMAGE_MMIO_SCOPE_WRITE

#define STATE_IDLE         AFU_IMAGE_STATE_IDLE
#define STATE_MEM          AFU_IMAGE_STATE_MEM 
#define STATE_RUN          AFU_IMAGE_STATE_RUN
#define STATE_DCR          AFU_IMAGE_STATE_DCR
#define STATE_BITS         AFU_IMAGE_STATE_BITS

#define RAM_PAGE_SIZE       4096

#ifndef MEM_TRANSF_WIDTH
#define MEM_TRANSF_WIDTH    (32/8)
#endif

// DBGPRINT and CHECK_ERR provided by common.h

#define CHECK_HANDLE(handle, _expr, _cleanup)   \
    auto handle = _expr;                        \
    if (handle == nullptr) {                    \
        printf("[VXDRV] Error: '%s' returned NULL!\n", #_expr); \
        _cleanup                                \
    }

///////////////////////////////////////////////////////////////////////////////

class vx_device;

struct vx_buffer {
  vx_device* device;
  uint64_t addr;
  uint64_t size;
};

class vx_device {
    public:

        vx_device(uint64_t base_mmio_addr) 
            : axi_ (base_mmio_addr)
        {}

        ~vx_device() 
        {
        }

        //// MEM SECTION ////

        int mem_alloc(uint64_t size, int flags, uint64_t* dev_addr) {
            uint64_t addr;
            CHECK_ERR(global_mem->allocate(size, &addr), { //allocation sucessfull ? 
                return err;
            });
            *dev_addr = addr;
            return 0;
        }

        int mem_reserve(uint64_t dev_addr, uint64_t size, int flags){
            CHECK_ERR(global_mem->reserve(dev_addr, size),{
                return err;
            });
            return 0;
        }

        int mem_free(uint64_t dev_addr) {           
            return global_mem->release(dev_addr);                                   
            // DO I still check for local mem  for safty -- memory managment local gloabl now internal (hardware managed)             
            //  if (dev_addr >= LMEM_BASE_ADDR) {                                       
            //      return local_mem->release(dev_addr);                                
            //  } else {                                                                
            //      return global_mem->release(dev_addr);                               
            //  }                                                                       
          }                              


        ////// 

        int write_register(uint64_t addr, uint64_t value)
        {
            CHECK_ERR(axi_.write32(addr, (uint32_t) value), { return -1; });
            DBGPRINT("*** write_register: addr=0x%lx, value=0x%lx\n", addr, value);
            return 0;
        }

        int read_register(uint64_t addr, uint64_t* value)
        {
            CHECK_ERR(axi_.read32(addr, (uint32_t*)value), { return -1; });
            DBGPRINT("*** read_register: addr=0x%lx, value=0x%lx\n", addr, *value);
            return 0;

        }

        int write_register64(uint64_t addr, uint64_t value)
        {
            CHECK_ERR(axi_.write64(addr, value), { return -1; });
            DBGPRINT("*** write_register: addr=0x%lx, value=0x%lx\n", addr, value);
            return 0;
        }

        int read_register64(uint64_t addr, uint64_t* value)
        {
            CHECK_ERR(axi_.read64(addr, value), { return -1; });
            DBGPRINT("*** read_register: addr=0x%lx, value=0x%lx\n", addr, *value);
            return 0;

        }
        int upload(uint64_t dev_addr, uint32_t* host_ptr, uint64_t asize) {    
            // ensure ready for new command
            if (vx_ready_wait((vx_device_h) this, VX_MAX_TIMEOUT) != 0)
                return -1;
            
            for (uint64_t i = 0; i < asize/MEM_TRANSF_WIDTH; ++i)
            {
                uint64_t value = host_ptr[i];
                CHECK_ERR(write_register(MMIO_CMD_DATA, (uint32_t) value), {return -1;});
                CHECK_ERR(write_register(MMIO_CMD_ADDR, (uint32_t) dev_addr+i*MEM_TRANSF_WIDTH), {return -1;});
                CHECK_ERR(write_register(MMIO_CMD_SIZE, MEM_TRANSF_WIDTH), {return -1;});
                CHECK_ERR(write_register(MMIO_CMD_TYPE, CMD_MEM_WRITE), {return -1;});
                // ensure transfer completed
                if (vx_ready_wait((vx_device_h) this, VX_MAX_TIMEOUT) != 0)
                    return -1;

            }
            return 0;
        }

        int download(uint32_t* host_ptr, uint64_t dev_addr, uint64_t asize) {    
            // ensure ready for new command
            if (vx_ready_wait((vx_device_h) this, VX_MAX_TIMEOUT) != 0)
                return -1;
            
            for (uint64_t i = 0; i < asize/MEM_TRANSF_WIDTH; ++i)
            {
                uint64_t value;
                CHECK_ERR(write_register(MMIO_CMD_ADDR, (uint32_t) dev_addr+i*MEM_TRANSF_WIDTH), {return -1;});
                CHECK_ERR(write_register(MMIO_CMD_SIZE, MEM_TRANSF_WIDTH), {return -1;});
                CHECK_ERR(write_register(MMIO_CMD_TYPE, CMD_MEM_READ), {return -1;});
                // ensure transfer completed
                if (vx_ready_wait((vx_device_h) this, VX_MAX_TIMEOUT) != 0)
                    return -1;

                CHECK_ERR(read_register(MMIO_DATA_READ, &value), {return -1;});
                host_ptr[i] = value;
            }
            return 0;
        }

        AxiCtrl axi_;
        std::shared_ptr<vortex::MemoryAllocator> global_mem;
        std::shared_ptr<vortex::MemoryAllocator> local_mem;
        DeviceConfig dcrs;
        uint64_t dev_caps;
        uint64_t isa_caps;
        uint64_t global_mem_size;
};

///////////////////////////////////////////////////////////////////////////////

extern int vx_dev_caps(vx_device_h hdevice, uint32_t caps_id, uint64_t *value) {
    if (nullptr == hdevice)
        return -1;

    auto device = ((vx_device*)hdevice);

    switch (caps_id) {
    case VX_CAPS_VERSION:
        *value = (device->dev_caps >> 0) & 0xff;
        break;
    case VX_CAPS_NUM_THREADS:
        *value = (device->dev_caps >> 8) & 0xff;
        break;
    case VX_CAPS_NUM_WARPS:
        *value = (device->dev_caps >> 16) & 0xff;
        break;
    case VX_CAPS_NUM_CORES:
        *value = (device->dev_caps >> 24) & 0xffff;
        break;
    case VX_CAPS_CACHE_LINE_SIZE:
        *value = CACHE_BLOCK_SIZE;
        break;
    case VX_CAPS_GLOBAL_MEM_SIZE:
        *value = device->global_mem_size;
        break;
    case VX_CAPS_LOCAL_MEM_SIZE:
        *value = 1ull << ((device->dev_caps >> 40) & 0xff);
        break;
    case VX_CAPS_ISA_FLAGS:
        *value = device->isa_caps;
        break;
    default:
        fprintf(stderr, "[VXDRV] Error: invalid caps id: %d\n", caps_id);
        std::abort();
        return -1;
    }

    return 0;
}

static int dcr_initialize(vx_device_h hdevice) {
    const uint64_t startup_addr(STARTUP_ADDR);

    CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_STARTUP_ADDR0, startup_addr & 0xffffffff), {
        return err;
    });
    CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_STARTUP_ADDR1, startup_addr >> 32), {
        return err;
    });
    CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_STARTUP_ARG0, 0), {
        return err;
    });
    CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_STARTUP_ARG1, 0), {
        return err;
    });
    CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_MPM_CLASS, 0), {
        return err;
    });

    return 0;
}

extern int vx_dev_open(vx_device_h* hdevice) {
    if (nullptr == hdevice)
        return  -1;

    vx_device* device;

    device = new vx_device(MMIO_BASE_ADDR);
    if (nullptr == device)
        return  -1;

    {   
        // assume 8GB as default
        device->global_mem_size = GLOBAL_MEM_SIZE;

        // Load ISA CAPS
        CHECK_ERR(device->read_register64(MMIO_ISA_CAPS, &device->isa_caps), {
            return -1;
        });
        // Load device CAPS        
        CHECK_ERR(device->read_register64(MMIO_DEV_CAPS, &device->dev_caps), {
            return -1;
        });
    }

    device->global_mem = std::make_shared<vortex::MemoryAllocator>(
        ALLOC_BASE_ADDR, GLOBAL_MEM_SIZE - ALLOC_BASE_ADDR, RAM_PAGE_SIZE, CACHE_BLOCK_SIZE);

    uint64_t local_mem_size = 0;
    vx_dev_caps(device, VX_CAPS_LOCAL_MEM_SIZE, &local_mem_size);
    if (local_mem_size <= 1) {        
        device->local_mem = std::make_shared<vortex::MemoryAllocator>(
            LMEM_BASE_ADDR, local_mem_size, RAM_PAGE_SIZE, 1);
    }

    int err = dcr_initialize(device);
    if (err != 0) {
        delete device;
        return err;
    }

#ifdef SCOPE
    {
        scope_callback_t callback;
        callback.registerWrite = [](vx_device_h hdevice, uint64_t value)->int { 
            auto device = (vx_device*)hdevice;
            CHECK_ERR(device->write_register64(MMIO_SCOPE_WRITE, value), {
                return -1;
            });
            return 0;
        };
        callback.registerRead = [](vx_device_h hdevice, uint64_t* value)->int {
            auto device = (vx_device*)hdevice;
            CHECK_ERR(device->read_register64(MMIO_SCOPE_READ, &value), {
                return -1;
            });
            return 0;
        };
        int ret = vx_scope_start(&callback, device, 0, -1);
        if (ret != 0) {
            delete device;
            return ret;
        }
    }
#endif

#ifdef DUMP_PERF_STATS
    perf_add_device(device);
#endif    

    *hdevice = device;    

    DBGPRINT("device creation complete!\n");
    return 0;
}

extern int vx_dev_close(vx_device_h hdevice) {
    if (nullptr == hdevice)
        return -1;

    auto device = ((vx_device*)hdevice);

#ifdef SCOPE
    vx_scope_stop(hdevice);
#endif

#ifdef DUMP_PERF_STATS
    perf_remove_device(hdevice);
#endif

    delete device;

    DBGPRINT("device destroyed!\n");

    return 0;
}


///MEM SECTION ////////

extern int vx_mem_alloc(vx_device_h hdevice, uint64_t size, int flags, vx_buffer_h* hbuffer) {
    if  (nullptr == hdevice || nullptr == hbuffer || 0 == size)
        return -1;

    auto device = ((vx_device*)hdevice);

    uint64_t dev_addr;

    CHECK_ERR(device->mem_alloc(size, flags, &dev_addr), {
          return err;
      });

    auto buffer = new vx_buffer{device, dev_addr, size}; //bundle ass new buffer
    if (nullptr == buffer) {  //if creating a new buffer fails free mem
          device->mem_free(dev_addr);
          return -1;
      }
    
    *hbuffer = buffer; //CHANGE return buffer instead of addr 
    return 0;
}


//same as alloc but u dotn get adress but rather know adress and set it 
extern int vx_mem_reserve(vx_device_h hdevice, uint64_t address, uint64_t size, int flags, vx_buffer_h* hbuffer) {
      if (nullptr == hdevice || nullptr == hbuffer || 0 == size)
          return -1;

      auto device = ((vx_device*)hdevice);

      CHECK_ERR(device->mem_reserve(address, size, flags), {
          return err;
      });

      auto buffer = new vx_buffer{device, address, size};
      if (nullptr == buffer) {
          device->mem_free(address);
          return -1;
      }

      *hbuffer = buffer;
      return 0;
  }

extern int vx_mem_free(vx_buffer_h hbuffer) {
      if (nullptr == hbuffer)                                                         
          return 0;
                                                                                      
      auto buffer = ((vx_buffer*)hbuffer);                                            
      auto device = buffer->device;      
                                                                                      
      int err = device->mem_free(buffer->addr);
      delete buffer;                                                                  
      return err;                                                                     
  }  


// to extract adress from the buffer wrapper
extern int vx_mem_address(vx_buffer_h hbuffer, uint64_t* address) {                 
      if (nullptr == hbuffer)                                                         
          return -1;                                                                  
                                                                                      
      auto buffer = ((vx_buffer*)hbuffer);                                            
      *address = buffer->addr;           
      return 0;
  }                                    


extern int vx_mem_info(vx_device_h hdevice, uint64_t* mem_free, uint64_t* mem_used) 
  {                                                                                   
      if (nullptr == hdevice)
          return -1;                                                                  
                                                                                      
      auto device = ((vx_device*)hdevice);
      if (mem_free)
          *mem_free = device->global_mem->free();                                     
      if (mem_used)
          *mem_used = device->global_mem->allocated();                                
      return 0;                                                                       
  }                


extern int vx_copy_to_dev(vx_buffer_h hbuffer, const void* host_ptr, uint64_t dst_offset, uint64_t size) {                                                        
      if (nullptr == hbuffer || nullptr == host_ptr)
          return -1;                                                                  
                                                                                      
      auto buffer = ((vx_buffer*)hbuffer);                                            
      auto device = buffer->device;
                                                                                      
      if ((dst_offset + size) > buffer->size)                                         
          return -1;                     

      uint64_t dev_addr = buffer->addr + dst_offset;                                  
   
      // check alignment                                                              
      if (!is_aligned(dev_addr, CACHE_BLOCK_SIZE))                                    
          return -1;                     

      auto asize = aligned_size(size, CACHE_BLOCK_SIZE);                              
   
      // bound checking                                                               
      if (dev_addr + asize > device->global_mem_size)                                 
          return -1;                     

      CHECK_ERR(device->upload(dev_addr, (uint32_t*)host_ptr, asize), {
          return -1;
      });                                                                             
   
      DBGPRINT("COPY_TO_DEV: dev_addr=0x%lx, host_addr=0x%lx, size=%ld bytes\n",      
  dev_addr, (uintptr_t)host_ptr, asize);                                              
                                                                                      
      return 0;                                                                       
  }  

extern int vx_copy_from_dev(void* host_ptr, vx_buffer_h hbuffer, uint64_t 
  src_offset, uint64_t size) {                                                        
      if (nullptr == hbuffer || nullptr == host_ptr)
          return -1;                                                                  
                                                                                      
      auto buffer = ((vx_buffer*)hbuffer);                                            
      auto device = buffer->device;
                                                                                      
      if ((src_offset + size) > buffer->size) // offset where to start reading + how much to read can not go over area end point                                        
          return -1;                     

      uint64_t dev_addr = buffer->addr + src_offset;

      // check alignment                                                              
      if (!is_aligned(dev_addr, CACHE_BLOCK_SIZE))
          return -1;                                                                  
                                                                                      
      auto asize = aligned_size(size, CACHE_BLOCK_SIZE);

      // bound checking
      if (dev_addr + asize > device->global_mem_size)
          return -1;                                                                  
   
      CHECK_ERR(device->download((uint32_t*)host_ptr, dev_addr, size), {              
          return -1;                                                                  
      });                                

      DBGPRINT("COPY_FROM_DEV: dev_addr=0x%lx, host_addr=0x%lx, size=%ld bytes\n",    
  dev_addr, (uintptr_t)host_ptr, size);
                                                                                      
      return 0;                                                                       
  } 

/// END OF MEM /////////


// Kernal now not always at same adress so need to actually write the adress 

extern int vx_start(vx_device_h hdevice, vx_buffer_h hkernel, vx_buffer_h harguments) {                                                                       
      if (nullptr == hdevice || nullptr == hkernel || nullptr == harguments)          
          return -1;                                                                  
                                                                                      
      auto device = (vx_device*)hdevice;                                              
      auto kernel = ((vx_buffer*)hkernel);
      auto arguments = ((vx_buffer*)harguments);                                      
   
      uint64_t krnl_addr = kernel->addr;                                              
      uint64_t args_addr = arguments->addr;                                           
                                                                                      
      // write kernel address to DCRs                                                  
      CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_STARTUP_ADDR0, krnl_addr ), {   // interface only 32  adress can be 64                                                         
          return -1;                                                                          // -> split into two sends   
      });                                                                             
      CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_STARTUP_ADDR1, krnl_addr >> 32), {   // >> 32 to get upper half
          return -1;                                                                  
      });
                                                                                      
      // write arguments address to DCRs
      CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_STARTUP_ARG0, args_addr), {                                                                      
          return -1;                                                                  
      });                                                                             
      CHECK_ERR(vx_dcr_write(hdevice, VX_DCR_BASE_STARTUP_ARG1, args_addr >> 32), {    
          return -1;                                                                  
      });

      // issue run command                                                            
      CHECK_ERR(device->write_register(MMIO_CMD_TYPE, CMD_RUN), {
          return -1;                                                                  
      });                                                                             
                                                                                      
      DBGPRINT("START: krnl_addr=0x%lx, args_addr=0x%lx\n", krnl_addr, args_addr);    
   
      return 0;                                                                       
  }        

extern int vx_ready_wait(vx_device_h hdevice, uint64_t timeout) {
    if (nullptr == hdevice)
        return -1;

    auto device = (vx_device*)hdevice;

    struct timespec sleep_time; 

#ifndef NDEBUG
    sleep_time.tv_sec = 1;
    sleep_time.tv_nsec = 0;
#else
    sleep_time.tv_sec = 0;
    sleep_time.tv_nsec = 1000000;
#endif

    // to milliseconds
    uint64_t sleep_time_ms = (sleep_time.tv_sec * 1000) + (sleep_time.tv_nsec / 1000000);

    // sim/uni-machine ONLY: heartbeat diagnostic so we can see whether the
    // host is stuck in this polling loop while the GPU isn't signaling done.
    // Prints raw status (before the state-bits mask) every N polls and on any
    // status change. Tells us:
    //   - host is alive (heartbeats appearing)
    //   - what AFU's status register currently reads
    //   - whether the value is changing or stuck
    uint64_t poll_count = 0;
    uint64_t last_raw = (uint64_t)-1;
    const uint64_t HB_EVERY = 1000;

    for (;;) {
        uint64_t raw_status = 0;
        CHECK_ERR(device->read_register(MMIO_STATUS, &raw_status), {
            return -1;
        });
        uint64_t status = raw_status & ((0x01 << STATE_BITS)-1);
        bool is_done = status == STATE_IDLE;

        ++poll_count;
        if (poll_count == 1 || poll_count % HB_EVERY == 0 || raw_status != last_raw) {
            printf("[hb] poll=%lu raw_status=0x%lx state=0x%lx done=%d\n",
                   (unsigned long)poll_count, (unsigned long)raw_status,
                   (unsigned long)status, is_done ? 1 : 0);
            last_raw = raw_status;
        }

        if (is_done || 0 == timeout) {
            printf("[hb] vx_ready_wait exit after %lu polls, final raw_status=0x%lx state=0x%lx done=%d\n",
                   (unsigned long)poll_count, (unsigned long)raw_status,
                   (unsigned long)status, is_done ? 1 : 0);
            break;
        }
        nanosleep(&sleep_time, nullptr);

        timeout -= sleep_time_ms;
    };

    return 0;
}

extern int vx_dcr_write(vx_device_h hdevice, uint32_t addr, uint32_t value) { //switch to 32 as the writes are 32 anyway
    if (nullptr == hdevice)
        return -1;

    auto device = (vx_device*)hdevice;
   
    CHECK_ERR(device->write_register(MMIO_CMD_ADDR, addr), { return -1; });
    CHECK_ERR(device->write_register(MMIO_CMD_DATA, value), { return -1; });
    CHECK_ERR(device->write_register(MMIO_CMD_TYPE, CMD_DCR_WRITE), { return -1; });

    // save the value
    DBGPRINT("DCR_WRITE: addr=0x%x, value=0x%x\n", addr, value);
    device->dcrs.write(addr, value);
    
    return 0;
}

  extern int vx_dcr_read(vx_device_h hdevice, uint32_t addr, uint32_t* value) {
      if (nullptr == hdevice || nullptr == value)                                     
          return -1;
                                                                                      
      auto device = (vx_device*)hdevice;                                              
                                                                                      
      return device->dcrs.read(addr, value);                                          
  }                                                                                   


//needed for vx_upload_kernel_bytes but as i understand there is no permissions
extern int vx_mem_access(vx_buffer_h hbuffer, uint64_t offset, uint64_t size, int  flags) {
      return 0;
  }

// stub — MetaSat AFU does not expose performance counters via MMIO
extern int vx_mpm_query(vx_device_h hdevice, uint32_t addr, uint32_t core_id, uint64_t* value) {
    if (nullptr == hdevice || nullptr == value)
        return -1;
    *value = 0;
    return 0;
}   

