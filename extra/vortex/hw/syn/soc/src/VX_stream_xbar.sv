module VX_stream_xbar #(
    parameter NUM_INPUTS    = 4,
    parameter NUM_OUTPUTS   = 4,
    parameter DATAW         = 4,
    parameter IN_WIDTH      = (((NUM_INPUTS) > 1) ? $clog2(NUM_INPUTS) : 1),
    parameter OUT_WIDTH     = (((NUM_OUTPUTS) > 1) ? $clog2(NUM_OUTPUTS) : 1),
    parameter ARBITER       = "R",
    parameter OUT_BUF       = 0,
    parameter LUTRAM        = 0,
    parameter MAX_FANOUT    = 8,
    parameter PERF_CTR_BITS = $clog2(NUM_INPUTS+1)
) (
    input wire                              clk,
    input wire                              reset,
    output wire [PERF_CTR_BITS-1:0]         collisions,
    input wire [NUM_INPUTS-1:0]             valid_in,
    input wire [NUM_INPUTS-1:0][DATAW-1:0]  data_in,
    input wire [NUM_INPUTS-1:0][OUT_WIDTH-1:0] sel_in,
    output wire [NUM_INPUTS-1:0]            ready_in,
    output wire [NUM_OUTPUTS-1:0]           valid_out,
    output wire [NUM_OUTPUTS-1:0][DATAW-1:0] data_out,
    output wire [NUM_OUTPUTS-1:0][IN_WIDTH-1:0] sel_out,
    input  wire [NUM_OUTPUTS-1:0]           ready_out
);
    if (NUM_INPUTS != 1) begin
        if (NUM_OUTPUTS != 1) begin
            wire [NUM_OUTPUTS-1:0][NUM_INPUTS-1:0] per_output_ready_in;
            for (genvar i = 0; i < NUM_OUTPUTS; ++i) begin
                wire [NUM_INPUTS-1:0] valid_in_q;
                for (genvar j = 0; j < NUM_INPUTS; ++j) begin
                    assign valid_in_q[j] = valid_in[j] && (sel_in[j] == i);
                end
    wire [1-1:0] slice_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __slice_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (slice_reset)                          
    );
                VX_stream_arb #(
                    .NUM_INPUTS  (NUM_INPUTS),
                    .NUM_OUTPUTS (1),
                    .DATAW       (DATAW),
                    .ARBITER     (ARBITER),
                    .MAX_FANOUT  (MAX_FANOUT),
                    .OUT_BUF     (OUT_BUF),
                    .LUTRAM      (LUTRAM)
                ) xbar_arb (
                    .clk       (clk),
                    .reset     (slice_reset),
                    .valid_in  (valid_in_q),
                    .data_in   (data_in),
                    .ready_in  (per_output_ready_in[i]),
                    .valid_out (valid_out[i]),
                    .data_out  (data_out[i]),
                    .sel_out   (sel_out[i]),
                    .ready_out (ready_out[i])
                );
            end
            for (genvar i = 0; i < NUM_INPUTS; ++i) begin
                assign ready_in[i] = per_output_ready_in[sel_in[i]][i];
            end
        end else begin
            VX_stream_arb #(
                .NUM_INPUTS  (NUM_INPUTS),
                .NUM_OUTPUTS (1),
                .DATAW       (DATAW),
                .ARBITER     (ARBITER),
                .MAX_FANOUT  (MAX_FANOUT),
                .OUT_BUF     (OUT_BUF),
                .LUTRAM      (LUTRAM)
            ) xbar_arb (
                .clk       (clk),
                .reset     (reset),
                .valid_in  (valid_in),
                .data_in   (data_in),
                .ready_in  (ready_in),
                .valid_out (valid_out),
                .data_out  (data_out),
                .sel_out   (sel_out),
                .ready_out (ready_out)
            );
        end
    end else if (NUM_OUTPUTS != 1) begin
        logic [NUM_OUTPUTS-1:0] valid_out_r, ready_out_r;
        logic [NUM_OUTPUTS-1:0][DATAW-1:0] data_out_r;
        always @(*) begin
            valid_out_r = '0;
            valid_out_r[sel_in] = valid_in;
        end
        assign data_out_r = {NUM_OUTPUTS{data_in}};
        assign ready_in = ready_out_r[sel_in];
    wire [NUM_OUTPUTS-1:0] out_buf_reset;                        
    VX_reset_relay #(.N(NUM_OUTPUTS), .MAX_FANOUT(8)) __out_buf_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (out_buf_reset)                          
    );
        for (genvar i = 0; i < NUM_OUTPUTS; ++i) begin
            VX_elastic_buffer #(
                .DATAW   (DATAW),
                .SIZE    ((((OUT_BUF) < (2)) ? (OUT_BUF) : (2))),
                .OUT_REG (((OUT_BUF < 2) ? OUT_BUF : (OUT_BUF - 2))),
                .LUTRAM  (LUTRAM)
            ) out_buf (
                .clk       (clk),
                .reset     (out_buf_reset[i]),
                .valid_in  (valid_out_r[i]),
                .ready_in  (ready_out_r[i]),
                .data_in   (data_out_r[i]),
                .data_out  (data_out[i]),
                .valid_out (valid_out[i]),
                .ready_out (ready_out[i])
            );
        end
        assign sel_out = 0;
    end else begin
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    ((((OUT_BUF) < (2)) ? (OUT_BUF) : (2))),
            .OUT_REG (((OUT_BUF < 2) ? OUT_BUF : (OUT_BUF - 2))),
            .LUTRAM  (LUTRAM)
        ) out_buf (
            .clk       (clk),
            .reset     (reset),
            .valid_in  (valid_in),
            .ready_in  (ready_in),
            .data_in   (data_in),
            .data_out  (data_out),
            .valid_out (valid_out),
            .ready_out (ready_out)
        );
        assign sel_out = 0;
    end
    reg [NUM_INPUTS-1:0] per_cycle_collision, per_cycle_collision_r;
    wire [$clog2(NUM_INPUTS+1)-1:0] collision_count;
    reg [PERF_CTR_BITS-1:0] collisions_r;
    always @(*) begin
        per_cycle_collision = 0;
        for (integer i = 0; i < NUM_INPUTS; ++i) begin
            for (integer j = 1; j < (NUM_INPUTS-i); ++j) begin
                per_cycle_collision[i] |= valid_in[i]
                                       && valid_in[j+i]
                                       && (sel_in[i] == sel_in[j+i])
                                       && (ready_in[i] | ready_in[j+i]);
            end
        end
    end
    VX_pipe_register #( 
        .DATAW  ($bits(per_cycle_collision_r)), 
        .RESETW ($bits(per_cycle_collision_r)), 
        .DEPTH  (1) 
    ) __per_cycle_collision_r__ ( 
        .clk      (clk), 
        .reset    (reset), 
        .enable   (1'b1), 
        .data_in  (per_cycle_collision), 
        .data_out (per_cycle_collision_r) 
    );
    VX_popcount #( 
        .N ($bits(per_cycle_collision_r)), 
        .MODEL (1) 
    ) __collision_count__ ( 
        .data_in  (per_cycle_collision_r), 
        .data_out (collision_count) 
    );
    always @(posedge clk) begin
        if (reset) begin
            collisions_r <= '0;
        end else begin
            collisions_r <= collisions_r + PERF_CTR_BITS'(collision_count);
        end
    end
    assign collisions = collisions_r;
endmodule
