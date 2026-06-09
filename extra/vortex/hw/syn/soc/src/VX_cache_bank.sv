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
    parameter WRITEBACK         = 0,
    parameter DIRTY_BYTES       = 0,
    parameter UUID_WIDTH        = 0,
    parameter TAG_WIDTH         = UUID_WIDTH + 1,
    parameter CORE_OUT_BUF      = 0,
    parameter MEM_OUT_BUF       = 0,
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
    input wire                          core_req_flush,  
    output wire                         core_req_ready,
    output wire                         core_rsp_valid,
    output wire [(8 * WORD_SIZE)-1:0]    core_rsp_data,
    output wire [TAG_WIDTH-1:0]         core_rsp_tag,
    output wire [REQ_SEL_WIDTH-1:0]     core_rsp_idx,
    input  wire                         core_rsp_ready,
    output wire                         mem_req_valid,
    output wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] mem_req_addr,
    output wire                         mem_req_rw,
    output wire [LINE_SIZE-1:0]         mem_req_byteen,
    output wire [(8 * LINE_SIZE)-1:0]    mem_req_data,
    output wire [MSHR_ADDR_WIDTH-1:0]   mem_req_id,      
    output wire                         mem_req_flush,
    input  wire                         mem_req_ready,
    input wire                          mem_rsp_valid,
    input wire [(8 * LINE_SIZE)-1:0]     mem_rsp_data,
    input wire [MSHR_ADDR_WIDTH-1:0]    mem_rsp_id,
    output wire                         mem_rsp_ready,
    input wire                          flush_begin,
    output wire                         flush_end
);
    localparam PIPELINE_STAGES = 2;
    wire [(((UUID_WIDTH) != 0) ? (UUID_WIDTH) : 1)-1:0] req_uuid_sel, req_uuid_st0, req_uuid_st1;
    wire                            crsp_queue_stall;
    wire                            mshr_alm_full;
    wire                            mreq_queue_empty;
    wire                            mreq_queue_alm_full;
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
    wire                            is_init_st0, is_init_st1;
    wire                            is_flush_st0, is_flush_st1;
    wire [NUM_WAYS-1:0]             flush_way_st0;
    wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0]  addr_sel, addr_st0, addr_st1;
    wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0]    line_sel_st0, line_sel_st1;
    wire                            rw_sel, rw_st0, rw_st1;
    wire [WORD_SEL_WIDTH-1:0]       wsel_sel, wsel_st0, wsel_st1;
    wire [WORD_SIZE-1:0]            byteen_sel, byteen_st0, byteen_st1;
    wire [REQ_SEL_WIDTH-1:0]        req_idx_sel, req_idx_st0, req_idx_st1;
    wire [TAG_WIDTH-1:0]            tag_sel, tag_st0, tag_st1;
    wire [(8 * WORD_SIZE)-1:0]       read_data_st1;
    wire [(8 * LINE_SIZE)-1:0]       data_sel, data_st0, data_st1;
    wire [MSHR_ADDR_WIDTH-1:0]      replay_id_st0, mshr_id_st0, mshr_id_st1;
    wire                            valid_sel, valid_st0, valid_st1;
    wire                            is_creq_st0, is_creq_st1;
    wire                            is_fill_st0, is_fill_st1;
    wire                            is_replay_st0, is_replay_st1;
    wire                            creq_flush_sel, creq_flush_st0, creq_flush_st1;
    wire                            evict_dirty_st0, evict_dirty_st1;
    wire [NUM_WAYS-1:0]             way_sel_st0, way_sel_st1;
    wire [NUM_WAYS-1:0]             tag_matches_st0;
    wire [MSHR_ADDR_WIDTH-1:0]      mshr_alloc_id_st0;
    wire [MSHR_ADDR_WIDTH-1:0]      mshr_prev_st0, mshr_prev_st1;
    wire                            mshr_pending_st0, mshr_pending_st1;
    wire                            mshr_empty;
    wire flush_valid;
    wire init_valid;
    wire [$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0] flush_sel;
    wire [NUM_WAYS-1:0] flush_way;
    wire flush_ready;
    wire no_pending_req = ~valid_st0 && ~valid_st1 && mreq_queue_empty;
    VX_bank_flush #(
        .BANK_ID    (BANK_ID),
        .CACHE_SIZE (CACHE_SIZE),
        .LINE_SIZE  (LINE_SIZE),
        .NUM_BANKS  (NUM_BANKS),
        .NUM_WAYS   (NUM_WAYS),
        .WRITEBACK  (WRITEBACK)
    ) flush_unit (
        .clk         (clk),
        .reset       (reset),
        .flush_begin (flush_begin),
        .flush_end   (flush_end),
        .flush_init  (init_valid),
        .flush_valid (flush_valid),
        .flush_line  (flush_sel),
        .flush_way   (flush_way),
        .flush_ready (flush_ready),
        .mshr_empty  (mshr_empty),
        .bank_empty  (no_pending_req)
    );
    wire rdw_hazard1_sel;
    wire rdw_hazard2_sel;
    reg rdw_hazard3_st1;
    wire pipe_stall = crsp_queue_stall || rdw_hazard3_st1;
    wire replay_grant = ~init_valid;
    wire replay_enable = replay_grant && replay_valid;
    wire fill_grant  = ~init_valid && ~replay_enable;
    wire fill_enable = fill_grant && mem_rsp_valid;
    wire flush_grant  = ~init_valid && ~replay_enable && ~fill_enable;
    wire flush_enable = flush_grant && flush_valid;
    wire creq_grant  = ~init_valid && ~replay_enable && ~fill_enable && ~flush_enable;
    wire creq_enable = creq_grant && core_req_valid;
    assign replay_ready = replay_grant
                       && ~rdw_hazard1_sel
                       && ~pipe_stall;
    assign mem_rsp_ready = fill_grant
                        && (!WRITEBACK || ~mreq_queue_alm_full)  
                        && ~rdw_hazard2_sel
                        && ~pipe_stall;
    assign flush_ready = flush_grant
                      && (!WRITEBACK || ~mreq_queue_alm_full)  
                      && ~rdw_hazard2_sel
                      && ~pipe_stall;
    assign core_req_ready = creq_grant
                         && ~mreq_queue_alm_full
                         && ~mshr_alm_full
                         && ~pipe_stall;
    wire init_fire     = init_valid;
    wire replay_fire   = replay_valid && replay_ready;
    wire mem_rsp_fire  = mem_rsp_valid && mem_rsp_ready;
    wire flush_fire = flush_valid && flush_ready;
    wire core_req_fire = core_req_valid && core_req_ready;
    assign valid_sel   = init_fire || replay_fire || mem_rsp_fire || flush_fire || core_req_fire;
    assign rw_sel      = replay_valid ? replay_rw : core_req_rw;
    assign byteen_sel  = replay_valid ? replay_byteen : core_req_byteen;
    assign wsel_sel    = replay_valid ? replay_wsel : core_req_wsel;
    assign req_idx_sel = replay_valid ? replay_idx : core_req_idx;
    assign tag_sel     = replay_valid ? replay_tag : core_req_tag;
    assign creq_flush_sel = core_req_valid && core_req_flush;
    assign addr_sel    = (init_valid | flush_valid) ? ((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))'(flush_sel) :
                            (replay_valid ? replay_addr : (mem_rsp_valid ? mem_rsp_addr : core_req_addr));
    if (WRITE_ENABLE) begin
        assign data_sel[(8 * WORD_SIZE)-1:0] = replay_valid ? replay_data : (mem_rsp_valid ? mem_rsp_data[(8 * WORD_SIZE)-1:0] : core_req_data);
    end else begin
        assign data_sel[(8 * WORD_SIZE)-1:0] = mem_rsp_data[(8 * WORD_SIZE)-1:0];
    end
    for (genvar i = (8 * WORD_SIZE); i < (8 * LINE_SIZE); ++i) begin
        assign data_sel[i] = mem_rsp_data[i];  
    end
    if (UUID_WIDTH != 0) begin
        assign req_uuid_sel = tag_sel[TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin
        assign req_uuid_sel = 0;
    end
    VX_pipe_register #(
        .DATAW  (1 + 1 + 1 + 1 + 1 + 1 + 1 + NUM_WAYS + ((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS)) + (8 * LINE_SIZE) + 1 + WORD_SIZE + WORD_SEL_WIDTH + REQ_SEL_WIDTH + TAG_WIDTH + MSHR_ADDR_WIDTH),
        .RESETW (1)
    ) pipe_reg0 (
        .clk      (clk),
        .reset    (reset),
        .enable   (~pipe_stall),
        .data_in  ({valid_sel, init_valid,  replay_enable, fill_enable, flush_enable, creq_enable, creq_flush_sel, flush_way,      addr_sel, data_sel, rw_sel, byteen_sel, wsel_sel, req_idx_sel, tag_sel, replay_id}),
        .data_out ({valid_st0, is_init_st0, is_replay_st0, is_fill_st0, is_flush_st0, is_creq_st0, creq_flush_st0, flush_way_st0,  addr_st0, data_st0, rw_st0, byteen_st0, wsel_st0, req_idx_st0, tag_st0, replay_id_st0})
    );
    if (UUID_WIDTH != 0) begin
        assign req_uuid_st0 = tag_st0[TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin
        assign req_uuid_st0 = 0;
    end
    wire do_init_st0    = valid_st0 && is_init_st0;
    wire do_flush_st0   = valid_st0 && is_flush_st0;
    wire do_creq_rd_st0 = valid_st0 && is_creq_st0 && ~rw_st0;
    wire do_creq_wr_st0 = valid_st0 && is_creq_st0 && rw_st0;
    wire do_replay_rd_st0 = valid_st0 && is_replay_st0 && ~rw_st0;
    wire do_replay_wr_st0 = valid_st0 && is_replay_st0 && rw_st0;
    wire do_fill_st0    = valid_st0 && is_fill_st0;
    wire do_cache_rd_st0 = do_creq_rd_st0 || do_replay_rd_st0;
    wire do_cache_wr_st0 = do_creq_wr_st0 || do_replay_wr_st0;
    wire do_lookup_st0  = do_cache_rd_st0 || do_cache_wr_st0;
    wire [(8 * WORD_SIZE)-1:0] write_data_st0 = data_st0[(8 * WORD_SIZE)-1:0];
    assign line_sel_st0 = addr_st0[$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0];
    wire [NUM_WAYS-1:0] evict_way_st0;
    wire [((32-$clog2(WORD_SIZE))-1-((1+((1+(0+$clog2((LINE_SIZE / WORD_SIZE))-1))+$clog2(NUM_BANKS)-1))+$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1))-1:0] evict_tag_st0;
    VX_cache_tags #(
        .INSTANCE_ID($sformatf("%s-tags", INSTANCE_ID)),
        .BANK_ID    (BANK_ID),
        .CACHE_SIZE (CACHE_SIZE),
        .LINE_SIZE  (LINE_SIZE),
        .NUM_BANKS  (NUM_BANKS),
        .NUM_WAYS   (NUM_WAYS),
        .WORD_SIZE  (WORD_SIZE),
        .WRITEBACK  (WRITEBACK),
        .UUID_WIDTH (UUID_WIDTH)
    ) cache_tags (
        .clk        (clk),
        .reset      (reset),
        .req_uuid   (req_uuid_st0),
        .stall      (pipe_stall),
        .init       (do_init_st0),
        .flush      (do_flush_st0),
        .fill       (do_fill_st0),
        .write      (do_cache_wr_st0),
        .lookup     (do_lookup_st0),
        .line_addr  (addr_st0),
        .way_sel    (flush_way_st0),
        .tag_matches(tag_matches_st0),
        .evict_dirty(evict_dirty_st0),
        .evict_way  (evict_way_st0),
        .evict_tag  (evict_tag_st0)
    );
    wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] addr2_st0;
    wire is_flush2_st0 = WRITEBACK && is_flush_st0;
    assign mshr_id_st0 = is_creq_st0 ? mshr_alloc_id_st0 : replay_id_st0;
    assign way_sel_st0 = (is_fill_st0 || is_flush2_st0) ? evict_way_st0 : tag_matches_st0;
    assign addr2_st0 = (is_fill_st0 || is_flush2_st0) ? {evict_tag_st0, line_sel_st0} : addr_st0;
    VX_pipe_register #(
        .DATAW  (1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + ((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS)) + (8 * LINE_SIZE) + WORD_SIZE + WORD_SEL_WIDTH + REQ_SEL_WIDTH + TAG_WIDTH + MSHR_ADDR_WIDTH + MSHR_ADDR_WIDTH + NUM_WAYS + 1 + 1),
        .RESETW (1)
    ) pipe_reg1 (
        .clk      (clk),
        .reset    (reset),
        .enable   (~pipe_stall),
        .data_in  ({valid_st0, is_init_st0, is_replay_st0, is_fill_st0, is_flush2_st0, is_creq_st0, creq_flush_st0, rw_st0, addr2_st0, data_st0, byteen_st0, wsel_st0, req_idx_st0, tag_st0, mshr_id_st0, mshr_prev_st0, way_sel_st0, evict_dirty_st0, mshr_pending_st0}),
        .data_out ({valid_st1, is_init_st1, is_replay_st1, is_fill_st1, is_flush_st1,  is_creq_st1, creq_flush_st1, rw_st1, addr_st1,  data_st1, byteen_st1, wsel_st1, req_idx_st1, tag_st1, mshr_id_st1, mshr_prev_st1, way_sel_st1, evict_dirty_st1, mshr_pending_st1})
    );
    wire is_hit_st1 = (| way_sel_st1);
    if (UUID_WIDTH != 0) begin
        assign req_uuid_st1 = tag_st1[TAG_WIDTH-1 -: UUID_WIDTH];
    end else begin
        assign req_uuid_st1 = 0;
    end
    wire is_read_st1      = is_creq_st1 && ~rw_st1;
    wire is_write_st1     = is_creq_st1 && rw_st1;
    wire do_init_st1      = valid_st1 && is_init_st1;
    wire do_fill_st1      = valid_st1 && is_fill_st1;
    wire do_flush_st1     = valid_st1 && is_flush_st1;
    wire do_creq_rd_st1   = valid_st1 && is_read_st1;
    wire do_creq_wr_st1   = valid_st1 && is_write_st1;
    wire do_replay_rd_st1 = valid_st1 && is_replay_st1 && ~rw_st1;
    wire do_replay_wr_st1 = valid_st1 && is_replay_st1 && rw_st1;
    wire do_read_hit_st1  = do_creq_rd_st1 && is_hit_st1;
    wire do_read_miss_st1 = do_creq_rd_st1 && ~is_hit_st1;
    wire do_write_hit_st1 = do_creq_wr_st1 && is_hit_st1;
    wire do_write_miss_st1= do_creq_wr_st1 && ~is_hit_st1;
    wire do_cache_rd_st1  = do_read_hit_st1 || do_replay_rd_st1;
    wire do_cache_wr_st1  = do_write_hit_st1 || do_replay_wr_st1;
    assign line_sel_st1 = addr_st1[$clog2(((CACHE_SIZE / NUM_BANKS) / (LINE_SIZE * NUM_WAYS)))-1:0];
    ;
    assign rdw_hazard1_sel = do_fill_st0;  
    assign rdw_hazard2_sel = WRITEBACK && do_cache_wr_st0;  
    always @(posedge clk) begin
        rdw_hazard3_st1 <= do_cache_rd_st0 && do_cache_wr_st1 && (line_sel_st0 == line_sel_st1)
                       && ~rdw_hazard3_st1;  
    end
    wire [(8 * LINE_SIZE)-1:0] write_data_st1 = {(LINE_SIZE / WORD_SIZE){data_st1[(8 * WORD_SIZE)-1:0]}};
    wire [(8 * LINE_SIZE)-1:0] fill_data_st1 = data_st1;
    wire [LINE_SIZE-1:0] write_byteen_st1;
    wire [(8 * LINE_SIZE)-1:0] dirty_data_st1;
    wire [LINE_SIZE-1:0] dirty_byteen_st1;
     if ((LINE_SIZE / WORD_SIZE) > 1) begin
        reg [LINE_SIZE-1:0] write_byteen_r;
        always @(*) begin
            write_byteen_r = '0;
            write_byteen_r[wsel_st1 * WORD_SIZE +: WORD_SIZE] = byteen_st1;
        end
        assign write_byteen_st1 = write_byteen_r;
    end else begin
        assign write_byteen_st1 = byteen_st1;
    end
    VX_cache_data #(
        .INSTANCE_ID  ($sformatf("%s-data", INSTANCE_ID)),
        .BANK_ID      (BANK_ID),
        .CACHE_SIZE   (CACHE_SIZE),
        .LINE_SIZE    (LINE_SIZE),
        .NUM_BANKS    (NUM_BANKS),
        .NUM_WAYS     (NUM_WAYS),
        .WORD_SIZE    (WORD_SIZE),
        .WRITE_ENABLE (WRITE_ENABLE),
        .WRITEBACK    (WRITEBACK),
        .DIRTY_BYTES  (DIRTY_BYTES),
        .UUID_WIDTH   (UUID_WIDTH)
    ) cache_data (
        .clk        (clk),
        .reset      (reset),
        .req_uuid   (req_uuid_st1),
        .stall      (pipe_stall),
        .init       (do_init_st1),
        .read       (do_cache_rd_st1),
        .fill       (do_fill_st1),
        .flush      (do_flush_st1),
        .write      (do_cache_wr_st1),
        .way_sel    (way_sel_st1),
        .line_addr  (addr_st1),
        .wsel       (wsel_st1),
        .fill_data  (fill_data_st1),
        .write_data (write_data_st1),
        .write_byteen(write_byteen_st1),
        .read_data  (read_data_st1),
        .dirty_data (dirty_data_st1),
        .dirty_byteen(dirty_byteen_st1)
    );
    wire [MSHR_SIZE-1:0] mshr_lookup_pending_st0;
    wire [MSHR_SIZE-1:0] mshr_lookup_rw_st0;
    wire mshr_allocate_st0 = valid_st0 && is_creq_st0 && ~pipe_stall;
    wire mshr_lookup_st0   = mshr_allocate_st0;
    wire mshr_finalize_st1 = valid_st1 && is_creq_st1 && ~pipe_stall;
    wire mshr_release_st1;
    if (WRITEBACK) begin
        assign mshr_release_st1 = is_hit_st1;
    end else begin
        assign mshr_release_st1 = is_hit_st1 || (rw_st1 && ~mshr_pending_st1);
    end
    VX_pending_size #(
        .SIZE (MSHR_SIZE)
    ) mshr_pending_size (
        .clk   (clk),
        .reset (reset),
        .incr  (core_req_fire),
        .decr  (replay_fire || (mshr_finalize_st1 && mshr_release_st1)),
        .empty (mshr_empty),
        . alm_empty (),
        .full  (mshr_alm_full),
        . alm_full (),
        . size ()
    );
    VX_cache_mshr #(
        .INSTANCE_ID ($sformatf("%s-mshr", INSTANCE_ID)),
        .BANK_ID     (BANK_ID),
        .LINE_SIZE   (LINE_SIZE),
        .NUM_BANKS   (NUM_BANKS),
        .MSHR_SIZE   (MSHR_SIZE),
        .UUID_WIDTH  (UUID_WIDTH),
        .DATA_WIDTH  (WORD_SEL_WIDTH + WORD_SIZE + (8 * WORD_SIZE) + TAG_WIDTH + REQ_SEL_WIDTH)
    ) cache_mshr (
        .clk            (clk),
        .reset          (reset),
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
        .allocate_prev  (mshr_prev_st0),
        . allocate_ready (),
        .lookup_valid   (mshr_lookup_st0),
        .lookup_addr    (addr_st0),
        .lookup_pending (mshr_lookup_pending_st0),
        .lookup_rw      (mshr_lookup_rw_st0),
        .finalize_valid (mshr_finalize_st1),
        .finalize_release(mshr_release_st1),
        .finalize_pending(mshr_pending_st1),
        .finalize_id    (mshr_id_st1),
        .finalize_prev  (mshr_prev_st1)
    );
    wire [MSHR_SIZE-1:0] lookup_matches;
    for (genvar i = 0; i < MSHR_SIZE; ++i) begin
        assign lookup_matches[i] = mshr_lookup_pending_st0[i]
                                && (i != mshr_alloc_id_st0)  
                                && (WRITEBACK || ~mshr_lookup_rw_st0[i]);   
    end
    assign mshr_pending_st0 = (| lookup_matches);
    wire crsp_queue_valid, crsp_queue_ready;
    wire [(8 * WORD_SIZE)-1:0] crsp_queue_data;
    wire [REQ_SEL_WIDTH-1:0] crsp_queue_idx;
    wire [TAG_WIDTH-1:0] crsp_queue_tag;
    assign crsp_queue_valid = do_cache_rd_st1;
    assign crsp_queue_idx   = req_idx_st1;
    assign crsp_queue_data  = read_data_st1;
    assign crsp_queue_tag   = tag_st1;
    VX_elastic_buffer #(
        .DATAW   (TAG_WIDTH + (8 * WORD_SIZE) + REQ_SEL_WIDTH),
        .SIZE    (CRSQ_SIZE),
        .OUT_REG (((CORE_OUT_BUF < 2) ? CORE_OUT_BUF : (CORE_OUT_BUF - 2)))
    ) core_rsp_queue (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (crsp_queue_valid && ~rdw_hazard3_st1),
        .ready_in  (crsp_queue_ready),
        .data_in   ({crsp_queue_tag, crsp_queue_data, crsp_queue_idx}),
        .data_out  ({core_rsp_tag, core_rsp_data, core_rsp_idx}),
        .valid_out (core_rsp_valid),
        .ready_out (core_rsp_ready)
    );
    assign crsp_queue_stall = crsp_queue_valid && ~crsp_queue_ready;
    wire mreq_queue_push, mreq_queue_pop;
    wire [(8 * LINE_SIZE)-1:0] mreq_queue_data;
    wire [LINE_SIZE-1:0] mreq_queue_byteen;
    wire [((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS))-1:0] mreq_queue_addr;
    wire [MSHR_ADDR_WIDTH-1:0] mreq_queue_id;
    wire mreq_queue_rw;
    wire mreq_queue_flush;
    wire is_fill_or_flush_st1 = is_fill_st1 || is_flush_st1;
    wire do_fill_or_flush_st1 = valid_st1 && is_fill_or_flush_st1;
    wire do_writeback_st1 = do_fill_or_flush_st1 && evict_dirty_st1;
    if (WRITEBACK) begin
        if (DIRTY_BYTES) begin
            wire has_dirty_bytes = (| dirty_byteen_st1);
            ;
        end
        assign mreq_queue_push = (((do_read_miss_st1 || do_write_miss_st1) && ~mshr_pending_st1)
                               || do_writeback_st1)
                              && ~rdw_hazard3_st1;
    end else begin
        assign mreq_queue_push = ((do_read_miss_st1 && ~mshr_pending_st1)
                               || do_creq_wr_st1)
                              && ~rdw_hazard3_st1;
    end
    assign mreq_queue_pop = mem_req_valid && mem_req_ready;
    assign mreq_queue_addr = addr_st1;
    assign mreq_queue_id = mshr_id_st1;
    assign mreq_queue_flush = creq_flush_st1;
    if (WRITE_ENABLE) begin
        assign mreq_queue_rw = WRITEBACK ? is_fill_or_flush_st1 : rw_st1;
        assign mreq_queue_data = WRITEBACK ? dirty_data_st1 : write_data_st1;
        assign mreq_queue_byteen = WRITEBACK ? dirty_byteen_st1 : write_byteen_st1;
    end else begin
        assign mreq_queue_rw = 0;
        assign mreq_queue_data = 0;
        assign mreq_queue_byteen = 0;
    end
    VX_fifo_queue #(
        .DATAW    (1 + ((32-$clog2(LINE_SIZE))-$clog2(NUM_BANKS)) + MSHR_ADDR_WIDTH + LINE_SIZE + (8 * LINE_SIZE) + 1),
        .DEPTH    (MREQ_SIZE),
        .ALM_FULL (MREQ_SIZE-PIPELINE_STAGES),
        .OUT_REG  (((MEM_OUT_BUF < 2) ? MEM_OUT_BUF : (MEM_OUT_BUF - 2)))
    ) mem_req_queue (
        .clk        (clk),
        .reset      (reset),
        .push       (mreq_queue_push),
        .pop        (mreq_queue_pop),
        .data_in    ({mreq_queue_rw, mreq_queue_addr, mreq_queue_id, mreq_queue_byteen, mreq_queue_data, mreq_queue_flush}),
        .data_out   ({mem_req_rw, mem_req_addr, mem_req_id, mem_req_byteen, mem_req_data, mem_req_flush}),
        .empty      (mreq_queue_empty),
        .alm_full   (mreq_queue_alm_full),
        . full (),
        . alm_empty (),
        . size ()
    );
    assign mem_req_valid = ~mreq_queue_empty;
endmodule
