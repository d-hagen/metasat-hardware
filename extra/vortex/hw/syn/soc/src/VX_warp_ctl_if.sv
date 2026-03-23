interface VX_warp_ctl_if import VX_gpu_pkg::*; ();
    wire        valid;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] wid;
    tmc_t       tmc;
    wspawn_t    wspawn;
    split_t     split;
    join_t      sjoin;
    barrier_t   barrier;
    modport master (
        output valid,
        output wid,
        output wspawn,
        output tmc,
        output split,
        output sjoin,
        output barrier
    );
    modport slave (
        input valid,
        input wid,
        input wspawn,
        input tmc,
        input split,
        input sjoin,
        input barrier
    );
endinterface
