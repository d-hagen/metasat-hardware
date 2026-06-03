interface VX_sched_csr_if ();
    wire [44-1:0] cycles;
    wire [2-1:0] active_warps;
    wire [2-1:0][2-1:0] thread_masks;
    wire alm_empty;
    wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0] alm_empty_wid;
    wire unlock_warp;
    wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0] unlock_wid;
    modport master (
        output cycles,
        output active_warps,
        output thread_masks,
        input  alm_empty_wid,
        output alm_empty,
        input  unlock_wid,        
        input  unlock_warp
    );
    modport slave (
        input  cycles,
        input  active_warps,
        input  thread_masks,
        output alm_empty_wid,
        input  alm_empty,
        output unlock_wid,
        output unlock_warp
    );
endinterface
