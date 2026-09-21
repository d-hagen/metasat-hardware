module VX_generic_arbiter #(
    parameter NUM_REQS     = 1,
    parameter  TYPE = "P",
    parameter LOG_NUM_REQS = (((NUM_REQS) > 1) ? $clog2(NUM_REQS) : 1)
) (
    input  wire                     clk,
    input  wire                     reset,
    input  wire [NUM_REQS-1:0]      requests,
    output wire [LOG_NUM_REQS-1:0]  grant_index,
    output wire [NUM_REQS-1:0]      grant_onehot,
    output wire                     grant_valid,
    input  wire                     grant_ready
);
    if (TYPE == "P") begin
        VX_priority_arbiter #(
            .NUM_REQS (NUM_REQS)
        ) priority_arbiter (
            .requests     (requests),
            .grant_valid  (grant_valid),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot)
        );
    end else if (TYPE == "R") begin
        VX_rr_arbiter #(
            .NUM_REQS (NUM_REQS)
        ) rr_arbiter (
            .clk          (clk),
            .reset        (reset),
            .requests     (requests),
            .grant_valid  (grant_valid),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot),
            .grant_ready  (grant_ready)
        );
    end else if (TYPE == "F") begin
        VX_fair_arbiter #(
            .NUM_REQS (NUM_REQS)
        ) fair_arbiter (
            .clk          (clk),
            .reset        (reset),
            .requests     (requests),
            .grant_valid  (grant_valid),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot),
            .grant_ready  (grant_ready)
        );
    end else if (TYPE == "M") begin
        VX_matrix_arbiter #(
            .NUM_REQS (NUM_REQS)
        ) matrix_arbiter (
            .clk          (clk),
            .reset        (reset),
            .requests     (requests),
            .grant_valid  (grant_valid),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot),
            .grant_ready  (grant_ready)
        );
    end else if (TYPE == "C") begin
        VX_cyclic_arbiter #(
            .NUM_REQS (NUM_REQS)
        ) cyclic_arbiter (
            .clk          (clk),
            .reset        (reset),
            .requests     (requests),
            .grant_valid  (grant_valid),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot),
            .grant_ready  (grant_ready)
        );
    end else begin
        ;
    end
endmodule
