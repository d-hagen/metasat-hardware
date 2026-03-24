module VX_cache_tags #(
    parameter  INSTANCE_ID = "",
    parameter BANK_ID       = 0,
    parameter CACHE_SIZE    = 1024,
    parameter LINE_SIZE     = 16,
    parameter NUM_BANKS     = 1,
    parameter NUM_WAYS      = 1,
    parameter WORD_SIZE     = 1,
    parameter WRITEBACK     = 0,
    parameter UUID_WIDTH    = 0
) (
    input wire                          clk,
    input wire                          reset,
    input wire [(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0]    req_uuid,
    input wire                          stall,
    input wire                          init,
    input wire                          flush,
    input wire                          fill,
    input wire                          write,
    input wire                          lookup,
    input wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] line_addr,
    input wire [NUM_WAYS-1:0]           way_sel,
    output wire [NUM_WAYS-1:0]          tag_matches,
    output wire                         evict_dirty,
    output wire [NUM_WAYS-1:0]          evict_way,
    output wire [((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1))-1:0]  evict_tag
);
    localparam TAG_WIDTH = 1 +  WRITEBACK + ((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1));
    wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0] line_sel = line_addr[$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0];
    wire [((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1))-1:0] line_tag = line_addr[((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1 : $clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))];
    wire [NUM_WAYS-1:0][((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1))-1:0] read_tag;
    wire [NUM_WAYS-1:0] read_valid;
    wire [NUM_WAYS-1:0] read_dirty;
    if (NUM_WAYS > 1)  begin
        reg [NUM_WAYS-1:0] evict_way_r;
        always @(posedge clk) begin
            if (reset) begin
                evict_way_r <= 1;
            end else if (~stall) begin  
                evict_way_r <= {evict_way_r[NUM_WAYS-2:0], evict_way_r[NUM_WAYS-1]};
            end
        end
        assign evict_way = fill ? evict_way_r : way_sel;
        VX_onehot_mux #(
            .DATAW (((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1))),
            .N     (NUM_WAYS)
        ) evict_tag_sel (
            .data_in  (read_tag),
            .sel_in   (evict_way),
            .data_out (evict_tag)
        );
    end else begin
        assign evict_way = 1'b1;
        assign evict_tag = read_tag;
    end
    wire fill_s = fill && (!WRITEBACK || ~stall);
    wire flush_s = flush && (!WRITEBACK || ~stall);
    for (genvar i = 0; i < NUM_WAYS; ++i) begin
        wire do_fill    = fill_s  && evict_way[i];
        wire do_flush   = flush_s && (!WRITEBACK || way_sel[i]);  
        wire do_write   = WRITEBACK && write && tag_matches[i];
        wire line_read  = (WRITEBACK && (fill_s || flush_s));
        wire line_write = init || do_fill || do_flush || do_write;
        wire line_valid = ~(init || flush);
        wire [TAG_WIDTH-1:0] line_wdata;
        wire [TAG_WIDTH-1:0] line_rdata;
        if (WRITEBACK) begin
            assign line_wdata = {line_valid, write, line_tag};
            assign {read_valid[i], read_dirty[i], read_tag[i]} = line_rdata;
        end else begin
            assign line_wdata = {line_valid, line_tag};
            assign {read_valid[i], read_tag[i]} = line_rdata;
            assign read_dirty[i] = 1'b0;
        end
        VX_sp_ram #(
            .DATAW (TAG_WIDTH),
            .SIZE  (((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS))),
            .NO_RWCHECK (1),
            .RW_ASSERT (1)
        ) tag_store (
            .clk   (clk),
            .reset (reset),
            .read  (line_read),
            .write (line_write),
            .wren  (1'b1),
            .addr  (line_sel),
            .wdata (line_wdata),
            .rdata (line_rdata)
        );
    end
    for (genvar i = 0; i < NUM_WAYS; ++i) begin
        assign tag_matches[i] = read_valid[i] && (line_tag == read_tag[i]);
    end
    assign evict_dirty = | (read_dirty & evict_way);
endmodule
