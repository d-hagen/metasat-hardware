module VX_smem_unit import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    VX_mem_bus_if.slave     dcache_bus_in_if [DCACHE_NUM_REQS],
    VX_mem_bus_if.master    dcache_bus_out_if [DCACHE_NUM_REQS]
);
    localparam SMEM_ADDR_WIDTH = 14 - $clog2(DCACHE_WORD_SIZE);
    wire [DCACHE_NUM_REQS-1:0]                  smem_req_valid;
    wire [DCACHE_NUM_REQS-1:0]                  smem_req_rw;
    wire [DCACHE_NUM_REQS-1:0][SMEM_ADDR_WIDTH-1:0] smem_req_addr;
    wire [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE-1:0] smem_req_byteen;
    wire [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE*8-1:0] smem_req_data;
    wire [DCACHE_NUM_REQS-1:0][DCACHE_NOSM_TAG_WIDTH-1:0] smem_req_tag;
    wire [DCACHE_NUM_REQS-1:0]                  smem_req_ready;
    wire [DCACHE_NUM_REQS-1:0]                  smem_rsp_valid;
    wire [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE*8-1:0] smem_rsp_data;
    wire [DCACHE_NUM_REQS-1:0][DCACHE_NOSM_TAG_WIDTH-1:0] smem_rsp_tag;
    wire [DCACHE_NUM_REQS-1:0]                  smem_rsp_ready;
    wire [1-1:0] smem_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __smem_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (smem_reset)                          
    );
    VX_shared_mem #(
        .INSTANCE_ID($sformatf("core%0d-smem", CORE_ID)),
        .SIZE       (1 << 14),
        .NUM_REQS   (DCACHE_NUM_REQS),
        .NUM_BANKS  (((((4) < (4)) ? (4) : (4)))),
        .WORD_SIZE  (DCACHE_WORD_SIZE),
        .ADDR_WIDTH (SMEM_ADDR_WIDTH),
        .UUID_WIDTH (1), 
        .TAG_WIDTH  (DCACHE_NOSM_TAG_WIDTH)
    ) shared_mem (        
        .clk        (clk),
        .reset      (smem_reset),
        .req_valid  (smem_req_valid),
        .req_rw     (smem_req_rw),
        .req_byteen (smem_req_byteen),
        .req_addr   (smem_req_addr),
        .req_data   (smem_req_data),        
        .req_tag    (smem_req_tag),
        .req_ready  (smem_req_ready),
        .rsp_valid  (smem_rsp_valid),
        .rsp_data   (smem_rsp_data),
        .rsp_tag    (smem_rsp_tag),
        .rsp_ready  (smem_rsp_ready)
    );
    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_WORD_SIZE),
        .TAG_WIDTH (DCACHE_NOSM_TAG_WIDTH)
    ) switch_out_bus_if[2 * DCACHE_NUM_REQS]();
    wire [1-1:0] switch_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __switch_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (switch_reset)                          
    );
    for (genvar i = 0; i < DCACHE_NUM_REQS; ++i) begin
        assign smem_req_valid[i] = switch_out_bus_if[i * 2 + 1].req_valid;
        assign smem_req_rw[i] = switch_out_bus_if[i * 2 + 1].req_data.rw;
        assign smem_req_byteen[i] = switch_out_bus_if[i * 2 + 1].req_data.byteen;
        assign smem_req_data[i] = switch_out_bus_if[i * 2 + 1].req_data.data;
        assign smem_req_tag[i] = switch_out_bus_if[i * 2 + 1].req_data.tag;
        assign switch_out_bus_if[i * 2 + 1].req_ready = smem_req_ready[i];
        assign switch_out_bus_if[i * 2 + 1].rsp_valid = smem_rsp_valid[i];
        assign switch_out_bus_if[i * 2 + 1].rsp_data.data = smem_rsp_data[i];
        assign switch_out_bus_if[i * 2 + 1].rsp_data.tag = smem_rsp_tag[i];
        assign smem_rsp_ready[i] = switch_out_bus_if[i * 2 + 1].rsp_ready;
        assign smem_req_addr[i] = switch_out_bus_if[i * 2 + 1].req_data.addr[SMEM_ADDR_WIDTH-1:0];
        VX_smem_switch #(
            .NUM_REQS     (2),
            .DATA_SIZE    (DCACHE_WORD_SIZE),
            .TAG_WIDTH    (DCACHE_TAG_WIDTH),
            .TAG_SEL_IDX  (0),
            .ARBITER      ("P"),
            .OUT_REG_REQ  (2),
            .OUT_REG_RSP  (2)
        ) smem_switch (
            .clk        (clk),
            .reset      (switch_reset),
            .bus_in_if  (dcache_bus_in_if[i]),
            .bus_out_if (switch_out_bus_if[i * 2 +: 2])
        );
    end
    for (genvar i = 0; i < DCACHE_NUM_REQS; ++i) begin
    assign dcache_bus_out_if[i].req_valid  = switch_out_bus_if[i * 2].req_valid; 
    assign dcache_bus_out_if[i].req_data   = switch_out_bus_if[i * 2].req_data; 
    assign switch_out_bus_if[i * 2].req_ready  = dcache_bus_out_if[i].req_ready; 
    assign switch_out_bus_if[i * 2].rsp_valid  = dcache_bus_out_if[i].rsp_valid; 
    assign switch_out_bus_if[i * 2].rsp_data   = dcache_bus_out_if[i].rsp_data; 
    assign dcache_bus_out_if[i].rsp_ready  = switch_out_bus_if[i * 2].rsp_ready;
    end
endmodule
