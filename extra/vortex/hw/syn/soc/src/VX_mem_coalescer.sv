module VX_mem_coalescer #(
    parameter  INSTANCE_ID = "",
    parameter NUM_REQS      = 1,
    parameter ADDR_WIDTH    = 32,
    parameter ATYPE_WIDTH   = 1,
    parameter DATA_IN_SIZE  = 4,
    parameter DATA_OUT_SIZE = 64,
    parameter TAG_WIDTH     = 8,
    parameter UUID_WIDTH    = 0,  
    parameter QUEUE_SIZE    = 8,
    parameter DATA_IN_WIDTH = DATA_IN_SIZE * 8,
    parameter DATA_OUT_WIDTH= DATA_OUT_SIZE * 8,
    parameter DATA_RATIO    = DATA_OUT_SIZE / DATA_IN_SIZE,
    parameter DATA_RATIO_W  = (((DATA_RATIO) > 1) ? $clog2(DATA_RATIO) : 1),
    parameter OUT_REQS      = NUM_REQS / DATA_RATIO,
    parameter OUT_ADDR_WIDTH= ADDR_WIDTH - DATA_RATIO_W,
    parameter QUEUE_ADDRW   = $clog2(QUEUE_SIZE),
    parameter OUT_TAG_WIDTH = UUID_WIDTH + QUEUE_ADDRW
) (
    input wire clk,
    input wire reset,
    input wire                          in_req_valid,
    input wire                          in_req_rw,
    input wire [NUM_REQS-1:0]           in_req_mask,
    input wire [NUM_REQS-1:0][DATA_IN_SIZE-1:0] in_req_byteen,
    input wire [NUM_REQS-1:0][ADDR_WIDTH-1:0] in_req_addr,
    input wire [NUM_REQS-1:0][ATYPE_WIDTH-1:0] in_req_atype,
    input wire [NUM_REQS-1:0][DATA_IN_WIDTH-1:0] in_req_data,
    input wire [TAG_WIDTH-1:0]          in_req_tag,
    output wire                         in_req_ready,
    output wire                         in_rsp_valid,
    output wire [NUM_REQS-1:0]          in_rsp_mask,
    output wire [NUM_REQS-1:0][DATA_IN_WIDTH-1:0] in_rsp_data,
    output wire [TAG_WIDTH-1:0]         in_rsp_tag,
    input wire                          in_rsp_ready,
    output wire                         out_req_valid,
    output wire                         out_req_rw,
    output wire [OUT_REQS-1:0]          out_req_mask,
    output wire [OUT_REQS-1:0][DATA_OUT_SIZE-1:0] out_req_byteen,
    output wire [OUT_REQS-1:0][OUT_ADDR_WIDTH-1:0] out_req_addr,
    output wire [OUT_REQS-1:0][ATYPE_WIDTH-1:0] out_req_atype,
    output wire [OUT_REQS-1:0][DATA_OUT_WIDTH-1:0] out_req_data,
    output wire [OUT_TAG_WIDTH-1:0]     out_req_tag,
    input wire 	                        out_req_ready,
    input wire                          out_rsp_valid,
    input wire [OUT_REQS-1:0]           out_rsp_mask,
    input wire [OUT_REQS-1:0][DATA_OUT_WIDTH-1:0] out_rsp_data,
    input wire [OUT_TAG_WIDTH-1:0]      out_rsp_tag,
    output wire                         out_rsp_ready
);
    ;
    ;
    localparam TAG_ID_WIDTH = TAG_WIDTH - UUID_WIDTH;
    localparam NUM_REQS_W   = (((NUM_REQS) > 1) ? $clog2(NUM_REQS) : 1);
    localparam IBUF_DATA_WIDTH = TAG_ID_WIDTH + NUM_REQS + (NUM_REQS * DATA_RATIO_W);
    localparam STATE_SETUP = 0;
    localparam STATE_SEND  = 1;
    logic state_r, state_n;
    logic out_req_valid_r, out_req_valid_n;
    logic out_req_rw_r, out_req_rw_n;
    logic [OUT_REQS-1:0] out_req_mask_r, out_req_mask_n;
    logic [OUT_REQS-1:0][OUT_ADDR_WIDTH-1:0] out_req_addr_r, out_req_addr_n;
    logic [OUT_REQS-1:0][ATYPE_WIDTH-1:0] out_req_atype_r, out_req_atype_n;
    logic [OUT_REQS-1:0][DATA_RATIO-1:0][DATA_IN_SIZE-1:0] out_req_byteen_r, out_req_byteen_n;
    logic [OUT_REQS-1:0][DATA_RATIO-1:0][DATA_IN_WIDTH-1:0] out_req_data_r, out_req_data_n;
    logic [OUT_TAG_WIDTH-1:0] out_req_tag_r, out_req_tag_n;
    reg in_req_ready_n;
    wire                        ibuf_push;
    wire                        ibuf_pop;
    wire [QUEUE_ADDRW-1:0]      ibuf_waddr;
    wire [QUEUE_ADDRW-1:0]      ibuf_raddr;
    wire                        ibuf_full;
    wire                        ibuf_empty;
    wire [IBUF_DATA_WIDTH-1:0]  ibuf_din;
    wire [IBUF_DATA_WIDTH-1:0]  ibuf_dout;
    logic [OUT_REQS-1:0] batch_valid_r, batch_valid_n;
    logic [OUT_REQS-1:0][OUT_ADDR_WIDTH-1:0] seed_addr_r, seed_addr_n;
    logic [OUT_REQS-1:0][ATYPE_WIDTH-1:0] seed_atype_r, seed_atype_n;
    logic [NUM_REQS-1:0] addr_matches_r, addr_matches_n;
    logic [NUM_REQS-1:0] processed_mask_r, processed_mask_n;
    wire [OUT_REQS-1:0][NUM_REQS_W-1:0] seed_idx;
    wire [NUM_REQS-1:0][OUT_ADDR_WIDTH-1:0] in_addr_base;
    wire [NUM_REQS-1:0][DATA_RATIO_W-1:0] in_addr_offset;
    for (genvar i = 0; i < NUM_REQS; i++) begin
        assign in_addr_base[i] = in_req_addr[i][ADDR_WIDTH-1:DATA_RATIO_W];
        assign in_addr_offset[i] = in_req_addr[i][DATA_RATIO_W-1:0];
    end
    for (genvar i = 0; i < OUT_REQS; ++i) begin
        wire [DATA_RATIO-1:0] batch_mask = in_req_mask[i * DATA_RATIO +: DATA_RATIO] & ~processed_mask_r[i * DATA_RATIO +: DATA_RATIO];
        wire [DATA_RATIO_W-1:0] batch_idx;
        VX_priority_encoder #(
            .N (DATA_RATIO)
        ) priority_encoder (
            .data_in (batch_mask),
            .index  (batch_idx),
            . onehot (),
            .valid_out (batch_valid_n[i])
        );
        if (OUT_REQS > 1) begin
            assign seed_idx[i] = {(NUM_REQS_W-DATA_RATIO_W)'(i), batch_idx};
        end else begin
            assign seed_idx[i] = batch_idx;
        end
    end
    for (genvar i = 0; i < OUT_REQS; ++i) begin
        assign seed_addr_n[i]  = in_addr_base[seed_idx[i]];
        assign seed_atype_n[i] = in_req_atype[seed_idx[i]];
    end
    for (genvar i = 0; i < OUT_REQS; ++i) begin
        for (genvar j = 0; j < DATA_RATIO; ++j) begin
            assign addr_matches_n[i * DATA_RATIO + j] = (in_addr_base[i * DATA_RATIO + j] == seed_addr_n[i]);
        end
    end
    wire [NUM_REQS-1:0] current_pmask = in_req_mask & addr_matches_r;
    reg [OUT_REQS-1:0][DATA_RATIO-1:0][DATA_IN_SIZE-1:0] req_byteen_merged;
    reg [OUT_REQS-1:0][DATA_RATIO-1:0][DATA_IN_WIDTH-1:0] req_data_merged;
    always @(*) begin
        req_byteen_merged = '0;
        req_data_merged = 'x;
        for (integer i = 0; i < OUT_REQS; ++i) begin
            for (integer j = 0; j < DATA_RATIO; ++j) begin
                if (current_pmask[i * DATA_RATIO + j]) begin
                    for (integer k = 0; k < DATA_IN_SIZE; ++k) begin
                        if (in_req_byteen[DATA_RATIO * i + j][k]) begin
                            req_byteen_merged[i][in_addr_offset[DATA_RATIO * i + j]][k] = 1'b1;
                            req_data_merged[i][in_addr_offset[DATA_RATIO * i + j]][k * 8 +: 8] = in_req_data[DATA_RATIO * i + j][k * 8 +: 8];
                        end
                    end
                end
            end
        end
    end
    wire [OUT_REQS * DATA_RATIO - 1:0] pending_mask;
    for (genvar i = 0; i < OUT_REQS * DATA_RATIO; ++i) begin
        assign pending_mask[i] = in_req_mask[i] && ~addr_matches_r[i] && ~processed_mask_r[i];
    end
    wire batch_completed = ~(| pending_mask);
    always @(*) begin
        state_n          = state_r;
        out_req_valid_n  = out_req_valid_r;
        out_req_mask_n   = out_req_mask_r;
        out_req_rw_n     = out_req_rw_r;
        out_req_addr_n   = out_req_addr_r;
        out_req_atype_n  = out_req_atype_r;
        out_req_byteen_n = out_req_byteen_r;
        out_req_data_n   = out_req_data_r;
        out_req_tag_n    = out_req_tag_r;
        processed_mask_n = processed_mask_r;
        in_req_ready_n   = 0;
        case (state_r)
        STATE_SETUP: begin
            if (out_req_valid && out_req_ready) begin
                out_req_valid_n = 0;
            end
            if (in_req_valid && ~out_req_valid_n && ~ibuf_full) begin
                state_n = STATE_SEND;
            end
        end
        default : begin
            out_req_valid_n = 1;
            out_req_mask_n  = batch_valid_r;
            out_req_rw_n    = in_req_rw;
            out_req_addr_n  = seed_addr_r;
            out_req_atype_n = seed_atype_r;
            out_req_byteen_n= req_byteen_merged;
            out_req_data_n  = req_data_merged;
            out_req_tag_n   = {in_req_tag[TAG_WIDTH-1 -: UUID_WIDTH], ibuf_waddr};
            in_req_ready_n  = batch_completed;
            if (batch_completed) begin
                processed_mask_n = '0;
            end else begin
                processed_mask_n = processed_mask_r | current_pmask;
            end
            state_n = STATE_SETUP;
        end
        endcase
    end
    VX_pipe_register #(
        .DATAW  (1 + NUM_REQS + 1 + 1 + NUM_REQS + OUT_REQS * (1 + 1 + OUT_ADDR_WIDTH + ATYPE_WIDTH + OUT_ADDR_WIDTH + ATYPE_WIDTH + DATA_OUT_SIZE + DATA_OUT_WIDTH) + OUT_TAG_WIDTH),
        .RESETW (1 + NUM_REQS + 1)
    ) pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({state_n, processed_mask_n, out_req_valid_n, out_req_rw_n, addr_matches_n, batch_valid_n, out_req_mask_n, seed_addr_n, seed_atype_n, out_req_addr_n, out_req_atype_n, out_req_byteen_n, out_req_data_n, out_req_tag_n}),
        .data_out ({state_r, processed_mask_r, out_req_valid_r, out_req_rw_r, addr_matches_r, batch_valid_r, out_req_mask_r, seed_addr_r, seed_atype_r, out_req_addr_r, out_req_atype_r, out_req_byteen_r, out_req_data_r, out_req_tag_r})
    );
    wire out_rsp_fire = out_rsp_valid && out_rsp_ready;
    wire out_rsp_eop;
    wire req_sent = (state_r == STATE_SEND);
    assign ibuf_push  = req_sent && ~in_req_rw;
    assign ibuf_pop   = out_rsp_fire && out_rsp_eop;
    assign ibuf_raddr = out_rsp_tag[QUEUE_ADDRW-1:0];
    wire [TAG_ID_WIDTH-1:0] ibuf_din_tag = in_req_tag[TAG_ID_WIDTH-1:0];
    wire [NUM_REQS-1:0][DATA_RATIO_W-1:0] ibuf_din_offset = in_addr_offset;
    wire [NUM_REQS-1:0] ibuf_din_pmask = current_pmask;
    assign ibuf_din = {ibuf_din_tag, ibuf_din_pmask, ibuf_din_offset};
    VX_index_buffer #(
        .DATAW (IBUF_DATA_WIDTH),
        .SIZE  (QUEUE_SIZE)
    ) req_ibuf (
        .clk          (clk),
        .reset        (reset),
        .acquire_en   (ibuf_push),
        .write_addr   (ibuf_waddr),
        .write_data   (ibuf_din),
        .read_data    (ibuf_dout),
        .read_addr    (ibuf_raddr),
        .release_en   (ibuf_pop),
        .full         (ibuf_full),
        .empty        (ibuf_empty)
    );
    assign out_req_valid  = out_req_valid_r;
    assign out_req_rw     = out_req_rw_r;
    assign out_req_mask   = out_req_mask_r;
    assign out_req_byteen = out_req_byteen_r;
    assign out_req_addr   = out_req_addr_r;
    assign out_req_atype  = out_req_atype_r;
    assign out_req_data   = out_req_data_r;
    assign out_req_tag    = out_req_tag_r;
    assign in_req_ready = in_req_ready_n;
    reg [QUEUE_SIZE-1:0][OUT_REQS-1:0] rsp_rem_mask;
    wire [OUT_REQS-1:0] rsp_rem_mask_n = rsp_rem_mask[ibuf_raddr] & ~out_rsp_mask;
    assign out_rsp_eop = ~(| rsp_rem_mask_n);
    always @(posedge clk) begin
        if (ibuf_push) begin
            rsp_rem_mask[ibuf_waddr] <= batch_valid_r;
        end
        if (out_rsp_fire) begin
            rsp_rem_mask[ibuf_raddr] <= rsp_rem_mask_n;
        end
    end
    wire [NUM_REQS-1:0][DATA_RATIO_W-1:0] ibuf_dout_offset;
    wire [NUM_REQS-1:0] ibuf_dout_pmask;
    wire [TAG_ID_WIDTH-1:0] ibuf_dout_tag;
    assign {ibuf_dout_tag, ibuf_dout_pmask, ibuf_dout_offset} = ibuf_dout;
    wire [NUM_REQS-1:0][DATA_IN_WIDTH-1:0] in_rsp_data_n;
    wire [NUM_REQS-1:0] in_rsp_mask_n;
    for (genvar i = 0; i < OUT_REQS; ++i) begin
        for (genvar j = 0; j < DATA_RATIO; ++j) begin
            assign in_rsp_mask_n[i * DATA_RATIO + j] = out_rsp_mask[i] && ibuf_dout_pmask[i * DATA_RATIO + j];
            assign in_rsp_data_n[i * DATA_RATIO + j] = out_rsp_data[i][ibuf_dout_offset[i * DATA_RATIO + j] * DATA_IN_WIDTH +: DATA_IN_WIDTH];
        end
    end
    assign in_rsp_valid  = out_rsp_valid;
    assign in_rsp_mask   = in_rsp_mask_n;
    assign in_rsp_data   = in_rsp_data_n;
    assign in_rsp_tag    = {out_rsp_tag[OUT_TAG_WIDTH-1 -: UUID_WIDTH], ibuf_dout_tag};
    assign out_rsp_ready = in_rsp_ready;
endmodule
