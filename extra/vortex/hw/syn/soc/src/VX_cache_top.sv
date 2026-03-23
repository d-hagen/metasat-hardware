module VX_cache_top #(
    parameter  INSTANCE_ID    = "",
    parameter NUM_REQS              = 4,
    parameter CACHE_SIZE            = 16384, 
    parameter LINE_SIZE             = 16, 
    parameter NUM_BANKS             = 4,
    parameter NUM_WAYS              = 4,
    parameter WORD_SIZE             = 4, 
    parameter CRSQ_SIZE             = 2,
    parameter MSHR_SIZE             = 16, 
    parameter MRSQ_SIZE             = 0,
    parameter MREQ_SIZE             = 4,
    parameter WRITE_ENABLE          = 1,
    parameter UUID_WIDTH            = 0,
    parameter TAG_WIDTH             = 16,
    parameter CORE_OUT_REG          = 2,
    parameter MEM_OUT_REG           = 2,
    parameter MEM_TAG_WIDTH = $clog2(MSHR_SIZE) + $clog2(NUM_BANKS)
 ) (    
    input wire clk,
    input wire reset,
    input  wire [NUM_REQS-1:0]                 core_req_valid,
    input  wire [NUM_REQS-1:0]                 core_req_rw,
    input  wire [NUM_REQS-1:0][WORD_SIZE-1:0]  core_req_byteen,
    input  wire [NUM_REQS-1:0][(32-$clog2(WORD_SIZE))-1:0] core_req_addr,
    input  wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_req_data,
    input  wire [NUM_REQS-1:0][TAG_WIDTH-1:0]  core_req_tag,
    output wire [NUM_REQS-1:0]                 core_req_ready,
    output wire [NUM_REQS-1:0]                 core_rsp_valid,
    output wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_rsp_data,
    output wire [NUM_REQS-1:0][TAG_WIDTH-1:0]  core_rsp_tag,
    input  wire [NUM_REQS-1:0]                 core_rsp_ready,
    output wire                    mem_req_valid,
    output wire                    mem_req_rw, 
    output wire [LINE_SIZE-1:0]    mem_req_byteen,
    output wire [(32-$clog2(LINE_SIZE))-1:0] mem_req_addr,
    output wire [(8 * LINE_SIZE)-1:0] mem_req_data, 
    output wire [MEM_TAG_WIDTH-1:0] mem_req_tag, 
    input  wire                    mem_req_ready,
    input  wire                    mem_rsp_valid, 
    input  wire [(8 * LINE_SIZE)-1:0] mem_rsp_data,
    input  wire [MEM_TAG_WIDTH-1:0] mem_rsp_tag, 
    output wire                    mem_rsp_ready
);
    VX_mem_bus_if #(
        .DATA_SIZE (WORD_SIZE),
        .TAG_WIDTH (TAG_WIDTH)
    ) core_bus_if[NUM_REQS]();
    VX_mem_bus_if #(
        .DATA_SIZE (LINE_SIZE),
        .TAG_WIDTH (MEM_TAG_WIDTH)
    ) mem_bus_if();
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign core_bus_if[i].req_valid = core_req_valid[i];
        assign core_bus_if[i].req_data.rw = core_req_rw[i];
        assign core_bus_if[i].req_data.byteen = core_req_byteen[i];
        assign core_bus_if[i].req_data.addr = core_req_addr[i];
        assign core_bus_if[i].req_data.data = core_req_data[i];
        assign core_bus_if[i].req_data.tag = core_req_tag[i];
        assign core_req_ready[i] = core_bus_if[i].req_ready;
    end
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign core_rsp_valid[i] = core_bus_if[i].rsp_valid;
        assign core_rsp_data[i] = core_bus_if[i].rsp_data.data;
        assign core_rsp_tag[i] = core_bus_if[i].rsp_data.tag;
        assign core_bus_if[i].rsp_ready = core_rsp_ready[i];
    end
    assign mem_req_valid = mem_bus_if.req_valid;
    assign mem_req_rw = mem_bus_if.req_data.rw; 
    assign mem_req_byteen = mem_bus_if.req_data.byteen;
    assign mem_req_addr = mem_bus_if.req_data.addr;
    assign mem_req_data = mem_bus_if.req_data.data;  
    assign mem_req_tag = mem_bus_if.req_data.tag; 
    assign mem_bus_if.req_ready = mem_req_ready;
    assign mem_bus_if.rsp_valid = mem_rsp_valid;    
    assign mem_bus_if.rsp_data.data = mem_rsp_data;
    assign mem_bus_if.rsp_data.tag = mem_rsp_tag; 
    assign mem_rsp_ready = mem_bus_if.rsp_ready;
    VX_cache #(
        .INSTANCE_ID    (INSTANCE_ID),
        .CACHE_SIZE     (CACHE_SIZE),
        .LINE_SIZE      (LINE_SIZE),
        .NUM_BANKS      (NUM_BANKS),
        .NUM_WAYS       (NUM_WAYS),
        .WORD_SIZE      (WORD_SIZE),
        .NUM_REQS       (NUM_REQS),
        .CRSQ_SIZE      (CRSQ_SIZE),
        .MSHR_SIZE      (MSHR_SIZE),
        .MRSQ_SIZE      (MRSQ_SIZE),
        .MREQ_SIZE      (MREQ_SIZE),
        .TAG_WIDTH      (TAG_WIDTH),
        .UUID_WIDTH     (UUID_WIDTH),
        .WRITE_ENABLE   (WRITE_ENABLE),
        .CORE_OUT_REG   (CORE_OUT_REG),
        .MEM_OUT_REG    (MEM_OUT_REG)
    ) cache (
        .clk            (clk),
        .reset          (reset),
        .core_bus_if    (core_bus_if),
        .mem_bus_if     (mem_bus_if)
    );
endmodule
