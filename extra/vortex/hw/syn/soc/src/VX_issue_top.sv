module VX_issue_top import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = "issue"
) (
    input wire                              clk,
    input wire                              reset,
    input wire                              decode_valid,
    input wire [1-1:0]            decode_uuid,
    input wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]              decode_wid,
    input wire [4-1:0]           decode_tmask,
    input wire [(32-1)-1:0]               decode_PC,
    input wire [$clog2((3 + 0))-1:0]               decode_ex_type,
    input wire [4-1:0]          decode_op_type,
    input op_args_t                         decode_op_args,
    input wire                              decode_wb,
    input wire [$clog2(32)-1:0]               decode_rd,
    input wire [$clog2(32)-1:0]               decode_rs1,
    input wire [$clog2(32)-1:0]               decode_rs2,
    input wire [$clog2(32)-1:0]               decode_rs3,
    output wire                             decode_ready,
    input wire                              writeback_valid[(((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire [1-1:0]            writeback_uuid[(((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire [ISSUE_WIS_W-1:0]            writeback_wis[(((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire [4-1:0]           writeback_tmask[(((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire [(32-1)-1:0]               writeback_PC[(((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire [$clog2(32)-1:0]               writeback_rd[(((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire [4-1:0][32-1:0] writeback_data[(((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire                              writeback_sop[(((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire                              writeback_eop[(((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire                             dispatch_valid[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [1-1:0]           dispatch_uuid[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [ISSUE_WIS_W-1:0]           dispatch_wis[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [4-1:0]          dispatch_tmask[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [(32-1)-1:0]              dispatch_PC[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [4-1:0]        dispatch_op_type[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output op_args_t                        dispatch_op_args[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire                             dispatch_wb[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [$clog2(32)-1:0]              dispatch_rd[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]             dispatch_tid[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [4-1:0][32-1:0] dispatch_rs1_data[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [4-1:0][32-1:0] dispatch_rs2_data[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    output wire [4-1:0][32-1:0] dispatch_rs3_data[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)],
    input wire                             dispatch_ready[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)]
);
    VX_decode_if    decode_if();
    VX_dispatch_if  dispatch_if[(3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1)]();
    VX_writeback_if writeback_if[(((4 / 8) != 0) ? (4 / 8) : 1)]();
    assign decode_if.valid = decode_valid;
    assign decode_if.data.uuid = decode_uuid;
    assign decode_if.data.wid = decode_wid;
    assign decode_if.data.tmask = decode_tmask;
    assign decode_if.data.PC = decode_PC;
    assign decode_if.data.ex_type = decode_ex_type;
    assign decode_if.data.op_type = decode_op_type;
    assign decode_if.data.op_args = decode_op_args;
    assign decode_if.data.wb = decode_wb;
    assign decode_if.data.rd = decode_rd;
    assign decode_if.data.rs1 = decode_rs1;
    assign decode_if.data.rs2 = decode_rs2;
    assign decode_if.data.rs3 = decode_rs3;
    assign decode_ready = decode_if.ready;
    for (genvar i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
        assign writeback_if[i].valid = writeback_valid[i];
        assign writeback_if[i].data.uuid = writeback_uuid[i];
        assign writeback_if[i].data.wis = writeback_wis[i];
        assign writeback_if[i].data.tmask = writeback_tmask[i];
        assign writeback_if[i].data.PC = writeback_PC[i];
        assign writeback_if[i].data.rd = writeback_rd[i];
        assign writeback_if[i].data.data = writeback_data[i];
        assign writeback_if[i].data.sop = writeback_sop[i];
        assign writeback_if[i].data.eop = writeback_eop[i];
    end
    for (genvar i = 0; i < (3 + 0) * (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
        assign dispatch_valid[i] = dispatch_if[i].valid;
        assign dispatch_uuid[i] = dispatch_if[i].data.uuid;
        assign dispatch_wis[i] = dispatch_if[i].data.wis;
        assign dispatch_tmask[i] = dispatch_if[i].data.tmask;
        assign dispatch_PC[i] = dispatch_if[i].data.PC;
        assign dispatch_op_type[i] = dispatch_if[i].data.op_type;
        assign dispatch_op_args[i] = dispatch_if[i].data.op_args;
        assign dispatch_wb[i] = dispatch_if[i].data.wb;
        assign dispatch_rd[i] = dispatch_if[i].data.rd;
        assign dispatch_tid[i] = dispatch_if[i].data.tid;
        assign dispatch_rs1_data[i] = dispatch_if[i].data.rs1_data;
        assign dispatch_rs2_data[i] = dispatch_if[i].data.rs2_data;
        assign dispatch_rs3_data[i] = dispatch_if[i].data.rs3_data;
        assign dispatch_if[i].ready = dispatch_ready[i];
    end
    VX_issue #(
        .INSTANCE_ID (INSTANCE_ID)
    ) issue (
        .clk            (clk),
        .reset          (reset),
        .decode_if      (decode_if),
        .writeback_if   (writeback_if),
        .dispatch_if    (dispatch_if)
    );
endmodule
