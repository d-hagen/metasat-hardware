module VX_shift_register #( 
    parameter DATAW      = 1,
    parameter RESETW     = 0,
    parameter DEPTH      = 1,
    parameter NUM_TAPS   = 1,    
    parameter TAP_START  = 0,
    parameter TAP_STRIDE = 1    
) (
    input wire                         clk,
    input wire                         reset,
    input wire                         enable,
    input wire [DATAW-1:0]             data_in,
    output wire [NUM_TAPS-1:0][DATAW-1:0] data_out
);
    if (DEPTH != 0) begin
        reg [DEPTH-1:0][DATAW-1:0] entries;
        always @(posedge clk) begin
            for (integer i = 0; i < DATAW; ++i) begin
                if ((i >= (DATAW-RESETW)) && reset) begin
                    for (integer j = 0; j < DEPTH; ++j)
                        entries[j][i] <= 0;
                end else if (enable) begin          
                    for (integer j = 1; j < DEPTH; ++j)
                        entries[j-1][i] <= entries[j][i];
                    entries[DEPTH-1][i] <= data_in[i];
                end
            end
        end
        for (genvar i = 0; i < NUM_TAPS; ++i) begin
            assign data_out[i] = entries[i * TAP_STRIDE + TAP_START];
        end
    end else begin
        assign data_out = data_in;
    end
endmodule
