interface VX_warp_ctl_if import VX_gpu_pkg::*; ();
    wire        valid;
    wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0] wid;
    tmc_t       tmc;
    wspawn_t    wspawn;
    split_t     split;
    join_t      sjoin;
    barrier_t   barrier;
    wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0] dvstack_wid;
    wire [((($clog2((((2-1) != 0) ? (2-1) : 1))) != 0) ? ($clog2((((2-1) != 0) ? (2-1) : 1))) : 1)-1:0] dvstack_ptr;
    modport master (
        output valid,
        output wid,
        output wspawn,
        output tmc,
        output split,
        output sjoin,
        output barrier,
        output dvstack_wid,
        input  dvstack_ptr
    );
    modport slave (
        input valid,
        input wid,
        input wspawn,
        input tmc,
        input split,
        input sjoin,
        input barrier,
        input dvstack_wid,
        output dvstack_ptr
    );
endinterface
