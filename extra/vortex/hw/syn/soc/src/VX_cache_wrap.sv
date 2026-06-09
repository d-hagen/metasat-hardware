module VX_cache_wrap import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID    = "",
    parameter TAG_SEL_IDX           = 0,
    parameter NUM_REQS              = 4,
    parameter CACHE_SIZE            = 4096,
    parameter LINE_SIZE             = 64,
    parameter NUM_BANKS             = 1,
    parameter NUM_WAYS              = 1,
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
    parameter PASSTHRU              = 0,
    parameter CORE_OUT_BUF          = 0,
    parameter MEM_OUT_BUF           = 0
 ) (
    input wire clk,
    input wire reset,
    VX_mem_bus_if.slave     core_bus_if [NUM_REQS],
    VX_mem_bus_if.master    mem_bus_if
);
    localparam MSHR_ADDR_WIDTH = (((MSHR_SIZE) > 1) ? $clog2(MSHR_SIZE) : 1);
    localparam CACHE_MEM_TAG_WIDTH = MSHR_ADDR_WIDTH + $clog2(NUM_BANKS);
    localparam MEM_TAG_WIDTH   = PASSTHRU ? 
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + TAG_WIDTH) :
                                            (NC_ENABLE ? 
        ((((
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS))) > (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + TAG_WIDTH))) ? (
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS))) : (
        ($clog2(NUM_REQS) + $clog2(LINE_SIZE / WORD_SIZE) + TAG_WIDTH))) + 1) :
        ($clog2(MSHR_SIZE) + $clog2(NUM_BANKS)));
    localparam NC_OR_BYPASS = (NC_ENABLE || PASSTHRU);
    VX_mem_bus_if #(
        .DATA_SIZE (WORD_SIZE),
        .TAG_WIDTH (TAG_WIDTH)
    ) core_bus_cache_if[NUM_REQS]();
    VX_mem_bus_if #(
        .DATA_SIZE (LINE_SIZE),
        .TAG_WIDTH (CACHE_MEM_TAG_WIDTH)
    ) mem_bus_cache_if();
    if (NC_OR_BYPASS) begin
    wire [1-1:0] nc_bypass_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __nc_bypass_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (nc_bypass_reset)                          
    );
        VX_cache_bypass #(
            .NUM_REQS          (NUM_REQS),
            .TAG_SEL_IDX       (TAG_SEL_IDX),
            .PASSTHRU          (PASSTHRU),
            .NC_ENABLE         (PASSTHRU ? 0 : NC_ENABLE),
            .WORD_SIZE         (WORD_SIZE),
            .LINE_SIZE         (LINE_SIZE),
            .CORE_ADDR_WIDTH   ((32-$clog2(WORD_SIZE))),
            .CORE_TAG_WIDTH    (TAG_WIDTH),
            .MEM_ADDR_WIDTH    ((32-$clog2(LINE_SIZE))),
            .MEM_TAG_IN_WIDTH  (CACHE_MEM_TAG_WIDTH),
            .MEM_TAG_OUT_WIDTH (MEM_TAG_WIDTH),
            .UUID_WIDTH        (UUID_WIDTH),
            .CORE_OUT_BUF      (CORE_OUT_BUF),
            .MEM_OUT_BUF       (MEM_OUT_BUF)
        ) cache_bypass (
            .clk            (clk),
            .reset          (nc_bypass_reset),
            .core_bus_in_if (core_bus_if),
            .core_bus_out_if(core_bus_cache_if),
            .mem_bus_in_if  (mem_bus_cache_if),
            .mem_bus_out_if (mem_bus_if)
        );
    end else begin
        for (genvar i = 0; i < NUM_REQS; ++i) begin
    assign core_bus_cache_if[i].req_valid  = core_bus_if[i].req_valid; 
    assign core_bus_cache_if[i].req_data   = core_bus_if[i].req_data; 
    assign core_bus_if[i].req_ready  = core_bus_cache_if[i].req_ready; 
    assign core_bus_if[i].rsp_valid  = core_bus_cache_if[i].rsp_valid; 
    assign core_bus_if[i].rsp_data   = core_bus_cache_if[i].rsp_data; 
    assign core_bus_cache_if[i].rsp_ready  = core_bus_if[i].rsp_ready;
        end
    assign mem_bus_if.req_valid  = mem_bus_cache_if.req_valid; 
    assign mem_bus_if.req_data   = mem_bus_cache_if.req_data; 
    assign mem_bus_cache_if.req_ready  = mem_bus_if.req_ready; 
    assign mem_bus_cache_if.rsp_valid  = mem_bus_if.rsp_valid; 
    assign mem_bus_cache_if.rsp_data   = mem_bus_if.rsp_data; 
    assign mem_bus_if.rsp_ready  = mem_bus_cache_if.rsp_ready;
    end
    if (PASSTHRU != 0) begin
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            assign core_bus_cache_if[i].req_ready = 0;
            assign core_bus_cache_if[i].rsp_valid = 0;
            assign core_bus_cache_if[i].rsp_data  = '0;
        end
        assign mem_bus_cache_if.req_valid = 0;
        assign mem_bus_cache_if.req_data = '0;
        assign mem_bus_cache_if.rsp_ready = 0;
    end else begin
    wire [1-1:0] cache_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __cache_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (cache_reset)                          
    );
        VX_cache #(
            .INSTANCE_ID  (INSTANCE_ID),
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
            .TAG_WIDTH    (TAG_WIDTH),
            .CORE_OUT_BUF (NC_OR_BYPASS ? 1 : CORE_OUT_BUF),
            .MEM_OUT_BUF  (NC_OR_BYPASS ? 1 : MEM_OUT_BUF)
        ) cache (
            .clk            (clk),
            .reset          (cache_reset),
            .core_bus_if    (core_bus_cache_if),
            .mem_bus_if     (mem_bus_cache_if)
        );
    end
endmodule
