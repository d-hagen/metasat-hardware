module VX_gather_unit import VX_gpu_pkg::*; #(
    parameter BLOCK_SIZE = 1,
    parameter NUM_LANES  = 1,
    parameter OUT_BUF    = 0
) (
    input  wire         clk,
    input  wire         reset,
    VX_commit_if.slave  commit_in_if [BLOCK_SIZE],
    VX_commit_if.master commit_out_if [(((4 / 8) != 0) ? (4 / 8) : 1)]
);
    localparam BLOCK_SIZE_W = (((BLOCK_SIZE) > 1) ? $clog2(BLOCK_SIZE) : 1);
    localparam PID_BITS     = $clog2(4 / NUM_LANES);
    localparam PID_WIDTH    = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam DATAW        = 16 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + (32-1) + 1 + $clog2(32) + NUM_LANES * 32 + PID_WIDTH + 1 + 1;
    localparam DATA_WIS_OFF = DATAW - (16 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1));
    wire [BLOCK_SIZE-1:0] commit_in_valid;
    wire [BLOCK_SIZE-1:0][DATAW-1:0] commit_in_data;
    wire [BLOCK_SIZE-1:0] commit_in_ready;
    wire [BLOCK_SIZE-1:0][ISSUE_ISW_W-1:0] commit_in_isw;
    for (genvar i = 0; i < BLOCK_SIZE; ++i) begin
        assign commit_in_valid[i] = commit_in_if[i].valid;
        assign commit_in_data[i] = commit_in_if[i].data;
        assign commit_in_if[i].ready = commit_in_ready[i];
        if (BLOCK_SIZE != (((4 / 8) != 0) ? (4 / 8) : 1)) begin
            if (BLOCK_SIZE != 1) begin
                assign commit_in_isw[i] = {commit_in_data[i][DATA_WIS_OFF+BLOCK_SIZE_W +: (ISSUE_ISW_W-BLOCK_SIZE_W)], BLOCK_SIZE_W'(i)};
            end else begin
                assign commit_in_isw[i] = commit_in_data[i][DATA_WIS_OFF +: ISSUE_ISW_W];
            end
        end else begin
            assign commit_in_isw[i] = BLOCK_SIZE_W'(i);
        end
    end
    reg [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0] commit_out_valid;
    reg [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0][DATAW-1:0] commit_out_data;
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0] commit_out_ready;
    always @(*) begin
        commit_out_valid = '0;
        for (integer i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
            commit_out_data[i] = 'x;
        end
        for (integer i = 0; i < BLOCK_SIZE; ++i) begin
            commit_out_valid[commit_in_isw[i]] = commit_in_valid[i];
            commit_out_data[commit_in_isw[i]] = commit_in_data[i];
        end
    end
    for (genvar i = 0; i < BLOCK_SIZE; ++i) begin
        assign commit_in_ready[i] = commit_out_ready[commit_in_isw[i]];
    end
    for (genvar i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
        VX_commit_if #(
            .NUM_LANES (NUM_LANES)
        ) commit_tmp_if();
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    ((((OUT_BUF) < (2)) ? (OUT_BUF) : (2))),
            .OUT_REG (((OUT_BUF < 2) ? OUT_BUF : (OUT_BUF - 2)))
        ) out_buf (
            .clk        (clk),
            .reset      (reset),
            .valid_in   (commit_out_valid[i]),
            .ready_in   (commit_out_ready[i]),
            .data_in    (commit_out_data[i]),
            .data_out   (commit_tmp_if.data),
            .valid_out  (commit_tmp_if.valid),
            .ready_out  (commit_tmp_if.ready)
        );
        logic [4-1:0] commit_tmask_r;
        logic [4-1:0][32-1:0] commit_data_r;
        if (PID_BITS != 0) begin
            always @(*) begin
                commit_tmask_r = '0;
                commit_data_r  = 'x;
                for (integer j = 0; j < NUM_LANES; ++j) begin
                    commit_tmask_r[commit_tmp_if.data.pid * NUM_LANES + j] = commit_tmp_if.data.tmask[j];
                    commit_data_r[commit_tmp_if.data.pid * NUM_LANES + j] = commit_tmp_if.data.data[j];
                end
            end
        end else begin
            assign commit_tmask_r = commit_tmp_if.data.tmask;
            assign commit_data_r = commit_tmp_if.data.data;
        end
        assign commit_out_if[i].valid = commit_tmp_if.valid;
        assign commit_out_if[i].data = {
            commit_tmp_if.data.uuid,
            commit_tmp_if.data.wid,
            commit_tmask_r,
            commit_tmp_if.data.PC,
            commit_tmp_if.data.wb,
            commit_tmp_if.data.rd,
            commit_data_r,
            1'b0,  
            commit_tmp_if.data.sop,
            commit_tmp_if.data.eop
        };
        assign commit_tmp_if.ready = commit_out_if[i].ready;
    end
endmodule
