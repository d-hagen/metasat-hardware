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
