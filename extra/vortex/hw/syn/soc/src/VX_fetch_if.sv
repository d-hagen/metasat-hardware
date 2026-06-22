interface VX_fetch_if ();
    typedef struct packed {
        logic [16-1:0]     uuid;
        logic [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]       wid;
        logic [4-1:0]    tmask;
        logic [(32-1)-1:0]        PC;
        logic [31:0]                instr;
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
