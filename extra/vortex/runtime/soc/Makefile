CXX = /home/msole/metasat/software/tools/compiler/riscv-sparrow-toolchain/bin/riscv-gaisler-elf-g++
AR = /home/msole/metasat/software/tools/compiler/riscv-sparrow-toolchain/bin/riscv-gaisler-elf-ar
XLEN ?= 32
DESTDIR ?= .
BUILDIR = build
HW_DIR = ../../hw
SYN_DIR = $(HW_DIR)/syn/soc/src

CXXFLAGS += -std=c++11 -Wall -Wextra -pedantic -Wfatal-errors
CXXFLAGS += -I../include -I../common -I.
CXXFLAGS += -DXLEN_$(XLEN)

H_FILES := VX_config.h VX_types.h vortex_afu.h

# Position independent code
#CXXFLAGS += -fPIC

# Add external configuration
CXXFLAGS += $(CONFIGS)

# Dump perf stats
#CXXFLAGS += -DDUMP_PERF_STATS

#LDFLAGS += -shared -ldl

# Debugigng
ifdef DEBUG
	CXXFLAGS += -g -O0
else    
	CXXFLAGS += -O2 -DNDEBUG
endif

# Enable scope logic analyzer
ifdef SCOPE
	CXXFLAGS += -DSCOPE	
	SRCS += ../common/scope.cpp
endif

# Enable perf counters
ifdef PERF
	CXXFLAGS += -DPERF_ENABLE
endif

PROJECT = libvortex.a

all: $(DESTDIR)/$(PROJECT)


%/:
	mkdir -p $@

%.h: $(SYN_DIR)/%.vh
	$(HW_DIR)/scripts/gen_config.py -i $< -o $@

$(BUILDIR)/vortex.o: $(BUILDIR)/ $(H_FILES) vortex.cpp
	$(CXX) $(CXXFLAGS) vortex.cpp -c -o $@
$(BUILDIR)/axictrl.o: $(BUILDIR)/ $(H_FILES) axictrl.cpp
	$(CXX) $(CXXFLAGS) axictrl.cpp -c -o $@
$(BUILDIR)/utils.o: $(BUILDIR)/ $(H_FILES) ../common/utils.cpp
	$(CXX) $(CXXFLAGS) ../common/utils.cpp -c -o $@

$(DESTDIR)/$(PROJECT): $(DESTDIR)/ $(BUILDIR)/vortex.o $(BUILDIR)/axictrl.o $(BUILDIR)/utils.o 
	$(AR) rcs $(DESTDIR)/$(PROJECT) $(BUILDIR)/*.o

clean:
	rm -rf $(BUILDIR)/ $(H_FILES)

clean-all: clean
	rm -rf $(DESTDIR)/$(PROJECT)
