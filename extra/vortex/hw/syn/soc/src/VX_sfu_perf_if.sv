interface VX_sfu_perf_if ();
    wire [44-1:0] wctl_stalls;
    modport master (
        output wctl_stalls
    );
    modport slave (
        input wctl_stalls
    );
endinterface
