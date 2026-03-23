module VX_cache_tags #(
    parameter  INSTANCE_ID = "",
    parameter BANK_ID       = 0,
    parameter CACHE_SIZE    = 1024, 
    parameter LINE_SIZE     = 16, 
    parameter NUM_BANKS     = 1, 
    parameter NUM_WAYS      = 1, 
    parameter WORD_SIZE     = 1, 
    parameter UUID_WIDTH    = 0
) (
    input wire                          clk,
    input wire                          reset,
    input wire [(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0]    req_uuid,
    input wire                          stall,
    input wire                          lookup,
    input wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] line_addr,
    input wire                          fill,    
    input wire                          init,
    output wire [NUM_WAYS-1:0]          way_sel,
    output wire [NUM_WAYS-1:0]          tag_matches
);
    localparam TAG_WIDTH = 1 + ((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1));
    wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0] line_sel = line_addr[$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0];
    wire [((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1))-1:0] line_tag = line_addr[((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1 : $clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))];
    if (NUM_WAYS > 1)  begin
        reg [NUM_WAYS-1:0] repl_way;
        always @(posedge clk) begin
            if (reset) begin
                repl_way <= 1;
            end else if (~stall) begin  
                repl_way <= {repl_way[NUM_WAYS-2:0], repl_way[NUM_WAYS-1]};
            end
        end        
        for (genvar i = 0; i < NUM_WAYS; ++i) begin
            assign way_sel[i] = fill && repl_way[i];
        end
    end else begin
        assign way_sel = fill;
    end
    for (genvar i = 0; i < NUM_WAYS; ++i) begin
        wire [((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1))-1:0] read_tag;
        wire read_valid;
        VX_sp_ram #(
            .DATAW (TAG_WIDTH),
            .SIZE  (((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS))),
            .NO_RWCHECK (1)
        ) tag_store (
            .clk   (clk),
            .read  (1'b1),
            .write (way_sel[i] || init),
            . wren (),                
            .addr  (line_sel),
            .wdata ({~init, line_tag}), 
            .rdata ({read_valid, read_tag})
        );
        assign tag_matches[i] = read_valid && (line_tag == read_tag);
    end
endmodule
