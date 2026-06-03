interface VX_commit_if #(
    parameter NUM_LANES = 2,
    parameter PID_WIDTH = (((2 / NUM_LANES) > 1) ? $clog2(2 / NUM_LANES) : 1)
) ();
    typedef struct packed {
        logic [1-1:0]     uuid;
        logic [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0]       wid;
        logic [NUM_LANES-1:0]       tmask;
        logic [(32-1)-1:0]        PC;
        logic                       wb;
        logic [$clog2(32)-1:0]        rd;
        logic [NUM_LANES-1:0][32-1:0] data;
        logic [PID_WIDTH-1:0]       pid;
        logic                       sop;
        logic                       eop;
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
