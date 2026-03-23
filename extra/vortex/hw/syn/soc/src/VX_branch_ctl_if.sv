interface VX_branch_ctl_if ();
    wire                    valid;    
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]    wid;    
    wire                    taken;
    wire [32-1:0]        dest;
    modport master (
        output valid,    
        output wid,
        output taken,
        output dest
    );
    modport slave (
        input valid,   
        input wid,
        input taken,
        input dest
    );
endinterface
