module VX_cache_cluster import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID    = "",
    parameter NUM_UNITS             = 1,
    parameter NUM_INPUTS            = 1,
    parameter TAG_SEL_IDX           = 0,
    parameter NUM_REQS              = 4,
    parameter CACHE_SIZE            = 16384,
    parameter LINE_SIZE             = 64,
    parameter NUM_BANKS             = 1,
    parameter NUM_WAYS              = 4,
    parameter WORD_SIZE             = 4,
    parameter CRSQ_SIZE             = 2,
    parameter MSHR_SIZE             = 8,
    parameter MRSQ_SIZE             = 0,
    parameter MREQ_SIZE             = 4,
    parameter WRITE_ENABLE          = 1,
    parameter WRITEBACK             = 0,
    parameter DIRTY_BYTES           = 0,
    parameter UUID_WIDTH            = 0,
    parameter TAG_WIDTH             = UUID_WIDTH + 1,
    parameter NC_ENABLE             = 0,
    parameter CORE_OUT_BUF          = 0,
    parameter MEM_OUT_BUF           = 0
 ) (
    input wire clk,
    input wire reset,
    VX_mem_bus_if.slave     core_bus_if [NUM_INPUTS * NUM_REQS],
    VX_mem_bus_if.master    mem_bus_if
);
    localparam NUM_CACHES = (((NUM_UNITS) != 0) ? (NUM_UNITS) : 1);
    localparam PASSTHRU   = (NUM_UNITS == 0);
    localparam ARB_TAG_WIDTH = TAG_WIDTH + ((NUM_INPUTS > NUM_CACHES) ? $clog2(((NUM_INPUTS + NUM_CACHES - 1) / (NUM_CACHES))) : 0);
    localparam MEM_TAG_WIDTH = PASSTHRU ? 
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + ARB_TAG_WIDTH) :
                                          (NC_ENABLE ? 
        ((((
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS))) > (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + ARB_TAG_WIDTH))) ? (
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS))) : (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + ARB_TAG_WIDTH))) + 1) :
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS)));
    VX_mem_bus_if #(
        .DATA_SIZE (LINE_SIZE),
        .TAG_WIDTH (MEM_TAG_WIDTH)
    ) cache_mem_bus_if[NUM_CACHES]();
    VX_mem_bus_if #(
        .DATA_SIZE (WORD_SIZE),
        .TAG_WIDTH (ARB_TAG_WIDTH)
    ) arb_core_bus_if[NUM_CACHES * NUM_REQS]();
    wire [NUM_REQS-1:0] cache_arb_reset;                        
    VX_reset_relay #(.N(NUM_REQS), .MAX_FANOUT(8)) __cache_arb_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (cache_arb_reset)                          
    );
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        VX_mem_bus_if #(
            .DATA_SIZE (WORD_SIZE),
            .TAG_WIDTH (TAG_WIDTH)
        ) core_bus_tmp_if[NUM_INPUTS]();
        VX_mem_bus_if #(
            .DATA_SIZE (WORD_SIZE),
            .TAG_WIDTH (ARB_TAG_WIDTH)
        ) arb_core_bus_tmp_if[NUM_CACHES]();
        for (genvar j = 0; j < NUM_INPUTS; ++j) begin
    assign core_bus_tmp_if[j].req_valid  = core_bus_if[j * NUM_REQS + i].req_valid; 
    assign core_bus_tmp_if[j].req_data   = core_bus_if[j * NUM_REQS + i].req_data; 
    assign core_bus_if[j * NUM_REQS + i].req_ready  = core_bus_tmp_if[j].req_ready; 
    assign core_bus_if[j * NUM_REQS + i].rsp_valid  = core_bus_tmp_if[j].rsp_valid; 
    assign core_bus_if[j * NUM_REQS + i].rsp_data   = core_bus_tmp_if[j].rsp_data; 
    assign core_bus_tmp_if[j].rsp_ready  = core_bus_if[j * NUM_REQS + i].rsp_ready;
        end
        VX_mem_arb #(
            .NUM_INPUTS   (NUM_INPUTS),
            .NUM_OUTPUTS  (NUM_CACHES),
            .DATA_SIZE    (WORD_SIZE),
            .TAG_WIDTH    (TAG_WIDTH),
            .TAG_SEL_IDX  (TAG_SEL_IDX),
            .ARBITER      ("R"),
            .REQ_OUT_BUF  ((NUM_INPUTS != NUM_CACHES) ? 2 : 0),
            .RSP_OUT_BUF  ((NUM_INPUTS != NUM_CACHES) ? 2 : 0)
        ) cache_arb (
            .clk        (clk),
            .reset      (cache_arb_reset[i]),
            .bus_in_if  (core_bus_tmp_if),
            .bus_out_if (arb_core_bus_tmp_if)
        );
        for (genvar k = 0; k < NUM_CACHES; ++k) begin
    assign arb_core_bus_if[k * NUM_REQS + i].req_valid  = arb_core_bus_tmp_if[k].req_valid; 
    assign arb_core_bus_if[k * NUM_REQS + i].req_data   = arb_core_bus_tmp_if[k].req_data; 
    assign arb_core_bus_tmp_if[k].req_ready  = arb_core_bus_if[k * NUM_REQS + i].req_ready; 
    assign arb_core_bus_tmp_if[k].rsp_valid  = arb_core_bus_if[k * NUM_REQS + i].rsp_valid; 
    assign arb_core_bus_tmp_if[k].rsp_data   = arb_core_bus_if[k * NUM_REQS + i].rsp_data; 
    assign arb_core_bus_if[k * NUM_REQS + i].rsp_ready  = arb_core_bus_tmp_if[k].rsp_ready;
        end
    end
     for (genvar i = 0; i < NUM_CACHES; ++i) begin : caches
    wire [1-1:0] cache_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __cache_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (cache_reset)                          
    );
        VX_cache_wrap #(
            .INSTANCE_ID  ($sformatf("%s%0d", INSTANCE_ID, i)),
            .CACHE_SIZE   (CACHE_SIZE),
            .LINE_SIZE    (LINE_SIZE),
            .NUM_BANKS    (NUM_BANKS),
            .NUM_WAYS     (NUM_WAYS),
            .WORD_SIZE    (WORD_SIZE),
            .NUM_REQS     (NUM_REQS),
            .CRSQ_SIZE    (CRSQ_SIZE),
            .MSHR_SIZE    (MSHR_SIZE),
            .MRSQ_SIZE    (MRSQ_SIZE),
            .MREQ_SIZE    (MREQ_SIZE),
            .WRITE_ENABLE (WRITE_ENABLE),
            .WRITEBACK    (WRITEBACK),
            .DIRTY_BYTES  (DIRTY_BYTES),
            .UUID_WIDTH   (UUID_WIDTH),
            .TAG_WIDTH    (ARB_TAG_WIDTH),
            .TAG_SEL_IDX  (TAG_SEL_IDX),
            .CORE_OUT_BUF ((NUM_INPUTS != NUM_CACHES) ? 2 : CORE_OUT_BUF),
            .MEM_OUT_BUF  ((NUM_CACHES > 1) ? 2 : MEM_OUT_BUF),
            .NC_ENABLE    (NC_ENABLE),
            .PASSTHRU     (PASSTHRU)
        ) cache_wrap (
            .clk         (clk),
            .reset       (cache_reset),
            .core_bus_if (arb_core_bus_if[i * NUM_REQS +: NUM_REQS]),
            .mem_bus_if  (cache_mem_bus_if[i])
        );
    end
    VX_mem_bus_if #(
        .DATA_SIZE (LINE_SIZE),
        .TAG_WIDTH (MEM_TAG_WIDTH + ((NUM_CACHES > 1) ? $clog2(((NUM_CACHES + 1 - 1) / (1))) : 0))
    ) mem_bus_tmp_if[1]();
    VX_mem_arb #(
        .NUM_INPUTS   (NUM_CACHES),
        .DATA_SIZE    (LINE_SIZE),
        .TAG_WIDTH    (MEM_TAG_WIDTH),
        .TAG_SEL_IDX  (TAG_SEL_IDX),
        .ARBITER      ("R"),
        .REQ_OUT_BUF ((NUM_CACHES > 1) ? 2 : 0),
        .RSP_OUT_BUF ((NUM_CACHES > 1) ? 2 : 0)
    ) mem_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_if  (cache_mem_bus_if),
        .bus_out_if (mem_bus_tmp_if)
    );
    assign mem_bus_if.req_valid  = mem_bus_tmp_if[0].req_valid; 
    assign mem_bus_if.req_data   = mem_bus_tmp_if[0].req_data; 
    assign mem_bus_tmp_if[0].req_ready  = mem_bus_if.req_ready; 
    assign mem_bus_tmp_if[0].rsp_valid  = mem_bus_if.rsp_valid; 
    assign mem_bus_tmp_if[0].rsp_data   = mem_bus_if.rsp_data; 
    assign mem_bus_if.rsp_ready  = mem_bus_tmp_if[0].rsp_ready;
endmodule
