interface VX_commit_sched_if ();
    wire [(((4) < (4)) ? (4) : (4))-1:0] committed;
    wire [(((4) < (4)) ? (4) : (4))-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] committed_wid;
    modport master (
        output committed,
        output committed_wid
    );
    modport slave (
        input committed,
        input committed_wid
    );
endinterface
