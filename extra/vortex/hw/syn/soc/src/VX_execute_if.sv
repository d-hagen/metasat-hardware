interface VX_execute_if import VX_gpu_pkg::*; #(
    parameter NUM_LANES = 1,
    parameter PID_WIDTH = (((4 / NUM_LANES) > 1) ? $clog2(4 / NUM_LANES) : 1)
);
    typedef struct packed {
        logic [1-1:0]         uuid;
        logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]           wid;
        logic [NUM_LANES-1:0]           tmask;
        logic [(32-1)-1:0]            PC;
        logic [4-1:0]      op_type;
        op_args_t                       op_args;
        logic                           wb;
        logic [$clog2((2 * 32))-1:0]            rd;
        logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]           tid;
        logic [NUM_LANES-1:0][32-1:0] rs1_data;
        logic [NUM_LANES-1:0][32-1:0] rs2_data;
        logic [NUM_LANES-1:0][32-1:0] rs3_data;
        logic [PID_WIDTH-1:0]           pid;
        logic                           sop;
        logic                           eop;
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
