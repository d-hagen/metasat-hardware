module VX_execute import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = "",
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    input base_dcrs_t       base_dcrs,
    VX_lsu_mem_if.master    lsu_mem_if [1],
    VX_dispatch_if.slave    dispatch_if [(3 + 0) * (((2 / 8) != 0) ? (2 / 8) : 1)],
    VX_commit_if.master     commit_if [(3 + 0) * (((2 / 8) != 0) ? (2 / 8) : 1)],
    VX_sched_csr_if.slave   sched_csr_if,
    VX_branch_ctl_if.master branch_ctl_if [(((2 / 8) != 0) ? (2 / 8) : 1)],
    VX_warp_ctl_if.master   warp_ctl_if,
    VX_commit_csr_if.slave  commit_csr_if
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
        .INSTANCE_ID ($sformatf("%s-alu", INSTANCE_ID))
    ) alu_unit (
        .clk            (clk),
        .reset          (alu_reset),
        .dispatch_if    (dispatch_if[0 * (((2 / 8) != 0) ? (2 / 8) : 1) +: (((2 / 8) != 0) ? (2 / 8) : 1)]),
        .commit_if      (commit_if[0 * (((2 / 8) != 0) ? (2 / 8) : 1) +: (((2 / 8) != 0) ? (2 / 8) : 1)]),
        .branch_ctl_if  (branch_ctl_if)
    );
    VX_lsu_unit #(
        .INSTANCE_ID ($sformatf("%s-lsu", INSTANCE_ID))
    ) lsu_unit (
        .clk            (clk),
        .reset          (lsu_reset),
        .dispatch_if    (dispatch_if[1 * (((2 / 8) != 0) ? (2 / 8) : 1) +: (((2 / 8) != 0) ? (2 / 8) : 1)]),
        .commit_if      (commit_if[1 * (((2 / 8) != 0) ? (2 / 8) : 1) +: (((2 / 8) != 0) ? (2 / 8) : 1)]),
        .lsu_mem_if     (lsu_mem_if)
    );
    VX_sfu_unit #(
        .INSTANCE_ID ($sformatf("%s-sfu", INSTANCE_ID)),
        .CORE_ID (CORE_ID)
    ) sfu_unit (
        .clk            (clk),
        .reset          (sfu_reset),
        .base_dcrs      (base_dcrs),
        .dispatch_if    (dispatch_if[2 * (((2 / 8) != 0) ? (2 / 8) : 1) +: (((2 / 8) != 0) ? (2 / 8) : 1)]),
        .commit_if      (commit_if[2 * (((2 / 8) != 0) ? (2 / 8) : 1) +: (((2 / 8) != 0) ? (2 / 8) : 1)]),
        .commit_csr_if  (commit_csr_if),
        .sched_csr_if   (sched_csr_if),
        .warp_ctl_if    (warp_ctl_if)
    );
endmodule
