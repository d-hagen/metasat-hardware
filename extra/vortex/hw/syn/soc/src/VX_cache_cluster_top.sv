module VX_cache_cluster_top import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID    = "",
    parameter NUM_UNITS             = 2,
    parameter NUM_INPUTS            = 4,
    parameter TAG_SEL_IDX           = 0,
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
    parameter TAG_WIDTH             = UUID_WIDTH + 16,
    parameter NC_ENABLE             = 1,
    parameter CORE_OUT_REG          = 2,
    parameter MEM_OUT_REG           = 2,
    parameter NUM_CACHES = (((NUM_UNITS) != 0) ? (NUM_UNITS) : 1),
    parameter PASSTHRU   = (NUM_UNITS == 0),
    parameter ARB_TAG_WIDTH = TAG_WIDTH + ((NUM_INPUTS > NUM_CACHES) ? $clog2((NUM_INPUTS + NUM_CACHES - 1) / NUM_CACHES) : 0),
    parameter MEM_TAG_WIDTH = PASSTHRU ? (NC_ENABLE ? 
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + ARB_TAG_WIDTH) : 
        (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + ARB_TAG_WIDTH) + 1)) : 
                                          (NC_ENABLE ? 
        (((
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS) + 1)) > (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + ARB_TAG_WIDTH))) ? (
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS) + 1)) : (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + ARB_TAG_WIDTH))) :
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS) + 1)),
    parameter MEM_TAG_X_WIDTH = MEM_TAG_WIDTH + ((NUM_CACHES > 1) ? $clog2((NUM_CACHES + 1 - 1) / 1) : 0)
 ) (    
    input wire clk,
    input wire reset,
    input  wire [NUM_INPUTS-1:0][NUM_REQS-1:0]                 core_req_valid,
    input  wire [NUM_INPUTS-1:0][NUM_REQS-1:0]                 core_req_rw,
    input  wire [NUM_INPUTS-1:0][NUM_REQS-1:0][WORD_SIZE-1:0]  core_req_byteen,
    input  wire [NUM_INPUTS-1:0][NUM_REQS-1:0][(32-$clog2(WORD_SIZE))-1:0] core_req_addr,
    input  wire [NUM_INPUTS-1:0][NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_req_data,
    input  wire [NUM_INPUTS-1:0][NUM_REQS-1:0][TAG_WIDTH-1:0]  core_req_tag,
    output wire [NUM_INPUTS-1:0][NUM_REQS-1:0]                 core_req_ready,
    output wire [NUM_INPUTS-1:0][NUM_REQS-1:0]                 core_rsp_valid,
    output wire [NUM_INPUTS-1:0][NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_rsp_data,
    output wire [NUM_INPUTS-1:0][NUM_REQS-1:0][TAG_WIDTH-1:0]  core_rsp_tag,
    input  wire [NUM_INPUTS-1:0][NUM_REQS-1:0]                 core_rsp_ready,
    output wire                    mem_req_valid,
    output wire                    mem_req_rw, 
    output wire [LINE_SIZE-1:0]    mem_req_byteen,
    output wire [(32-$clog2(LINE_SIZE))-1:0] mem_req_addr,
    output wire [(8 * LINE_SIZE)-1:0] mem_req_data, 
    output wire [MEM_TAG_X_WIDTH-1:0] mem_req_tag, 
    input  wire                    mem_req_ready,
    input  wire                    mem_rsp_valid, 
    input  wire [(8 * LINE_SIZE)-1:0] mem_rsp_data,
    input  wire [MEM_TAG_X_WIDTH-1:0] mem_rsp_tag, 
    output wire                    mem_rsp_ready
);
    VX_mem_bus_if #(
        .DATA_SIZE (WORD_SIZE),
        .TAG_WIDTH (TAG_WIDTH)
    ) core_bus_if[NUM_INPUTS * NUM_REQS]();
    VX_mem_bus_if #(
        .DATA_SIZE (LINE_SIZE),
        .TAG_WIDTH (MEM_TAG_X_WIDTH)
    ) mem_bus_if();
    for (genvar i = 0; i < NUM_INPUTS; ++i) begin
        for (genvar r = 0; r < NUM_REQS; ++r) begin
            assign core_bus_if[i * NUM_REQS + r].req_valid = core_req_valid[i][r];
            assign core_bus_if[i * NUM_REQS + r].req_data.rw = core_req_rw[i][r];
            assign core_bus_if[i * NUM_REQS + r].req_data.byteen = core_req_byteen[i][r];
            assign core_bus_if[i * NUM_REQS + r].req_data.addr = core_req_addr[i][r];
            assign core_bus_if[i * NUM_REQS + r].req_data.data = core_req_data[i][r];
            assign core_bus_if[i * NUM_REQS + r].req_data.tag = core_req_tag[i][r];
            assign core_req_ready[i][r] = core_bus_if[i * NUM_REQS + r].req_ready;
        end
    end
    for (genvar i = 0; i < NUM_INPUTS; ++i) begin
        for (genvar r = 0; r < NUM_REQS; ++r) begin
            assign core_rsp_valid[i][r] = core_bus_if[i * NUM_REQS + r].rsp_valid;
            assign core_rsp_data[i][r] = core_bus_if[i * NUM_REQS + r].rsp_data.data;
            assign core_rsp_tag[i][r] = core_bus_if[i * NUM_REQS + r].rsp_data.tag;
            assign core_bus_if[i * NUM_REQS + r].rsp_ready = core_rsp_ready[i][r];
        end
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
    VX_cache_cluster #(
        .INSTANCE_ID    (INSTANCE_ID),
        .NUM_UNITS      (NUM_UNITS),
        .NUM_INPUTS     (NUM_INPUTS),
        .TAG_SEL_IDX    (TAG_SEL_IDX),
        .NUM_REQS       (NUM_REQS),
        .CACHE_SIZE     (CACHE_SIZE),        
        .LINE_SIZE      (LINE_SIZE),
        .NUM_BANKS      (NUM_BANKS),
        .NUM_WAYS       (NUM_WAYS),
        .WORD_SIZE      (WORD_SIZE),
        .CRSQ_SIZE      (CRSQ_SIZE),
        .MSHR_SIZE      (MSHR_SIZE),
        .MRSQ_SIZE      (MRSQ_SIZE),
        .MREQ_SIZE      (MREQ_SIZE),
        .WRITE_ENABLE   (WRITE_ENABLE),
        .UUID_WIDTH     (UUID_WIDTH),
        .TAG_WIDTH      (TAG_WIDTH),
        .NC_ENABLE      (NC_ENABLE),
        .CORE_OUT_REG   (CORE_OUT_REG),
        .MEM_OUT_REG    (MEM_OUT_REG)
    ) cache (
        .clk            (clk),
        .reset          (reset),
        .core_bus_if    (core_bus_if),
        .mem_bus_if     (mem_bus_if)
    );
endmodule
