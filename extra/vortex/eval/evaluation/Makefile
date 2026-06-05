TEST = gpu-evaluation

SRC = src/main.c src/heap_init.c

VX_SRC = src/kernel.c

CFLAGS += -I$(VORTEX_RT_PATH)/include -I$(VORTEX_KN_PATH)/../hw

LDFLAGS += $(VORTEX_RT_PATH)/soc/libvortex.a

SIZE ?= 1024
VERBOSE ?= 1

ARGS = -DSIZE=$(SIZE) -DVERBOSE=$(VERBOSE)


all:
	make vortex

include ../common.mk

vortex: $(TEST)-vortex

vortex-light:
	$(MAKE) clean-all
	$(MAKE) vortex SIZE=16

srec: gpu-evaluation-vortex
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec $< gpu-evaluation.srec

srec-light: vortex-light
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-light.srec

# Minimal test case SRECs — each isolates one level of complexity
srec-bare:
	$(MAKE) clean-all
	$(MAKE) vortex VX_SRC=src/kernel_bare.c SIZE=1
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-bare.srec

srec-nospawn:
	$(MAKE) clean-all
	$(MAKE) vortex VX_SRC=src/kernel_nospawn.c SIZE=1
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-nospawn.srec

srec-spawn1:
	$(MAKE) clean-all
	$(MAKE) vortex VX_SRC=src/kernel_spawn1.c SIZE=1
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-spawn1.srec

srec-all: srec-bare srec-nospawn srec-spawn1 srec-light
