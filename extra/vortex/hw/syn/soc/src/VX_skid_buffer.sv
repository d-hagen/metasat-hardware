module VX_skid_buffer #(
    parameter DATAW    = 32,
    parameter PASSTHRU = 0,
    parameter HALF_BW  = 0,
    parameter OUT_REG  = 0
) ( 
    input  wire             clk,
    input  wire             reset,
    input  wire             valid_in,
    output wire             ready_in,        
    input  wire [DATAW-1:0] data_in,
    output wire [DATAW-1:0] data_out,
    input  wire             ready_out,
    output wire             valid_out
);
    if (PASSTHRU != 0) begin
        assign valid_out = valid_in;
        assign data_out  = data_in;
        assign ready_in  = ready_out;
    end else if (HALF_BW != 0) begin
        VX_toggle_buffer #(
            .DATAW (DATAW)
        ) toggle_buffer (
            .clk       (clk),
            .reset     (reset),
            .valid_in  (valid_in),
            .data_in   (data_in),
            .ready_in  (ready_in),
            .valid_out (valid_out),
            .data_out  (data_out),
            .ready_out (ready_out)
        );
    end else begin
        VX_stream_buffer #(
            .DATAW (DATAW),
            .OUT_REG (OUT_REG)
        ) stream_buffer (
            .clk       (clk),
            .reset     (reset),
            .valid_in  (valid_in),
            .data_in   (data_in),
            .ready_in  (ready_in),
            .valid_out (valid_out),
            .data_out  (data_out),
            .ready_out (ready_out)
        );
    end
endmodule
