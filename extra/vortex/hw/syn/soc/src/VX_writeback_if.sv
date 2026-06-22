interface VX_writeback_if import VX_gpu_pkg::*; ();
    typedef struct packed {
        logic [16-1:0]         uuid;
        logic [ISSUE_WIS_W-1:0]         wis;
        logic [4-1:0]        tmask;
        logic [(32-1)-1:0]            PC;
        logic [$clog2(32)-1:0]            rd;
        logic [4-1:0][32-1:0] data;
        logic                           sop;
        logic                           eop;
    } data_t;
    logic  valid;
    data_t data;
    modport master (
        output valid,
        output data
    );
    modport slave (
        input valid,
        input data
    );
endinterface
