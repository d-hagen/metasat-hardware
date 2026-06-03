    # Design configuration
    XLEN = 32
    NUM_CORES = 1

    # Extensions enabled
    EXT_F_EN = 0
    EXT_M_EN = 1

    # GPU configuration
    NUM_WARPS = 2
    NUM_THREADS = 2
    NUM_BARRIERS = 4

    STARTUP_ADDR = $$((0x60000000))
    STACK_BASE_ADDR = $$((0x7F000000))

    # Memory configuration
    MEM_BLOCK_SIZE = 16

    # Debug in simulation
    DBG_TRACE_EN = 0
