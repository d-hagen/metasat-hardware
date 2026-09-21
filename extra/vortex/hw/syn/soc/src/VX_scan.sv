module VX_scan #(
    parameter N       = 1,
    parameter OP      = 0,   
    parameter REVERSE = 0    
) (
    input  wire [N-1:0] data_in,
    output wire [N-1:0] data_out
);
    localparam LOGN = $clog2(N);
    wire [LOGN:0][N-1:0] t;   
    if (REVERSE != 0) begin
        assign t[0] = data_in;
    end else begin
        assign t[0] = {<<{data_in}};
    end
    if ((N == 2) && (OP == 1)) begin
	    assign t[LOGN] = {t[0][1], &t[0][1:0]};
    end else if ((N == 3) && (OP == 1)) begin
	    assign t[LOGN] = {t[0][2], &t[0][2:1], &t[0][2:0]};
    end else if ((N == 4) && (OP == 1)) begin
	    assign t[LOGN] = {t[0][3], &t[0][3:2], &t[0][3:1], &t[0][3:0]};
    end else begin
        wire [N-1:0] fill;
	    for (genvar i = 0; i < LOGN; ++i) begin
            wire [N-1:0] shifted = N'({fill, t[i]} >> (1<<i));
            if (OP == 0) begin
		        assign fill = {N{1'b0}};
		        assign t[i+1] = t[i] ^ shifted;
            end else if (OP == 1) begin
		        assign fill = {N{1'b1}};
		        assign t[i+1] = t[i] & shifted;
            end else if (OP == 2) begin
		        assign fill = {N{1'b0}};
		        assign t[i+1] = t[i] | shifted;
            end
	    end
    end   
    if (REVERSE != 0) begin
        assign data_out = t[LOGN];
    end else begin
        for (genvar i = 0; i < N; ++i) begin
            assign data_out[i] = t[LOGN][N-1-i];
        end        
    end
endmodule
