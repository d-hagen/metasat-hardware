interface VX_mem_perf_if import VX_gpu_pkg::*; ();
    cache_perf_t icache;
    cache_perf_t dcache;
    cache_perf_t l2cache;
    cache_perf_t l3cache;
    cache_perf_t smem;
    mem_perf_t   mem;
    modport master (
        output icache,
        output dcache,
        output l2cache,
        output l3cache,
        output smem,
        output mem
    );
    modport slave (
        input icache,
        input dcache,
        input l2cache,
        input l3cache,
        input smem,        
        input mem
    );
endinterface
