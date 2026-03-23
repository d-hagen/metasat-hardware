module VX_shared_mem import VX_gpu_pkg::*; #(
    parameter   INSTANCE_ID = "",
    parameter SIZE              = (1024*16*8), 
    parameter NUM_REQS          = 4, 
    parameter NUM_BANKS         = 4,
    parameter ADDR_WIDTH        = $clog2(SIZE),
    parameter WORD_SIZE         = 32/8,
    parameter UUID_WIDTH        = 0,
    parameter TAG_WIDTH         = 16
 ) (    
    input wire clk,
    input wire reset,
    input wire [NUM_REQS-1:0]                   req_valid,
    input wire [NUM_REQS-1:0]                   req_rw,
    input wire [NUM_REQS-1:0][ADDR_WIDTH-1:0]   req_addr,
    input wire [NUM_REQS-1:0][WORD_SIZE-1:0]    req_byteen,
    input wire [NUM_REQS-1:0][WORD_SIZE*8-1:0]  req_data,
    input wire [NUM_REQS-1:0][TAG_WIDTH-1:0]    req_tag,
    output wire [NUM_REQS-1:0]                  req_ready,
    output wire [NUM_REQS-1:0]                  rsp_valid,
    output wire [NUM_REQS-1:0][WORD_SIZE*8-1:0] rsp_data,
    output wire [NUM_REQS-1:0][TAG_WIDTH-1:0]   rsp_tag,
    input  wire [NUM_REQS-1:0]                  rsp_ready
);
    localparam REQ_SEL_BITS    = $clog2(NUM_REQS);
    localparam REQ_SEL_WIDTH   = (((REQ_SEL_BITS) != 0) ? (REQ_SEL_BITS) : 1);
    localparam WORD_WIDTH      = WORD_SIZE * 8;
    localparam NUM_WORDS       = SIZE / WORD_SIZE;
    localparam WORDS_PER_BANK  = NUM_WORDS / NUM_BANKS;
    localparam BANK_ADDR_WIDTH = $clog2(WORDS_PER_BANK);
    localparam BANK_SEL_BITS   = $clog2(NUM_BANKS);
    localparam BANK_SEL_WIDTH  = (((BANK_SEL_BITS) != 0) ? (BANK_SEL_BITS) : 1);
    localparam REQ_DATAW       = 1 + BANK_ADDR_WIDTH + WORD_SIZE + WORD_WIDTH + TAG_WIDTH;
    localparam RSP_DATAW       = WORD_WIDTH + TAG_WIDTH;
    wire [NUM_REQS-1:0][BANK_SEL_WIDTH-1:0] req_bank_idx;
    if (NUM_BANKS > 1) begin
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            assign req_bank_idx[i] = req_addr[i][0 +: BANK_SEL_BITS];
        end
    end else begin
        assign req_bank_idx = 0;
    end   
    wire [NUM_REQS-1:0][BANK_ADDR_WIDTH-1:0] req_bank_addr;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign req_bank_addr[i] = req_addr[i][BANK_SEL_BITS +: BANK_ADDR_WIDTH];
    end
    wire [NUM_BANKS-1:0]                    per_bank_req_valid;
    wire [NUM_BANKS-1:0]                    per_bank_req_rw;      
    wire [NUM_BANKS-1:0][BANK_ADDR_WIDTH-1:0] per_bank_req_addr;
    wire [NUM_BANKS-1:0][WORD_SIZE-1:0]     per_bank_req_byteen;
    wire [NUM_BANKS-1:0][WORD_WIDTH-1:0]    per_bank_req_data;
    wire [NUM_BANKS-1:0][TAG_WIDTH-1:0]     per_bank_req_tag;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0] per_bank_req_idx;
    wire [NUM_BANKS-1:0]                    per_bank_req_ready;
    wire [NUM_REQS-1:0][REQ_DATAW-1:0] req_data_in;    
    wire [NUM_BANKS-1:0][REQ_DATAW-1:0] req_data_out;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign req_data_in[i] = {
            req_rw[i],        
            req_bank_addr[i],
            req_byteen[i],
            req_data[i],
            req_tag[i]};
    end
    VX_stream_xbar #(
        .NUM_INPUTS  (NUM_REQS),
        .NUM_OUTPUTS (NUM_BANKS),
        .DATAW       (REQ_DATAW),
        .PERF_CTR_BITS (44),
        .OUT_REG     (3)  
    ) req_xbar (
        .clk       (clk),
        .reset     (reset),
        . collisions (),
        .valid_in  (req_valid),
        .data_in   (req_data_in),
        .sel_in    (req_bank_idx),
        .ready_in  (req_ready),
        .valid_out (per_bank_req_valid),
        .data_out  (req_data_out),
        .sel_out   (per_bank_req_idx),
        .ready_out (per_bank_req_ready)
    );
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign {
            per_bank_req_rw[i],        
            per_bank_req_addr[i],
            per_bank_req_byteen[i],        
            per_bank_req_data[i],        
            per_bank_req_tag[i]} = req_data_out[i];
    end
    wire [NUM_BANKS-1:0]                per_bank_rsp_valid;
    wire [NUM_BANKS-1:0][WORD_WIDTH-1:0] per_bank_rsp_data;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0] per_bank_rsp_idx; 
    wire [NUM_BANKS-1:0][TAG_WIDTH-1:0] per_bank_rsp_tag;   
    wire [NUM_BANKS-1:0]                per_bank_rsp_ready;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin        
        VX_sp_ram #(
            .DATAW (WORD_WIDTH),
            .SIZE  (WORDS_PER_BANK),
            .WRENW (WORD_SIZE)
        ) data_store (
            .clk   (clk),
            .read  (1'b1),
            .write (per_bank_req_valid[i] && per_bank_req_ready[i] && per_bank_req_rw[i]),
            .wren  (per_bank_req_byteen[i]),
            .addr  (per_bank_req_addr[i]),            
            .wdata (per_bank_req_data[i]),
            .rdata (per_bank_rsp_data[i])
        );
        wire per_bank_req_valid_w, per_bank_req_ready_w;
        assign per_bank_req_valid_w = per_bank_req_valid[i] && ~per_bank_req_rw[i];
        assign per_bank_req_ready[i] = per_bank_req_ready_w || per_bank_req_rw[i];
        VX_elastic_buffer #(
            .DATAW (REQ_SEL_WIDTH + TAG_WIDTH),
            .SIZE  (0)
        ) bank_buf (
            .clk       (clk),
            .reset     (reset),
            .valid_in  (per_bank_req_valid_w),
            .ready_in  (per_bank_req_ready_w),
            .data_in   ({per_bank_req_idx[i], per_bank_req_tag[i]}),
            .data_out  ({per_bank_rsp_idx[i], per_bank_rsp_tag[i]}),
            .valid_out (per_bank_rsp_valid[i]),
            .ready_out (per_bank_rsp_ready[i])
        );
    end
    wire [NUM_BANKS-1:0][RSP_DATAW-1:0] rsp_data_in;
    wire [NUM_REQS-1:0][RSP_DATAW-1:0] rsp_data_out;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign rsp_data_in[i] = {per_bank_rsp_data[i], per_bank_rsp_tag[i]};
    end
    VX_stream_xbar #(
        .NUM_INPUTS  (NUM_BANKS),
        .NUM_OUTPUTS (NUM_REQS),
        .DATAW       (RSP_DATAW),
        .OUT_REG     (2)
    ) rsp_xbar (
        .clk       (clk),
        .reset     (reset),
        . collisions (),
        .sel_in    (per_bank_rsp_idx),
        .valid_in  (per_bank_rsp_valid),
        .ready_in  (per_bank_rsp_ready),
        .data_in   (rsp_data_in),
        .data_out  (rsp_data_out),
        .valid_out (rsp_valid),
        .ready_out (rsp_ready),
        . sel_out ()
    );
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign {rsp_data[i], rsp_tag[i]} = rsp_data_out[i];
    end
endmodule
