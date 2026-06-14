interface VX_mem_bus_if #(
    parameter DATA_SIZE  = 1,
    parameter ATYPE_WIDTH= (2 + 1),
    parameter TAG_WIDTH  = 1,
    parameter MEM_ADDR_WIDTH = 32,
    parameter ADDR_WIDTH = MEM_ADDR_WIDTH - $clog2(DATA_SIZE)
) ();
    typedef struct packed {
        logic                   rw;
        logic [DATA_SIZE-1:0]   byteen;
        logic [ADDR_WIDTH-1:0]  addr;
        logic [ATYPE_WIDTH-1:0] atype;
        logic [DATA_SIZE*8-1:0] data;
        logic [TAG_WIDTH-1:0]   tag;
    } req_data_t;
    typedef struct packed {
        logic [DATA_SIZE*8-1:0] data;
        logic [TAG_WIDTH-1:0]   tag;
    } rsp_data_t;
    logic  req_valid;
    req_data_t req_data;
    logic  req_ready;
    logic  rsp_valid;
    rsp_data_t rsp_data;
    logic  rsp_ready;
    modport master (
        output req_valid,
        output req_data,
        input  req_ready,
        input  rsp_valid,
        input  rsp_data,
        output rsp_ready
    );
    modport slave (
        input  req_valid,
        input  req_data,
        output req_ready,
        output rsp_valid,
        output rsp_data,
        input  rsp_ready
    );
endinterface
