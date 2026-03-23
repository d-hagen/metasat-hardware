module VX_cache_bank #(
    parameter  INSTANCE_ID= "",
    parameter BANK_ID           = 0,
    parameter NUM_REQS          = 1, 
    parameter CACHE_SIZE        = 1024, 
    parameter LINE_SIZE         = 16, 
    parameter NUM_BANKS         = 1,
    parameter NUM_WAYS          = 1, 
    parameter WORD_SIZE         = 4, 
    parameter CRSQ_SIZE         = 1,
    parameter MSHR_SIZE         = 1, 
    parameter MREQ_SIZE         = 1,
    parameter WRITE_ENABLE      = 1,
    parameter UUID_WIDTH        = 0,
    parameter TAG_WIDTH         = UUID_WIDTH + 1,
    parameter CORE_OUT_REG      = 0,
    parameter MEM_OUT_REG       = 0,
    parameter MSHR_ADDR_WIDTH   = (((MSHR_SIZE) > 1) ? $clog2(MSHR_SIZE) : 1),
    parameter REQ_SEL_WIDTH     = ((($clog2(NUM_REQS)) != 0) ? ($clog2(NUM_REQS)) : 1),
    parameter WORD_SEL_WIDTH    = ((($clog2((LINE_SIZE / WORD_SIZE))) != 0) ? ($clog2((LINE_SIZE / WORD_SIZE))) : 1)
) (
    input wire clk,
    input wire reset,
    input wire                          core_req_valid,
    input wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] core_req_addr,
    input wire                          core_req_rw, 
    input wire [WORD_SEL_WIDTH-1:0]     core_req_wsel,
    input wire [WORD_SIZE-1:0]          core_req_byteen,
    input wire [(8 * WORD_SIZE)-1:0]     core_req_data, 
    input wire [TAG_WIDTH-1:0]          core_req_tag,
    input wire [REQ_SEL_WIDTH-1:0]      core_req_idx,
    output wire                         core_req_ready,
    output wire                         core_rsp_valid,
    output wire [(8 * WORD_SIZE)-1:0]    core_rsp_data,
    output wire [TAG_WIDTH-1:0]         core_rsp_tag,
    output wire [REQ_SEL_WIDTH-1:0]     core_rsp_idx,
    input  wire                         core_rsp_ready,
    output wire                         mem_req_valid,
    output wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] mem_req_addr,
    output wire                         mem_req_rw,
    output wire [WORD_SEL_WIDTH-1:0]    mem_req_wsel,  
    output wire [WORD_SIZE-1:0]         mem_req_byteen,
    output wire [(8 * WORD_SIZE)-1:0]    mem_req_data,
    output wire [MSHR_ADDR_WIDTH-1:0]   mem_req_id,
    input  wire                         mem_req_ready,
    input wire                          mem_rsp_valid,
    input wire [(8 * LINE_SIZE)-1:0]     mem_rsp_data,
    input wire [MSHR_ADDR_WIDTH-1:0]    mem_rsp_id,
    output wire                         mem_rsp_ready,
    input wire                          init_enable,
    input wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0]  init_line_sel
);
    wire [(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0] req_uuid_sel, req_uuid_st0, req_uuid_st1;
    wire                            crsq_stall;
    wire                            mshr_alm_full;
    wire                            mreq_alm_full;
    wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0]  mem_rsp_addr;
    wire                            replay_valid;
    wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0]  replay_addr;
    wire                            replay_rw;
    wire [WORD_SEL_WIDTH-1:0]       replay_wsel;
    wire [WORD_SIZE-1:0]            replay_byteen;
    wire [(8 * WORD_SIZE)-1:0]       replay_data;
    wire [TAG_WIDTH-1:0]            replay_tag;
    wire [REQ_SEL_WIDTH-1:0]        replay_idx;
    wire [MSHR_ADDR_WIDTH-1:0]      replay_id;
    wire                            replay_ready;
    wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0]  addr_sel, addr_st0, addr_st1;
    wire                            rw_st0, rw_st1;
    wire [WORD_SEL_WIDTH-1:0]       wsel_st0, wsel_st1;
    wire [WORD_SIZE-1:0]            byteen_st0, byteen_st1;
    wire [REQ_SEL_WIDTH-1:0]        req_idx_st0, req_idx_st1;
    wire [TAG_WIDTH-1:0]            tag_st0, tag_st1;
    wire [(8 * WORD_SIZE)-1:0]       read_data_st1;
    wire [(8 * LINE_SIZE)-1:0]       data_sel, data_st0, data_st1;
    wire [MSHR_ADDR_WIDTH-1:0]      replay_id_st0, mshr_id_st0, mshr_id_st1;
    wire                            valid_sel, valid_st0, valid_st1;
    wire                            is_init_st0;
    wire                            is_creq_st0, is_creq_st1;
    wire                            is_fill_st0, is_fill_st1;
    wire                            is_replay_st0, is_replay_st1;
    wire [MSHR_ADDR_WIDTH-1:0]      mshr_alloc_id_st0;
    wire [MSHR_ADDR_WIDTH-1:0]      mshr_tail_st0, mshr_tail_st1;
    wire                            mshr_pending_st0, mshr_pending_st1;
    wire rdw_hazard_st0;
    reg rdw_hazard_st1;
    wire pipe_stall = crsq_stall || rdw_hazard_st1;
    wire replay_grant = ~init_enable;
    wire replay_enable = replay_grant && replay_valid; 
    wire fill_grant  = ~init_enable && ~replay_enable;
    wire fill_enable = fill_grant && mem_rsp_valid;
    wire creq_grant  = ~init_enable && ~replay_enable && ~fill_enable;
    wire creq_enable = creq_grant && core_req_valid;
    assign replay_ready = replay_grant
                         && ~rdw_hazard_st0
                         && ~pipe_stall;
    assign mem_rsp_ready = fill_grant
                        && ~pipe_stall;
    assign core_req_ready = creq_grant
                        && ~mreq_alm_full
                        && ~mshr_alm_full
                        && ~pipe_stall;
    wire init_fire     = init_enable;
    wire replay_fire = replay_valid && replay_ready;
    wire mem_rsp_fire  = mem_rsp_valid && mem_rsp_ready;
    wire core_req_fire = core_req_valid && core_req_ready;
    wire [TAG_WIDTH-1:0] mshr_creq_tag = replay_enable ? replay_tag : core_req_tag;
    if (UUID_WIDTH != 0) begin
        assign req_uuid_sel = mshr_creq_tag[TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin
        assign req_uuid_sel = 0;
    end
    assign valid_sel = init_fire || replay_fire || mem_rsp_fire || core_req_fire;
    assign addr_sel = init_enable ? ((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))'(init_line_sel) :
                        (replay_valid ? replay_addr : 
                            (mem_rsp_valid ? mem_rsp_addr : core_req_addr));
    assign data_sel[(8 * WORD_SIZE)-1:0] = (mem_rsp_valid || !WRITE_ENABLE) ? mem_rsp_data[(8 * WORD_SIZE)-1:0] : (replay_valid ? replay_data : core_req_data);
    for (genvar i = (8 * WORD_SIZE); i < (8 * LINE_SIZE); ++i) begin
        assign data_sel[i] = mem_rsp_data[i];
    end
    VX_pipe_register #(
        .DATAW  (1 + 1 + 1 + 1 + 1 + ((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS)) + (8 * LINE_SIZE) + 1 + WORD_SIZE + WORD_SEL_WIDTH + REQ_SEL_WIDTH + TAG_WIDTH + MSHR_ADDR_WIDTH),
        .RESETW (1)
    ) pipe_reg0 (
        .clk      (clk),
        .reset    (reset),
        .enable   (~pipe_stall),
        .data_in  ({
            valid_sel,
            init_enable,
            replay_enable,
            fill_enable,
            creq_enable,
            addr_sel,
            data_sel,
            replay_valid ? replay_rw : core_req_rw,
            replay_valid ? replay_byteen : core_req_byteen,
            replay_valid ? replay_wsel : core_req_wsel, 
            replay_valid ? replay_idx : core_req_idx,
            replay_valid ? replay_tag : core_req_tag,
            replay_id
        }),
        .data_out ({valid_st0, is_init_st0, is_replay_st0, is_fill_st0, is_creq_st0, addr_st0, data_st0, rw_st0, byteen_st0, wsel_st0, req_idx_st0, tag_st0, replay_id_st0})
    );
    if (UUID_WIDTH != 0) begin
        assign req_uuid_st0 = tag_st0[TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin
        assign req_uuid_st0 = 0;
    end
    wire do_creq_rd_st0 = valid_st0 && is_creq_st0 && ~rw_st0;
    wire do_fill_st0    = valid_st0 && is_fill_st0;
    wire do_init_st0    = valid_st0 && is_init_st0;
    wire do_lookup_st0  = valid_st0 && ~(is_fill_st0 || is_init_st0);
    wire [(8 * WORD_SIZE)-1:0] write_data_st0 = data_st0[(8 * WORD_SIZE)-1:0];
    wire [NUM_WAYS-1:0] tag_matches_st0, tag_matches_st1;
    wire [NUM_WAYS-1:0] way_sel_st0, way_sel_st1;
    wire [1-1:0] tag_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __tag_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (tag_reset)                          
    );
    VX_cache_tags #(
        .INSTANCE_ID(INSTANCE_ID),
        .BANK_ID    (BANK_ID), 
        .CACHE_SIZE (CACHE_SIZE),
        .LINE_SIZE  (LINE_SIZE),
        .NUM_BANKS  (NUM_BANKS),
        .NUM_WAYS   (NUM_WAYS),
        .WORD_SIZE  (WORD_SIZE), 
        .UUID_WIDTH (UUID_WIDTH)
    ) cache_tags (
        .clk        (clk),
        .reset      (tag_reset),
        .req_uuid   (req_uuid_st0),
        .stall      (pipe_stall),
        .lookup     (do_lookup_st0),
        .line_addr  (addr_st0),
        .fill       (do_fill_st0),
        .init       (do_init_st0),
        .way_sel    (way_sel_st0),
        .tag_matches(tag_matches_st0)
    );
    assign mshr_id_st0 = is_creq_st0 ? mshr_alloc_id_st0 : replay_id_st0;
    VX_pipe_register #(
        .DATAW  (1 + 1 + 1 + 1 + 1 + ((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS)) + (8 * LINE_SIZE) + WORD_SIZE + WORD_SEL_WIDTH + REQ_SEL_WIDTH + TAG_WIDTH + MSHR_ADDR_WIDTH + MSHR_ADDR_WIDTH + NUM_WAYS + NUM_WAYS + 1),
        .RESETW (1)
    ) pipe_reg1 (
        .clk      (clk),
        .reset    (reset),
        .enable   (~pipe_stall),
        .data_in  ({valid_st0, is_replay_st0, is_fill_st0, is_creq_st0, rw_st0, addr_st0, data_st0, byteen_st0, wsel_st0, req_idx_st0, tag_st0, mshr_id_st0, mshr_tail_st0, tag_matches_st0, way_sel_st0, mshr_pending_st0}),
        .data_out ({valid_st1, is_replay_st1, is_fill_st1, is_creq_st1, rw_st1, addr_st1, data_st1, byteen_st1, wsel_st1, req_idx_st1, tag_st1, mshr_id_st1, mshr_tail_st1, tag_matches_st1, way_sel_st1, mshr_pending_st1})
    );
    wire is_hit_st1 = (| tag_matches_st1);
    if (UUID_WIDTH != 0) begin
        assign req_uuid_st1 = tag_st1[TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin
        assign req_uuid_st1 = 0;
    end
    wire do_creq_rd_st1   = valid_st1 && is_creq_st1 && ~rw_st1;
    wire do_creq_wr_st1   = valid_st1 && is_creq_st1 && rw_st1;
    wire do_fill_st1      = valid_st1 && is_fill_st1;
    wire do_replay_rd_st1 = valid_st1 && is_replay_st1 && ~rw_st1;
    wire do_replay_wr_st1 = valid_st1 && is_replay_st1 && rw_st1;
    wire do_read_hit_st1  = do_creq_rd_st1 && is_hit_st1;
    wire do_read_miss_st1 = do_creq_rd_st1 && ~is_hit_st1;
    wire do_write_hit_st1 = do_creq_wr_st1 && is_hit_st1;
    wire do_write_miss_st1= do_creq_wr_st1 && ~is_hit_st1;
    ;
    assign rdw_hazard_st0 = do_fill_st0;  
    always @(posedge clk) begin
        rdw_hazard_st1 <= (do_creq_rd_st0 && do_write_hit_st1 && (addr_st0 == addr_st1))
                       && ~rdw_hazard_st1;  
    end
    wire [(8 * WORD_SIZE)-1:0] write_data_st1 = data_st1[(8 * WORD_SIZE)-1:0];
    wire [(8 * LINE_SIZE)-1:0] fill_data_st1 = data_st1;
    wire [1-1:0] data_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __data_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (data_reset)                          
    );
    VX_cache_data #(
        .INSTANCE_ID  (INSTANCE_ID),
        .BANK_ID      (BANK_ID), 
        .CACHE_SIZE   (CACHE_SIZE),
        .LINE_SIZE    (LINE_SIZE),
        .NUM_BANKS    (NUM_BANKS),
        .NUM_WAYS     (NUM_WAYS),
        .WORD_SIZE    (WORD_SIZE),
        .WRITE_ENABLE (WRITE_ENABLE),
        .UUID_WIDTH   (UUID_WIDTH)
    ) cache_data (
        .clk        (clk),
        .reset      (data_reset),
        .req_uuid   (req_uuid_st1),
        .stall      (pipe_stall),
        .read       (do_read_hit_st1 || do_replay_rd_st1), 
        .fill       (do_fill_st1), 
        .write      (do_write_hit_st1 || do_replay_wr_st1),
        .way_sel    (way_sel_st1 | tag_matches_st1),
        .line_addr  (addr_st1),
        .wsel       (wsel_st1),
        .byteen     (byteen_st1),
        .fill_data  (fill_data_st1), 
        .write_data (write_data_st1),
        .read_data  (read_data_st1)
    );
    wire [MSHR_SIZE-1:0] mshr_matches_st0;
    wire mshr_allocate_st0 = valid_st0 && is_creq_st0 && ~pipe_stall;
    wire mshr_lookup_st0   = mshr_allocate_st0;
    wire mshr_finalize_st1 = valid_st1 && is_creq_st1 && ~pipe_stall;
    wire mshr_release_st1  = is_hit_st1 || (rw_st1 && ~mshr_pending_st1);
    VX_pending_size #( 
        .SIZE (MSHR_SIZE)
    ) mshr_pending_size (
        .clk   (clk),
        .reset (reset),
        .incr  (core_req_fire),
        .decr  (replay_fire || (mshr_finalize_st1 && mshr_release_st1)),
        .full  (mshr_alm_full),
        . size (),
        . empty ()
    );
    wire [1-1:0] mshr_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mshr_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mshr_reset)                          
    );
    VX_cache_mshr #(
        .INSTANCE_ID (INSTANCE_ID),
        .BANK_ID     (BANK_ID), 
        .LINE_SIZE   (LINE_SIZE),
        .NUM_BANKS   (NUM_BANKS),
        .MSHR_SIZE   (MSHR_SIZE),
        .UUID_WIDTH  (UUID_WIDTH),
        .DATA_WIDTH  (WORD_SEL_WIDTH + WORD_SIZE + (8 * WORD_SIZE) + TAG_WIDTH + REQ_SEL_WIDTH)
    ) cache_mshr (
        .clk            (clk),
        .reset          (mshr_reset),
        .deq_req_uuid   (req_uuid_sel),
        .lkp_req_uuid   (req_uuid_st0),
        .fin_req_uuid   (req_uuid_st1),
        .fill_valid     (mem_rsp_fire),
        .fill_id        (mem_rsp_id),
        .fill_addr      (mem_rsp_addr),
        .dequeue_valid  (replay_valid),
        .dequeue_addr   (replay_addr),
        .dequeue_rw     (replay_rw),        
        .dequeue_data   ({replay_wsel, replay_byteen, replay_data, replay_tag, replay_idx}),
        .dequeue_id     (replay_id),
        .dequeue_ready  (replay_ready),
        .allocate_valid (mshr_allocate_st0),
        .allocate_addr  (addr_st0),
        .allocate_rw    (rw_st0),
        .allocate_data  ({wsel_st0, byteen_st0, write_data_st0, tag_st0, req_idx_st0}),
        .allocate_id    (mshr_alloc_id_st0),
        .allocate_tail  (mshr_tail_st0),
        . allocate_ready (),
        .lookup_valid   (mshr_lookup_st0),
        .lookup_addr    (addr_st0),
        .lookup_matches (mshr_matches_st0),
        .finalize_valid (mshr_finalize_st1),
        .finalize_release(mshr_release_st1),
        .finalize_pending(mshr_pending_st1),
        .finalize_id    (mshr_id_st1),
        .finalize_tail  (mshr_tail_st1)
    );
    wire [MSHR_SIZE-1:0] lookup_matches;
    for (genvar i = 0; i < MSHR_SIZE; ++i) begin
        assign lookup_matches[i] = (i != mshr_alloc_id_st0) && mshr_matches_st0[i];
    end
    assign mshr_pending_st0 = (| lookup_matches);
    wire crsq_valid, crsq_ready;
    wire [(8 * WORD_SIZE)-1:0] crsq_data;
    wire [REQ_SEL_WIDTH-1:0] crsq_idx;
    wire [TAG_WIDTH-1:0] crsq_tag;
    assign crsq_valid = do_read_hit_st1 || do_replay_rd_st1;
    assign crsq_idx   = req_idx_st1;
    assign crsq_data  = read_data_st1;
    assign crsq_tag   = tag_st1;
    wire [1-1:0] crsp_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __crsp_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (crsp_reset)                          
    );
    VX_elastic_buffer #(
        .DATAW   (TAG_WIDTH + (8 * WORD_SIZE) + REQ_SEL_WIDTH),
        .SIZE    (CRSQ_SIZE),
        .OUT_REG (CORE_OUT_REG)
    ) core_rsp_queue (
        .clk       (clk),
        .reset     (crsp_reset),
        .valid_in  (crsq_valid && ~rdw_hazard_st1),
        .ready_in  (crsq_ready),
        .data_in   ({crsq_tag, crsq_data, crsq_idx}), 
        .data_out  ({core_rsp_tag, core_rsp_data, core_rsp_idx}),
        .valid_out (core_rsp_valid),
        .ready_out (core_rsp_ready)
    );
    assign crsq_stall = crsq_valid && ~crsq_ready;
    wire mreq_push, mreq_pop, mreq_empty;
    wire [(8 * WORD_SIZE)-1:0] mreq_data;
    wire [WORD_SIZE-1:0] mreq_byteen;
    wire [WORD_SEL_WIDTH-1:0] mreq_wsel;
    wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] mreq_addr;
    wire [MSHR_ADDR_WIDTH-1:0] mreq_id;
    wire mreq_rw;
    assign mreq_push = (do_read_miss_st1 && ~mshr_pending_st1)
                     || do_creq_wr_st1;
    assign mreq_pop = mem_req_valid && mem_req_ready;
    assign mreq_rw   = WRITE_ENABLE && rw_st1;
    assign mreq_addr = addr_st1;
    assign mreq_id   = mshr_id_st1;
    assign mreq_wsel = wsel_st1;
    assign mreq_byteen = byteen_st1;
    assign mreq_data = write_data_st1;
    wire [1-1:0] mreq_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mreq_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mreq_reset)                          
    );
    VX_fifo_queue #(
        .DATAW    (1 + ((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS)) + MSHR_ADDR_WIDTH + WORD_SIZE + WORD_SEL_WIDTH + (8 * WORD_SIZE)), 
        .DEPTH    (MREQ_SIZE),
        .ALM_FULL (MREQ_SIZE-2),
        .OUT_REG  (MEM_OUT_REG)
    ) mem_req_queue (
        .clk        (clk),
        .reset      (mreq_reset),
        .push       (mreq_push),
        .pop        (mreq_pop),
        .data_in    ({mreq_rw, mreq_addr, mreq_id, mreq_byteen, mreq_wsel, mreq_data}),
        .data_out   ({mem_req_rw, mem_req_addr, mem_req_id, mem_req_byteen, mem_req_wsel, mem_req_data}),
        .empty      (mreq_empty), 
        .alm_full   (mreq_alm_full),
        . full (),
        . alm_empty (), 
        . size ()
    );
    assign mem_req_valid = ~mreq_empty;
endmodule
