interface VX_pipeline_perf_if import VX_gpu_pkg::*; ();
    sched_perf_t              sched;
    issue_perf_t              issue;
    wire [44-1:0] ifetches;
    wire [44-1:0] loads;
    wire [44-1:0] stores;
    wire [44-1:0] ifetch_latency;
    wire [44-1:0] load_latency;
    modport master (
        output sched,
        output issue,
        output ifetches,
        output loads,
        output stores,
        output ifetch_latency,
        output load_latency
    );
    modport slave (
        input sched,
        input issue,
        input ifetches,
        input loads,
        input stores,
        input ifetch_latency,
        input load_latency
    );
endinterface
