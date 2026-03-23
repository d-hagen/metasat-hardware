module VX_cache import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID    = "",
    parameter NUM_REQS              = 4,
    parameter CACHE_SIZE            = 4096, 
    parameter LINE_SIZE             = 64, 
    parameter NUM_BANKS             = 1,
    parameter NUM_WAYS              = 1,
    parameter WORD_SIZE             = 32/8,
    parameter CRSQ_SIZE             = 2,
    parameter MSHR_SIZE             = 8, 
    parameter MRSQ_SIZE             = 0,
    parameter MREQ_SIZE             = 4,
    parameter WRITE_ENABLE          = 1,
    parameter UUID_WIDTH            = 0,
    parameter TAG_WIDTH             = UUID_WIDTH + 1,
    parameter CORE_OUT_REG          = 0,
    parameter MEM_OUT_REG           = 0
 ) (    
    input wire clk,
    input wire reset,
    VX_mem_bus_if.slave     core_bus_if [NUM_REQS],
    VX_mem_bus_if.master    mem_bus_if
);
    localparam REQ_SEL_WIDTH   = ((($clog2(NUM_REQS)) != 0) ? ($clog2(NUM_REQS)) : 1);
    localparam WORD_SEL_WIDTH  = ((($clog2((LINE_SIZE / WORD_SIZE))) != 0) ? ($clog2((LINE_SIZE / WORD_SIZE))) : 1);
    localparam MSHR_ADDR_WIDTH = (((MSHR_SIZE) > 1) ? $clog2(MSHR_SIZE) : 1);
    localparam MEM_TAG_WIDTH   = MSHR_ADDR_WIDTH + $clog2(NUM_BANKS);
    localparam WORDS_PER_LINE  = LINE_SIZE / WORD_SIZE;
    localparam WORD_WIDTH      = WORD_SIZE * 8;
    localparam WORD_SEL_BITS   = $clog2(WORDS_PER_LINE);
    localparam BANK_SEL_BITS   = $clog2(NUM_BANKS);
    localparam BANK_SEL_WIDTH  = (((BANK_SEL_BITS) != 0) ? (BANK_SEL_BITS) : 1);
    localparam LINE_ADDR_WIDTH = ((32-$clog2(WORD_SIZE)) - BANK_SEL_BITS - WORD_SEL_BITS);
    localparam CORE_REQ_DATAW  = LINE_ADDR_WIDTH + 1 + WORD_SEL_WIDTH + WORD_SIZE + WORD_WIDTH + TAG_WIDTH;
    localparam CORE_RSP_DATAW  = WORD_WIDTH + TAG_WIDTH;
    localparam CORE_REQ_BUF_ENABLE = (NUM_BANKS != 1) || (NUM_REQS != 1);
    localparam MEM_REQ_BUF_ENABLE  = (NUM_BANKS != 1);
    wire [NUM_REQS-1:0]                     core_req_valid;
    wire [NUM_REQS-1:0][(32-$clog2(WORD_SIZE))-1:0] core_req_addr;
    wire [NUM_REQS-1:0]                     core_req_rw;    
    wire [NUM_REQS-1:0][WORD_SIZE-1:0]      core_req_byteen;
    wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_req_data;
    wire [NUM_REQS-1:0][TAG_WIDTH-1:0]      core_req_tag;
    wire [NUM_REQS-1:0]                     core_req_ready;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign core_req_valid[i]  = core_bus_if[i].req_valid;
        assign core_req_addr[i]   = core_bus_if[i].req_data.addr;
        assign core_req_rw[i]     = core_bus_if[i].req_data.rw;
        assign core_req_byteen[i] = core_bus_if[i].req_data.byteen;
        assign core_req_data[i]   = core_bus_if[i].req_data.data;
        assign core_req_tag[i]    = core_bus_if[i].req_data.tag;
        assign core_bus_if[i].req_ready = core_req_ready[i];
    end
    wire [NUM_REQS-1:0]                  core_rsp_valid_s;
    wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_rsp_data_s;
    wire [NUM_REQS-1:0][TAG_WIDTH-1:0]   core_rsp_tag_s;
    wire [NUM_REQS-1:0]                  core_rsp_ready_s;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
    wire [1-1:0] core_rsp_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __core_rsp_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (core_rsp_reset)                          
    );
        VX_elastic_buffer #(
            .DATAW   ((8 * WORD_SIZE) + TAG_WIDTH),
            .SIZE    (CORE_REQ_BUF_ENABLE ? (((CORE_OUT_REG) < (2)) ? (CORE_OUT_REG) : (2)) : 0),
            .OUT_REG (((CORE_OUT_REG & 1) + ((CORE_OUT_REG >> 2) << 1)))
        ) core_rsp_buf (
            .clk       (clk),
            .reset     (core_rsp_reset),
            .valid_in  (core_rsp_valid_s[i]),
            .ready_in  (core_rsp_ready_s[i]),
            .data_in   ({core_rsp_data_s[i], core_rsp_tag_s[i]}),
            .data_out  ({core_bus_if[i].rsp_data.data, core_bus_if[i].rsp_data.tag}), 
            .valid_out (core_bus_if[i].rsp_valid),
            .ready_out (core_bus_if[i].rsp_ready)
        );
    end
    wire                             mem_req_valid_s;
    wire [(32-$clog2(LINE_SIZE))-1:0]    mem_req_addr_s;
    wire                             mem_req_rw_s;
    wire [LINE_SIZE-1:0]             mem_req_byteen_s;
    wire [(8 * LINE_SIZE)-1:0]        mem_req_data_s;
    wire [MEM_TAG_WIDTH-1:0]         mem_req_tag_s;
    wire                             mem_req_ready_s;
    wire [1-1:0] mem_req_buf_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mem_req_buf_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mem_req_buf_reset)                          
    );
    VX_elastic_buffer #(
        .DATAW   (1 + LINE_SIZE + (32-$clog2(LINE_SIZE)) + (8 * LINE_SIZE) + MEM_TAG_WIDTH),
        .SIZE    (MEM_REQ_BUF_ENABLE ? (((MEM_OUT_REG) < (2)) ? (MEM_OUT_REG) : (2)) : 0),
        .OUT_REG (((MEM_OUT_REG & 1) + ((MEM_OUT_REG >> 2) << 1)))
    ) mem_req_buf (
        .clk       (clk),
        .reset     (mem_req_buf_reset),
        .valid_in  (mem_req_valid_s), 
        .ready_in  (mem_req_ready_s), 
        .data_in   ({mem_req_rw_s, mem_req_byteen_s, mem_req_addr_s, mem_req_data_s, mem_req_tag_s}),
        .data_out  ({mem_bus_if.req_data.rw, mem_bus_if.req_data.byteen, mem_bus_if.req_data.addr, mem_bus_if.req_data.data, mem_bus_if.req_data.tag}), 
        .valid_out (mem_bus_if.req_valid), 
        .ready_out (mem_bus_if.req_ready)
    );
    wire                         mem_rsp_valid_s;
    wire [(8 * LINE_SIZE)-1:0]    mem_rsp_data_s;
    wire [MEM_TAG_WIDTH-1:0]     mem_rsp_tag_s;
    wire                         mem_rsp_ready_s;
    wire [1-1:0] mem_rsp_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mem_rsp_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mem_rsp_reset)                          
    );
    VX_elastic_buffer #(
        .DATAW   (MEM_TAG_WIDTH + (8 * LINE_SIZE)), 
        .SIZE    (MRSQ_SIZE),
        .OUT_REG (MRSQ_SIZE > 2)
    ) mem_rsp_queue (
        .clk        (clk),
        .reset      (mem_rsp_reset),
        .valid_in   (mem_bus_if.rsp_valid),
        .ready_in   (mem_bus_if.rsp_ready),
        .data_in    ({mem_bus_if.rsp_data.tag, mem_bus_if.rsp_data.data}), 
        .data_out   ({mem_rsp_tag_s, mem_rsp_data_s}), 
        .valid_out  (mem_rsp_valid_s),
        .ready_out  (mem_rsp_ready_s)
    );
    wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0] init_line_sel;
    wire init_enable;
    wire [1-1:0] init_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __init_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (init_reset)                          
    );
    VX_cache_init #( 
        .CACHE_SIZE (CACHE_SIZE),
        .LINE_SIZE  (LINE_SIZE), 
        .NUM_BANKS  (NUM_BANKS),
        .NUM_WAYS   (NUM_WAYS)
    ) cache_init (
        .clk       (clk),
        .reset     (init_reset),
        .addr_out  (init_line_sel),
        .valid_out (init_enable)
    );
    wire [NUM_BANKS-1:0]                        per_bank_core_req_valid;
    wire [NUM_BANKS-1:0][((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] per_bank_core_req_addr;
    wire [NUM_BANKS-1:0]                        per_bank_core_req_rw;
    wire [NUM_BANKS-1:0][WORD_SEL_WIDTH-1:0]    per_bank_core_req_wsel;
    wire [NUM_BANKS-1:0][WORD_SIZE-1:0]         per_bank_core_req_byteen;
    wire [NUM_BANKS-1:0][(8 * WORD_SIZE)-1:0]    per_bank_core_req_data;
    wire [NUM_BANKS-1:0][TAG_WIDTH-1:0]         per_bank_core_req_tag;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0]     per_bank_core_req_idx;
    wire [NUM_BANKS-1:0]                        per_bank_core_req_ready;
    wire [NUM_BANKS-1:0]                        per_bank_core_rsp_valid;
    wire [NUM_BANKS-1:0][(8 * WORD_SIZE)-1:0]    per_bank_core_rsp_data;
    wire [NUM_BANKS-1:0][TAG_WIDTH-1:0]         per_bank_core_rsp_tag;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0]     per_bank_core_rsp_idx;
    wire [NUM_BANKS-1:0]                        per_bank_core_rsp_ready;
    wire [NUM_BANKS-1:0]                        per_bank_mem_req_valid;    
    wire [NUM_BANKS-1:0][(32-$clog2(LINE_SIZE))-1:0] per_bank_mem_req_addr;
    wire [NUM_BANKS-1:0]                        per_bank_mem_req_rw;
    wire [NUM_BANKS-1:0][WORD_SEL_WIDTH-1:0]    per_bank_mem_req_wsel;
    wire [NUM_BANKS-1:0][WORD_SIZE-1:0]         per_bank_mem_req_byteen;
    wire [NUM_BANKS-1:0][(8 * WORD_SIZE)-1:0]    per_bank_mem_req_data;
    wire [NUM_BANKS-1:0][MSHR_ADDR_WIDTH-1:0]   per_bank_mem_req_id;
    wire [NUM_BANKS-1:0]                        per_bank_mem_req_ready;
    wire [NUM_BANKS-1:0]                        per_bank_mem_rsp_ready;
    if (NUM_BANKS == 1) begin
        assign mem_rsp_ready_s = per_bank_mem_rsp_ready;
    end else begin
        assign mem_rsp_ready_s = per_bank_mem_rsp_ready[mem_rsp_tag_s[MSHR_ADDR_WIDTH +: $clog2(NUM_BANKS)]];
    end
    wire [NUM_REQS-1:0][CORE_REQ_DATAW-1:0]  core_req_data_in;    
    wire [NUM_BANKS-1:0][CORE_REQ_DATAW-1:0] core_req_data_out;
    wire [NUM_REQS-1:0][LINE_ADDR_WIDTH-1:0] core_req_line_addr;
    wire [NUM_REQS-1:0][BANK_SEL_WIDTH-1:0]  core_req_bid;
    wire [NUM_REQS-1:0][WORD_SEL_WIDTH-1:0]  core_req_wsel;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        if (WORDS_PER_LINE > 1) begin
            assign core_req_wsel[i] = core_req_addr[i][0 +: WORD_SEL_BITS];
        end else begin
            assign core_req_wsel[i] = '0;
        end
        assign core_req_line_addr[i] = core_req_addr[i][(BANK_SEL_BITS + WORD_SEL_BITS) +: LINE_ADDR_WIDTH];
    end
    if (NUM_BANKS > 1) begin
        for (genvar i = 0; i < NUM_REQS; ++i) begin
            assign core_req_bid[i] = core_req_addr[i][WORD_SEL_BITS +: BANK_SEL_BITS];
        end
    end else begin
        assign core_req_bid = '0;
    end
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign core_req_data_in[i] = {
            core_req_line_addr[i],
            core_req_rw[i],
            core_req_wsel[i],
            core_req_byteen[i],            
            core_req_data[i],
            core_req_tag[i]};
    end
    wire [1-1:0] req_xbar_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __req_xbar_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (req_xbar_reset)                          
    );
     VX_stream_xbar #(
        .NUM_INPUTS  (NUM_REQS),
        .NUM_OUTPUTS (NUM_BANKS),
        .DATAW       (CORE_REQ_DATAW),
        .PERF_CTR_BITS (44)
    ) req_xbar (
        .clk       (clk),
        .reset     (req_xbar_reset),
        . collisions (),
        .valid_in  (core_req_valid),
        .data_in   (core_req_data_in),
        .sel_in    (core_req_bid),
        .ready_in  (core_req_ready),
        .valid_out (per_bank_core_req_valid),
        .data_out  (core_req_data_out),
        .sel_out   (per_bank_core_req_idx),
        .ready_out (per_bank_core_req_ready)
    );
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign {
            per_bank_core_req_addr[i],
            per_bank_core_req_rw[i],
            per_bank_core_req_wsel[i],
            per_bank_core_req_byteen[i],            
            per_bank_core_req_data[i],
            per_bank_core_req_tag[i]} = core_req_data_out[i];
    end
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] curr_bank_mem_req_addr;
        wire curr_bank_mem_rsp_valid;
        if (NUM_BANKS == 1) begin
            assign curr_bank_mem_rsp_valid = mem_rsp_valid_s;
        end else begin
            assign curr_bank_mem_rsp_valid = mem_rsp_valid_s && (mem_rsp_tag_s[MSHR_ADDR_WIDTH +: $clog2(NUM_BANKS)] == i);
        end
    wire [1-1:0] bank_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __bank_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (bank_reset)                          
    );
        VX_cache_bank #(                
            .BANK_ID      (i),
            .INSTANCE_ID  (INSTANCE_ID),
            .CACHE_SIZE   (CACHE_SIZE),
            .LINE_SIZE    (LINE_SIZE),
            .NUM_BANKS    (NUM_BANKS),
            .NUM_WAYS     (NUM_WAYS),
            .WORD_SIZE    (WORD_SIZE),
            .NUM_REQS     (NUM_REQS),
            .CRSQ_SIZE    (CRSQ_SIZE),
            .MSHR_SIZE    (MSHR_SIZE),
            .MREQ_SIZE    (MREQ_SIZE),
            .WRITE_ENABLE (WRITE_ENABLE),
            .UUID_WIDTH   (UUID_WIDTH),
            .TAG_WIDTH    (TAG_WIDTH),
            .CORE_OUT_REG (CORE_REQ_BUF_ENABLE ? 0 : CORE_OUT_REG),
            .MEM_OUT_REG  (MEM_REQ_BUF_ENABLE ? 0 : MEM_OUT_REG)
        ) bank (          
            .clk                (clk),
            .reset              (bank_reset),
            .core_req_valid     (per_bank_core_req_valid[i]),
            .core_req_addr      (per_bank_core_req_addr[i]),
            .core_req_rw        (per_bank_core_req_rw[i]),
            .core_req_wsel      (per_bank_core_req_wsel[i]),
            .core_req_byteen    (per_bank_core_req_byteen[i]),
            .core_req_data      (per_bank_core_req_data[i]),
            .core_req_tag       (per_bank_core_req_tag[i]),
            .core_req_idx       (per_bank_core_req_idx[i]),
            .core_req_ready     (per_bank_core_req_ready[i]),
            .core_rsp_valid     (per_bank_core_rsp_valid[i]),
            .core_rsp_data      (per_bank_core_rsp_data[i]),
            .core_rsp_tag       (per_bank_core_rsp_tag[i]),
            .core_rsp_idx       (per_bank_core_rsp_idx[i]),
            .core_rsp_ready     (per_bank_core_rsp_ready[i]),
            .mem_req_valid      (per_bank_mem_req_valid[i]),
            .mem_req_addr       (curr_bank_mem_req_addr),
            .mem_req_rw         (per_bank_mem_req_rw[i]),
            .mem_req_wsel       (per_bank_mem_req_wsel[i]),
            .mem_req_byteen     (per_bank_mem_req_byteen[i]),
            .mem_req_data       (per_bank_mem_req_data[i]),
            .mem_req_id         (per_bank_mem_req_id[i]),
            .mem_req_ready      (per_bank_mem_req_ready[i]),
            .mem_rsp_valid      (curr_bank_mem_rsp_valid),
            .mem_rsp_data       (mem_rsp_data_s),
            .mem_rsp_id         (mem_rsp_tag_s[MSHR_ADDR_WIDTH-1:0]),
            .mem_rsp_ready      (per_bank_mem_rsp_ready[i]),
            .init_enable        (init_enable),
            .init_line_sel      (init_line_sel)
        );
        if (NUM_BANKS == 1) begin
            assign per_bank_mem_req_addr[i] = curr_bank_mem_req_addr;
        end else begin
            assign per_bank_mem_req_addr[i] = {curr_bank_mem_req_addr, $clog2(NUM_BANKS)'(i)};
        end
    end   
    wire [NUM_BANKS-1:0][CORE_RSP_DATAW-1:0] core_rsp_data_in;
    wire [NUM_REQS-1:0][CORE_RSP_DATAW-1:0]  core_rsp_data_out;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign core_rsp_data_in[i] = {per_bank_core_rsp_data[i], per_bank_core_rsp_tag[i]};
    end
    wire [1-1:0] rsp_xbar_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __rsp_xbar_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (rsp_xbar_reset)                          
    );
    VX_stream_xbar #(
        .NUM_INPUTS  (NUM_BANKS),
        .NUM_OUTPUTS (NUM_REQS),
        .DATAW       (CORE_RSP_DATAW)
    ) rsp_xbar (
        .clk       (clk),
        .reset     (rsp_xbar_reset),
        . collisions (),
        .valid_in  (per_bank_core_rsp_valid),
        .data_in   (core_rsp_data_in),
        .sel_in    (per_bank_core_rsp_idx),
        .ready_in  (per_bank_core_rsp_ready),
        .valid_out (core_rsp_valid_s),
        .data_out  (core_rsp_data_out),
        .ready_out (core_rsp_ready_s),
        . sel_out ()
    );
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign {core_rsp_data_s[i], core_rsp_tag_s[i]} = core_rsp_data_out[i];
    end
    wire                        mem_req_valid_p;
    wire [(32-$clog2(LINE_SIZE))-1:0] mem_req_addr_p;
    wire                        mem_req_rw_p;
    wire [WORD_SEL_WIDTH-1:0]   mem_req_wsel_p;
    wire [WORD_SIZE-1:0]        mem_req_byteen_p;
    wire [(8 * WORD_SIZE)-1:0]   mem_req_data_p;
    wire [MEM_TAG_WIDTH-1:0]    mem_req_tag_p;
    wire [MSHR_ADDR_WIDTH-1:0]  mem_req_id_p;
    wire                        mem_req_ready_p;
    wire [NUM_BANKS-1:0][((32-$clog2(LINE_SIZE)) + MSHR_ADDR_WIDTH + 1 + WORD_SIZE + WORD_SEL_WIDTH + (8 * WORD_SIZE))-1:0] data_in;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign data_in[i] = {per_bank_mem_req_addr[i],
                             per_bank_mem_req_rw[i],
                             per_bank_mem_req_wsel[i], 
                             per_bank_mem_req_byteen[i],                              
                             per_bank_mem_req_data[i],
                             per_bank_mem_req_id[i]};
    end
    wire [1-1:0] mem_req_arb_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mem_req_arb_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mem_req_arb_reset)                          
    );
    VX_stream_arb #(
        .NUM_INPUTS (NUM_BANKS),
        .DATAW      ((32-$clog2(LINE_SIZE)) + 1  + WORD_SEL_WIDTH + WORD_SIZE + (8 * WORD_SIZE) + MSHR_ADDR_WIDTH),
        .ARBITER    ("R")
    ) mem_req_arb (
        .clk       (clk),
        .reset     (mem_req_arb_reset),
        .valid_in  (per_bank_mem_req_valid),
        .ready_in  (per_bank_mem_req_ready),
        .data_in   (data_in),
        .data_out  ({mem_req_addr_p, mem_req_rw_p, mem_req_wsel_p, mem_req_byteen_p, mem_req_data_p, mem_req_id_p}),
        .valid_out (mem_req_valid_p),
        .ready_out (mem_req_ready_p),
        . sel_out ()
    );
    if (NUM_BANKS > 1) begin
        wire [$clog2(NUM_BANKS)-1:0] mem_req_bank_id = mem_req_addr_p[0 +: $clog2(NUM_BANKS)];
        assign mem_req_tag_p = MEM_TAG_WIDTH'({mem_req_bank_id, mem_req_id_p});            
    end else begin
        assign mem_req_tag_p = MEM_TAG_WIDTH'(mem_req_id_p);
    end   
    assign mem_req_valid_s = mem_req_valid_p;
    assign mem_req_addr_s  = mem_req_addr_p;
    assign mem_req_tag_s   = mem_req_tag_p;
    assign mem_req_ready_p = mem_req_ready_s;
    if (WRITE_ENABLE != 0) begin
        if ((LINE_SIZE / WORD_SIZE) > 1) begin
            reg [LINE_SIZE-1:0]      mem_req_byteen_r;
            reg [(8 * LINE_SIZE)-1:0] mem_req_data_r;
            always @(*) begin
                mem_req_byteen_r = '0;
                mem_req_data_r   = 'x;
                mem_req_byteen_r[mem_req_wsel_p * WORD_SIZE +: WORD_SIZE] = mem_req_byteen_p;
                mem_req_data_r[mem_req_wsel_p * (8 * WORD_SIZE) +: (8 * WORD_SIZE)] = mem_req_data_p;
            end            
            assign mem_req_rw_s     = mem_req_rw_p;
            assign mem_req_byteen_s = mem_req_byteen_r;
            assign mem_req_data_s   = mem_req_data_r;
        end else begin
            assign mem_req_rw_s     = mem_req_rw_p;
            assign mem_req_byteen_s = mem_req_byteen_p;            
            assign mem_req_data_s   = mem_req_data_p;            
        end
    end else begin
        assign mem_req_rw_s     = 0;
        assign mem_req_byteen_s = {LINE_SIZE{1'b1}};
        assign mem_req_data_s   = '0;
    end
endmodule
