module VX_reset_relay #(
    parameter N          = 1,
    parameter MAX_FANOUT = 0
) (
    input wire          clk,
    input wire          reset,
    output wire [N-1:0] reset_o
);
    if (MAX_FANOUT >= 0 && N > (MAX_FANOUT + MAX_FANOUT/2)) begin
        localparam F = (((MAX_FANOUT) != 0) ? (MAX_FANOUT) : 1);
        localparam R = N / F;
        (* keep = "true" *) reg [R-1:0] reset_r;
        for (genvar i = 0; i < R; ++i) begin
            always @(posedge clk) begin
                reset_r[i] <= reset;
            end
        end
        for (genvar i = 0; i < N; ++i) begin
            assign reset_o[i] = reset_r[i / F];
        end
    end else begin
        assign reset_o = {N{reset}};
    end
endmodule
