module VX_stream_unpack #(
    parameter NUM_REQS      = 1, 
    parameter DATA_WIDTH    = 1, 
    parameter TAG_WIDTH     = 1,
    parameter OUT_BUF       = 0
) (
    input wire                          clk,
    input wire                          reset,
    input wire                          valid_in,
    input wire [NUM_REQS-1:0]           mask_in,
    input wire [NUM_REQS-1:0][DATA_WIDTH-1:0] data_in,
    input wire [TAG_WIDTH-1:0]          tag_in,
    output wire                         ready_in,
    output wire [NUM_REQS-1:0]          valid_out,    
    output wire [NUM_REQS-1:0][DATA_WIDTH-1:0] data_out,
    output wire [NUM_REQS-1:0][TAG_WIDTH-1:0] tag_out,
    input wire  [NUM_REQS-1:0]          ready_out
);
    if (NUM_REQS > 1) begin
        reg [NUM_REQS-1:0] sent_mask;
        wire [NUM_REQS-1:0] ready_out_r;
        wire [NUM_REQS-1:0] sent_mask_n = sent_mask | ready_out_r;    
        wire sent_all = ~(| (mask_in & ~sent_mask_n));
        always @(posedge clk) begin
            if (reset) begin
                sent_mask <= '0;
            end else begin
                if (valid_in) begin
                    if (sent_all) begin
                        sent_mask <= '0;
                    end else begin
                        sent_mask <= sent_mask_n;
                    end
                end
            end
        end
        assign ready_in = sent_all;
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            VX_elastic_buffer #(
                .DATAW   (DATA_WIDTH + TAG_WIDTH),
                .SIZE    ((((OUT_BUF) < (2)) ? (OUT_BUF) : (2))),
                .OUT_REG (((OUT_BUF < 2) ? OUT_BUF : (OUT_BUF - 2)))
            ) out_buf (
                .clk       (clk),
                .reset     (reset),
                .valid_in  (valid_in && mask_in[i] && ~sent_mask[i]),
                .ready_in  (ready_out_r[i]),
                .data_in   ({data_in[i],  tag_in}),
                .data_out  ({data_out[i], tag_out[i]}),
                .valid_out (valid_out[i]),
                .ready_out (ready_out[i])
            );
        end
    end else begin
        assign valid_out = valid_in;        
        assign data_out  = data_in;
        assign tag_out   = tag_in;
        assign ready_in  = ready_out;
    end
endmodule
