module VX_fair_arbiter #(
    parameter NUM_REQS     = 1,
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
    if (NUM_REQS == 1)  begin
        assign grant_index  = '0;
        assign grant_onehot = requests;
        assign grant_valid  = requests[0];
    end else begin
        reg [NUM_REQS-1:0] requests_r;
        wire [NUM_REQS-1:0] requests_sel = requests_r & requests;
        wire [NUM_REQS-1:0] requests_qual = (| requests_sel) ? requests_sel : requests;
        always @(posedge clk) begin
            if (reset) begin
                requests_r <= '0;
            end else if (grant_ready) begin
                requests_r <= requests_qual & ~grant_onehot;
            end
        end
        VX_priority_arbiter #(
            .NUM_REQS (NUM_REQS)
        ) priority_arbiter (
            .requests     (requests_qual),
            .grant_index  (grant_index),
            .grant_onehot (grant_onehot),
            .grant_valid  (grant_valid)
        );
    end
endmodule
