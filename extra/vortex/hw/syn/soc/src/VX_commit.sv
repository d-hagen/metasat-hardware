module VX_commit import VX_gpu_pkg::*, VX_trace_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_commit_if.slave      commit_if [(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    VX_writeback_if.master  writeback_if  [(((4 / 8) != 0) ? (4 / 8) : 1)],
    VX_commit_csr_if.master commit_csr_if,
    VX_commit_sched_if.master commit_sched_if
);
    localparam DATAW = 1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + 4 + (32-1) + 1 + $clog2(32) + 4 * 32 + 1 + 1 + 1;
    localparam COMMIT_SIZEW = $clog2(4 + 1);
    localparam COMMIT_ALL_SIZEW = COMMIT_SIZEW + (((4 / 8) != 0) ? (4 / 8) : 1) - 1;
    VX_commit_if commit_arb_if[(((4 / 8) != 0) ? (4 / 8) : 1)]();
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0] per_issue_commit_fire;
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] per_issue_commit_wid;
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0][4-1:0] per_issue_commit_tmask;
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0] per_issue_commit_eop;
    for (genvar i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
        wire [(3 + 0)-1:0]            valid_in;
        wire [(3 + 0)-1:0][DATAW-1:0] data_in;
        wire [(3 + 0)-1:0]            ready_in;
        for (genvar j = 0; j < (3 + 0); ++j) begin
            assign valid_in[j] = commit_if[j * (((4 / 8) != 0) ? (4 / 8) : 1) + i].valid;
            assign data_in[j]  = commit_if[j * (((4 / 8) != 0) ? (4 / 8) : 1) + i].data;
            assign commit_if[j * (((4 / 8) != 0) ? (4 / 8) : 1) + i].ready = ready_in[j];
        end
    wire [1-1:0] arb_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __arb_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (arb_reset)                          
    );
        VX_stream_arb #(
            .NUM_INPUTS ((3 + 0)),
            .DATAW      (DATAW),
            .ARBITER    ("R"),
            .OUT_BUF    (1)
        ) commit_arb (
            .clk        (clk),
            .reset      (arb_reset),
            .valid_in   (valid_in),
            .ready_in   (ready_in),
            .data_in    (data_in),
            .data_out   (commit_arb_if[i].data),
            .valid_out  (commit_arb_if[i].valid),
            .ready_out  (commit_arb_if[i].ready),
            . sel_out ()
        );
        assign per_issue_commit_fire[i] = commit_arb_if[i].valid && commit_arb_if[i].ready;
        assign per_issue_commit_tmask[i]= {4{per_issue_commit_fire[i]}} & commit_arb_if[i].data.tmask;
        assign per_issue_commit_wid[i]  = commit_arb_if[i].data.wid;
        assign per_issue_commit_eop[i]  = commit_arb_if[i].data.eop;
    end
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0][COMMIT_SIZEW-1:0] commit_size, commit_size_r;
    wire [COMMIT_ALL_SIZEW-1:0] commit_size_all_r, commit_size_all_rr;
    wire commit_fire_any, commit_fire_any_r, commit_fire_any_rr;
    assign commit_fire_any = (| per_issue_commit_fire);
    for (genvar i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
        wire [COMMIT_SIZEW-1:0] count;
    VX_popcount #( 
        .N ($bits(per_issue_commit_tmask[i])), 
        .MODEL (1) 
    ) __count__ ( 
        .data_in  (per_issue_commit_tmask[i]), 
        .data_out (count) 
    );
        assign commit_size[i] = count;
    end
    VX_pipe_register #(
        .DATAW  (1 + (((4 / 8) != 0) ? (4 / 8) : 1) * COMMIT_SIZEW),
        .RESETW (1)
    ) commit_size_reg1 (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({commit_fire_any, commit_size}),
        .data_out ({commit_fire_any_r, commit_size_r})
    );
    VX_reduce #(
        .DATAW_IN (COMMIT_SIZEW),
        .DATAW_OUT (COMMIT_ALL_SIZEW),
        .N  ((((4 / 8) != 0) ? (4 / 8) : 1)),
        .OP ("+")
    ) commit_size_reduce (
        .data_in  (commit_size_r),
        .data_out (commit_size_all_r)
    );
    VX_pipe_register #(
        .DATAW  (1 + COMMIT_ALL_SIZEW),
        .RESETW (1)
    ) commit_size_reg2 (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({commit_fire_any_r, commit_size_all_r}),
        .data_out ({commit_fire_any_rr, commit_size_all_rr})
    );
    reg [44-1:0] instret;
    always @(posedge clk) begin
       if (reset) begin
            instret <= '0;
        end else begin
            if (commit_fire_any_rr) begin
                instret <= instret + 44'(commit_size_all_rr);
            end
        end
    end
    assign commit_csr_if.instret = instret;
    reg [4-1:0] committed_warps;
    always @(*) begin
        committed_warps = 0;
        for (integer i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
            if (per_issue_commit_fire[i] && per_issue_commit_eop[i]) begin
                committed_warps[per_issue_commit_wid[i]] = 1;
            end
        end
    end
    VX_pipe_register #(
        .DATAW  (4),
        .RESETW (4)
    ) committed_pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  (committed_warps),
        .data_out ({commit_sched_if.committed_warps})
    );
    for (genvar i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
        assign writeback_if[i].valid     = commit_arb_if[i].valid && commit_arb_if[i].data.wb;
        assign writeback_if[i].data.uuid = commit_arb_if[i].data.uuid;
        assign writeback_if[i].data.wis  = wid_to_wis(commit_arb_if[i].data.wid);
        assign writeback_if[i].data.PC   = commit_arb_if[i].data.PC;
        assign writeback_if[i].data.tmask= commit_arb_if[i].data.tmask;
        assign writeback_if[i].data.rd   = commit_arb_if[i].data.rd;
        assign writeback_if[i].data.data = commit_arb_if[i].data.data;
        assign writeback_if[i].data.sop  = commit_arb_if[i].data.sop;
        assign writeback_if[i].data.eop  = commit_arb_if[i].data.eop;
        assign commit_arb_if[i].ready = 1'b1;  
    end
endmodule
