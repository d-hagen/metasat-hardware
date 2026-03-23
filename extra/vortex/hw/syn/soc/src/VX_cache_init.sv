module VX_cache_init #(
    parameter CACHE_SIZE    = 1024, 
    parameter LINE_SIZE     = 16, 
    parameter NUM_BANKS     = 1,
    parameter NUM_WAYS      = 1
) (
    input  wire clk,
    input  wire reset,    
    output wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0] addr_out,
    output wire valid_out
);
    reg enabled;
    reg [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0] line_ctr;
    always @(posedge clk) begin
        if (reset) begin
            enabled  <= 1;
            line_ctr <= '0;
        end else begin
            if (enabled) begin
                if (line_ctr == ((2 ** $clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS))))-1)) begin
                    enabled <= 0;
                end
                line_ctr <= line_ctr + $clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))'(1);           
            end
        end
    end
    assign addr_out  = line_ctr;
    assign valid_out = enabled;
endmodule
