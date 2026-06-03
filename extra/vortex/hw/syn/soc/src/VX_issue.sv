module VX_issue import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_decode_if.slave      decode_if,
    VX_writeback_if.slave   writeback_if [(((2 / 8) != 0) ? (2 / 8) : 1)],
    VX_dispatch_if.master   dispatch_if [(3 + 0) * (((2 / 8) != 0) ? (2 / 8) : 1)]
);
    wire [ISSUE_ISW_W-1:0] decode_isw = wid_to_isw(decode_if.data.wid);
    wire [ISSUE_WIS_W-1:0] decode_wis = wid_to_wis(decode_if.data.wid);
    wire [(((2 / 8) != 0) ? (2 / 8) : 1)-1:0] decode_ready_in;
    assign decode_if.ready = decode_ready_in[decode_isw];
    for (genvar issue_id = 0; issue_id < (((2 / 8) != 0) ? (2 / 8) : 1); ++issue_id) begin : issue_slices
        VX_decode_if #(
            .NUM_WARPS (PER_ISSUE_WARPS)
        ) per_issue_decode_if();
        VX_dispatch_if per_issue_dispatch_if[(3 + 0)]();
        assign per_issue_decode_if.valid = decode_if.valid && (decode_isw == ISSUE_ISW_W'(issue_id));
        assign per_issue_decode_if.data.uuid = decode_if.data.uuid;
        assign per_issue_decode_if.data.wid = decode_wis;
        assign per_issue_decode_if.data.tmask = decode_if.data.tmask;
        assign per_issue_decode_if.data.PC = decode_if.data.PC;
        assign per_issue_decode_if.data.ex_type = decode_if.data.ex_type;
        assign per_issue_decode_if.data.op_type = decode_if.data.op_type;
        assign per_issue_decode_if.data.op_args = decode_if.data.op_args;
        assign per_issue_decode_if.data.wb = decode_if.data.wb;
        assign per_issue_decode_if.data.rd = decode_if.data.rd;
        assign per_issue_decode_if.data.rs1 = decode_if.data.rs1;
        assign per_issue_decode_if.data.rs2 = decode_if.data.rs2;
        assign per_issue_decode_if.data.rs3 = decode_if.data.rs3;
        assign decode_ready_in[issue_id] = per_issue_decode_if.ready;
    wire [1-1:0] slice_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __slice_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (slice_reset)                          
    );
        VX_issue_slice #(
            .INSTANCE_ID ($sformatf("%s%0d", INSTANCE_ID, issue_id)),
            .ISSUE_ID (issue_id)
        ) issue_slice (
            .clk          (clk),
            .reset        (slice_reset),
            .decode_if    (per_issue_decode_if),
            .writeback_if (writeback_if[issue_id]),
            .dispatch_if  (per_issue_dispatch_if)
        );
        for (genvar ex_id = 0; ex_id < (3 + 0); ++ex_id) begin
    assign dispatch_if[ex_id * (((2 / 8) != 0) ? (2 / 8) : 1) + issue_id].valid = per_issue_dispatch_if[ex_id].valid; 
    assign dispatch_if[ex_id * (((2 / 8) != 0) ? (2 / 8) : 1) + issue_id].data  = per_issue_dispatch_if[ex_id].data; 
    assign per_issue_dispatch_if[ex_id].ready = dispatch_if[ex_id * (((2 / 8) != 0) ? (2 / 8) : 1) + issue_id].ready;
        end
     end
endmodule
