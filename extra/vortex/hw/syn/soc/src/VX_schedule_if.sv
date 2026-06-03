interface VX_schedule_if ();
    typedef struct packed {
        logic [1-1:0]     uuid;
        logic [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0]       wid;
        logic [2-1:0]    tmask;
        logic [(32-1)-1:0]        PC;
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
