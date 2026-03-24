module VX_sfu_unit import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = "",
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    input base_dcrs_t       base_dcrs,
    VX_dispatch_if.slave    dispatch_if [(((4 / 8) != 0) ? (4 / 8) : 1)],
    VX_commit_csr_if.slave  commit_csr_if,
    VX_sched_csr_if.slave   sched_csr_if,
    VX_commit_if.master     commit_if [(((4 / 8) != 0) ? (4 / 8) : 1)],
    VX_warp_ctl_if.master   warp_ctl_if
);
    localparam BLOCK_SIZE = 1;
    localparam NUM_LANES  = 4;
    localparam PID_BITS   = $clog2(4 / NUM_LANES);
    localparam PID_WIDTH  = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam RSP_ARB_DATAW = 1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + (NUM_LANES * 32) + $clog2(32) + 1 + (32-1) + PID_WIDTH + 1 + 1;
    localparam RSP_ARB_SIZE = 1 + 1;
    localparam RSP_ARB_IDX_WCTL = 0;
    localparam RSP_ARB_IDX_CSRS = 1;
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
    wire [RSP_ARB_SIZE-1:0] rsp_arb_valid_in;
    wire [RSP_ARB_SIZE-1:0] rsp_arb_ready_in;
    wire [RSP_ARB_SIZE-1:0][RSP_ARB_DATAW-1:0] rsp_arb_data_in;
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) wctl_execute_if();
    VX_commit_if#(
        .NUM_LANES (NUM_LANES)
    ) wctl_commit_if();
    assign wctl_execute_if.valid = per_block_execute_if[0].valid && (per_block_execute_if[0].data.op_type <= 5);
    assign wctl_execute_if.data = per_block_execute_if[0].data;
    wire [1-1:0] wctl_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __wctl_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (wctl_reset)                          
    );
    VX_wctl_unit #(
        .INSTANCE_ID ($sformatf("%s-wctl", INSTANCE_ID)),
        .NUM_LANES (NUM_LANES)
    ) wctl_unit (
        .clk        (clk),
        .reset      (wctl_reset),
        .execute_if (wctl_execute_if),
        .warp_ctl_if(warp_ctl_if),
        .commit_if  (wctl_commit_if)
    );
    assign rsp_arb_valid_in[RSP_ARB_IDX_WCTL] = wctl_commit_if.valid;
    assign rsp_arb_data_in[RSP_ARB_IDX_WCTL] = wctl_commit_if.data;
    assign wctl_commit_if.ready = rsp_arb_ready_in[RSP_ARB_IDX_WCTL];
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) csr_execute_if();
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) csr_commit_if();
    assign csr_execute_if.valid = per_block_execute_if[0].valid && (per_block_execute_if[0].data.op_type >= 6 && per_block_execute_if[0].data.op_type <= 8);
    assign csr_execute_if.data = per_block_execute_if[0].data;
    wire [1-1:0] csr_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __csr_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (csr_reset)                          
    );
    VX_csr_unit #(
        .INSTANCE_ID ($sformatf("%s-csr", INSTANCE_ID)),
        .CORE_ID   (CORE_ID),
        .NUM_LANES (NUM_LANES)
    ) csr_unit (
        .clk            (clk),
        .reset          (csr_reset),
        .base_dcrs      (base_dcrs),
        .execute_if     (csr_execute_if),
        .sched_csr_if   (sched_csr_if),
        .commit_csr_if  (commit_csr_if),
        .commit_if      (csr_commit_if)
    );
    assign rsp_arb_valid_in[RSP_ARB_IDX_CSRS] = csr_commit_if.valid;
    assign rsp_arb_data_in[RSP_ARB_IDX_CSRS] = csr_commit_if.data;
    assign csr_commit_if.ready = rsp_arb_ready_in[RSP_ARB_IDX_CSRS];
    reg sfu_req_ready;
    always @(*) begin
        case (per_block_execute_if[0].data.op_type)
         4'h6,
         4'h7,
         4'h8: sfu_req_ready = csr_execute_if.ready;
        default: sfu_req_ready = wctl_execute_if.ready;
        endcase
    end
    assign per_block_execute_if[0].ready = sfu_req_ready;
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) arb_commit_if[BLOCK_SIZE]();
    VX_stream_arb #(
        .NUM_INPUTS (RSP_ARB_SIZE),
        .DATAW      (RSP_ARB_DATAW),
        .ARBITER    ("R"),
        .OUT_BUF    (3)
    ) rsp_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (rsp_arb_valid_in),
        .ready_in  (rsp_arb_ready_in),
        .data_in   (rsp_arb_data_in),
        .data_out  (arb_commit_if[0].data),
        .valid_out (arb_commit_if[0].valid),
        .ready_out (arb_commit_if[0].ready),
        . sel_out ()
    );
    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (3)
    ) gather_unit (
        .clk           (clk),
        .reset         (reset),
        .commit_in_if  (arb_commit_if),
        .commit_out_if (commit_if)
    );
endmodule
