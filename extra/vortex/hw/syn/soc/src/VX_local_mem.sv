module VX_local_mem import VX_gpu_pkg::*; #(
    parameter   INSTANCE_ID = "",
    parameter SIZE              = (1024*16*8),
    parameter NUM_REQS          = 4,
    parameter NUM_BANKS         = 4,
    parameter ADDR_WIDTH        = $clog2(SIZE),
    parameter WORD_SIZE         = 32/8,
    parameter UUID_WIDTH        = 0,
    parameter TAG_WIDTH         = 16,
    parameter OUT_BUF           = 0
 ) (
    input wire clk,
    input wire reset,
    VX_mem_bus_if.slave mem_bus_if [NUM_REQS]
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
            assign req_bank_idx[i] = mem_bus_if[i].req_data.addr[0 +: BANK_SEL_BITS];
        end
    end else begin
        assign req_bank_idx = 0;
    end
    wire [NUM_REQS-1:0][BANK_ADDR_WIDTH-1:0] req_bank_addr;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign req_bank_addr[i] = mem_bus_if[i].req_data.addr[BANK_SEL_BITS +: BANK_ADDR_WIDTH];
    end
    wire [NUM_BANKS-1:0]                    per_bank_req_valid;
    wire [NUM_BANKS-1:0]                    per_bank_req_rw;
    wire [NUM_BANKS-1:0][BANK_ADDR_WIDTH-1:0] per_bank_req_addr;
    wire [NUM_BANKS-1:0][WORD_SIZE-1:0]     per_bank_req_byteen;
    wire [NUM_BANKS-1:0][WORD_WIDTH-1:0]    per_bank_req_data;
    wire [NUM_BANKS-1:0][TAG_WIDTH-1:0]     per_bank_req_tag;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0] per_bank_req_idx;
    wire [NUM_BANKS-1:0]                    per_bank_req_ready;
    wire [NUM_BANKS-1:0][REQ_DATAW-1:0]     per_bank_req_data_aos;
    wire [NUM_REQS-1:0]                 req_valid_in;
    wire [NUM_REQS-1:0][REQ_DATAW-1:0]  req_data_in;
    wire [NUM_REQS-1:0]                 req_ready_in;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign req_valid_in[i] = mem_bus_if[i].req_valid;
        assign req_data_in[i] = {
            mem_bus_if[i].req_data.rw,
            req_bank_addr[i],
            mem_bus_if[i].req_data.byteen,
            mem_bus_if[i].req_data.data,
            mem_bus_if[i].req_data.tag
        };
        assign mem_bus_if[i].req_ready = req_ready_in[i];
    end
    VX_stream_xbar #(
        .NUM_INPUTS  (NUM_REQS),
        .NUM_OUTPUTS (NUM_BANKS),
        .DATAW       (REQ_DATAW),
        .PERF_CTR_BITS (44),
        .ARBITER     ("F"),
        .OUT_BUF     (3)  
    ) req_xbar (
        .clk       (clk),
        .reset     (reset),
        . collisions (),
        .valid_in  (req_valid_in),
        .data_in   (req_data_in),
        .sel_in    (req_bank_idx),
        .ready_in  (req_ready_in),
        .valid_out (per_bank_req_valid),
        .data_out  (per_bank_req_data_aos),
        .sel_out   (per_bank_req_idx),
        .ready_out (per_bank_req_ready)
    );
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign {
            per_bank_req_rw[i],
            per_bank_req_addr[i],
            per_bank_req_byteen[i],
            per_bank_req_data[i],
            per_bank_req_tag[i]
        } = per_bank_req_data_aos[i];
    end
    wire [NUM_BANKS-1:0]                per_bank_rsp_valid;
    wire [NUM_BANKS-1:0][WORD_WIDTH-1:0] per_bank_rsp_data;
    wire [NUM_BANKS-1:0][REQ_SEL_WIDTH-1:0] per_bank_rsp_idx;
    wire [NUM_BANKS-1:0][TAG_WIDTH-1:0] per_bank_rsp_tag;
    wire [NUM_BANKS-1:0]                per_bank_rsp_ready;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        wire bank_rsp_valid, bank_rsp_ready;
        wire [WORD_WIDTH-1:0] bank_rsp_data;
    wire [1-1:0] bram_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT((((NUM_BANKS > 1)) ? 0 : -1))) __bram_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (bram_reset)                          
    );
        VX_sp_ram #(
            .DATAW (WORD_WIDTH),
            .SIZE  (WORDS_PER_BANK),
            .WRENW (WORD_SIZE),
            .NO_RWCHECK (1)
        ) data_store (
            .clk   (clk),
            .reset (bram_reset),
            .read  (per_bank_req_valid[i] && per_bank_req_ready[i] && ~per_bank_req_rw[i]),
            .write (per_bank_req_valid[i] && per_bank_req_ready[i] && per_bank_req_rw[i]),
            .wren  (per_bank_req_byteen[i]),
            .addr  (per_bank_req_addr[i]),
            .wdata (per_bank_req_data[i]),
            .rdata (bank_rsp_data)
        );
        reg [BANK_ADDR_WIDTH-1:0] last_wr_addr;
        reg last_wr_valid;
        always @(posedge clk) begin
            if (bram_reset) begin
                last_wr_valid <= 0;
            end else begin
                last_wr_valid <= per_bank_req_valid[i] && per_bank_req_ready[i] && per_bank_req_rw[i];
            end
            last_wr_addr <= per_bank_req_addr[i];
        end
        wire is_rdw_hazard = last_wr_valid && ~per_bank_req_rw[i] && (per_bank_req_addr[i] == last_wr_addr);
        assign bank_rsp_valid = per_bank_req_valid[i] && ~per_bank_req_rw[i] && ~is_rdw_hazard;
        assign per_bank_req_ready[i] = (bank_rsp_ready || per_bank_req_rw[i]) && ~is_rdw_hazard;
        VX_pipe_buffer #(
            .DATAW (REQ_SEL_WIDTH + WORD_WIDTH + TAG_WIDTH)
        ) bram_buf (
            .clk       (clk),
            .reset     (bram_reset),
            .valid_in  (bank_rsp_valid),
            .ready_in  (bank_rsp_ready),
            .data_in   ({per_bank_req_idx[i], bank_rsp_data,        per_bank_req_tag[i]}),
            .data_out  ({per_bank_rsp_idx[i], per_bank_rsp_data[i], per_bank_rsp_tag[i]}),
            .valid_out (per_bank_rsp_valid[i]),
            .ready_out (per_bank_rsp_ready[i])
        );
    end
    wire [NUM_BANKS-1:0][RSP_DATAW-1:0] per_bank_rsp_data_aos;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign per_bank_rsp_data_aos[i] = {per_bank_rsp_data[i], per_bank_rsp_tag[i]};
    end
    wire [NUM_REQS-1:0]                 rsp_valid_out;
    wire [NUM_REQS-1:0][RSP_DATAW-1:0]  rsp_data_out;
    wire [NUM_REQS-1:0]                 rsp_ready_out;
    VX_stream_xbar #(
        .NUM_INPUTS  (NUM_BANKS),
        .NUM_OUTPUTS (NUM_REQS),
        .DATAW       (RSP_DATAW),
        .ARBITER     ("P"),  
        .OUT_BUF     (OUT_BUF)
    ) rsp_xbar (
        .clk       (clk),
        .reset     (reset),
        . collisions (),
        .sel_in    (per_bank_rsp_idx),
        .valid_in  (per_bank_rsp_valid),
        .data_in   (per_bank_rsp_data_aos),
        .ready_in  (per_bank_rsp_ready),
        .valid_out (rsp_valid_out),
        .data_out  (rsp_data_out),
        .ready_out (rsp_ready_out),
        . sel_out ()
    );
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign mem_bus_if[i].rsp_valid = rsp_valid_out[i];
        assign mem_bus_if[i].rsp_data = rsp_data_out[i];
        assign rsp_ready_out[i] = mem_bus_if[i].rsp_ready;
    end
endmodule
