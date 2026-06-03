module VX_lsu_unit import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_dispatch_if.slave    dispatch_if [(((2 / 8) != 0) ? (2 / 8) : 1)],
    VX_commit_if.master     commit_if [(((2 / 8) != 0) ? (2 / 8) : 1)],
    VX_lsu_mem_if.master    lsu_mem_if [1]
);
    localparam BLOCK_SIZE = 1;
    localparam NUM_LANES  = 2;
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) per_block_execute_if[BLOCK_SIZE]();
    VX_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (1)
    ) dispatch_unit (
        .clk        (clk),
        .reset      (reset),
        .dispatch_if(dispatch_if),
        .execute_if (per_block_execute_if)
    );
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) per_block_commit_if[BLOCK_SIZE]();
    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin : lsu_slices
    wire [1-1:0] slice_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __slice_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (slice_reset)                          
    );
        VX_lsu_slice #(
            .INSTANCE_ID ($sformatf("%s%0d", INSTANCE_ID, block_idx))
        ) lsu_slice(
            .clk        (clk),
            .reset      (slice_reset),
            .execute_if (per_block_execute_if[block_idx]),
            .commit_if  (per_block_commit_if[block_idx]),
            .lsu_mem_if (lsu_mem_if[block_idx])
        );
    end
    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (3)
    ) gather_unit (
        .clk           (clk),
        .reset         (reset),
        .commit_in_if  (per_block_commit_if),
        .commit_out_if (commit_if)
    );
endmodule
