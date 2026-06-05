module VX_core import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0,
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_dcr_bus_if.slave     dcr_bus_if,
    VX_mem_bus_if.master    dcache_bus_if [DCACHE_NUM_REQS],
    VX_mem_bus_if.master    icache_bus_if,
    output wire             busy
);
    VX_schedule_if      schedule_if();
    VX_fetch_if         fetch_if();
    VX_decode_if        decode_if();
    VX_sched_csr_if     sched_csr_if();
    VX_decode_sched_if  decode_sched_if();
    VX_commit_sched_if  commit_sched_if();
    VX_commit_csr_if    commit_csr_if();
    VX_branch_ctl_if    branch_ctl_if[(((4 / 8) != 0) ? (4 / 8) : 1)]();
    VX_warp_ctl_if      warp_ctl_if();
    VX_dispatch_if      dispatch_if[(3 + 1) * (((4 / 8) != 0) ? (4 / 8) : 1)]();
    VX_commit_if        commit_if[(3 + 1) * (((4 / 8) != 0) ? (4 / 8) : 1)]();
    VX_writeback_if     writeback_if[(((4 / 8) != 0) ? (4 / 8) : 1)]();
    VX_lsu_mem_if #(
        .NUM_LANES (4),
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LSU_TAG_WIDTH)
    ) lsu_mem_if[1]();
    wire [1-1:0] dcr_data_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __dcr_data_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (dcr_data_reset)                          
    );
    wire [1-1:0] schedule_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __schedule_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (schedule_reset)                          
    );
    wire [1-1:0] fetch_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __fetch_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (fetch_reset)                          
    );
    wire [1-1:0] decode_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __decode_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (decode_reset)                          
    );
    wire [1-1:0] issue_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __issue_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (issue_reset)                          
    );
    wire [1-1:0] execute_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __execute_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (execute_reset)                          
    );
    wire [1-1:0] commit_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __commit_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (commit_reset)                          
    );
    base_dcrs_t base_dcrs;
    VX_dcr_data dcr_data (
        .clk        (clk),
        .reset      (dcr_data_reset),
        .dcr_bus_if (dcr_bus_if),
        .base_dcrs  (base_dcrs)
    );
    VX_schedule #(
        .INSTANCE_ID ($sformatf("%s-schedule", INSTANCE_ID)),
        .CORE_ID (CORE_ID)
    ) schedule (
        .clk            (clk),
        .reset          (schedule_reset),
        .base_dcrs      (base_dcrs),
        .warp_ctl_if    (warp_ctl_if),
        .branch_ctl_if  (branch_ctl_if),
        .decode_sched_if(decode_sched_if),
        .commit_sched_if(commit_sched_if),
        .schedule_if    (schedule_if),
        .sched_csr_if   (sched_csr_if),
        .busy           (busy)
    );
    VX_fetch #(
        .INSTANCE_ID ($sformatf("%s-fetch", INSTANCE_ID))
    ) fetch (
        .clk            (clk),
        .reset          (fetch_reset),
        .icache_bus_if  (icache_bus_if),
        .schedule_if    (schedule_if),
        .fetch_if       (fetch_if)
    );
    VX_decode #(
        .INSTANCE_ID ($sformatf("%s-decode", INSTANCE_ID))
    ) decode (
        .clk            (clk),
        .reset          (decode_reset),
        .fetch_if       (fetch_if),
        .decode_if      (decode_if),
        .decode_sched_if(decode_sched_if)
    );
    VX_issue #(
        .INSTANCE_ID ($sformatf("%s-issue", INSTANCE_ID))
    ) issue (
        .clk            (clk),
        .reset          (issue_reset),
        .decode_if      (decode_if),
        .writeback_if   (writeback_if),
        .dispatch_if    (dispatch_if)
    );
    VX_execute #(
        .INSTANCE_ID ($sformatf("%s-execute", INSTANCE_ID)),
        .CORE_ID (CORE_ID)
    ) execute (
        .clk            (clk),
        .reset          (execute_reset),
        .base_dcrs      (base_dcrs),
        .lsu_mem_if     (lsu_mem_if),
        .dispatch_if    (dispatch_if),
        .commit_if      (commit_if),
        .commit_csr_if  (commit_csr_if),
        .sched_csr_if   (sched_csr_if),
        .warp_ctl_if    (warp_ctl_if),
        .branch_ctl_if  (branch_ctl_if)
    );
    VX_commit #(
        .INSTANCE_ID ($sformatf("%s-commit", INSTANCE_ID))
    ) commit (
        .clk            (clk),
        .reset          (commit_reset),
        .commit_if      (commit_if),
        .writeback_if   (writeback_if),
        .commit_csr_if  (commit_csr_if),
        .commit_sched_if(commit_sched_if)
    );
    VX_lsu_mem_if #(
        .NUM_LANES (4),
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LSU_TAG_WIDTH)
    ) lsu_dcache_if[1]();
    wire [1-1:0] lmem_unit_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __lmem_unit_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (lmem_unit_reset)                          
    );
    VX_lmem_unit #(
        .INSTANCE_ID (INSTANCE_ID)
    ) lmem_unit (
        .clk            (clk),
        .reset          (lmem_unit_reset),
        .lsu_mem_in_if  (lsu_mem_if),
        .lsu_mem_out_if (lsu_dcache_if)
    );
    for (genvar i = 0; i < 1; ++i) begin
        VX_lsu_mem_if #(
            .NUM_LANES (DCACHE_CHANNELS),
            .DATA_SIZE (DCACHE_WORD_SIZE),
            .TAG_WIDTH (DCACHE_TAG_WIDTH)
        ) dcache_coalesced_if();
        if (LSU_WORD_SIZE != DCACHE_WORD_SIZE) begin
    wire [1-1:0] mem_coalescer_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mem_coalescer_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mem_coalescer_reset)                          
    );
            VX_mem_coalescer #(
                .INSTANCE_ID    ($sformatf("%s-coalescer%0d", INSTANCE_ID, i)),
                .NUM_REQS       (4),
                .DATA_IN_SIZE   (LSU_WORD_SIZE),
                .DATA_OUT_SIZE  (DCACHE_WORD_SIZE),
                .ADDR_WIDTH     (LSU_ADDR_WIDTH),
                .ATYPE_WIDTH    ((2 + 1)),
                .TAG_WIDTH      (LSU_TAG_WIDTH),
                .UUID_WIDTH     (1),
                .QUEUE_SIZE     (((((2 * (4 / 4))) > ((((4 * (32 / 8)) < (16)) ? (4 * (32 / 8)) : (16)) / (32 / 8))) ? ((2 * (4 / 4))) : ((((4 * (32 / 8)) < (16)) ? (4 * (32 / 8)) : (16)) / (32 / 8))))
            ) mem_coalescer (
                .clk   (clk),
                .reset (mem_coalescer_reset),
                .in_req_valid   (lsu_dcache_if[i].req_valid),
                .in_req_mask    (lsu_dcache_if[i].req_data.mask),
                .in_req_rw      (lsu_dcache_if[i].req_data.rw),
                .in_req_byteen  (lsu_dcache_if[i].req_data.byteen),
                .in_req_addr    (lsu_dcache_if[i].req_data.addr),
                .in_req_atype   (lsu_dcache_if[i].req_data.atype),
                .in_req_data    (lsu_dcache_if[i].req_data.data),
                .in_req_tag     (lsu_dcache_if[i].req_data.tag),
                .in_req_ready   (lsu_dcache_if[i].req_ready),
                .in_rsp_valid   (lsu_dcache_if[i].rsp_valid),
                .in_rsp_mask    (lsu_dcache_if[i].rsp_data.mask),
                .in_rsp_data    (lsu_dcache_if[i].rsp_data.data),
                .in_rsp_tag     (lsu_dcache_if[i].rsp_data.tag),
                .in_rsp_ready   (lsu_dcache_if[i].rsp_ready),
                .out_req_valid  (dcache_coalesced_if.req_valid),
                .out_req_mask   (dcache_coalesced_if.req_data.mask),
                .out_req_rw     (dcache_coalesced_if.req_data.rw),
                .out_req_byteen (dcache_coalesced_if.req_data.byteen),
                .out_req_addr   (dcache_coalesced_if.req_data.addr),
                .out_req_atype  (dcache_coalesced_if.req_data.atype),
                .out_req_data   (dcache_coalesced_if.req_data.data),
                .out_req_tag    (dcache_coalesced_if.req_data.tag),
                .out_req_ready  (dcache_coalesced_if.req_ready),
                .out_rsp_valid  (dcache_coalesced_if.rsp_valid),
                .out_rsp_mask   (dcache_coalesced_if.rsp_data.mask),
                .out_rsp_data   (dcache_coalesced_if.rsp_data.data),
                .out_rsp_tag    (dcache_coalesced_if.rsp_data.tag),
                .out_rsp_ready  (dcache_coalesced_if.rsp_ready)
            );
        end else begin
    assign dcache_coalesced_if.req_valid  = lsu_dcache_if[i].req_valid; 
    assign dcache_coalesced_if.req_data   = lsu_dcache_if[i].req_data; 
    assign lsu_dcache_if[i].req_ready  = dcache_coalesced_if.req_ready; 
    assign lsu_dcache_if[i].rsp_valid  = dcache_coalesced_if.rsp_valid; 
    assign lsu_dcache_if[i].rsp_data   = dcache_coalesced_if.rsp_data; 
    assign dcache_coalesced_if.rsp_ready  = lsu_dcache_if[i].rsp_ready;
        end
        VX_mem_bus_if #(
            .DATA_SIZE (DCACHE_WORD_SIZE),
            .TAG_WIDTH (DCACHE_TAG_WIDTH)
        ) dcache_bus_tmp_if[DCACHE_CHANNELS]();
    wire [1-1:0] lsu_adapter_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __lsu_adapter_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (lsu_adapter_reset)                          
    );
        VX_lsu_adapter #(
            .NUM_LANES    (DCACHE_CHANNELS),
            .DATA_SIZE    (DCACHE_WORD_SIZE),
            .TAG_WIDTH    (DCACHE_TAG_WIDTH),
            .TAG_SEL_BITS (DCACHE_TAG_WIDTH - 1),
            .ARBITER      ("P"),
            .REQ_OUT_BUF  (0),
            .RSP_OUT_BUF  (0)
        ) lsu_adapter (
            .clk        (clk),
            .reset      (lsu_adapter_reset),
            .lsu_mem_if (dcache_coalesced_if),
            .mem_bus_if (dcache_bus_tmp_if)
        );
        for (genvar j = 0; j < DCACHE_CHANNELS; ++j) begin
    assign dcache_bus_if[i * DCACHE_CHANNELS + j].req_valid  = dcache_bus_tmp_if[j].req_valid; 
    assign dcache_bus_if[i * DCACHE_CHANNELS + j].req_data   = dcache_bus_tmp_if[j].req_data; 
    assign dcache_bus_tmp_if[j].req_ready  = dcache_bus_if[i * DCACHE_CHANNELS + j].req_ready; 
    assign dcache_bus_tmp_if[j].rsp_valid  = dcache_bus_if[i * DCACHE_CHANNELS + j].rsp_valid; 
    assign dcache_bus_tmp_if[j].rsp_data   = dcache_bus_if[i * DCACHE_CHANNELS + j].rsp_data; 
    assign dcache_bus_if[i * DCACHE_CHANNELS + j].rsp_ready  = dcache_bus_tmp_if[j].rsp_ready;
        end
    end
endmodule
