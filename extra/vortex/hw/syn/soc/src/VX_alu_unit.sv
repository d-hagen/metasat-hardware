module VX_alu_unit #(
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    VX_dispatch_if.slave    dispatch_if [(((4) < (4)) ? (4) : (4))],
    VX_commit_if.master     commit_if [(((4) < (4)) ? (4) : (4))],
    VX_branch_ctl_if.master branch_ctl_if [((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1)]
);   
    localparam BLOCK_SIZE   = ((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1);
    localparam NUM_LANES    = (((4 / 2) != 0) ? (4 / 2) : 1);
    localparam PID_BITS     = $clog2(4 / NUM_LANES);
    localparam PID_WIDTH    = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam RSP_ARB_DATAW= 1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + 32 + $clog2(32) + 1 + NUM_LANES * 32 + PID_WIDTH + 1 + 1;
    localparam RSP_ARB_SIZE = 1 + 1;
    localparam PARTIAL_BW   = (BLOCK_SIZE != (((4) < (4)) ? (4) : (4))) || (NUM_LANES != 4);
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) execute_if[BLOCK_SIZE]();
    wire [1-1:0] dispatch_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __dispatch_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (dispatch_reset)                          
    );
    VX_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_REG    (PARTIAL_BW ? 1 : 0)
    ) dispatch_unit (
        .clk        (clk),
        .reset      (dispatch_reset),
        .dispatch_if(dispatch_if),
        .execute_if (execute_if)
    );
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) commit_block_if[BLOCK_SIZE]();
    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin
        wire is_muldiv_op;
        VX_execute_if #(
            .NUM_LANES (NUM_LANES)
        ) int_execute_if();
        assign int_execute_if.valid = execute_if[block_idx].valid && ~is_muldiv_op;
        assign int_execute_if.data = execute_if[block_idx].data;
        VX_commit_if #(
            .NUM_LANES (NUM_LANES)
        ) int_commit_if();
    wire [1-1:0] int_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __int_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (int_reset)                          
    );
        VX_int_unit #(
            .CORE_ID   (CORE_ID),
            .BLOCK_IDX (block_idx),
            .NUM_LANES (NUM_LANES)
        ) int_unit (
            .clk        (clk),
            .reset      (int_reset),
            .execute_if (int_execute_if),
            .branch_ctl_if (branch_ctl_if[block_idx]),
            .commit_if  (int_commit_if)
        );
        assign is_muldiv_op = execute_if[block_idx].data.op_mod[1];
    wire [1-1:0] mdv_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mdv_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mdv_reset)                          
    );
        VX_execute_if #(
            .NUM_LANES (NUM_LANES)
        ) mdv_execute_if();
        assign mdv_execute_if.valid = execute_if[block_idx].valid && is_muldiv_op;
        assign mdv_execute_if.data = execute_if[block_idx].data;
        VX_commit_if #(
            .NUM_LANES (NUM_LANES)
        ) mdv_commit_if();
        VX_muldiv_unit #(
            .CORE_ID   (CORE_ID),
            .NUM_LANES (NUM_LANES)
        ) mdv_unit (
            .clk        (clk),
            .reset      (mdv_reset),
            .execute_if (mdv_execute_if),
            .commit_if  (mdv_commit_if)
        );       
        assign execute_if[block_idx].ready = is_muldiv_op ? mdv_execute_if.ready : int_execute_if.ready;
        VX_stream_arb #(
            .NUM_INPUTS (RSP_ARB_SIZE),
            .DATAW      (RSP_ARB_DATAW),
            .OUT_REG    (PARTIAL_BW ? 1 : 3)
        ) rsp_arb (
            .clk       (clk),
            .reset     (reset),
            .valid_in  ({                
                mdv_commit_if.valid,
                int_commit_if.valid
            }),
            .ready_in  ({
                mdv_commit_if.ready,
                int_commit_if.ready
            }),
            .data_in   ({
                mdv_commit_if.data,
                int_commit_if.data
            }),
            .data_out  (commit_block_if[block_idx].data),
            .valid_out (commit_block_if[block_idx].valid), 
            .ready_out (commit_block_if[block_idx].ready),            
            . sel_out ()
        );
    end
    wire [1-1:0] commit_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __commit_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (commit_reset)                          
    );
    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_REG    (PARTIAL_BW ? 3 : 0)
    ) gather_unit (
        .clk           (clk),
        .reset         (commit_reset),
        .commit_in_if  (commit_block_if),
        .commit_out_if (commit_if)
    );
endmodule
