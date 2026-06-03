module VX_stream_pack #(
    parameter NUM_REQS      = 1,
    parameter DATA_WIDTH    = 1,
    parameter TAG_WIDTH     = 1,
    parameter TAG_SEL_BITS  = 0,
    parameter  ARBITER = "P",
    parameter OUT_BUF       = 0
) (
    input wire                          clk,
    input wire                          reset,
    input wire [NUM_REQS-1:0]           valid_in,
    input wire [NUM_REQS-1:0][DATA_WIDTH-1:0] data_in,
    input wire [NUM_REQS-1:0][TAG_WIDTH-1:0] tag_in,
    output wire [NUM_REQS-1:0]          ready_in,
    output wire                         valid_out,
    output wire [NUM_REQS-1:0]          mask_out,
    output wire [NUM_REQS-1:0][DATA_WIDTH-1:0] data_out,
    output wire [TAG_WIDTH-1:0]         tag_out,
    input wire                          ready_out
);
    if (NUM_REQS > 1) begin
        localparam LOG_NUM_REQS = $clog2(NUM_REQS);
        wire [LOG_NUM_REQS-1:0] grant_index;
        wire grant_valid;
        wire grant_ready;
        VX_generic_arbiter #(
            .NUM_REQS (NUM_REQS),
            .TYPE     (ARBITER)
        ) arbiter (
            .clk         (clk),
            .reset       (reset),
            .requests    (valid_in),
            .grant_valid (grant_valid),
            .grant_index (grant_index),
            . grant_onehot (),
            .grant_ready (grant_ready)
        );
        wire [TAG_WIDTH-1:0] tag_sel = tag_in[grant_index];
        wire [NUM_REQS-1:0] tag_matches;
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            assign tag_matches[i] = (tag_in[i][TAG_SEL_BITS-1:0] == tag_sel[TAG_SEL_BITS-1:0]);
        end
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            assign ready_in[i] = grant_ready & tag_matches[i];
        end
        wire [NUM_REQS-1:0] mask_sel = valid_in & tag_matches;
        VX_elastic_buffer #(
            .DATAW   (NUM_REQS + TAG_WIDTH + (NUM_REQS * DATA_WIDTH)),
            .SIZE    ((((OUT_BUF) < (2)) ? (OUT_BUF) : (2))),
            .OUT_REG (((OUT_BUF < 2) ? OUT_BUF : (OUT_BUF - 2)))
        ) out_buf (
            .clk       (clk),
            .reset     (reset),
            .valid_in  (grant_valid),
            .data_in   ({mask_sel, tag_sel, data_in}),
            .ready_in  (grant_ready),
            .valid_out (valid_out),
            .data_out  ({mask_out, tag_out, data_out}),
            .ready_out (ready_out)
        );
    end else begin
        assign valid_out = valid_in;
        assign mask_out  = 1'b1;
        assign data_out  = data_in;
        assign tag_out   = tag_in;
        assign ready_in  = ready_out;
    end
endmodule
