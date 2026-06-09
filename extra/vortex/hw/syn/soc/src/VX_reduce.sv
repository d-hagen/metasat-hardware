module VX_reduce #(    
    parameter DATAW_IN   = 1,
    parameter DATAW_OUT  = DATAW_IN,
    parameter N          = 1,
    parameter  OP = "+"
) (
    input wire [N-1:0][DATAW_IN-1:0] data_in,
    output wire [DATAW_OUT-1:0]      data_out
);
    if (N == 1) begin
        assign data_out = DATAW_OUT'(data_in[0]);
    end else begin
        localparam int N_A = N / 2;
        localparam int N_B = N - N_A;
        wire [N_A-1:0][DATAW_IN-1:0] in_A;
        wire [N_B-1:0][DATAW_IN-1:0] in_B;
        wire [DATAW_OUT-1:0] out_A, out_B;
        for (genvar i = 0; i < N_A; i++) begin
            assign in_A[i] = data_in[i];
        end
        for (genvar i = 0; i < N_B; i++) begin
            assign in_B[i] = data_in[N_A + i];
        end
        VX_reduce #(
            .DATAW_IN  (DATAW_IN), 
            .DATAW_OUT (DATAW_OUT),
            .N  (N_A),
            .OP (OP)
        ) reduce_A (
            .data_in  (in_A), 
            .data_out (out_A)
        );
        VX_reduce #(
            .DATAW_IN  (DATAW_IN), 
            .DATAW_OUT (DATAW_OUT),
            .N  (N_B),
            .OP (OP)
        ) reduce_B (
            .data_in  (in_B), 
            .data_out (out_B)
        );
             if (OP == "+") assign data_out = out_A + out_B;
        else if (OP == "^") assign data_out = out_A ^ out_B;
        else if (OP == "&") assign data_out = out_A & out_B;
        else if (OP == "|") assign data_out = out_A | out_B;
        else ;
    end
endmodule
