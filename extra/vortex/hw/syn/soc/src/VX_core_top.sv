module VX_core_top import VX_gpu_pkg::*; #( 
    parameter CORE_ID = 0
) (  
    input wire                              clk,
    input wire                              reset,
    input wire                              dcr_write_valid,
    input wire [12-1:0]     dcr_write_addr,
    input wire [32-1:0]     dcr_write_data,
    output wire [DCACHE_NUM_REQS-1:0]       dcache_req_valid,
    output wire [DCACHE_NUM_REQS-1:0]       dcache_req_rw,
    output wire [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE-1:0] dcache_req_byteen,
    output wire [DCACHE_NUM_REQS-1:0][DCACHE_ADDR_WIDTH-1:0] dcache_req_addr,
    output wire [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE*8-1:0] dcache_req_data,
    output wire [DCACHE_NUM_REQS-1:0][DCACHE_NOSM_TAG_WIDTH-1:0] dcache_req_tag,
    input  wire [DCACHE_NUM_REQS-1:0]       dcache_req_ready,
    input wire  [DCACHE_NUM_REQS-1:0]       dcache_rsp_valid,
    input wire  [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE*8-1:0] dcache_rsp_data,
    input wire  [DCACHE_NUM_REQS-1:0][DCACHE_NOSM_TAG_WIDTH-1:0] dcache_rsp_tag,
    output wire [DCACHE_NUM_REQS-1:0]       dcache_rsp_ready,
    output wire                             icache_req_valid,
    output wire                             icache_req_rw,
    output wire [ICACHE_WORD_SIZE-1:0]      icache_req_byteen,
    output wire [ICACHE_ADDR_WIDTH-1:0]     icache_req_addr,
    output wire [ICACHE_WORD_SIZE*8-1:0]    icache_req_data,
    output wire [ICACHE_TAG_WIDTH-1:0]      icache_req_tag,
    input  wire                             icache_req_ready,
    input wire                              icache_rsp_valid,
    input wire  [ICACHE_WORD_SIZE*8-1:0]    icache_rsp_data,
    input wire  [ICACHE_TAG_WIDTH-1:0]      icache_rsp_tag,
    output wire                             icache_rsp_ready,
    output wire                             sim_ebreak,
    output wire [32-1:0][32-1:0]  sim_wb_value,
    output wire                             busy
);
    VX_dcr_bus_if dcr_bus_if(); 
    assign dcr_bus_if.write_valid = dcr_write_valid;
    assign dcr_bus_if.write_addr = dcr_write_addr;
    assign dcr_bus_if.write_data = dcr_write_data;
    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_WORD_SIZE),
        .TAG_WIDTH (DCACHE_NOSM_TAG_WIDTH)
    ) dcache_bus_if[DCACHE_NUM_REQS]();
    for (genvar i = 0; i < DCACHE_NUM_REQS; ++i) begin
        assign dcache_req_valid[i] = dcache_bus_if[i].req_valid;
        assign dcache_req_rw[i] = dcache_bus_if[i].req_data.rw;
        assign dcache_req_byteen[i] = dcache_bus_if[i].req_data.byteen;
        assign dcache_req_addr[i] = dcache_bus_if[i].req_data.addr;
        assign dcache_req_data[i] = dcache_bus_if[i].req_data.data;
        assign dcache_req_tag[i] = dcache_bus_if[i].req_data.tag;
        assign dcache_bus_if[i].req_ready = dcache_req_ready[i];
        assign dcache_bus_if[i].rsp_valid = dcache_rsp_valid[i];
        assign dcache_bus_if[i].rsp_data.tag = dcache_rsp_tag[i];
        assign dcache_bus_if[i].rsp_data.data = dcache_rsp_data[i];
        assign dcache_rsp_ready[i] = dcache_bus_if[i].rsp_ready;
    end
    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_WORD_SIZE),
        .TAG_WIDTH (ICACHE_TAG_WIDTH)
    ) icache_bus_if();
    assign icache_req_valid = icache_bus_if.req_valid;
    assign icache_req_rw = icache_bus_if.req_data.rw;
    assign icache_req_byteen = icache_bus_if.req_data.byteen;
    assign icache_req_addr = icache_bus_if.req_data.addr;
    assign icache_req_data = icache_bus_if.req_data.data;
    assign icache_req_tag = icache_bus_if.req_data.tag;
    assign icache_bus_if.req_ready = icache_req_ready;
    assign icache_bus_if.rsp_valid = icache_rsp_valid;
    assign icache_bus_if.rsp_data.tag = icache_rsp_tag;
    assign icache_bus_if.rsp_data.data = icache_rsp_data;
    assign icache_rsp_ready = icache_bus_if.rsp_ready;
    VX_core #(
        .CORE_ID (CORE_ID)
    ) core (
        .clk            (clk),
        .reset          (reset),
        .dcr_bus_if     (dcr_bus_if),
        .dcache_bus_if  (dcache_bus_if),
        .icache_bus_if  (icache_bus_if),
        .sim_ebreak     (sim_ebreak),
        .sim_wb_value   (sim_wb_value),
        .busy           (busy)
    );
endmodule
