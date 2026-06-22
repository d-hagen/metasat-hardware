interface VX_gbar_bus_if ();
    wire                    req_valid;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]    req_id;
    wire [((($clog2(8)) != 0) ? ($clog2(8)) : 1)-1:0]    req_size_m1;
    wire [((($clog2(8)) != 0) ? ($clog2(8)) : 1)-1:0]    req_core_id;
    wire                    req_ready;
    wire                    rsp_valid;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]    rsp_id;
    modport master (
        output  req_valid,
        output  req_id,
        output  req_size_m1,    
        output  req_core_id,
        input   req_ready,
        input   rsp_valid,
        input   rsp_id
    );
    modport slave (
        input   req_valid,
        input   req_id,
        input   req_size_m1,
        input   req_core_id,
        output  req_ready,
        output  rsp_valid,
        output  rsp_id
    );
endinterface
