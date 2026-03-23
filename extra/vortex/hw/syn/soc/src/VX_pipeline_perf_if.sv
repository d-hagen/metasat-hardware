interface VX_pipeline_perf_if ();
    wire [44-1:0]   ibf_stalls;
    wire [44-1:0]   scb_stalls;
    wire [44-1:0]   dsp_stalls [(3 + 0)];
    wire [44-1:0]   ifetches;
    wire [44-1:0]   loads;
    wire [44-1:0]   stores;    
    wire [44-1:0]   ifetch_latency;
    wire [44-1:0]   load_latency;
    modport issue (
        output ibf_stalls,
        output scb_stalls,
        output dsp_stalls
    );    
    modport slave (
        input ibf_stalls,
        input scb_stalls,
        input dsp_stalls,
        input ifetches,
        input loads,
        input stores,
        input ifetch_latency,
        input load_latency
    );
endinterface
