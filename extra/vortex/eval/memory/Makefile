TEST = gpu-memory

SRC = src/main.c src/heap_init.c

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

srec: gpu-memory-vortex
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec $< gpu-memory.srec

srec-light: vortex-light
	$(CP) --srec-len=16 --srec-forceS3 --gap-fill=0 -O srec gpu-memory-vortex gpu-memory-light.srec
