module VX_socket import VX_gpu_pkg::*; #(
    parameter SOCKET_ID = 0,
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_dcr_bus_if.slave     dcr_bus_if,
    VX_mem_bus_if.master    mem_bus_if,
    output wire             busy
);
    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_WORD_SIZE),
        .TAG_WIDTH (ICACHE_TAG_WIDTH)
    ) per_core_icache_bus_if[(((4) < (2)) ? (4) : (2))]();
    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_LINE_SIZE),
        .TAG_WIDTH (ICACHE_MEM_TAG_WIDTH)
    ) icache_mem_bus_if();
    wire [1-1:0] icache_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __icache_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (icache_reset)                          
    );
    VX_cache_cluster #(
        .INSTANCE_ID    ($sformatf("%s-icache", INSTANCE_ID)),
        .NUM_UNITS      (((((((4) < (2)) ? (4) : (2)) / 4) != 0) ? ((((4) < (2)) ? (4) : (2)) / 4) : 1)),
        .NUM_INPUTS     ((((4) < (2)) ? (4) : (2))),
        .TAG_SEL_IDX    (0),
        .CACHE_SIZE     (16384),
        .LINE_SIZE      (ICACHE_LINE_SIZE),
        .NUM_BANKS      (1),
        .NUM_WAYS       (1),
        .WORD_SIZE      (ICACHE_WORD_SIZE),
        .NUM_REQS       (1),
        .CRSQ_SIZE      (2),
        .MSHR_SIZE      (16),
        .MRSQ_SIZE      (0),
        .MREQ_SIZE      (4),
        .TAG_WIDTH      (ICACHE_TAG_WIDTH),
        .UUID_WIDTH     (1),
        .WRITE_ENABLE   (0),
        .NC_ENABLE      (0),
        .CORE_OUT_BUF   (2),
        .MEM_OUT_BUF    (2)
    ) icache (
        .clk            (clk),
        .reset          (icache_reset),
        .core_bus_if    (per_core_icache_bus_if),
        .mem_bus_if     (icache_mem_bus_if)
    );
    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_WORD_SIZE),
        .TAG_WIDTH (DCACHE_TAG_WIDTH)
    ) per_core_dcache_bus_if[(((4) < (2)) ? (4) : (2)) * DCACHE_NUM_REQS]();
    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_LINE_SIZE),
        .TAG_WIDTH (DCACHE_MEM_TAG_WIDTH)
    ) dcache_mem_bus_if();
    wire [1-1:0] dcache_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __dcache_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (dcache_reset)                          
    );
    VX_cache_cluster #(
        .INSTANCE_ID    ($sformatf("%s-dcache", INSTANCE_ID)),
        .NUM_UNITS      (((((((4) < (2)) ? (4) : (2)) / 4) != 0) ? ((((4) < (2)) ? (4) : (2)) / 4) : 1)),
        .NUM_INPUTS     ((((4) < (2)) ? (4) : (2))),
        .TAG_SEL_IDX    (0),
        .CACHE_SIZE     (16384),
        .LINE_SIZE      (DCACHE_LINE_SIZE),
        .NUM_BANKS      ((((4) < (4)) ? (4) : (4))),
        .NUM_WAYS       (1),
        .WORD_SIZE      (DCACHE_WORD_SIZE),
        .NUM_REQS       (DCACHE_NUM_REQS),
        .CRSQ_SIZE      (2),
        .MSHR_SIZE      (16),
        .MRSQ_SIZE      (0),
        .MREQ_SIZE      (0 ? 16 : 4),
        .TAG_WIDTH      (DCACHE_TAG_WIDTH),
        .UUID_WIDTH     (1),
        .WRITE_ENABLE   (1),
        .WRITEBACK      (0),
        .DIRTY_BYTES    (0),
        .NC_ENABLE      (1),
        .CORE_OUT_BUF   (2),
        .MEM_OUT_BUF    (2)
    ) dcache (
        .clk            (clk),
        .reset          (dcache_reset),
        .core_bus_if    (per_core_dcache_bus_if),
        .mem_bus_if     (dcache_mem_bus_if)
    );
    VX_mem_bus_if #(
        .DATA_SIZE (16),
        .TAG_WIDTH (L1_MEM_TAG_WIDTH)
    ) l1_mem_bus_if[2]();
    VX_mem_bus_if #(
        .DATA_SIZE (16),
        .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
    ) l1_mem_arb_bus_if[1]();
    assign l1_mem_bus_if[0].req_valid = icache_mem_bus_if.req_valid; 
    assign l1_mem_bus_if[0].req_data.rw = icache_mem_bus_if.req_data.rw; 
    assign l1_mem_bus_if[0].req_data.byteen = icache_mem_bus_if.req_data.byteen; 
    assign l1_mem_bus_if[0].req_data.addr = icache_mem_bus_if.req_data.addr; 
    assign l1_mem_bus_if[0].req_data.atype = icache_mem_bus_if.req_data.atype; 
    assign l1_mem_bus_if[0].req_data.data = icache_mem_bus_if.req_data.data; 
    if (L1_MEM_TAG_WIDTH != ICACHE_MEM_TAG_WIDTH) 
        assign l1_mem_bus_if[0].req_data.tag = {icache_mem_bus_if.req_data.tag, {(L1_MEM_TAG_WIDTH-ICACHE_MEM_TAG_WIDTH){1'b0}}}; 
    else 
        assign l1_mem_bus_if[0].req_data.tag = icache_mem_bus_if.req_data.tag; 
    assign icache_mem_bus_if.req_ready = l1_mem_bus_if[0].req_ready; 
    assign icache_mem_bus_if.rsp_valid = l1_mem_bus_if[0].rsp_valid; 
    assign icache_mem_bus_if.rsp_data.data = l1_mem_bus_if[0].rsp_data.data; 
    assign icache_mem_bus_if.rsp_data.tag = l1_mem_bus_if[0].rsp_data.tag[L1_MEM_TAG_WIDTH-1 -: ICACHE_MEM_TAG_WIDTH]; 
    assign l1_mem_bus_if[0].rsp_ready = icache_mem_bus_if.rsp_ready;
    assign l1_mem_bus_if[1].req_valid = dcache_mem_bus_if.req_valid; 
    assign l1_mem_bus_if[1].req_data.rw = dcache_mem_bus_if.req_data.rw; 
    assign l1_mem_bus_if[1].req_data.byteen = dcache_mem_bus_if.req_data.byteen; 
    assign l1_mem_bus_if[1].req_data.addr = dcache_mem_bus_if.req_data.addr; 
    assign l1_mem_bus_if[1].req_data.atype = dcache_mem_bus_if.req_data.atype; 
    assign l1_mem_bus_if[1].req_data.data = dcache_mem_bus_if.req_data.data; 
    if (L1_MEM_TAG_WIDTH != DCACHE_MEM_TAG_WIDTH) 
        assign l1_mem_bus_if[1].req_data.tag = {dcache_mem_bus_if.req_data.tag, {(L1_MEM_TAG_WIDTH-DCACHE_MEM_TAG_WIDTH){1'b0}}}; 
    else 
        assign l1_mem_bus_if[1].req_data.tag = dcache_mem_bus_if.req_data.tag; 
    assign dcache_mem_bus_if.req_ready = l1_mem_bus_if[1].req_ready; 
    assign dcache_mem_bus_if.rsp_valid = l1_mem_bus_if[1].rsp_valid; 
    assign dcache_mem_bus_if.rsp_data.data = l1_mem_bus_if[1].rsp_data.data; 
    assign dcache_mem_bus_if.rsp_data.tag = l1_mem_bus_if[1].rsp_data.tag[L1_MEM_TAG_WIDTH-1 -: DCACHE_MEM_TAG_WIDTH]; 
    assign l1_mem_bus_if[1].rsp_ready = dcache_mem_bus_if.rsp_ready;
    VX_mem_arb #(
        .NUM_INPUTS   (2),
        .DATA_SIZE    (16),
        .TAG_WIDTH    (L1_MEM_TAG_WIDTH),
        .TAG_SEL_IDX  (0),
        .ARBITER      ("R"),
        .REQ_OUT_BUF  (2),
        .RSP_OUT_BUF  (2)
    ) mem_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_if  (l1_mem_bus_if),
        .bus_out_if (l1_mem_arb_bus_if)
    );
    assign mem_bus_if.req_valid  = l1_mem_arb_bus_if[0].req_valid; 
    assign mem_bus_if.req_data   = l1_mem_arb_bus_if[0].req_data; 
    assign l1_mem_arb_bus_if[0].req_ready  = mem_bus_if.req_ready; 
    assign l1_mem_arb_bus_if[0].rsp_valid  = mem_bus_if.rsp_valid; 
    assign l1_mem_arb_bus_if[0].rsp_data   = mem_bus_if.rsp_data; 
    assign mem_bus_if.rsp_ready  = l1_mem_arb_bus_if[0].rsp_ready;
    wire [(((4) < (2)) ? (4) : (2))-1:0] per_core_busy;
    VX_dcr_bus_if core_dcr_bus_if();
    if (((((4) < (2)) ? (4) : (2)) > 1)) begin 
        reg [(1 + 12 + 32)-1:0] __dst; 
        always @(posedge clk) begin 
            __dst <= {dcr_bus_if.write_valid, dcr_bus_if.write_addr, dcr_bus_if.write_data}; 
        end 
        assign {core_dcr_bus_if.write_valid, core_dcr_bus_if.write_addr, core_dcr_bus_if.write_data} = __dst; 
    end else begin 
        assign {core_dcr_bus_if.write_valid, core_dcr_bus_if.write_addr, core_dcr_bus_if.write_data} = {dcr_bus_if.write_valid, dcr_bus_if.write_addr, dcr_bus_if.write_data}; 
    end;
    for (genvar core_id = 0; core_id < (((4) < (2)) ? (4) : (2)); ++core_id) begin : cores
    wire [1-1:0] core_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __core_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (core_reset)                          
    );
        VX_core #(
            .CORE_ID  ((SOCKET_ID * (((4) < (2)) ? (4) : (2))) + core_id),
            .INSTANCE_ID ($sformatf("%s-core%0d", INSTANCE_ID, core_id))
        ) core (
            .clk            (clk),
            .reset          (core_reset),
            .dcr_bus_if     (core_dcr_bus_if),
            .dcache_bus_if  (per_core_dcache_bus_if[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .icache_bus_if  (per_core_icache_bus_if[core_id]),
            .busy           (per_core_busy[core_id])
        );
    end
    VX_pipe_register #( 
        .DATAW  ($bits(busy)), 
        .RESETW ($bits(busy)), 
        .DEPTH  (((((4) < (2)) ? (4) : (2)) > 1)) 
    ) __busy__ ( 
        .clk      (clk), 
        .reset    (reset), 
        .enable   (1'b1), 
        .data_in  ((| per_core_busy)), 
        .data_out (busy) 
    );
endmodule
