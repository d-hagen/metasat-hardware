module VX_alu_int #(
    parameter  INSTANCE_ID = "",
    parameter BLOCK_IDX = 0,
    parameter NUM_LANES = 1
) (
    input wire              clk,
    input wire              reset,
    VX_execute_if.slave     execute_if,
    VX_commit_if.master     commit_if,
    VX_branch_ctl_if.master branch_ctl_if
);
    localparam LANE_BITS      = $clog2(NUM_LANES);
    localparam LANE_WIDTH     = (((LANE_BITS) != 0) ? (LANE_BITS) : 1);
    localparam PID_BITS       = $clog2(2 / NUM_LANES);
    localparam PID_WIDTH      = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam SHIFT_IMM_BITS = $clog2(32);
    wire [NUM_LANES-1:0][32-1:0] add_result;
    wire [NUM_LANES-1:0][32:0]   sub_result;  
    reg  [NUM_LANES-1:0][32-1:0] shr_zic_result;
    reg  [NUM_LANES-1:0][32-1:0] msc_result;
    wire [NUM_LANES-1:0][32-1:0] add_result_w;
    wire [NUM_LANES-1:0][32-1:0] sub_result_w;
    wire [NUM_LANES-1:0][32-1:0] shr_result_w;
    reg  [NUM_LANES-1:0][32-1:0] msc_result_w;
    reg [NUM_LANES-1:0][32-1:0] alu_result;
    wire [NUM_LANES-1:0][32-1:0] alu_result_r;
    wire is_alu_w = 0;
    wire [4-1:0] alu_op = 4'(execute_if.data.op_type);
    wire [4-1:0]   br_op = 4'(execute_if.data.op_type);
    wire                    is_br_op = (execute_if.data.op_args.alu.xtype == 1);
    wire                   is_sub_op = alu_op[1];
    wire                   is_signed = alu_op[0];
    wire [1:0]              op_class = is_br_op ? {1'b0, ~alu_op[3]} : alu_op[3:2];
    wire [NUM_LANES-1:0][32-1:0] alu_in1 = execute_if.data.rs1_data;
    wire [NUM_LANES-1:0][32-1:0] alu_in2 = execute_if.data.rs2_data;
    wire [NUM_LANES-1:0][32-1:0] alu_in1_PC  = execute_if.data.op_args.alu.use_PC ? {NUM_LANES{execute_if.data.PC, 1'd0}} : alu_in1;
    wire [NUM_LANES-1:0][32-1:0] alu_in2_imm = execute_if.data.op_args.alu.use_imm ? {NUM_LANES{{{(32-$bits(execute_if.data.op_args.alu.imm)+1){execute_if.data.op_args.alu.imm[$bits(execute_if.data.op_args.alu.imm)-1]}}, execute_if.data.op_args.alu.imm[$bits(execute_if.data.op_args.alu.imm)-2:0]}}} : alu_in2;
    wire [NUM_LANES-1:0][32-1:0] alu_in2_br  = (execute_if.data.op_args.alu.use_imm && ~is_br_op) ? {NUM_LANES{{{(32-$bits(execute_if.data.op_args.alu.imm)+1){execute_if.data.op_args.alu.imm[$bits(execute_if.data.op_args.alu.imm)-1]}}, execute_if.data.op_args.alu.imm[$bits(execute_if.data.op_args.alu.imm)-2:0]}}} : alu_in2;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign add_result[i] = alu_in1_PC[i] + alu_in2_imm[i];
        assign add_result_w[i] = 32'($signed(alu_in1[i][31:0] + alu_in2_imm[i][31:0]));
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire [32:0] sub_in1 = {is_signed & alu_in1[i][32-1], alu_in1[i]};
        wire [32:0] sub_in2 = {is_signed & alu_in2_br[i][32-1], alu_in2_br[i]};
        assign sub_result[i] = sub_in1 - sub_in2;
        assign sub_result_w[i] = 32'($signed(alu_in1[i][31:0] - alu_in2_imm[i][31:0]));
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire [32:0] shr_in1 = {is_signed && alu_in1[i][32-1], alu_in1[i]};
        always @(*) begin
            case (alu_op[1:0])
                2'b10, 2'b11: begin  
                    shr_zic_result[i] = alu_in1[i] & {32{alu_op[0] ^ (| alu_in2[i])}};
                end
                default: begin  
                    shr_zic_result[i] = 32'($signed(shr_in1) >>> alu_in2_imm[i][SHIFT_IMM_BITS-1:0]);
                end
            endcase
        end
        wire [32:0] shr_in1_w = {is_signed && alu_in1[i][31], alu_in1[i][31:0]};
        wire [31:0] shr_res_w = 32'($signed(shr_in1_w) >>> alu_in2_imm[i][4:0]);
        assign shr_result_w[i] = 32'($signed(shr_res_w));
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        always @(*) begin
            case (alu_op[1:0])
                2'b00: msc_result[i] = alu_in1[i] & alu_in2_imm[i];  
                2'b01: msc_result[i] = alu_in1[i] | alu_in2_imm[i];  
                2'b10: msc_result[i] = alu_in1[i] ^ alu_in2_imm[i];  
                2'b11: msc_result[i] = alu_in1[i] << alu_in2_imm[i][SHIFT_IMM_BITS-1:0];  
            endcase
        end
        assign msc_result_w[i] = 32'($signed(alu_in1[i][31:0] << alu_in2_imm[i][4:0]));  
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire [32-1:0] slt_br_result = 32'({is_br_op && ~(| sub_result[i][32-1:0]), sub_result[i][32]});
        wire [32-1:0] sub_slt_br_result = (is_sub_op && ~is_br_op) ? sub_result[i][32-1:0] : slt_br_result;
        always @(*) begin
            case ({is_alu_w, op_class})
                3'b000: alu_result[i] = add_result[i];       
                3'b001: alu_result[i] = sub_slt_br_result;   
                3'b010: alu_result[i] = shr_zic_result[i];   
                3'b011: alu_result[i] = msc_result[i];       
                3'b100: alu_result[i] = add_result_w[i];     
                3'b101: alu_result[i] = sub_result_w[i];     
                3'b110: alu_result[i] = shr_result_w[i];     
                3'b111: alu_result[i] = msc_result_w[i];     
            endcase
        end
    end
    wire [(32-1)-1:0] PC_r;
    wire [4-1:0] br_op_r;
    wire [(32-1)-1:0] cbr_dest, cbr_dest_r;
    wire [LANE_WIDTH-1:0] tid, tid_r;
    wire is_br_op_r;
    assign cbr_dest = add_result[0][1 +: (32-1)];
    if (LANE_BITS != 0) begin
        assign tid = execute_if.data.tid[0 +: LANE_BITS];
    end else begin
        assign tid = 0;
    end
    VX_elastic_buffer #(
        .DATAW (1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + NUM_LANES + $clog2(32) + 1 + PID_WIDTH + 1 + 1 + (NUM_LANES * 32) + (32-1) + (32-1) + 1 + 4 + LANE_WIDTH)
    ) rsp_buf (
        .clk      (clk),
        .reset    (reset),
        .valid_in (execute_if.valid),
        .ready_in (execute_if.ready),
        .data_in  ({execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.rd, execute_if.data.wb, execute_if.data.pid, execute_if.data.sop, execute_if.data.eop, alu_result, execute_if.data.PC, cbr_dest, is_br_op, br_op, tid}),
        .data_out ({commit_if.data.uuid, commit_if.data.wid, commit_if.data.tmask, commit_if.data.rd, commit_if.data.wb, commit_if.data.pid, commit_if.data.sop, commit_if.data.eop, alu_result_r, PC_r, cbr_dest_r, is_br_op_r, br_op_r, tid_r}),
        .valid_out (commit_if.valid),
        .ready_out (commit_if.ready)
    );
    wire is_br_neg  = br_op_r[1];
    wire is_br_less = br_op_r[2];
    wire is_br_static = br_op_r[3];
    wire [32-1:0] br_result = alu_result_r[tid_r];
    wire is_less  = br_result[0];
    wire is_equal = br_result[1];
    wire br_enable = is_br_op_r && commit_if.valid && commit_if.ready && commit_if.data.eop;
    wire br_taken = ((is_br_less ? is_less : is_equal) ^ is_br_neg) | is_br_static;
    wire [(32-1)-1:0] br_dest = is_br_static ? br_result[1 +: (32-1)] : cbr_dest_r;
    wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0] br_wid;
    if ((((2 / 8) != 0) ? (2 / 8) : 1) != 1) begin 
        if ((((2 / 8) != 0) ? (2 / 8) : 1) != 2) begin 
            assign br_wid = {commit_if.data.wid[((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:$clog2((((2 / 8) != 0) ? (2 / 8) : 1))], $clog2((((2 / 8) != 0) ? (2 / 8) : 1))'(BLOCK_IDX)}; 
        end else begin 
            assign br_wid = ((($clog2(2)) != 0) ? ($clog2(2)) : 1)'(BLOCK_IDX); 
        end 
    end else begin 
        assign br_wid = commit_if.data.wid; 
    end
    VX_pipe_register #(
        .DATAW (1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + 1 + (32-1))
    ) branch_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({br_enable,           br_wid,            br_taken,            br_dest}),
        .data_out ({branch_ctl_if.valid, branch_ctl_if.wid, branch_ctl_if.taken, branch_ctl_if.dest})
    );
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign commit_if.data.data[i] = (is_br_op_r && is_br_static) ? {(PC_r + (32-1)'(2)), 1'd0} : alu_result_r[i];
    end
    assign commit_if.data.PC = PC_r;
endmodule
