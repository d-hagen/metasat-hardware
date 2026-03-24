module VX_cache import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID   = "",
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
    parameter WRITEBACK             = 0,
    parameter DIRTY_BYTES           = 0,
    parameter UUID_WIDTH            = 0,
    parameter TAG_WIDTH             = UUID_WIDTH + 1,
    parameter CORE_OUT_BUF          = 0,
    parameter MEM_OUT_BUF           = 0
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
    localparam CORE_REQ_DATAW  = LINE_ADDR_WIDTH + 1 + WORD_SEL_WIDTH + WORD_SIZE + WORD_WIDTH + TAG_WIDTH + 1;
    localparam CORE_RSP_DATAW  = WORD_WIDTH + TAG_WIDTH;
    localparam CORE_REQ_BUF_ENABLE = (NUM_BANKS != 1) || (NUM_REQS != 1);
    localparam MEM_REQ_BUF_ENABLE  = (NUM_BANKS != 1);
    localparam REQ_XBAR_BUF = (NUM_REQS > 4) ? 2 : 0;
    VX_mem_bus_if #(
        .DATA_SIZE (WORD_SIZE),
        .TAG_WIDTH (TAG_WIDTH)
    ) core_bus2_if[NUM_REQS]();
    wire [NUM_BANKS-1:0] per_bank_flush_begin;
    wire [NUM_BANKS-1:0] per_bank_flush_end;
    wire [NUM_BANKS-1:0] per_bank_core_req_fire;
    VX_cache_flush #(
        .NUM_REQS  (NUM_REQS),
        .NUM_BANKS (NUM_BANKS),
        .BANK_SEL_LATENCY (((REQ_XBAR_BUF < 2) ? REQ_XBAR_BUF : (REQ_XBAR_BUF - 2)))  
    ) flush_unit (
        .clk             (clk),
        .reset           (reset),
        .core_bus_in_if  (core_bus_if),
        .core_bus_out_if (core_bus2_if),
        .bank_req_fire   (per_bank_core_req_fire),
        .flush_begin     (per_bank_flush_begin),
        .flush_end       (per_bank_flush_end)
    );
    wire [NUM_REQS-1:0]                  core_rsp_valid_s;
    wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0] core_rsp_data_s;
    wire [NUM_REQS-1:0][TAG_WIDTH-1:0]   core_rsp_tag_s;
    wire [NUM_REQS-1:0]                  core_rsp_ready_s;
    wire [NUM_REQS-1:0] core_rsp_reset;                        
    VX_reset_relay #(.N(NUM_REQS), .MAX_FANOUT(8)) __core_rsp_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (core_rsp_reset)                          
    );
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        VX_elastic_buffer #(
            .DATAW   ((8 * WORD_SIZE) + TAG_WIDTH),
            .SIZE    (CORE_REQ_BUF_ENABLE ? (((CORE_OUT_BUF) < (2)) ? (CORE_OUT_BUF) : (2)) : 0),
            .OUT_REG (((CORE_OUT_BUF < 2) ? CORE_OUT_BUF : (CORE_OUT_BUF - 2)))
        ) core_rsp_buf (
            .clk       (clk),
            .reset     (core_rsp_reset[i]),
            .valid_in  (core_rsp_valid_s[i]),
            .ready_in  (core_rsp_ready_s[i]),
            .data_in   ({core_rsp_data_s[i], core_rsp_tag_s[i]}),
            .data_out  ({core_bus2_if[i].rsp_data.data, core_bus2_if[i].rsp_data.tag}),
            .valid_out (core_bus2_if[i].rsp_valid),
            .ready_out (core_bus2_if[i].rsp_ready)
        );
    end
    wire                             mem_req_valid_s;
    wire [(32-$clog2(LINE_SIZE))-1:0]    mem_req_addr_s;
    wire                             mem_req_rw_s;
    wire [LINE_SIZE-1:0]             mem_req_byteen_s;
    wire [(8 * LINE_SIZE)-1:0]        mem_req_data_s;
    wire [MEM_TAG_WIDTH-1:0]         mem_req_tag_s;
    wire                             mem_req_flush_s;
    wire                             mem_req_ready_s;
    wire                             mem_bus_if_flush;
    VX_elastic_buffer #(
        .DATAW   (1 + LINE_SIZE + (32-$clog2(LINE_SIZE)) + (8 * LINE_SIZE) + MEM_TAG_WIDTH + 1),
        .SIZE    (MEM_REQ_BUF_ENABLE ? (((MEM_OUT_BUF) < (2)) ? (MEM_OUT_BUF) : (2)) : 0),
        .OUT_REG (((MEM_OUT_BUF < 2) ? MEM_OUT_BUF : (MEM_OUT_BUF - 2)))
    ) mem_req_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (mem_req_valid_s),
        .ready_in  (mem_req_ready_s),
        .data_in   ({mem_req_rw_s, mem_req_byteen_s, mem_req_addr_s, mem_req_data_s, mem_req_tag_s, mem_req_flush_s}),
        .data_out  ({mem_bus_if.req_data.rw, mem_bus_if.req_data.byteen, mem_bus_if.req_data.addr, mem_bus_if.req_data.data, mem_bus_if.req_data.tag, mem_bus_if_flush}),
        .valid_out (mem_bus_if.req_valid),
        .ready_out (mem_bus_if.req_ready)
    );
    assign mem_bus_if.req_data.atype = mem_bus_if_flush ? (2 + 1)'(1 << 0) : '0;
    wire                         mem_rsp_valid_s;
    wire [(8 * LINE_SIZE)-1:0]    mem_rsp_data_s;
    wire [MEM_TAG_WIDTH-1:0]     mem_rsp_tag_s;
    wire                         mem_rsp_ready_s;
    VX_elastic_buffer #(
        .DATAW   (MEM_TAG_WIDTH + (8 * LINE_SIZE)),
        .SIZE    (MRSQ_SIZE),
        .OUT_REG (MRSQ_SIZE > 2)
    ) mem_rsp_queue (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (mem_bus_if.rsp_valid),
        .ready_in   (mem_bus_if.rsp_ready),
        .data_in    ({mem_bus_if.rsp_data.tag, mem_bus_if.rsp_data.data}),
        .data_out   ({mem_rsp_tag_s, mem_rsp_data_s}),
        .valid_out  (mem_rsp_valid_s),
        .ready_out  (mem_rsp_ready_s)
    );
    wire [NUM_BANKS-1:0]                        per_bank_core_req_valid;
    wire [NUM_BANKS-1:0][((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] per_bank_core_req_addr;
    wire [NUM_BANKS-1:0]                        per_bank_core_req_rw;
    wire [NUM_BANKS-1:0][WORD_SEL_WIDTH-1:0]    per_bank_core_req_wsel;
    wire [NUM_BANKS-1:0][WORD_SIZE-1:0]         per_bank_core_req_byteen;
    wire [NUM_BANKS-1:0][(8 * WORD_SIZE)-1:0]    per_bank_core_req_data;
    wire [NUM_BANKS-1:0][TAG_WIDTH-1:0]         per_bank_core_req_tag;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0]     per_bank_core_req_idx;
    wire [NUM_BANKS-1:0]                        per_bank_core_req_flush;
    wire [NUM_BANKS-1:0]                        per_bank_core_req_ready;
    wire [NUM_BANKS-1:0]                        per_bank_core_rsp_valid;
    wire [NUM_BANKS-1:0][(8 * WORD_SIZE)-1:0]    per_bank_core_rsp_data;
    wire [NUM_BANKS-1:0][TAG_WIDTH-1:0]         per_bank_core_rsp_tag;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0]     per_bank_core_rsp_idx;
    wire [NUM_BANKS-1:0]                        per_bank_core_rsp_ready;
    wire [NUM_BANKS-1:0]                        per_bank_mem_req_valid;
    wire [NUM_BANKS-1:0][(32-$clog2(LINE_SIZE))-1:0] per_bank_mem_req_addr;
    wire [NUM_BANKS-1:0]                        per_bank_mem_req_rw;
    wire [NUM_BANKS-1:0][LINE_SIZE-1:0]         per_bank_mem_req_byteen;
    wire [NUM_BANKS-1:0][(8 * LINE_SIZE)-1:0]    per_bank_mem_req_data;
    wire [NUM_BANKS-1:0][MSHR_ADDR_WIDTH-1:0]   per_bank_mem_req_id;
    wire [NUM_BANKS-1:0]                        per_bank_mem_req_flush;
    wire [NUM_BANKS-1:0]                        per_bank_mem_req_ready;
    wire [NUM_BANKS-1:0]                        per_bank_mem_rsp_ready;
    assign per_bank_core_req_fire = per_bank_core_req_valid & per_bank_mem_req_ready;
    if (NUM_BANKS == 1) begin
        assign mem_rsp_ready_s = per_bank_mem_rsp_ready;
    end else begin
        assign mem_rsp_ready_s = per_bank_mem_rsp_ready[mem_rsp_tag_s[MSHR_ADDR_WIDTH +: $clog2(NUM_BANKS)]];
    end
    wire [NUM_REQS-1:0]                      core_req_valid;
    wire [NUM_REQS-1:0][(32-$clog2(WORD_SIZE))-1:0] core_req_addr;
    wire [NUM_REQS-1:0]                      core_req_rw;
    wire [NUM_REQS-1:0][WORD_SIZE-1:0]       core_req_byteen;
    wire [NUM_REQS-1:0][(8 * WORD_SIZE)-1:0]  core_req_data;
    wire [NUM_REQS-1:0][TAG_WIDTH-1:0]       core_req_tag;
    wire [NUM_REQS-1:0]                      core_req_flush;
    wire [NUM_REQS-1:0]                      core_req_ready;
    wire [NUM_REQS-1:0][LINE_ADDR_WIDTH-1:0] core_req_line_addr;
    wire [NUM_REQS-1:0][BANK_SEL_WIDTH-1:0]  core_req_bid;
    wire [NUM_REQS-1:0][WORD_SEL_WIDTH-1:0]  core_req_wsel;
    wire [NUM_REQS-1:0][CORE_REQ_DATAW-1:0]  core_req_data_in;
    wire [NUM_BANKS-1:0][CORE_REQ_DATAW-1:0] core_req_data_out;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign core_req_valid[i]  = core_bus2_if[i].req_valid;
        assign core_req_rw[i]     = core_bus2_if[i].req_data.rw;
        assign core_req_byteen[i] = core_bus2_if[i].req_data.byteen;
        assign core_req_addr[i]   = core_bus2_if[i].req_data.addr;
        assign core_req_data[i]   = core_bus2_if[i].req_data.data;
        assign core_req_tag[i]    = core_bus2_if[i].req_data.tag;
        assign core_req_flush[i]  = core_bus2_if[i].req_data.atype[0];
        assign core_bus2_if[i].req_ready = core_req_ready[i];
    end
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
            core_req_tag[i],
            core_req_flush[i]
        };
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
        .PERF_CTR_BITS (44),
        .ARBITER     ("F"),
        .OUT_BUF     (REQ_XBAR_BUF)
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
            per_bank_core_req_tag[i],
            per_bank_core_req_flush[i]
        } = core_req_data_out[i];
    end
    for (genvar bank_id = 0; bank_id < NUM_BANKS; ++bank_id) begin : banks
        wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] curr_bank_mem_req_addr;
        wire curr_bank_mem_rsp_valid;
        if (NUM_BANKS == 1) begin
            assign curr_bank_mem_rsp_valid = mem_rsp_valid_s;
        end else begin
            assign curr_bank_mem_rsp_valid = mem_rsp_valid_s && (mem_rsp_tag_s[MSHR_ADDR_WIDTH +: $clog2(NUM_BANKS)] == bank_id);
        end
    wire [1-1:0] bank_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __bank_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (bank_reset)                          
    );
        VX_cache_bank #(
            .BANK_ID      (bank_id),
            .INSTANCE_ID  ($sformatf("%s-bank%0d", INSTANCE_ID, bank_id)),
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
            .DIRTY_BYTES  (DIRTY_BYTES),
            .WRITEBACK    (WRITEBACK),
            .UUID_WIDTH   (UUID_WIDTH),
            .TAG_WIDTH    (TAG_WIDTH),
            .CORE_OUT_BUF (CORE_REQ_BUF_ENABLE ? 0 : CORE_OUT_BUF),
            .MEM_OUT_BUF  (MEM_REQ_BUF_ENABLE ? 0 : MEM_OUT_BUF)
        ) bank (
            .clk                (clk),
            .reset              (bank_reset),
            .core_req_valid     (per_bank_core_req_valid[bank_id]),
            .core_req_addr      (per_bank_core_req_addr[bank_id]),
            .core_req_rw        (per_bank_core_req_rw[bank_id]),
            .core_req_wsel      (per_bank_core_req_wsel[bank_id]),
            .core_req_byteen    (per_bank_core_req_byteen[bank_id]),
            .core_req_data      (per_bank_core_req_data[bank_id]),
            .core_req_tag       (per_bank_core_req_tag[bank_id]),
            .core_req_idx       (per_bank_core_req_idx[bank_id]),
            .core_req_flush     (per_bank_core_req_flush[bank_id]),
            .core_req_ready     (per_bank_core_req_ready[bank_id]),
            .core_rsp_valid     (per_bank_core_rsp_valid[bank_id]),
            .core_rsp_data      (per_bank_core_rsp_data[bank_id]),
            .core_rsp_tag       (per_bank_core_rsp_tag[bank_id]),
            .core_rsp_idx       (per_bank_core_rsp_idx[bank_id]),
            .core_rsp_ready     (per_bank_core_rsp_ready[bank_id]),
            .mem_req_valid      (per_bank_mem_req_valid[bank_id]),
            .mem_req_addr       (curr_bank_mem_req_addr),
            .mem_req_rw         (per_bank_mem_req_rw[bank_id]),
            .mem_req_byteen     (per_bank_mem_req_byteen[bank_id]),
            .mem_req_data       (per_bank_mem_req_data[bank_id]),
            .mem_req_id         (per_bank_mem_req_id[bank_id]),
            .mem_req_flush      (per_bank_mem_req_flush[bank_id]),
            .mem_req_ready      (per_bank_mem_req_ready[bank_id]),
            .mem_rsp_valid      (curr_bank_mem_rsp_valid),
            .mem_rsp_data       (mem_rsp_data_s),
            .mem_rsp_id         (mem_rsp_tag_s[MSHR_ADDR_WIDTH-1:0]),
            .mem_rsp_ready      (per_bank_mem_rsp_ready[bank_id]),
            .flush_begin        (per_bank_flush_begin[bank_id]),
            .flush_end          (per_bank_flush_end[bank_id])
        );
        if (NUM_BANKS == 1) begin
            assign per_bank_mem_req_addr[bank_id] = curr_bank_mem_req_addr;
        end else begin
            assign per_bank_mem_req_addr[bank_id] = {curr_bank_mem_req_addr, $clog2(NUM_BANKS)'(bank_id)};
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
        .DATAW       (CORE_RSP_DATAW),
        .ARBITER     ("F")
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
    wire [LINE_SIZE-1:0]        mem_req_byteen_p;
    wire [(8 * LINE_SIZE)-1:0]   mem_req_data_p;
    wire [MEM_TAG_WIDTH-1:0]    mem_req_tag_p;
    wire [MSHR_ADDR_WIDTH-1:0]  mem_req_id_p;
    wire                        mem_req_flush_p;
    wire                        mem_req_ready_p;
    wire [NUM_BANKS-1:0][((32-$clog2(LINE_SIZE)) + MSHR_ADDR_WIDTH + 1 + LINE_SIZE + (8 * LINE_SIZE) + 1)-1:0] data_in;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign data_in[i] = {
            per_bank_mem_req_addr[i],
            per_bank_mem_req_rw[i],
            per_bank_mem_req_byteen[i],
            per_bank_mem_req_data[i],
            per_bank_mem_req_id[i],
            per_bank_mem_req_flush[i]
        };
    end
    VX_stream_arb #(
        .NUM_INPUTS (NUM_BANKS),
        .DATAW      ((32-$clog2(LINE_SIZE)) + 1  + LINE_SIZE + (8 * LINE_SIZE) + MSHR_ADDR_WIDTH + 1),
        .ARBITER    ("F")
    ) mem_req_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (per_bank_mem_req_valid),
        .ready_in  (per_bank_mem_req_ready),
        .data_in   (data_in),
        .data_out  ({mem_req_addr_p, mem_req_rw_p, mem_req_byteen_p, mem_req_data_p, mem_req_id_p, mem_req_flush_p}),
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
    assign mem_req_flush_s = mem_req_flush_p;
    assign mem_req_ready_p = mem_req_ready_s;
    if (WRITE_ENABLE != 0) begin
        assign mem_req_rw_s     = mem_req_rw_p;
        assign mem_req_byteen_s = mem_req_byteen_p;
        assign mem_req_data_s   = mem_req_data_p;
    end else begin
        assign mem_req_rw_s     = 0;
        assign mem_req_byteen_s = {LINE_SIZE{1'b1}};
        assign mem_req_data_s   = '0;
    end
endmodule
