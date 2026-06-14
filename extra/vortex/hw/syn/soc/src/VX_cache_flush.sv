module VX_cache_flush #(
    parameter NUM_REQS  = 4,
    parameter NUM_BANKS = 1,
    parameter BANK_SEL_LATENCY = 1
) (
    input wire              clk,
    input wire              reset,
    VX_mem_bus_if.slave     core_bus_in_if [NUM_REQS],
    VX_mem_bus_if.master    core_bus_out_if [NUM_REQS],
    input wire [NUM_BANKS-1:0] bank_req_fire,
    output wire [NUM_BANKS-1:0] flush_begin,
    input wire [NUM_BANKS-1:0] flush_end
);
    localparam STATE_IDLE  = 0;
    localparam STATE_WAIT1 = 1;
    localparam STATE_FLUSH = 2;
    localparam STATE_WAIT2 = 3;
    localparam STATE_DONE  = 4;
    reg [2:0] state, state_n;
    wire no_inflight_reqs;
    if (BANK_SEL_LATENCY != 0) begin
        localparam NUM_REQS_W  = $clog2(NUM_REQS+1);
        localparam NUM_BANKS_W = $clog2(NUM_BANKS+1);
        wire [NUM_REQS-1:0] core_bus_out_fire;
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            assign core_bus_out_fire[i] = core_bus_out_if[i].req_valid && core_bus_out_if[i].req_ready;
        end
        wire [NUM_REQS_W-1:0] core_bus_out_cnt;
        wire [NUM_BANKS_W-1:0] bank_req_cnt;
    VX_popcount #( 
        .N ($bits(core_bus_out_fire)), 
        .MODEL (1) 
    ) __core_bus_out_cnt__ ( 
        .data_in  (core_bus_out_fire), 
        .data_out (core_bus_out_cnt) 
    );
    VX_popcount #( 
        .N ($bits(bank_req_fire)), 
        .MODEL (1) 
    ) __bank_req_cnt__ ( 
        .data_in  (bank_req_fire), 
        .data_out (bank_req_cnt) 
    );
        VX_pending_size #(
            .SIZE  (BANK_SEL_LATENCY * NUM_BANKS),
            .INCRW (NUM_BANKS_W),
            .DECRW (NUM_BANKS_W)
        ) pending_size (
            .clk   (clk),
            .reset (reset),
            .incr  (NUM_BANKS_W'(core_bus_out_cnt)),
            .decr  (bank_req_cnt),
            .empty (no_inflight_reqs),
            . alm_empty (),
            . full (),
            . alm_full (),
            . size ()
        );
    end else begin
        assign no_inflight_reqs = 0;
    end
    reg [NUM_BANKS-1:0] flush_done, flush_done_n;
    wire [NUM_REQS-1:0] flush_req_mask;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign flush_req_mask[i] = core_bus_in_if[i].req_valid && core_bus_in_if[i].req_data.atype[0];
    end
    wire flush_req_enable = (| flush_req_mask);
    reg [NUM_REQS-1:0] lock_released, lock_released_n;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        wire input_enable = ~flush_req_enable || lock_released[i];
        assign core_bus_out_if[i].req_valid = core_bus_in_if[i].req_valid && input_enable;
        assign core_bus_out_if[i].req_data  = core_bus_in_if[i].req_data;
        assign core_bus_in_if[i].req_ready  = core_bus_out_if[i].req_ready && input_enable;
    end
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign core_bus_in_if[i].rsp_valid  = core_bus_out_if[i].rsp_valid;
        assign core_bus_in_if[i].rsp_data   = core_bus_out_if[i].rsp_data;
        assign core_bus_out_if[i].rsp_ready = core_bus_in_if[i].rsp_ready;
    end
    wire [NUM_REQS-1:0] core_bus_out_ready;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign core_bus_out_ready[i] = core_bus_out_if[i].req_ready;
    end
    always @(*) begin
        state_n = state;
        flush_done_n = flush_done;
        lock_released_n = lock_released;
        case (state)
            STATE_IDLE: begin
                if (flush_req_enable) begin
                    state_n = (BANK_SEL_LATENCY != 0) ? STATE_WAIT1 : STATE_FLUSH;
                end
            end
            STATE_WAIT1: begin
                if (no_inflight_reqs) begin
                    state_n = STATE_FLUSH;
                end
            end
            STATE_FLUSH: begin
                state_n = STATE_WAIT2;
            end
            STATE_WAIT2: begin
                flush_done_n = flush_done | flush_end;
                if (flush_done_n == {NUM_BANKS{1'b1}}) begin
                    state_n = STATE_DONE;
                    flush_done_n = '0;
                    lock_released_n = flush_req_mask;
                end
            end
            STATE_DONE: begin
                lock_released_n = lock_released & ~core_bus_out_ready;
                if (lock_released_n == 0) begin
                    state_n = STATE_IDLE;
                end
            end
        endcase
    end
    always @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            flush_done <= '0;
            lock_released <= '0;
        end else begin
            state <= state_n;
            flush_done <= flush_done_n;
            lock_released <= lock_released_n;
        end
    end
    assign flush_begin = {NUM_BANKS{state == STATE_FLUSH}};
endmodule
