interface VX_decode_if ();
    typedef struct packed {
        logic [1-1:0]     uuid;
        logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]       wid;
        logic [4-1:0]    tmask;
        logic [$clog2((3 + 0))-1:0]        ex_type;    
        logic [4-1:0]   op_type;
        logic [3-1:0]  op_mod;    
        logic                       wb;
        logic                       use_PC;
        logic                       use_imm;
        logic [32-1:0]           PC;
        logic [32-1:0]           imm;
        logic [$clog2(32)-1:0]        rd;
        logic [$clog2(32)-1:0]        rs1;
        logic [$clog2(32)-1:0]        rs2;
        logic [$clog2(32)-1:0]        rs3;
    } data_t;
    logic  valid;
    data_t data;
    logic  ready;
    wire [(((4) < (4)) ? (4) : (4))-1:0] ibuf_pop;
    modport master (
        output valid,
        output data,
        input  ibuf_pop,
        input  ready
    );
    modport slave (
        input  valid,
        input  data,
        output ibuf_pop,
        output ready
    );
endinterface
