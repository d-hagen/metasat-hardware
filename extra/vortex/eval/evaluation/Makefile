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

VX_LDFLAGS += -Wl,--wrap=memset,--wrap=memcpy

vortex: $(TEST)-vortex

vortex-light:
	$(MAKE) clean-all
	$(MAKE) vortex SIZE=16

srec: gpu-evaluation-vortex
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec $< gpu-evaluation.srec

srec-light: vortex-light
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-light.srec

srec-bare:
	cp src/kernel_bare.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-bare.srec

srec-nospawn:
	cp src/kernel_nospawn.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-nospawn.srec

srec-spawn1:
	cp src/kernel_spawn1.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-spawn1.srec

srec-parallel:
	cp src/kernel_parallel.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=16
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel.srec
