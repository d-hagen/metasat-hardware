module VX_operands import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = "",
    parameter NUM_BANKS = 4,
    parameter OUT_BUF   = 4  
) (
    input wire              clk,
    input wire              reset,
    VX_writeback_if.slave   writeback_if,
    VX_scoreboard_if.slave  scoreboard_if,
    VX_operands_if.master   operands_if
);
    localparam NUM_SRC_REGS = 3;
    localparam REQ_SEL_BITS = $clog2(NUM_SRC_REGS);
    localparam REQ_SEL_WIDTH = (((REQ_SEL_BITS) != 0) ? (REQ_SEL_BITS) : 1);
    localparam BANK_SEL_BITS = $clog2(NUM_BANKS);
    localparam BANK_SEL_WIDTH = (((BANK_SEL_BITS) != 0) ? (BANK_SEL_BITS) : 1);
    localparam PER_BANK_REGS = (2 * 32) / NUM_BANKS;
    localparam META_DATAW = ISSUE_WIS_W + 4 + (32-1) + 1 + $clog2((3 + 1)) + 4 + $bits(op_args_t) + $clog2((2 * 32)) + 1;
    localparam REGS_DATAW = 32 * 4;
    localparam DATAW = META_DATAW + NUM_SRC_REGS * REGS_DATAW;
    localparam RAM_ADDRW = ((((2 * 32) * PER_ISSUE_WARPS) > 1) ? $clog2((2 * 32) * PER_ISSUE_WARPS) : 1);
    localparam PER_BANK_ADDRW = RAM_ADDRW - BANK_SEL_BITS;
    localparam XLEN_SIZE = 32 / 8;
    localparam BYTEENW = 4 * XLEN_SIZE;
    wire [NUM_SRC_REGS-1:0] src_valid;
    wire [NUM_SRC_REGS-1:0] req_in_valid, req_in_ready;
    wire [NUM_SRC_REGS-1:0][PER_BANK_ADDRW-1:0] req_in_data;
    wire [NUM_SRC_REGS-1:0][BANK_SEL_WIDTH-1:0] req_bank_idx;
    wire [NUM_BANKS-1:0] gpr_rd_valid, gpr_rd_ready;
    wire [NUM_BANKS-1:0] gpr_rd_valid_st1, gpr_rd_valid_st2;
    wire [NUM_BANKS-1:0][PER_BANK_ADDRW-1:0] gpr_rd_addr, gpr_rd_addr_st1;
    wire [NUM_BANKS-1:0][4-1:0][32-1:0] gpr_rd_data_st1, gpr_rd_data_st2;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0] gpr_rd_req_idx, gpr_rd_req_idx_st1, gpr_rd_req_idx_st2;
    wire pipe_valid_st1, pipe_ready_st1;
    wire pipe_valid_st2, pipe_ready_st2;
    wire [META_DATAW-1:0] pipe_data, pipe_data_st1, pipe_data_st2;
    reg [NUM_SRC_REGS-1:0][4-1:0][32-1:0] src_data_n;
    wire [NUM_SRC_REGS-1:0][4-1:0][32-1:0] src_data_st1, src_data_st2;
    reg [NUM_SRC_REGS-1:0] data_fetched_n;
    wire [NUM_SRC_REGS-1:0] data_fetched_st1;
    reg has_collision_n;
    wire has_collision_st1;
    wire [NUM_SRC_REGS-1:0][$clog2((2 * 32))-1:0] src_regs = {scoreboard_if.data.rs3,
                                                      scoreboard_if.data.rs2,
                                                      scoreboard_if.data.rs1};
    for (genvar i = 0; i < NUM_SRC_REGS; ++i) begin
        if (ISSUE_WIS != 0) begin
            assign req_in_data[i] = {src_regs[i][$clog2((2 * 32))-1:BANK_SEL_BITS], scoreboard_if.data.wis};
        end else begin
            assign req_in_data[i] = src_regs[i][$clog2((2 * 32))-1:BANK_SEL_BITS];
        end
        if (NUM_BANKS != 1) begin
            assign req_bank_idx[i] = src_regs[i][BANK_SEL_BITS-1:0];
        end else begin
            assign req_bank_idx[i] = '0;
        end
    end
    for (genvar i = 0; i < NUM_SRC_REGS; ++i) begin
        assign src_valid[i] = (src_regs[i] != 0) && ~data_fetched_st1[i];
    end
    assign req_in_valid = {NUM_SRC_REGS{scoreboard_if.valid}} & src_valid;
    VX_stream_xbar #(
        .NUM_INPUTS  (NUM_SRC_REGS),
        .NUM_OUTPUTS (NUM_BANKS),
        .DATAW       (PER_BANK_ADDRW),
        .ARBITER     ("P"),  
        .PERF_CTR_BITS(44),
        .OUT_BUF     (0)  
    ) req_xbar (
        .clk       (clk),
        .reset     (reset),
        . collisions (),
        .valid_in  (req_in_valid),
        .data_in   (req_in_data),
        .sel_in    (req_bank_idx),
        .ready_in  (req_in_ready),
        .valid_out (gpr_rd_valid),
        .data_out  (gpr_rd_addr),
        .sel_out   (gpr_rd_req_idx),
        .ready_out (gpr_rd_ready)
    );
    wire pipe_in_ready = pipe_ready_st1 || ~pipe_valid_st1;
    assign gpr_rd_ready = {NUM_BANKS{pipe_in_ready}};
    assign scoreboard_if.ready = pipe_in_ready && ~has_collision_n;
    wire pipe_fire_st1 = pipe_valid_st1 && pipe_ready_st1;
    wire pipe_fire_st2 = pipe_valid_st2 && pipe_ready_st2;
    always @(*) begin
        has_collision_n = 0;
        for (integer i = 0; i < NUM_SRC_REGS; ++i) begin
            for (integer j = 1; j < (NUM_SRC_REGS-i); ++j) begin
                has_collision_n |= src_valid[i]
                                && src_valid[j+i]
                                && (req_bank_idx[i] == req_bank_idx[j+i]);
            end
        end
    end
    always @(*) begin
        data_fetched_n = data_fetched_st1;
         if (scoreboard_if.ready) begin
            data_fetched_n = '0;
        end else begin
            data_fetched_n = data_fetched_st1 | req_in_ready;
        end
    end
    assign pipe_data = {
        scoreboard_if.data.wis,
        scoreboard_if.data.tmask,
        scoreboard_if.data.PC,
        scoreboard_if.data.wb,
        scoreboard_if.data.ex_type,
        scoreboard_if.data.op_type,
        scoreboard_if.data.op_args,
        scoreboard_if.data.rd,
        scoreboard_if.data.uuid
    };
    VX_pipe_register #(
        .DATAW  (1 + NUM_SRC_REGS + NUM_BANKS + META_DATAW + 1 + NUM_BANKS * (PER_BANK_ADDRW + REQ_SEL_WIDTH)),
        .RESETW (1 + NUM_SRC_REGS)
    ) pipe_reg1 (
        .clk      (clk),
        .reset    (reset),
        .enable   (pipe_in_ready),
        .data_in  ({scoreboard_if.valid, data_fetched_n,   gpr_rd_valid,     pipe_data,     has_collision_n,   gpr_rd_addr,     gpr_rd_req_idx}),
        .data_out ({pipe_valid_st1,      data_fetched_st1, gpr_rd_valid_st1, pipe_data_st1, has_collision_st1, gpr_rd_addr_st1, gpr_rd_req_idx_st1})
    );
    assign pipe_ready_st1 = pipe_ready_st2 || ~pipe_valid_st2;
    assign src_data_st1 = pipe_fire_st2 ? '0 : src_data_n;
    wire pipe_valid2_st1 = pipe_valid_st1 && ~has_collision_st1;
    wire [1-1:0] pipe2_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __pipe2_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (pipe2_reset)                          
    );  
    VX_pipe_register #(
        .DATAW  (1 + NUM_SRC_REGS * REGS_DATAW + NUM_BANKS + NUM_BANKS * REGS_DATAW + META_DATAW + NUM_BANKS * REQ_SEL_WIDTH),
        .RESETW (1 + NUM_SRC_REGS * REGS_DATAW)
    ) pipe_reg2 (
        .clk      (clk),
        .reset    (pipe2_reset),
        .enable   (pipe_ready_st1),
        .data_in  ({pipe_valid2_st1, src_data_st1, gpr_rd_valid_st1, gpr_rd_data_st1, pipe_data_st1, gpr_rd_req_idx_st1}),
        .data_out ({pipe_valid_st2,  src_data_st2, gpr_rd_valid_st2, gpr_rd_data_st2, pipe_data_st2, gpr_rd_req_idx_st2})
    );
    always @(*) begin
        src_data_n = src_data_st2;
        for (integer b = 0; b < NUM_BANKS; ++b) begin
            if (gpr_rd_valid_st2[b]) begin
                src_data_n[gpr_rd_req_idx_st2[b]] = gpr_rd_data_st2[b];
            end
        end
    end
    VX_elastic_buffer #(
        .DATAW   (DATAW),
        .SIZE    ((((OUT_BUF) < (2)) ? (OUT_BUF) : (2))),
        .OUT_REG (((OUT_BUF < 2) ? OUT_BUF : (OUT_BUF - 2))),
        .LUTRAM  (1)
    ) out_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (pipe_valid_st2),
        .ready_in  (pipe_ready_st2),
        .data_in   ({
            pipe_data_st2,
            src_data_n[0],
            src_data_n[1],
            src_data_n[2]
        }),
        .data_out  ({
            operands_if.data.wis,
            operands_if.data.tmask,
            operands_if.data.PC,
            operands_if.data.wb,
            operands_if.data.ex_type,
            operands_if.data.op_type,
            operands_if.data.op_args,
            operands_if.data.rd,
            operands_if.data.uuid,
            operands_if.data.rs1_data,
            operands_if.data.rs2_data,
            operands_if.data.rs3_data
        }),
        .valid_out (operands_if.valid),
        .ready_out (operands_if.ready)
    );
    wire [PER_BANK_ADDRW-1:0] gpr_wr_addr;
    if (ISSUE_WIS != 0) begin
        assign gpr_wr_addr = {writeback_if.data.rd[$clog2((2 * 32))-1:BANK_SEL_BITS], writeback_if.data.wis};
    end else begin
        assign gpr_wr_addr = writeback_if.data.rd[$clog2((2 * 32))-1:BANK_SEL_BITS];
    end
    wire [BANK_SEL_WIDTH-1:0] gpr_wr_bank_idx;
    if (NUM_BANKS != 1) begin
        assign gpr_wr_bank_idx = writeback_if.data.rd[BANK_SEL_BITS-1:0];
    end else begin
        assign gpr_wr_bank_idx = '0;
    end
        wire wr_enabled = 1;
    for (genvar b = 0; b < NUM_BANKS; ++b) begin
        wire gpr_wr_enabled;
        if (BANK_SEL_BITS != 0) begin
            assign gpr_wr_enabled = wr_enabled
                                 && writeback_if.valid
                                 && (gpr_wr_bank_idx == BANK_SEL_BITS'(b));
        end else begin
            assign gpr_wr_enabled = wr_enabled && writeback_if.valid;
        end
        wire [BYTEENW-1:0] wren;
        for (genvar i = 0; i < 4; ++i) begin
            assign wren[i*XLEN_SIZE+:XLEN_SIZE] = {XLEN_SIZE{writeback_if.data.tmask[i]}};
        end
        VX_dp_ram #(
            .DATAW (REGS_DATAW),
            .SIZE  (PER_BANK_REGS * PER_ISSUE_WARPS),
            .WRENW (BYTEENW),
            .NO_RWCHECK (1)
        ) gpr_ram (
            .clk   (clk),
            .reset (reset),
            .read  (pipe_fire_st1),
            .wren  (wren),
            .write (gpr_wr_enabled),
            .waddr (gpr_wr_addr),
            .wdata (writeback_if.data.data),
            .raddr (gpr_rd_addr_st1[b]),
            .rdata (gpr_rd_data_st1[b])
        );
    end
endmodule
