module VX_cache_data #(
    parameter  INSTANCE_ID= "",
    parameter BANK_ID           = 0,
    parameter CACHE_SIZE        = 1024, 
    parameter LINE_SIZE         = 16, 
    parameter NUM_BANKS         = 1, 
    parameter NUM_WAYS          = 1,
    parameter WORD_SIZE         = 1,
    parameter WRITE_ENABLE      = 1,
    parameter UUID_WIDTH        = 0
) (
    input wire                          clk,
    input wire                          reset,
    input wire[(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0]     req_uuid,
    input wire                          stall,
    input wire                          read,
    input wire                          fill, 
    input wire                          write,
    input wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] line_addr,
    input wire [((($clog2((LINE_SIZE / WORD_SIZE))) != 0) ? ($clog2((LINE_SIZE / WORD_SIZE))) : 1)-1:0] wsel,
    input wire [WORD_SIZE-1:0]          byteen,
    input wire [(LINE_SIZE / WORD_SIZE)-1:0][(8 * WORD_SIZE)-1:0] fill_data,
    input wire [(8 * WORD_SIZE)-1:0]     write_data,
    input wire [NUM_WAYS-1:0]           way_sel,
    output wire [(8 * WORD_SIZE)-1:0]    read_data
);
    localparam BYTEENW = (WRITE_ENABLE != 0 || (NUM_WAYS > 1)) ? (LINE_SIZE * NUM_WAYS) : 1;
    wire [(LINE_SIZE / WORD_SIZE)-1:0][NUM_WAYS-1:0][(8 * WORD_SIZE)-1:0] wdata;
    wire [BYTEENW-1:0] wren;
    if (WRITE_ENABLE != 0 || (NUM_WAYS > 1)) begin
        reg [(LINE_SIZE / WORD_SIZE)-1:0][(8 * WORD_SIZE)-1:0] wdata_r;
        reg [(LINE_SIZE / WORD_SIZE)-1:0][WORD_SIZE-1:0] wren_r;
        always @(*) begin
            wdata_r = {(LINE_SIZE / WORD_SIZE){write_data}};
            wren_r  = '0;
            wren_r[wsel] = byteen;
        end
        wire [(LINE_SIZE / WORD_SIZE)-1:0][NUM_WAYS-1:0][WORD_SIZE-1:0] wren_w;
        for (genvar i = 0; i < (LINE_SIZE / WORD_SIZE); ++i) begin
            assign wdata[i] = fill ? {NUM_WAYS{fill_data[i]}} : {NUM_WAYS{wdata_r[i]}};            
            for (genvar j = 0; j < NUM_WAYS; ++j) begin
                assign wren_w[i][j] = (fill ? {WORD_SIZE{1'b1}} : wren_r[i])
                                    & {WORD_SIZE{((NUM_WAYS == 1) || way_sel[j])}};
            end
        end
        assign wren = wren_w;
    end else begin
        assign wdata = fill_data;
        assign wren  = fill;
    end
    wire [$clog2(NUM_WAYS)-1:0] way_idx;
    VX_onehot_encoder #(
        .N (NUM_WAYS)
    ) way_enc (
        .data_in  (way_sel),
        .data_out (way_idx),
        . valid_out ()
    );
    wire [(LINE_SIZE / WORD_SIZE)-1:0][NUM_WAYS-1:0][(8 * WORD_SIZE)-1:0] rdata;
    wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0] line_sel = line_addr[$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0];
    VX_sp_ram #(
        .DATAW ((8 * LINE_SIZE) * NUM_WAYS),
        .SIZE  (((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS))),
        .WRENW (BYTEENW),
        .NO_RWCHECK (1)
    ) data_store (
        .clk   (clk),
        .read  (1'b1),
        .write (write || fill),
        .wren  (wren),
        .addr  (line_sel),
        .wdata (wdata),
        .rdata (rdata) 
    );
    wire [NUM_WAYS-1:0][(8 * WORD_SIZE)-1:0] per_way_rdata;
    if ((LINE_SIZE / WORD_SIZE) > 1) begin
        assign per_way_rdata = rdata[wsel];
    end else begin
        assign per_way_rdata = rdata;
    end    
    assign read_data = per_way_rdata[way_idx];
endmodule
