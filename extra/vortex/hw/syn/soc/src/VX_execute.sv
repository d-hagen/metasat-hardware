module VX_execute import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0
) (
    input wire              clk, 
    input wire              reset,    
    input base_dcrs_t       base_dcrs,
    VX_mem_bus_if.master    dcache_bus_if [DCACHE_NUM_REQS],
    VX_commit_csr_if.slave  commit_csr_if,
    VX_sched_csr_if.slave   sched_csr_if,
    VX_dispatch_if.slave    alu_dispatch_if [(((4) < (4)) ? (4) : (4))],
    VX_commit_if.master     alu_commit_if [(((4) < (4)) ? (4) : (4))],
    VX_branch_ctl_if.master branch_ctl_if [((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1)],
    VX_dispatch_if.slave    lsu_dispatch_if [(((4) < (4)) ? (4) : (4))],  
    VX_commit_if.master     lsu_commit_if [(((4) < (4)) ? (4) : (4))],
    VX_dispatch_if.slave    sfu_dispatch_if [(((4) < (4)) ? (4) : (4))], 
    VX_commit_if.master     sfu_commit_if [(((4) < (4)) ? (4) : (4))],
    VX_warp_ctl_if.master   warp_ctl_if,
    output wire             sim_ebreak
);
    wire [1-1:0] alu_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __alu_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (alu_reset)                          
    );
    wire [1-1:0] lsu_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __lsu_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (lsu_reset)                          
    );
    wire [1-1:0] sfu_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __sfu_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (sfu_reset)                          
    );
    VX_alu_unit #(
        .CORE_ID (CORE_ID)
    ) alu_unit (
        .clk            (clk),
        .reset          (alu_reset),
        .dispatch_if    (alu_dispatch_if),
        .branch_ctl_if  (branch_ctl_if),
        .commit_if      (alu_commit_if)
    );
    VX_lsu_unit #(
        .CORE_ID (CORE_ID)
    ) lsu_unit (
        .clk            (clk),
        .reset          (lsu_reset),
        .cache_bus_if   (dcache_bus_if),
        .dispatch_if    (lsu_dispatch_if),
        .commit_if      (lsu_commit_if)
    );
    VX_sfu_unit #(
        .CORE_ID (CORE_ID)
    ) sfu_unit (
        .clk            (clk),
        .reset          (sfu_reset),
        .base_dcrs      (base_dcrs),            
        .dispatch_if    (sfu_dispatch_if),
        .commit_csr_if  (commit_csr_if),
        .sched_csr_if   (sched_csr_if),
        .warp_ctl_if    (warp_ctl_if),
        .commit_if      (sfu_commit_if)
    );
    assign sim_ebreak = alu_dispatch_if[0].valid && alu_dispatch_if[0].ready 
                     && alu_dispatch_if[0].data.wis == 0
                     && alu_dispatch_if[0].data.op_mod[0]
                     && (4'(alu_dispatch_if[0].data.op_type) == 4'b1011
                      || 4'(alu_dispatch_if[0].data.op_type) == 4'b1010);
endmodule
