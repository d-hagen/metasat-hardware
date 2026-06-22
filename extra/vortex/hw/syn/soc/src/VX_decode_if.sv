interface VX_decode_if import VX_gpu_pkg::*; #(
    parameter NUM_WARPS = 4,
    parameter NW_WIDTH  = (((NUM_WARPS) > 1) ? $clog2(NUM_WARPS) : 1)
);
    typedef struct packed {
        logic [23-1:0]     uuid;
        logic [NW_WIDTH-1:0]        wid;
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
