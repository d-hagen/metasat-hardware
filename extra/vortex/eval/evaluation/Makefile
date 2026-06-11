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

# Override SIMT-unsafe newlib memset/memcpy. newlib_s memset/memcpy use jalr
# Override SIMT-unsafe newlib memset/memcpy. newlib_s versions use jalr jump
# tables for per-byte alignment which diverge across SIMT threads. The kernel
# files (kernel_bare.c, kernel_nospawn.c, kernel_spawn1.c, kernel_parallel.c)
# provide __wrap_memset / __wrap_memcpy as plain byte loops. _start_s BSS
# clear uses single-thread mask so it would work either way, but __init_tls
# (called with tmc(-1) widened to all 4 threads) tail-calls memset and memcpy,
# so the wrap is required to keep __init_tls SIMT-safe.
VX_LDFLAGS += -Wl,--wrap=memset,--wrap=memcpy

vortex: $(TEST)-vortex

vortex-light:
	$(MAKE) clean-all
	$(MAKE) vortex SIZE=16

srec: gpu-evaluation-vortex
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec $< gpu-evaluation.srec

srec-light: vortex-light
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-evaluation-vortex gpu-evaluation-light.srec

# Test variants. Each target swaps the corresponding kernel_<variant>.c into
# kernel.c, builds at the appropriate SIZE, restores kernel.c from git, and
# captures the SREC under a variant-specific name. The cp/git checkout dance
# keeps the linker symbol vx_kernel_start/end (main.c references those) while
# letting us build N variants from one VX_SRC slot.

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
