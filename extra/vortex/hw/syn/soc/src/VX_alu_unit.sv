module VX_alu_unit #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_dispatch_if.slave    dispatch_if [(((4 / 8) != 0) ? (4 / 8) : 1)],
    VX_commit_if.master     commit_if [(((4 / 8) != 0) ? (4 / 8) : 1)],
    VX_branch_ctl_if.master branch_ctl_if [(((4 / 8) != 0) ? (4 / 8) : 1)]
);
    localparam BLOCK_SIZE   = (((4 / 8) != 0) ? (4 / 8) : 1);
    localparam NUM_LANES    = 4;
    localparam PID_BITS     = $clog2(4 / NUM_LANES);
    localparam PID_WIDTH    = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam RSP_ARB_DATAW= 16 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + (32-1) + $clog2(32) + 1 + NUM_LANES * 32 + PID_WIDTH + 1 + 1;
    localparam RSP_ARB_SIZE = 1 + 1;
    localparam PARTIAL_BW   = (BLOCK_SIZE != (((4 / 8) != 0) ? (4 / 8) : 1)) || (NUM_LANES != 4);
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) per_block_execute_if[BLOCK_SIZE]();
    VX_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (PARTIAL_BW ? 1 : 0)
    ) dispatch_unit (
        .clk        (clk),
        .reset      (reset),
        .dispatch_if(dispatch_if),
        .execute_if (per_block_execute_if)
    );
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) per_block_commit_if[BLOCK_SIZE]();
    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin
    wire [1-1:0] block_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT((((BLOCK_SIZE > 1)) ? 0 : -1))) __block_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (block_reset)                          
    );
        wire is_muldiv_op = 1 && (per_block_execute_if[block_idx].data.op_args.alu.xtype == 2);
        VX_execute_if #(
            .NUM_LANES (NUM_LANES)
        ) int_execute_if();
        VX_commit_if #(
            .NUM_LANES (NUM_LANES)
        ) int_commit_if();
        assign int_execute_if.valid = per_block_execute_if[block_idx].valid && ~is_muldiv_op;
        assign int_execute_if.data = per_block_execute_if[block_idx].data;
        VX_alu_int #(
            .INSTANCE_ID ($sformatf("%s-int%0d", INSTANCE_ID, block_idx)),
            .BLOCK_IDX (block_idx),
            .NUM_LANES (NUM_LANES)
        ) alu_int (
            .clk        (clk),
            .reset      (block_reset),
            .execute_if (int_execute_if),
            .branch_ctl_if (branch_ctl_if[block_idx]),
            .commit_if  (int_commit_if)
        );
        VX_execute_if #(
            .NUM_LANES (NUM_LANES)
        ) muldiv_execute_if();
        VX_commit_if #(
            .NUM_LANES (NUM_LANES)
        ) muldiv_commit_if();
        assign muldiv_execute_if.valid = per_block_execute_if[block_idx].valid && is_muldiv_op;
        assign muldiv_execute_if.data = per_block_execute_if[block_idx].data;
        VX_alu_muldiv #(
            .INSTANCE_ID ($sformatf("%s-muldiv%0d", INSTANCE_ID, block_idx)),
            .NUM_LANES (NUM_LANES)
        ) muldiv_unit (
            .clk        (clk),
            .reset      (block_reset),
            .execute_if (muldiv_execute_if),
            .commit_if  (muldiv_commit_if)
        );
        assign per_block_execute_if[block_idx].ready =
            is_muldiv_op ? muldiv_execute_if.ready :
            int_execute_if.ready;
        VX_stream_arb #(
            .NUM_INPUTS (RSP_ARB_SIZE),
            .DATAW      (RSP_ARB_DATAW),
            .OUT_BUF    (PARTIAL_BW ? 1 : 3),
            .ARBITER    ("F")
        ) rsp_arb (
            .clk       (clk),
            .reset     (block_reset),
            .valid_in  ({
                muldiv_commit_if.valid,
                int_commit_if.valid
            }),
            .ready_in  ({
                muldiv_commit_if.ready,
                int_commit_if.ready
            }),
            .data_in   ({
                muldiv_commit_if.data,
                int_commit_if.data
            }),
            .data_out  (per_block_commit_if[block_idx].data),
            .valid_out (per_block_commit_if[block_idx].valid),
            .ready_out (per_block_commit_if[block_idx].ready),
            . sel_out ()
        );
    end
    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (PARTIAL_BW ? 3 : 0)
    ) gather_unit (
        .clk           (clk),
        .reset         (reset),
        .commit_in_if  (per_block_commit_if),
        .commit_out_if (commit_if)
    );
endmodule
