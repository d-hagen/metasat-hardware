module VX_socket import VX_gpu_pkg::*; #( 
    parameter SOCKET_ID = 0
) (        
    input wire              clk,
    input wire              reset,
    VX_dcr_bus_if.slave     dcr_bus_if,
    VX_mem_bus_if.master    mem_bus_if,
    output wire             sim_ebreak,
    output wire [32-1:0][32-1:0] sim_wb_value,
    output wire             busy
);
    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_LINE_SIZE),
        .TAG_WIDTH (ICACHE_MEM_TAG_WIDTH)
    ) icache_mem_bus_if();
    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_LINE_SIZE),
        .TAG_WIDTH (DCACHE_MEM_TAG_WIDTH)
    ) dcache_mem_bus_if();
    VX_mem_bus_if #(
        .DATA_SIZE (((0 || 0) ? 16 : 16)),
        .TAG_WIDTH (L1_MEM_TAG_WIDTH)
    ) cache_mem_bus_if[2]();
    VX_mem_bus_if #(
        .DATA_SIZE (((0 || 0) ? 16 : 16)),
        .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
    ) mem_bus_tmp_if[1]();
    assign cache_mem_bus_if[0].req_valid = icache_mem_bus_if.req_valid; 
    assign cache_mem_bus_if[0].req_data.rw = icache_mem_bus_if.req_data.rw; 
    assign cache_mem_bus_if[0].req_data.byteen = icache_mem_bus_if.req_data.byteen; 
    assign cache_mem_bus_if[0].req_data.addr = icache_mem_bus_if.req_data.addr; 
    assign cache_mem_bus_if[0].req_data.data = icache_mem_bus_if.req_data.data; 
    if (L1_MEM_TAG_WIDTH != ICACHE_MEM_TAG_WIDTH) 
        assign cache_mem_bus_if[0].req_data.tag = {icache_mem_bus_if.req_data.tag, {(L1_MEM_TAG_WIDTH-ICACHE_MEM_TAG_WIDTH){1'b0}}}; 
    else 
        assign cache_mem_bus_if[0].req_data.tag = icache_mem_bus_if.req_data.tag; 
    assign icache_mem_bus_if.req_ready = cache_mem_bus_if[0].req_ready; 
    assign icache_mem_bus_if.rsp_valid = cache_mem_bus_if[0].rsp_valid; 
    assign icache_mem_bus_if.rsp_data.data = cache_mem_bus_if[0].rsp_data.data; 
    assign icache_mem_bus_if.rsp_data.tag = cache_mem_bus_if[0].rsp_data.tag[L1_MEM_TAG_WIDTH-1 -: ICACHE_MEM_TAG_WIDTH]; 
    assign cache_mem_bus_if[0].rsp_ready = icache_mem_bus_if.rsp_ready;
    assign cache_mem_bus_if[1].req_valid = dcache_mem_bus_if.req_valid; 
    assign cache_mem_bus_if[1].req_data.rw = dcache_mem_bus_if.req_data.rw; 
    assign cache_mem_bus_if[1].req_data.byteen = dcache_mem_bus_if.req_data.byteen; 
    assign cache_mem_bus_if[1].req_data.addr = dcache_mem_bus_if.req_data.addr; 
    assign cache_mem_bus_if[1].req_data.data = dcache_mem_bus_if.req_data.data; 
    if (L1_MEM_TAG_WIDTH != DCACHE_MEM_TAG_WIDTH) 
        assign cache_mem_bus_if[1].req_data.tag = {dcache_mem_bus_if.req_data.tag, {(L1_MEM_TAG_WIDTH-DCACHE_MEM_TAG_WIDTH){1'b0}}}; 
    else 
        assign cache_mem_bus_if[1].req_data.tag = dcache_mem_bus_if.req_data.tag; 
    assign dcache_mem_bus_if.req_ready = cache_mem_bus_if[1].req_ready; 
    assign dcache_mem_bus_if.rsp_valid = cache_mem_bus_if[1].rsp_valid; 
    assign dcache_mem_bus_if.rsp_data.data = cache_mem_bus_if[1].rsp_data.data; 
    assign dcache_mem_bus_if.rsp_data.tag = cache_mem_bus_if[1].rsp_data.tag[L1_MEM_TAG_WIDTH-1 -: DCACHE_MEM_TAG_WIDTH]; 
    assign cache_mem_bus_if[1].rsp_ready = dcache_mem_bus_if.rsp_ready;
    wire [1-1:0] mem_arb_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mem_arb_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mem_arb_reset)                          
    );
    VX_mem_arb #(
        .NUM_INPUTS   (2),
        .DATA_SIZE    (((0 || 0) ? 16 : 16)),
        .TAG_WIDTH    (L1_MEM_TAG_WIDTH),
        .TAG_SEL_IDX  (1),  
        .ARBITER      ("R"),
        .OUT_REG_REQ  (2),
        .OUT_REG_RSP  (2)
    ) mem_arb (
        .clk        (clk),
        .reset      (mem_arb_reset),
        .bus_in_if  (cache_mem_bus_if),
        .bus_out_if (mem_bus_tmp_if)
    );
    assign mem_bus_if.req_valid  = mem_bus_tmp_if[0].req_valid; 
    assign mem_bus_if.req_data   = mem_bus_tmp_if[0].req_data; 
    assign mem_bus_tmp_if[0].req_ready  = mem_bus_if.req_ready; 
    assign mem_bus_tmp_if[0].rsp_valid  = mem_bus_if.rsp_valid; 
    assign mem_bus_tmp_if[0].rsp_data   = mem_bus_if.rsp_data; 
    assign mem_bus_if.rsp_ready  = mem_bus_tmp_if[0].rsp_ready;
    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_WORD_SIZE), 
        .TAG_WIDTH (ICACHE_TAG_WIDTH)
    ) per_core_icache_bus_if[(((4) < (1)) ? (4) : (1))]();
    wire [1-1:0] icache_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __icache_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (icache_reset)                          
    );
    VX_cache_cluster #(
        .INSTANCE_ID    ($sformatf("socket%0d-icache", SOCKET_ID)),    
        .NUM_UNITS      ((((1 / 4) != 0) ? (1 / 4) : 1)),
        .NUM_INPUTS     ((((4) < (1)) ? (4) : (1))),
        .TAG_SEL_IDX    (0),
        .CACHE_SIZE     (16384),
        .LINE_SIZE      (ICACHE_LINE_SIZE),
        .NUM_BANKS      (1),
        .NUM_WAYS       (2),
        .WORD_SIZE      (ICACHE_WORD_SIZE),
        .NUM_REQS       (1),
        .CRSQ_SIZE      (2),
        .MSHR_SIZE      (16),
        .MRSQ_SIZE      (0),
        .MREQ_SIZE      (4),
        .TAG_WIDTH      (ICACHE_TAG_WIDTH),
        .UUID_WIDTH     (1),
        .WRITE_ENABLE   (0),
        .CORE_OUT_REG   (2),
        .MEM_OUT_REG    (2)
    ) icache (
        .clk            (clk),
        .reset          (icache_reset),
        .core_bus_if    (per_core_icache_bus_if),
        .mem_bus_if     (icache_mem_bus_if)
    );
    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_WORD_SIZE), 
        .TAG_WIDTH (DCACHE_NOSM_TAG_WIDTH)
    ) per_core_dcache_bus_if[(((4) < (1)) ? (4) : (1)) * DCACHE_NUM_REQS]();
    wire [1-1:0] dcache_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __dcache_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (dcache_reset)                          
    );
    VX_cache_cluster #(
        .INSTANCE_ID    ($sformatf("socket%0d-dcache", SOCKET_ID)),    
        .NUM_UNITS      ((((1 / 4) != 0) ? (1 / 4) : 1)),
        .NUM_INPUTS     ((((4) < (1)) ? (4) : (1))),
        .TAG_SEL_IDX    (1),
        .CACHE_SIZE     (16384),
        .LINE_SIZE      (DCACHE_LINE_SIZE),
        .NUM_BANKS      (((((4) < (4)) ? (4) : (4)))),
        .NUM_WAYS       (2),
        .WORD_SIZE      (DCACHE_WORD_SIZE),
        .NUM_REQS       (DCACHE_NUM_REQS),
        .CRSQ_SIZE      (2),
        .MSHR_SIZE      (16),
        .MRSQ_SIZE      (0),
        .MREQ_SIZE      (4),
        .TAG_WIDTH      (DCACHE_NOSM_TAG_WIDTH),
        .UUID_WIDTH     (1),
        .WRITE_ENABLE   (1),        
        .NC_ENABLE      (1),
        .CORE_OUT_REG   (1 ? 2 : 1),
        .MEM_OUT_REG    (2)
    ) dcache (
        .clk            (clk),
        .reset          (dcache_reset),        
        .core_bus_if    (per_core_dcache_bus_if),
        .mem_bus_if     (dcache_mem_bus_if)
    );
    wire [(((4) < (1)) ? (4) : (1))-1:0] per_core_sim_ebreak;
    wire [(((4) < (1)) ? (4) : (1))-1:0][32-1:0][32-1:0] per_core_sim_wb_value;
    assign sim_ebreak = per_core_sim_ebreak[0];
    assign sim_wb_value = per_core_sim_wb_value[0];
    wire [(((4) < (1)) ? (4) : (1))-1:0] per_core_busy;
    logic [(1 + 12 + 32)-1:0] __core_dcr_bus_if; 
    if (((((4) < (1)) ? (4) : (1)) > 1)) begin 
        always @(posedge clk) begin 
            __core_dcr_bus_if <= {dcr_bus_if.write_valid, dcr_bus_if.write_addr, dcr_bus_if.write_data}; 
        end 
    end else begin 
        assign __core_dcr_bus_if = {dcr_bus_if.write_valid, dcr_bus_if.write_addr, dcr_bus_if.write_data}; 
    end 
    VX_dcr_bus_if core_dcr_bus_if(); 
    assign {core_dcr_bus_if.write_valid, core_dcr_bus_if.write_addr, core_dcr_bus_if.write_data} = __core_dcr_bus_if;
    for (genvar i = 0; i < (((4) < (1)) ? (4) : (1)); ++i) begin
    wire [1-1:0] core_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __core_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (core_reset)                          
    );
        VX_core #(
            .CORE_ID ((SOCKET_ID * (((4) < (1)) ? (4) : (1))) + i)
        ) core (
            .clk            (clk),
            .reset          (core_reset),
            .dcr_bus_if     (core_dcr_bus_if),
            .dcache_bus_if  (per_core_dcache_bus_if[i * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .icache_bus_if  (per_core_icache_bus_if[i]),
            .sim_ebreak     (per_core_sim_ebreak[i]),
            .sim_wb_value   (per_core_sim_wb_value[i]),
            .busy           (per_core_busy[i])
        );
    end
    logic __busy; 
    if (((((4) < (1)) ? (4) : (1)) > 1)) begin 
        always @(posedge clk) begin 
            if (reset) begin 
                __busy <= 1'b0; 
            end else begin 
                __busy <= (| per_core_busy); 
            end 
        end 
    end else begin 
        assign __busy = (| per_core_busy); 
    end 
    assign busy = __busy;
endmodule
