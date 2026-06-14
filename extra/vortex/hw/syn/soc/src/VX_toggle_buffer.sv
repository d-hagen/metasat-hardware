module VX_toggle_buffer #(
    parameter DATAW    = 1,
    parameter PASSTHRU = 0
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
        assign ready_in  = ready_out;
        assign valid_out = valid_in;        
        assign data_out  = data_in;
    end else begin
        reg [DATAW-1:0] buffer;
        reg has_data;
        always @(posedge clk) begin
            if (reset) begin
                has_data <= 0;
            end else begin
                if (~has_data) begin
                    has_data <= valid_in;
                end else if (ready_out) begin
                    has_data <= 0;
                end 
            end
            if (~has_data) begin
                buffer <= data_in;
            end
        end
        assign ready_in  = ~has_data;
        assign valid_out = has_data;
        assign data_out  = buffer;
    end
endmodule
