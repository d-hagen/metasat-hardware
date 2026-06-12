TEST = gpu-evaluation

SRC = src/main.c src/heap_init.c

VX_SRC = src/kernel.c

CFLAGS += -I$(VORTEX_RT_PATH)/include -I$(VORTEX_KN_PATH)/../hw

LDFLAGS += $(VORTEX_RT_PATH)/soc/libvortex.a
LDFLAGS += -Wl,--wrap=clock,--wrap=nanosleep

SIZE ?= 1024
VERBOSE ?= 1

ARGS = -DSIZE=$(SIZE) -DVERBOSE=$(VERBOSE)


all:
	make vortex

include ../common.mk

NOWRAP ?= 0
ifeq ($(NOWRAP),0)
VX_LDFLAGS += -Wl,--wrap=memset,--wrap=memcpy
endif

ifneq ($(WRAPONLY),)
VX_LDFLAGS += -Wl,--wrap=$(WRAPONLY)
endif

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
	$(MAKE) vortex
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel.srec

srec-parallel-light:
	cp src/kernel_parallel.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=16
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel-light.srec

srec-bare-nowrap:
	cp src/kernel_bare_nowrap.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=1 NOWRAP=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-bare-nowrap.srec

srec-nospawn-nowrap:
	cp src/kernel_nospawn_nowrap.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=1 NOWRAP=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-nospawn-nowrap.srec

srec-spawn1-nowrap:
	cp src/kernel_spawn1_nowrap.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=1 NOWRAP=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-spawn1-nowrap.srec

srec-parallel-nowrap:
	cp src/kernel_parallel_nowrap.c src/kernel.c
	rm -rf build
	$(MAKE) vortex NOWRAP=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel-nowrap.srec

srec-parallel-nowrap-light:
	cp src/kernel_parallel_nowrap.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=16 NOWRAP=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel-nowrap-light.srec

srec-parallel-nowrap-pad:
	cp src/kernel_parallel_nowrap_pad.c src/kernel.c
	rm -rf build
	$(MAKE) vortex NOWRAP=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel-nowrap-pad.srec

srec-parallel-nowrap-pad-light:
	cp src/kernel_parallel_nowrap_pad.c src/kernel.c
	rm -rf build
	$(MAKE) vortex SIZE=16 NOWRAP=1
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel-nowrap-pad-light.srec

srec-parallel-wrapset:
	cp src/kernel_parallel_wrapset.c src/kernel.c
	rm -rf build
	$(MAKE) vortex NOWRAP=1 WRAPONLY=memset
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel-wrapset.srec

srec-parallel-wrapcpy:
	cp src/kernel_parallel_wrapcpy.c src/kernel.c
	rm -rf build
	$(MAKE) vortex NOWRAP=1 WRAPONLY=memcpy
	git checkout src/kernel.c 2>/dev/null || true
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-parallel-wrapcpy.srec
