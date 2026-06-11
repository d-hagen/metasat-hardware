module VX_priority_arbiter #(
    parameter NUM_REQS     = 1,
    parameter LOG_NUM_REQS = (((NUM_REQS) > 1) ? $clog2(NUM_REQS) : 1)
) (
    input  wire [NUM_REQS-1:0]      requests,
    output wire [LOG_NUM_REQS-1:0]  grant_index,
    output wire [NUM_REQS-1:0]      grant_onehot,
    output wire                     grant_valid
);
    if (NUM_REQS == 1)  begin
        assign grant_index  = '0;
        assign grant_onehot = requests;
        assign grant_valid  = requests[0];
    end else begin
        VX_priority_encoder #(
            .N (NUM_REQS)
        ) priority_encoder (
            .data_in   (requests),
            .index     (grant_index),
            .onehot    (grant_onehot),
            .valid_out (grant_valid)
        );
    end
endmodule
