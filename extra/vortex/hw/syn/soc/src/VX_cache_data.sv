module VX_cache_data #(
    parameter  INSTANCE_ID= "",
    parameter BANK_ID           = 0,
    parameter CACHE_SIZE        = 1024,
    parameter LINE_SIZE         = 16,
    parameter NUM_BANKS         = 1,
    parameter NUM_WAYS          = 1,
    parameter WORD_SIZE         = 1,
    parameter WRITE_ENABLE      = 1,
    parameter WRITEBACK         = 0,
    parameter DIRTY_BYTES       = 0,
    parameter UUID_WIDTH        = 0
) (
    input wire                          clk,
    input wire                          reset,
    input wire[(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0]     req_uuid,
    input wire                          stall,
    input wire                          init,
    input wire                          read,
    input wire                          fill,
    input wire                          flush,
    input wire                          write,
    input wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] line_addr,
    input wire [((($clog2((LINE_SIZE / WORD_SIZE))) != 0) ? ($clog2((LINE_SIZE / WORD_SIZE))) : 1)-1:0] wsel,
    input wire [(LINE_SIZE / WORD_SIZE)-1:0][(8 * WORD_SIZE)-1:0] fill_data,
    input wire [(LINE_SIZE / WORD_SIZE)-1:0][(8 * WORD_SIZE)-1:0] write_data,
    input wire [(LINE_SIZE / WORD_SIZE)-1:0][WORD_SIZE-1:0] write_byteen,
    input wire [NUM_WAYS-1:0]           way_sel,
    output wire [(8 * WORD_SIZE)-1:0]    read_data,
    output wire [(8 * LINE_SIZE)-1:0]    dirty_data,
    output wire [LINE_SIZE-1:0]         dirty_byteen
);
    localparam BYTEENW = (WRITE_ENABLE != 0 || (NUM_WAYS > 1)) ? (LINE_SIZE * NUM_WAYS) : 1;
    wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0] line_sel = line_addr[$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0];
    wire [(LINE_SIZE / WORD_SIZE)-1:0][NUM_WAYS-1:0][(8 * WORD_SIZE)-1:0] line_rdata;
    wire [(((NUM_WAYS) > 1) ? $clog2(NUM_WAYS) : 1)-1:0] way_idx;
    if (WRITEBACK) begin
        if (DIRTY_BYTES) begin
            wire [NUM_WAYS-1:0][LINE_SIZE-1:0] bs_rdata;
            wire [NUM_WAYS-1:0][LINE_SIZE-1:0] bs_wdata;
            for (genvar i = 0; i < NUM_WAYS; ++i) begin
                wire [LINE_SIZE-1:0] wdata = write ? (bs_rdata[i] | write_byteen) : ((fill || flush) ? '0 : bs_rdata[i]);
                assign bs_wdata[i] = init ? '0 : (way_sel[i] ? wdata : bs_rdata[i]);
            end
            VX_sp_ram #(
                .DATAW (LINE_SIZE * NUM_WAYS),
                .SIZE  (((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))
            ) byteen_store (
                .clk   (clk),
                .reset (reset),
                .read  (write || fill || flush),
                .write (init || write || fill || flush),
                .wren  (1'b1),
                .addr  (line_sel),
                .wdata (bs_wdata),
                .rdata (bs_rdata)
            );
            assign dirty_byteen = bs_rdata[way_idx];
        end else begin
            assign dirty_byteen = {LINE_SIZE{1'b1}};
        end
        wire [NUM_WAYS-1:0][(LINE_SIZE / WORD_SIZE)-1:0][(8 * WORD_SIZE)-1:0] flipped_rdata;
        for (genvar i = 0; i < (LINE_SIZE / WORD_SIZE); ++i) begin
            for (genvar j = 0; j < NUM_WAYS; ++j) begin
                assign flipped_rdata[j][i] = line_rdata[i][j];
            end
        end
        assign dirty_data = flipped_rdata[way_idx];
    end else begin
        assign dirty_byteen = '0;
        assign dirty_data = '0;
    end
    wire [(LINE_SIZE / WORD_SIZE)-1:0][NUM_WAYS-1:0][(8 * WORD_SIZE)-1:0] line_wdata;
    wire [BYTEENW-1:0] line_wren;
    if (WRITE_ENABLE != 0 || (NUM_WAYS > 1)) begin
        wire [(LINE_SIZE / WORD_SIZE)-1:0][NUM_WAYS-1:0][WORD_SIZE-1:0] wren_w;
        for (genvar i = 0; i < (LINE_SIZE / WORD_SIZE); ++i) begin
            for (genvar j = 0; j < NUM_WAYS; ++j) begin
                assign line_wdata[i][j] = (fill || !WRITE_ENABLE) ? fill_data[i] : write_data[i];
                assign wren_w[i][j] = ((fill || !WRITE_ENABLE) ? {WORD_SIZE{1'b1}} : write_byteen[i])
                                    & {WORD_SIZE{(way_sel[j] || (NUM_WAYS == 1))}};
            end
        end
        assign line_wren = wren_w;
    end else begin
        assign line_wdata = fill_data;
        assign line_wren  = fill;
    end
    VX_onehot_encoder #(
        .N (NUM_WAYS)
    ) way_enc (
        .data_in  (way_sel),
        .data_out (way_idx),
        . valid_out ()
    );
    wire line_read = (read && ~stall)
                  || (WRITEBACK && (fill || flush));
    wire line_write = write || fill;
    VX_sp_ram #(
        .DATAW ((8 * LINE_SIZE) * NUM_WAYS),
        .SIZE  (((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS))),
        .WRENW (BYTEENW),
        .NO_RWCHECK (1),
        .RW_ASSERT (1)
    ) data_store (
        .clk   (clk),
        .reset (reset),
        .read  (line_read),
        .write (line_write),
        .wren  (line_wren),
        .addr  (line_sel),
        .wdata (line_wdata),
        .rdata (line_rdata)
    );
    wire [NUM_WAYS-1:0][(8 * WORD_SIZE)-1:0] per_way_rdata;
    if ((LINE_SIZE / WORD_SIZE) > 1) begin
        assign per_way_rdata = line_rdata[wsel];
    end else begin
        assign per_way_rdata = line_rdata;
    end
    assign read_data = per_way_rdata[way_idx];
endmodule
