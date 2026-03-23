module VX_wctl_unit import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0,
    parameter NUM_LANES = 1
) (
    input wire              clk,
    input wire              reset,
    VX_execute_if.slave     execute_if,
    VX_warp_ctl_if.master   warp_ctl_if,
    VX_commit_if.master     commit_if
);
    localparam LANE_BITS  = $clog2(NUM_LANES);
    localparam LANE_WIDTH = (((LANE_BITS) != 0) ? (LANE_BITS) : 1);
    localparam PID_BITS   = $clog2(4 / NUM_LANES);
    localparam PID_WIDTH  = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam WCTL_WIDTH = $bits(tmc_t) + $bits(wspawn_t) + $bits(split_t) + $bits(join_t) + $bits(barrier_t);
    localparam DATAW = 1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + 32 + $clog2(32) + 1 + WCTL_WIDTH + PID_WIDTH + 1 + 1;
    tmc_t       tmc, tmc_r;
    wspawn_t    wspawn, wspawn_r;    
    split_t     split, split_r;
    join_t      sjoin, sjoin_r;
    barrier_t   barrier, barrier_r;
    wire is_wspawn = (execute_if.data.op_type == 4'h1);
    wire is_tmc    = (execute_if.data.op_type == 4'h0);
    wire is_pred   = (execute_if.data.op_type == 4'h5);
    wire is_split  = (execute_if.data.op_type == 4'h2);
    wire is_join   = (execute_if.data.op_type == 4'h3);
    wire is_bar    = (execute_if.data.op_type == 4'h4);
    wire [LANE_WIDTH-1:0] tid;
    if (LANE_BITS != 0) begin
        assign tid = execute_if.data.tid[0 +: LANE_BITS];
    end else begin
        assign tid = 0;
    end
    wire [32-1:0] rs1_data = execute_if.data.rs1_data[tid];
    wire [32-1:0] rs2_data = execute_if.data.rs2_data[tid];
    wire [NUM_LANES-1:0] taken;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign taken[i] = execute_if.data.rs1_data[i][0];
    end
    reg [4-1:0] then_tmask_r, then_tmask_n;
    reg [4-1:0] else_tmask_r, else_tmask_n;
    always @(*) begin
        then_tmask_n = then_tmask_r;
        else_tmask_n = else_tmask_r;
        if (execute_if.data.sop) begin
            then_tmask_n = '0;
            else_tmask_n = '0;
        end
        then_tmask_n[execute_if.data.pid * NUM_LANES +: NUM_LANES] = taken & execute_if.data.tmask;
        else_tmask_n[execute_if.data.pid * NUM_LANES +: NUM_LANES] = ~taken & execute_if.data.tmask;
    end
    always @(posedge clk) begin
        if (execute_if.valid) begin
            then_tmask_r <= then_tmask_n;
            else_tmask_r <= else_tmask_n;
        end
    end
    wire has_then = (then_tmask_n != 0);
    wire has_else = (else_tmask_n != 0);
    wire [4-1:0] pred_mask = has_then ? then_tmask_n : rs2_data[4-1:0];
    assign tmc.valid = (is_tmc || is_pred);
    assign tmc.tmask = is_pred ? pred_mask : rs1_data[4-1:0];
    assign split.valid      = is_split;
    assign split.is_dvg     = has_then && has_else;
    assign split.then_tmask = then_tmask_n;
    assign split.else_tmask = else_tmask_n;
    assign split.next_pc    = execute_if.data.PC + 4;
    assign sjoin.valid      = is_join;   
    assign sjoin.is_dvg     = rs1_data[0];
    assign barrier.valid    = is_bar;
    assign barrier.id       = rs1_data[((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0];
    assign barrier.is_global = 1'b0;
    assign barrier.size_m1  = rs2_data[$bits(barrier.size_m1)-1:0] - $bits(barrier.size_m1)'(1);
    wire [4-1:0] wspawn_wmask;
    for (genvar i = 0; i < 4; ++i) begin
        assign wspawn_wmask[i] = (i < rs1_data[$clog2(4):0]) && (i != execute_if.data.wid);
    end
    assign wspawn.valid = is_wspawn;
    assign wspawn.wmask = wspawn_wmask;
    assign wspawn.pc    = rs2_data;
    VX_elastic_buffer #(
        .DATAW (DATAW),
        .SIZE  (2)
    ) rsp_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (execute_if.valid),
        .ready_in  (execute_if.ready),
        .data_in   ({execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.PC, execute_if.data.rd, execute_if.data.wb, execute_if.data.pid, execute_if.data.sop, execute_if.data.eop, {tmc, wspawn, split, sjoin, barrier}}),
        .data_out  ({commit_if.data.uuid, commit_if.data.wid, commit_if.data.tmask, commit_if.data.PC, commit_if.data.rd, commit_if.data.wb, commit_if.data.pid, commit_if.data.sop, commit_if.data.eop, {tmc_r, wspawn_r, split_r, sjoin_r, barrier_r}}),
        .valid_out (commit_if.valid),
        .ready_out (commit_if.ready)
    );
    assign warp_ctl_if.valid   = commit_if.valid && commit_if.ready && commit_if.data.eop;
    assign warp_ctl_if.wid     = commit_if.data.wid;
    assign warp_ctl_if.tmc     = tmc_r;
    assign warp_ctl_if.wspawn  = wspawn_r;
    assign warp_ctl_if.split   = split_r;
    assign warp_ctl_if.sjoin   = sjoin_r;
    assign warp_ctl_if.barrier = barrier_r;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign commit_if.data.data[i] = 32'(split_r.is_dvg);
    end
endmodule
