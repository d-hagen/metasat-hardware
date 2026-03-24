interface VX_scoreboard_if import VX_gpu_pkg::*; ();
    typedef struct packed {
        logic [1-1:0]     uuid;
        logic [ISSUE_WIS_W-1:0]     wis;
        logic [4-1:0]    tmask;
        logic [(32-1)-1:0]        PC;
        logic [$clog2((3 + 0))-1:0]        ex_type;
        logic [4-1:0]   op_type;
        op_args_t                   op_args;
        logic                       wb;
        logic [$clog2(32)-1:0]        rd;
        logic [$clog2(32)-1:0]        rs1;
        logic [$clog2(32)-1:0]        rs2;
        logic [$clog2(32)-1:0]        rs3;
    } data_t;
    logic  valid;
    data_t data;
    logic  ready;
    modport master (
        output valid,
        output data,
        input  ready
    );
    modport slave (
        input  valid,
        input  data,
        output ready
    );
endinterface
