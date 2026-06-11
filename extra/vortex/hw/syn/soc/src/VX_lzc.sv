module VX_lzc #(
    parameter N       = 2,
    parameter REVERSE = 0,   
    parameter LOGN    = (((N) > 1) ? $clog2(N) : 1)
) (
    input  wire [N-1:0]    data_in,
    output wire [LOGN-1:0] data_out,
    output wire            valid_out
);
    if (N == 1) begin
        assign data_out  = '0;
        assign valid_out = data_in;
    end else begin
        wire [N-1:0][LOGN-1:0] indices;
        for (genvar i = 0; i < N; ++i) begin
            assign indices[i] = REVERSE ? LOGN'(i) : LOGN'(N-1-i);
        end
        VX_find_first #(
            .N       (N),
            .DATAW   (LOGN),
            .REVERSE (!REVERSE)
        ) find_first (        
            .data_in   (indices),
            .valid_in  (data_in),
            .data_out  (data_out),
            .valid_out (valid_out)
        );
    end
endmodule
