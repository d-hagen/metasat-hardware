module VX_scoreboard import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_writeback_if.slave   writeback_if,
    VX_ibuffer_if.slave     ibuffer_if [PER_ISSUE_WARPS],
    VX_scoreboard_if.master scoreboard_if
);
    localparam DATAW = 23 + 4 + (32-1) + $clog2((3 + 0)) + 4 + $bits(op_args_t) + ($clog2(32) * 4) + 1;
    VX_ibuffer_if staging_if [PER_ISSUE_WARPS]();
    reg [PER_ISSUE_WARPS-1:0] operands_ready;
    for (genvar w = 0; w < PER_ISSUE_WARPS; ++w) begin
        VX_elastic_buffer #(
            .DATAW (DATAW),
            .SIZE  (1)
        ) stanging_buf (
            .clk      (clk),
            .reset    (reset),
            .valid_in (ibuffer_if[w].valid),
            .data_in  (ibuffer_if[w].data),
            .ready_in (ibuffer_if[w].ready),
            .valid_out(staging_if[w].valid),
            .data_out (staging_if[w].data),
            .ready_out(staging_if[w].ready)
        );
    end
    for (genvar w = 0; w < PER_ISSUE_WARPS; ++w) begin
        reg [32-1:0] inuse_regs;
        reg [3:0] operands_busy, operands_busy_n;
        wire ibuffer_fire = ibuffer_if[w].valid && ibuffer_if[w].ready;
        wire staging_fire = staging_if[w].valid && staging_if[w].ready;
        wire writeback_fire = writeback_if.valid
                           && (writeback_if.data.wis == ISSUE_WIS_W'(w))
                           && writeback_if.data.eop;
        always @(*) begin
            operands_busy_n = operands_busy;
            if (ibuffer_fire) begin
                operands_busy_n = {
                    inuse_regs[ibuffer_if[w].data.rs3],
                    inuse_regs[ibuffer_if[w].data.rs2],
                    inuse_regs[ibuffer_if[w].data.rs1],
                    inuse_regs[ibuffer_if[w].data.rd]
                };
            end
            if (writeback_fire) begin
                if (ibuffer_fire) begin
                    if (writeback_if.data.rd == ibuffer_if[w].data.rd) begin
                        operands_busy_n[0] = 0;
                    end
                    if (writeback_if.data.rd == ibuffer_if[w].data.rs1) begin
                        operands_busy_n[1] = 0;
                    end
                    if (writeback_if.data.rd == ibuffer_if[w].data.rs2) begin
                        operands_busy_n[2] = 0;
                    end
                    if (writeback_if.data.rd == ibuffer_if[w].data.rs3) begin
                        operands_busy_n[3] = 0;
                    end
                end else begin
                    if (writeback_if.data.rd == staging_if[w].data.rd) begin
                        operands_busy_n[0] = 0;
                    end
                    if (writeback_if.data.rd == staging_if[w].data.rs1) begin
                        operands_busy_n[1] = 0;
                    end
                    if (writeback_if.data.rd == staging_if[w].data.rs2) begin
                        operands_busy_n[2] = 0;
                    end
                    if (writeback_if.data.rd == staging_if[w].data.rs3) begin
                        operands_busy_n[3] = 0;
                    end
                end
            end
            if (staging_fire && staging_if[w].data.wb) begin
                if (staging_if[w].data.rd == ibuffer_if[w].data.rd) begin
                    operands_busy_n[0] = 1;
                end
                if (staging_if[w].data.rd == ibuffer_if[w].data.rs1) begin
                    operands_busy_n[1] = 1;
                end
                if (staging_if[w].data.rd == ibuffer_if[w].data.rs2) begin
                    operands_busy_n[2] = 1;
                end
                if (staging_if[w].data.rd == ibuffer_if[w].data.rs3) begin
                    operands_busy_n[3] = 1;
                end
            end
        end
        always @(posedge clk) begin
            if (reset) begin
                inuse_regs <= '0;
            end else begin
                if (writeback_fire) begin
                    inuse_regs[writeback_if.data.rd] <= 0;
                end
                if (staging_fire && staging_if[w].data.wb) begin
                    inuse_regs[staging_if[w].data.rd] <= 1;
                end
            end
            operands_busy <= operands_busy_n;
            operands_ready[w] <= ~(| operands_busy_n);
        end
    end
    wire [PER_ISSUE_WARPS-1:0] arb_valid_in;
    wire [PER_ISSUE_WARPS-1:0][DATAW-1:0] arb_data_in;
    wire [PER_ISSUE_WARPS-1:0] arb_ready_in;
    for (genvar w = 0; w < PER_ISSUE_WARPS; ++w) begin
        assign arb_valid_in[w] = staging_if[w].valid && operands_ready[w];
        assign arb_data_in[w] = staging_if[w].data;
        assign staging_if[w].ready = arb_ready_in[w] && operands_ready[w];
    end
    wire [1-1:0] arb_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __arb_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (arb_reset)                          
    );
    VX_stream_arb #(
        .NUM_INPUTS (PER_ISSUE_WARPS),
        .DATAW      (DATAW),
        .ARBITER    ("F"),
        .LUTRAM     (1),
        .OUT_BUF    (4)  
    ) out_arb (
        .clk      (clk),
        .reset    (arb_reset),
        .valid_in (arb_valid_in),
        .ready_in (arb_ready_in),
        .data_in  (arb_data_in),
        .data_out ({
            scoreboard_if.data.uuid,
            scoreboard_if.data.tmask,
            scoreboard_if.data.PC,
            scoreboard_if.data.ex_type,
            scoreboard_if.data.op_type,
            scoreboard_if.data.op_args,
            scoreboard_if.data.wb,
            scoreboard_if.data.rd,
            scoreboard_if.data.rs1,
            scoreboard_if.data.rs2,
            scoreboard_if.data.rs3
        }),
        .valid_out (scoreboard_if.valid),
        .ready_out (scoreboard_if.ready),
        .sel_out   (scoreboard_if.data.wis)
    );
endmodule
