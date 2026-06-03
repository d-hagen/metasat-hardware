module VX_alu_muldiv #(
    parameter  INSTANCE_ID = "",
    parameter NUM_LANES = 1
) (
    input wire          clk,
    input wire          reset,
    VX_execute_if.slave execute_if,
    VX_commit_if.master commit_if
);
    localparam PID_BITS  = $clog2(2 / NUM_LANES);
    localparam PID_WIDTH = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam TAG_WIDTH = 1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + NUM_LANES + (32-1) + $clog2(32) + 1 + PID_WIDTH + 1 + 1;
    wire [3-1:0] muldiv_op = 3'(execute_if.data.op_type);
    wire is_mulx_op = (~muldiv_op[2]);
    wire is_signed_op = (~muldiv_op[0]);
    wire is_alu_w = 0;
    wire [NUM_LANES-1:0][32-1:0] mul_result_out;
    wire [1-1:0] mul_uuid_out;
    wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0] mul_wid_out;
    wire [NUM_LANES-1:0] mul_tmask_out;
    wire [(32-1)-1:0] mul_PC_out;
    wire [$clog2(32)-1:0] mul_rd_out;
    wire mul_wb_out;
    wire [PID_WIDTH-1:0] mul_pid_out;
    wire mul_sop_out, mul_eop_out;
    wire mul_valid_in = execute_if.valid && is_mulx_op;
    wire mul_ready_in;
    wire mul_valid_out;
    wire mul_ready_out;
    wire is_mulh_in      = (muldiv_op[1:0] != 0);
    wire is_signed_mul_a = (muldiv_op[1:0] != 1);
    wire is_signed_mul_b = is_signed_op;
    wire [NUM_LANES-1:0][2*(32+1)-1:0] mul_result_tmp;
    wire is_mulh_out;
    wire is_mul_w_out;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire [32:0] mul_in1 = {is_signed_mul_a && execute_if.data.rs1_data[i][32-1], execute_if.data.rs1_data[i]};
        wire [32:0] mul_in2 = {is_signed_mul_b && execute_if.data.rs2_data[i][32-1], execute_if.data.rs2_data[i]};
        VX_multiplier #(
            .A_WIDTH (32+1),
            .B_WIDTH (32+1),
            .R_WIDTH (2*(32+1)),
            .SIGNED  (1),
            .LATENCY (4)
        ) multiplier (
            .clk    (clk),
            .enable (mul_ready_in),
            .dataa  (mul_in1),
            .datab  (mul_in2),
            .result (mul_result_tmp[i])
        );
    end
    VX_shift_register #(
        .DATAW  (1 + TAG_WIDTH + 1 + 1),
        .DEPTH  (4),
        .RESETW (1)
    ) mul_shift_reg (
        .clk(clk),
        .reset    (reset),
        .enable   (mul_ready_in),
        .data_in  ({mul_valid_in, execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.PC, execute_if.data.rd, execute_if.data.wb, execute_if.data.pid, execute_if.data.sop, execute_if.data.eop, is_mulh_in, is_alu_w}),
        .data_out ({mul_valid_out, mul_uuid_out, mul_wid_out, mul_tmask_out, mul_PC_out, mul_rd_out, mul_wb_out, mul_pid_out, mul_sop_out, mul_eop_out, is_mulh_out, is_mul_w_out})
    );
    assign mul_ready_in = mul_ready_out || ~mul_valid_out;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign mul_result_out[i] = is_mulh_out ? mul_result_tmp[i][2*(32)-1:32] : mul_result_tmp[i][32-1:0];
    end
    wire [NUM_LANES-1:0][32-1:0] div_result_out;
    wire [1-1:0] div_uuid_out;
    wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0] div_wid_out;
    wire [NUM_LANES-1:0] div_tmask_out;
    wire [(32-1)-1:0] div_PC_out;
    wire [$clog2(32)-1:0] div_rd_out;
    wire div_wb_out;
    wire [PID_WIDTH-1:0] div_pid_out;
    wire div_sop_out, div_eop_out;
    wire is_rem_op = muldiv_op[1];
    wire div_valid_in = execute_if.valid && ~is_mulx_op;
    wire div_ready_in;
    wire div_valid_out;
    wire div_ready_out;
    wire [NUM_LANES-1:0][32-1:0] div_in1;
    wire [NUM_LANES-1:0][32-1:0] div_in2;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign div_in1[i] = execute_if.data.rs1_data[i];
        assign div_in2[i] = execute_if.data.rs2_data[i];
    end
    wire [NUM_LANES-1:0][32-1:0] div_quotient, div_remainder;
    wire is_rem_op_out;
    wire is_div_w_out;
    wire div_strode;
    wire div_busy;
    VX_elastic_adapter div_elastic_adapter (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (div_valid_in),
        .ready_in  (div_ready_in),
        .valid_out (div_valid_out),
        .ready_out (div_ready_out),
        .strobe    (div_strode),
        .busy      (div_busy)
    );
    VX_serial_div #(
        .WIDTHN (32),
        .WIDTHD (32),
        .WIDTHQ (32),
        .WIDTHR (32),
        .LANES  (NUM_LANES)
    ) serial_div (
        .clk       (clk),
        .reset     (reset),
        .strobe    (div_strode),
        .busy      (div_busy),
        .is_signed (is_signed_op),
        .numer     (div_in1),
        .denom     (div_in2),
        .quotient  (div_quotient),
        .remainder (div_remainder)
    );
    reg [TAG_WIDTH+2-1:0] div_tag_r;
    always @(posedge clk) begin
        if (div_valid_in && div_ready_in) begin
            div_tag_r <= {execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.PC, execute_if.data.rd, execute_if.data.wb, is_rem_op, is_alu_w, execute_if.data.pid, execute_if.data.sop, execute_if.data.eop};
        end
    end
    assign {div_uuid_out, div_wid_out, div_tmask_out, div_PC_out, div_rd_out, div_wb_out, is_rem_op_out, is_div_w_out, div_pid_out, div_sop_out, div_eop_out} = div_tag_r;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign div_result_out[i] = is_rem_op_out ? div_remainder[i] : div_quotient[i];
    end
    assign execute_if.ready = is_mulx_op ? mul_ready_in : div_ready_in;
    VX_stream_arb #(
        .NUM_INPUTS (2),
        .DATAW (TAG_WIDTH + (NUM_LANES * 32)),
        .ARBITER ("F"),
        .OUT_BUF (1)
    ) rsp_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  ({div_valid_out, mul_valid_out}),
        .ready_in  ({div_ready_out, mul_ready_out}),
        .data_in   ({{div_uuid_out, div_wid_out, div_tmask_out, div_PC_out, div_rd_out, div_wb_out, div_pid_out, div_sop_out, div_eop_out, div_result_out},
                     {mul_uuid_out, mul_wid_out, mul_tmask_out, mul_PC_out, mul_rd_out, mul_wb_out, mul_pid_out, mul_sop_out, mul_eop_out, mul_result_out}}),
        .data_out  ({commit_if.data.uuid, commit_if.data.wid, commit_if.data.tmask, commit_if.data.PC, commit_if.data.rd, commit_if.data.wb, commit_if.data.pid, commit_if.data.sop, commit_if.data.eop, commit_if.data.data}),
        .valid_out (commit_if.valid),
        .ready_out (commit_if.ready),
        . sel_out ()
    );
endmodule
