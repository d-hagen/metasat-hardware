module VX_core import VX_gpu_pkg::*; #( 
    parameter CORE_ID = 0
) (        
    input wire              clk,
    input wire              reset,
    VX_dcr_bus_if.slave     dcr_bus_if,
    VX_mem_bus_if.master    dcache_bus_if [DCACHE_NUM_REQS],
    VX_mem_bus_if.master    icache_bus_if,
    output wire             sim_ebreak,
    output wire [32-1:0][32-1:0] sim_wb_value,
    output wire             busy
);
    VX_schedule_if      schedule_if();
    VX_fetch_if         fetch_if();
    VX_decode_if        decode_if();
    VX_sched_csr_if     sched_csr_if();
    VX_decode_sched_if  decode_sched_if();
    VX_commit_sched_if  commit_sched_if();
    VX_commit_csr_if    commit_csr_if();
    VX_branch_ctl_if    branch_ctl_if[((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1)]();
    VX_warp_ctl_if      warp_ctl_if();    
    VX_dispatch_if      alu_dispatch_if[(((4) < (4)) ? (4) : (4))]();
    VX_commit_if        alu_commit_if[(((4) < (4)) ? (4) : (4))]();
    VX_dispatch_if      lsu_dispatch_if[(((4) < (4)) ? (4) : (4))]();
    VX_commit_if        lsu_commit_if[(((4) < (4)) ? (4) : (4))]();
    VX_dispatch_if      sfu_dispatch_if[(((4) < (4)) ? (4) : (4))]();
    VX_commit_if        sfu_commit_if[(((4) < (4)) ? (4) : (4))]();    
    VX_writeback_if     writeback_if[(((4) < (4)) ? (4) : (4))]();
    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_WORD_SIZE), 
        .TAG_WIDTH (DCACHE_TAG_WIDTH)
    ) dcache_bus_tmp_if[DCACHE_NUM_REQS]();
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
    reg  [32-1:0] debug_fetch [2];
    reg  [32-1:0] debug_decode;
    reg  [32-1:0] debug_issue [(((4) < (4)) ? (4) : (4))];
    reg  [32-1:0] debug_commit[(((4) < (4)) ? (4) : (4))];
    wire [32-1:0] debug_stall [(((4) < (4)) ? (4) : (4))];
    VX_schedule #(
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
        .CORE_ID (CORE_ID)
    ) fetch (
        .clk            (clk),
        .reset          (fetch_reset),
        .icache_bus_if  (icache_bus_if),
        .schedule_if    (schedule_if),
        .fetch_if       (fetch_if)
    );
    VX_decode #(
        .CORE_ID (CORE_ID)
    ) decode (
        .clk            (clk),
        .reset          (decode_reset),
        .fetch_if       (fetch_if),
        .decode_if      (decode_if),
        .decode_sched_if(decode_sched_if)
    );
    VX_issue #(
        .CORE_ID (CORE_ID)
    ) issue (
        .clk            (clk),
        .reset          (issue_reset),
        .debug_stall    (debug_stall),
        .decode_if      (decode_if),
        .writeback_if   (writeback_if),
        .alu_dispatch_if(alu_dispatch_if),
        .lsu_dispatch_if(lsu_dispatch_if),
        .sfu_dispatch_if(sfu_dispatch_if)
    );
    VX_execute #(
        .CORE_ID (CORE_ID)
    ) execute (
        .clk            (clk),
        .reset          (execute_reset),
        .base_dcrs      (base_dcrs),
        .dcache_bus_if  (dcache_bus_tmp_if),
        .commit_csr_if  (commit_csr_if),
        .sched_csr_if   (sched_csr_if),
        .alu_dispatch_if(alu_dispatch_if),
        .lsu_dispatch_if(lsu_dispatch_if),
        .sfu_dispatch_if(sfu_dispatch_if),
        .warp_ctl_if    (warp_ctl_if),
        .branch_ctl_if  (branch_ctl_if),
        .alu_commit_if  (alu_commit_if),
        .lsu_commit_if  (lsu_commit_if),
        .sfu_commit_if  (sfu_commit_if),
        .sim_ebreak     (sim_ebreak)
    );    
    VX_commit #(
        .CORE_ID (CORE_ID)
    ) commit (
        .clk            (clk),
        .reset          (commit_reset),
        .alu_commit_if  (alu_commit_if),
        .lsu_commit_if  (lsu_commit_if),
        .sfu_commit_if  (sfu_commit_if),
        .writeback_if   (writeback_if),
        .commit_csr_if  (commit_csr_if),
        .commit_sched_if(commit_sched_if),
        .sim_wb_value   (sim_wb_value)
    );
    always @(posedge clk) begin
        if (reset) begin
            debug_fetch  <= '{default: '0};
            debug_decode <= '0;
        end else begin
            if (fetch_if.valid) begin
                debug_fetch[0] <= fetch_if.data.PC;
                debug_fetch[1] <= fetch_if.data.instr;
            end
            if (decode_if.valid) begin
                debug_decode <= decode_if.data.PC;
            end
       end  
    end  
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        always @(posedge clk) begin
            if (reset) begin
                debug_issue[i]  <= '0;
                debug_commit[i] <= '0;
            end else begin
                if (alu_dispatch_if[i].valid) begin
                    debug_issue[i] <= alu_dispatch_if[i].data.PC;
    	    end else if (lsu_dispatch_if[i].valid) begin
                    debug_issue[i] <= lsu_dispatch_if[i].data.PC;
                end else if (sfu_dispatch_if[i].valid) begin
                    debug_issue[i] <= sfu_dispatch_if[i].data.PC;
                end
                if (alu_commit_if[i].valid) begin
                    debug_commit[i] <= alu_commit_if[i].data.PC;
    	    end else if (lsu_commit_if[i].valid) begin
                    debug_commit[i] <= lsu_commit_if[i].data.PC;
                end else if (sfu_commit_if[i].valid) begin
                    debug_commit[i] <= sfu_commit_if[i].data.PC;
                end
           end  
        end  
    end  
    VX_smem_unit #(
        .CORE_ID (CORE_ID)
    ) smem_unit (
        .clk                (clk),
        .reset              (reset),
        .dcache_bus_in_if   (dcache_bus_tmp_if),
        .dcache_bus_out_if  (dcache_bus_if)
    );
endmodule
