interface VX_commit_sched_if ();
    wire [2-1:0] committed_warps;
    modport master (
        output committed_warps
    );
    modport slave (
        input committed_warps
    );
endinterface
