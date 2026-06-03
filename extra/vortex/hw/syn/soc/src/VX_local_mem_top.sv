module VX_local_mem_top import VX_gpu_pkg::*; #(
    parameter   INSTANCE_ID = "",
    parameter SIZE              = (1024*16*8), 
    parameter NUM_REQS          = 4, 
    parameter NUM_BANKS         = 4,
    parameter ADDR_WIDTH        = $clog2(SIZE),
    parameter WORD_SIZE         = 32/8,
    parameter UUID_WIDTH        = 0,
    parameter TAG_WIDTH         = 16
 ) (    
    input wire clk,
    input wire reset,
    input  wire [NUM_REQS-1:0]                 mem_req_valid,
    input  wire [NUM_REQS-1:0]                 mem_req_rw,
    input  wire [NUM_REQS-1:0][WORD_SIZE-1:0]  mem_req_byteen,
    input  wire [NUM_REQS-1:0][ADDR_WIDTH-1:0] mem_req_addr,
    input  wire [NUM_REQS-1:0][(2 + 1)-1:0] mem_req_atype,
    input  wire [NUM_REQS-1:0][WORD_SIZE*8-1:0] mem_req_data,
    input  wire [NUM_REQS-1:0][TAG_WIDTH-1:0]  mem_req_tag,
    output wire [NUM_REQS-1:0]                 mem_req_ready,
    output wire [NUM_REQS-1:0]                 mem_rsp_valid,
    output wire [NUM_REQS-1:0][WORD_SIZE*8-1:0] mem_rsp_data,
    output wire [NUM_REQS-1:0][TAG_WIDTH-1:0]  mem_rsp_tag,
    input  wire [NUM_REQS-1:0]                 mem_rsp_ready
);
    VX_mem_bus_if #(
        .DATA_SIZE (WORD_SIZE),
        .TAG_WIDTH (TAG_WIDTH)
    ) mem_bus_if[NUM_REQS]();
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign mem_bus_if[i].req_valid = mem_req_valid[i];
        assign mem_bus_if[i].req_data.rw = mem_req_rw[i];
        assign mem_bus_if[i].req_data.byteen = mem_req_byteen[i];
        assign mem_bus_if[i].req_data.addr = mem_req_addr[i];
        assign mem_bus_if[i].req_data.atype = mem_req_atype[i];
        assign mem_bus_if[i].req_data.data = mem_req_data[i];
        assign mem_bus_if[i].req_data.tag = mem_req_tag[i];
        assign mem_req_ready[i] = mem_bus_if[i].req_ready;
    end
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign mem_rsp_valid[i] = mem_bus_if[i].rsp_valid;
        assign mem_rsp_data[i] = mem_bus_if[i].rsp_data.data;
        assign mem_rsp_tag[i] = mem_bus_if[i].rsp_data.tag;
        assign mem_bus_if[i].rsp_ready = mem_rsp_ready[i];
    end
    VX_local_mem #(
        .INSTANCE_ID(INSTANCE_ID),
        .SIZE       (SIZE),
        .NUM_REQS   (NUM_REQS),
        .NUM_BANKS  (NUM_BANKS),
        .WORD_SIZE  (WORD_SIZE),
        .ADDR_WIDTH (ADDR_WIDTH),
        .UUID_WIDTH (UUID_WIDTH), 
        .TAG_WIDTH  (TAG_WIDTH)
    ) local_mem (        
        .clk        (clk),
        .reset      (reset),
        .mem_bus_if (mem_bus_if)
    );
endmodule
