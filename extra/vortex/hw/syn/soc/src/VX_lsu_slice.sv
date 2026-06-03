module VX_lsu_slice import VX_gpu_pkg::*, VX_trace_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_execute_if.slave     execute_if,
    VX_commit_if.master     commit_if,
    VX_lsu_mem_if.master    lsu_mem_if
);
    localparam NUM_LANES    = 2;
    localparam PID_BITS     = $clog2(2 / NUM_LANES);
    localparam PID_WIDTH    = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam RSP_ARB_DATAW= 1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + NUM_LANES + (32-1) + $clog2(32) + 1 + NUM_LANES * 32 + PID_WIDTH + 1 + 1;
    localparam LSUQ_SIZEW   = ((((2 * (2 / 2))) > 1) ? $clog2((2 * (2 / 2))) : 1);
    localparam REQ_ASHIFT   = $clog2(LSU_WORD_SIZE);
    localparam MEM_ASHIFT   = $clog2(16);
    localparam MEM_ADDRW    = 32 - MEM_ASHIFT;
    localparam TAG_ID_WIDTH = ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + (32-1) + 1 + $clog2(32) + 4 + (NUM_LANES * REQ_ASHIFT) + PID_WIDTH + LSUQ_SIZEW + 1;
    localparam TAG_WIDTH = 1 + TAG_ID_WIDTH;
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) commit_rsp_if();
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) commit_no_rsp_if();
    wire req_is_fence, rsp_is_fence;
    wire [NUM_LANES-1:0][32-1:0] full_addr;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign full_addr[i] = execute_if.data.rs1_data[i] + {{(32-$bits(execute_if.data.op_args.lsu.offset)+1){execute_if.data.op_args.lsu.offset[$bits(execute_if.data.op_args.lsu.offset)-1]}}, execute_if.data.op_args.lsu.offset[$bits(execute_if.data.op_args.lsu.offset)-2:0]};
    end
    wire [NUM_LANES-1:0][(2 + 1)-1:0] mem_req_atype;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire [MEM_ADDRW-1:0] block_addr = full_addr[i][MEM_ASHIFT +: MEM_ADDRW];
        wire [MEM_ADDRW-1:0] io_addr_start = MEM_ADDRW'(32'(32'h00000040) >> MEM_ASHIFT);
        wire [MEM_ADDRW-1:0] io_addr_end = MEM_ADDRW'(32'(32'h00010000) >> MEM_ASHIFT);
        assign mem_req_atype[i][0] = req_is_fence;
        assign mem_req_atype[i][1] = (block_addr >= io_addr_start) && (block_addr < io_addr_end);
        wire [MEM_ADDRW-1:0] lmem_addr_start = MEM_ADDRW'(32'(2130706432) >> MEM_ASHIFT);
        wire [MEM_ADDRW-1:0] lmem_addr_end = MEM_ADDRW'((32'(2130706432) + 32'(1 << 14)) >> MEM_ASHIFT);
        assign mem_req_atype[i][2] = (block_addr >= lmem_addr_start) && (block_addr < lmem_addr_end);
    end
    wire                            mem_req_valid;
    wire [NUM_LANES-1:0]            mem_req_mask;
    wire                            mem_req_rw;
    wire [NUM_LANES-1:0][LSU_ADDR_WIDTH-1:0] mem_req_addr;
    wire [NUM_LANES-1:0][LSU_WORD_SIZE-1:0] mem_req_byteen;
    reg  [NUM_LANES-1:0][LSU_WORD_SIZE*8-1:0] mem_req_data;
    wire [TAG_WIDTH-1:0]            mem_req_tag;
    wire                            mem_req_ready;
    wire                            mem_rsp_valid;
    wire [NUM_LANES-1:0]            mem_rsp_mask;
    wire [NUM_LANES-1:0][LSU_WORD_SIZE*8-1:0] mem_rsp_data;
    wire [TAG_WIDTH-1:0]            mem_rsp_tag;
    wire                            mem_rsp_sop;
    wire                            mem_rsp_eop;
    wire                            mem_rsp_ready;
    wire mem_req_fire = mem_req_valid && mem_req_ready;
    wire mem_rsp_fire = mem_rsp_valid && mem_rsp_ready;
    wire mem_rsp_sop_pkt, mem_rsp_eop_pkt;
    wire no_rsp_buf_valid, no_rsp_buf_ready;
    reg fence_lock;
    assign req_is_fence = (execute_if.data.op_type[3:2] == 3);
    always @(posedge clk) begin
        if (reset) begin
            fence_lock <= 0;
        end else begin
            if (mem_req_fire && req_is_fence && execute_if.data.eop) begin
                fence_lock <= 1;
            end
            if (mem_rsp_fire && rsp_is_fence && mem_rsp_eop_pkt) begin
                fence_lock <= 0;
            end
        end
    end
    wire req_skip = req_is_fence && ~execute_if.data.eop;
    wire no_rsp_buf_enable = (mem_req_rw && ~execute_if.data.wb) || req_skip;
    assign mem_req_valid = execute_if.valid
                        && ~req_skip
                        && ~(no_rsp_buf_enable && ~no_rsp_buf_ready)
                        && ~fence_lock;
    assign no_rsp_buf_valid = execute_if.valid
                           && no_rsp_buf_enable
                           && (req_skip || mem_req_ready)
                           && ~fence_lock;
    assign execute_if.ready = (mem_req_ready || req_skip)
                           && ~(no_rsp_buf_enable && ~no_rsp_buf_ready)
                           && ~fence_lock;
    assign mem_req_mask = execute_if.data.tmask;
    assign mem_req_rw = execute_if.data.op_args.lsu.is_store;
    wire [NUM_LANES-1:0][REQ_ASHIFT-1:0] req_align;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign req_align[i] = full_addr[i][REQ_ASHIFT-1:0];
        assign mem_req_addr[i] = full_addr[i][32-1:REQ_ASHIFT];
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        reg [LSU_WORD_SIZE-1:0] mem_req_byteen_r;
        always @(*) begin
            mem_req_byteen_r = '0;
            case (execute_if.data.op_type[1:0])
                0: begin  
                    mem_req_byteen_r[req_align[i]] = 1'b1;
                end
                1: begin  
                    mem_req_byteen_r[{req_align[i][REQ_ASHIFT-1:1], 1'b0}] = 1'b1;
                    mem_req_byteen_r[{req_align[i][REQ_ASHIFT-1:1], 1'b1}] = 1'b1;
                end
                default : mem_req_byteen_r = {LSU_WORD_SIZE{1'b1}};
            endcase
        end
        assign mem_req_byteen[i] = mem_req_byteen_r;
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire lsu_req_fire = execute_if.valid && execute_if.ready;
;
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        always @(*) begin
            mem_req_data[i] = execute_if.data.rs2_data[i];
            case (req_align[i])
                1: mem_req_data[i][32-1:8]  = execute_if.data.rs2_data[i][32-9:0];
                2: mem_req_data[i][32-1:16] = execute_if.data.rs2_data[i][32-17:0];
                3: mem_req_data[i][32-1:24] = execute_if.data.rs2_data[i][32-25:0];
                default:;
            endcase
        end
    end
    wire [LSUQ_SIZEW-1:0] pkt_waddr, pkt_raddr;
    if (PID_BITS != 0) begin
        reg [(2 * (2 / 2))-1:0][PID_BITS:0] pkt_ctr;
        reg [(2 * (2 / 2))-1:0] pkt_sop, pkt_eop;
        wire mem_req_rd_fire     = mem_req_fire && ~mem_req_rw;
        wire mem_req_rd_sop_fire = mem_req_rd_fire && execute_if.data.sop;
        wire mem_req_rd_eop_fire = mem_req_rd_fire && execute_if.data.eop;
        wire mem_rsp_eop_fire    = mem_rsp_fire && mem_rsp_eop;
        wire full;
        VX_allocator #(
            .SIZE ((2 * (2 / 2)))
        ) pkt_allocator (
            .clk        (clk),
            .reset      (reset),
            .acquire_en (mem_req_rd_eop_fire),
            .acquire_addr(pkt_waddr),
            .release_en (mem_rsp_eop_pkt),
            .release_addr(pkt_raddr),
            . empty (),
            .full       (full)
        );
        wire rd_during_wr = mem_req_rd_fire && mem_rsp_eop_fire && (pkt_raddr == pkt_waddr);
        always @(posedge clk) begin
            if (reset) begin
                pkt_ctr <= '0;
                pkt_sop <= '0;
                pkt_eop <= '0;
            end else begin
                if (mem_req_rd_sop_fire) begin
                    pkt_sop[pkt_waddr] <= 1;
                end
                if (mem_req_rd_eop_fire) begin
                    pkt_eop[pkt_waddr] <= 1;
                end
                if (mem_rsp_fire) begin
                    pkt_sop[pkt_raddr] <= 0;
                end
                if (mem_rsp_eop_pkt) begin
                    pkt_eop[pkt_raddr] <= 0;
                end
                if (~rd_during_wr) begin
                    if (mem_req_rd_fire) begin
                        pkt_ctr[pkt_waddr] <= pkt_ctr[pkt_waddr] + PID_BITS'(1);
                    end
                    if (mem_rsp_eop_fire) begin
                        pkt_ctr[pkt_raddr] <= pkt_ctr[pkt_raddr] - PID_BITS'(1);
                    end
                end
            end
        end
        assign mem_rsp_sop_pkt = pkt_sop[pkt_raddr];
        assign mem_rsp_eop_pkt = mem_rsp_eop_fire && pkt_eop[pkt_raddr] && (pkt_ctr[pkt_raddr] == 1);
    end else begin
        assign pkt_waddr = 0;
        assign mem_rsp_sop_pkt = mem_rsp_sop;
        assign mem_rsp_eop_pkt = mem_rsp_eop;
    end
    assign mem_req_tag = {
        execute_if.data.uuid,
        execute_if.data.wid,
        execute_if.data.PC,
        execute_if.data.wb,
        execute_if.data.rd,
        execute_if.data.op_type,
        req_align,
        execute_if.data.pid,
        pkt_waddr,
        req_is_fence
    };
    wire                                    lsu_mem_req_valid;
    wire                                    lsu_mem_req_rw;
    wire [NUM_LANES-1:0]                    lsu_mem_req_mask;
    wire [NUM_LANES-1:0][LSU_WORD_SIZE-1:0] lsu_mem_req_byteen;
    wire [NUM_LANES-1:0][LSU_ADDR_WIDTH-1:0] lsu_mem_req_addr;
    wire [NUM_LANES-1:0][(2 + 1)-1:0] lsu_mem_req_atype;
    wire [NUM_LANES-1:0][(LSU_WORD_SIZE*8)-1:0] lsu_mem_req_data;
    wire [LSU_TAG_WIDTH-1:0]                lsu_mem_req_tag;
    wire                                    lsu_mem_req_ready;
    wire                                    lsu_mem_rsp_valid;
    wire [NUM_LANES-1:0]                    lsu_mem_rsp_mask;
    wire [NUM_LANES-1:0][(LSU_WORD_SIZE*8)-1:0] lsu_mem_rsp_data;
    wire [LSU_TAG_WIDTH-1:0]                lsu_mem_rsp_tag;
    wire                                    lsu_mem_rsp_ready;
    wire [1-1:0] mem_scheduler_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mem_scheduler_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mem_scheduler_reset)                          
    );
    VX_mem_scheduler #(
        .INSTANCE_ID ($sformatf("%s-scheduler", INSTANCE_ID)),
        .CORE_REQS   (NUM_LANES),
        .MEM_CHANNELS(NUM_LANES),
        .WORD_SIZE   (LSU_WORD_SIZE),
        .LINE_SIZE   (LSU_WORD_SIZE),
        .ADDR_WIDTH  (LSU_ADDR_WIDTH),
        .ATYPE_WIDTH ((2 + 1)),
        .TAG_WIDTH   (TAG_WIDTH),
        .CORE_QUEUE_SIZE ((2 * (2 / 2))),
        .MEM_QUEUE_SIZE (((((2 * (2 / 2))) > ((((2 * (32 / 8)) < (16)) ? (2 * (32 / 8)) : (16)) / (32 / 8))) ? ((2 * (2 / 2))) : ((((2 * (32 / 8)) < (16)) ? (2 * (32 / 8)) : (16)) / (32 / 8)))),
        .UUID_WIDTH  (1),
        .RSP_PARTIAL (1),
        .MEM_OUT_BUF (0),
        .CORE_OUT_BUF(0)
    ) mem_scheduler (
        .clk            (clk),
        .reset          (mem_scheduler_reset),
        .core_req_valid (mem_req_valid),
        .core_req_rw    (mem_req_rw),
        .core_req_mask  (mem_req_mask),
        .core_req_byteen(mem_req_byteen),
        .core_req_addr  (mem_req_addr),
        .core_req_atype (mem_req_atype),
        .core_req_data  (mem_req_data),
        .core_req_tag   (mem_req_tag),
        .core_req_ready (mem_req_ready),
        . core_req_empty (),
        . core_req_sent (),
        .core_rsp_valid (mem_rsp_valid),
        .core_rsp_mask  (mem_rsp_mask),
        .core_rsp_data  (mem_rsp_data),
        .core_rsp_tag   (mem_rsp_tag),
        .core_rsp_sop   (mem_rsp_sop),
        .core_rsp_eop   (mem_rsp_eop),
        .core_rsp_ready (mem_rsp_ready),
        .mem_req_valid  (lsu_mem_req_valid),
        .mem_req_rw     (lsu_mem_req_rw),
        .mem_req_mask   (lsu_mem_req_mask),
        .mem_req_byteen (lsu_mem_req_byteen),
        .mem_req_addr   (lsu_mem_req_addr),
        .mem_req_atype  (lsu_mem_req_atype),
        .mem_req_data   (lsu_mem_req_data),
        .mem_req_tag    (lsu_mem_req_tag),
        .mem_req_ready  (lsu_mem_req_ready),
        .mem_rsp_valid  (lsu_mem_rsp_valid),
        .mem_rsp_mask   (lsu_mem_rsp_mask),
        .mem_rsp_data   (lsu_mem_rsp_data),
        .mem_rsp_tag    (lsu_mem_rsp_tag),
        .mem_rsp_ready  (lsu_mem_rsp_ready)
    );
    assign lsu_mem_if.req_valid = lsu_mem_req_valid;
    assign lsu_mem_if.req_data.mask = lsu_mem_req_mask;
    assign lsu_mem_if.req_data.rw = lsu_mem_req_rw;
    assign lsu_mem_if.req_data.byteen = lsu_mem_req_byteen;
    assign lsu_mem_if.req_data.addr = lsu_mem_req_addr;
    assign lsu_mem_if.req_data.atype = lsu_mem_req_atype;
    assign lsu_mem_if.req_data.data = lsu_mem_req_data;
    assign lsu_mem_if.req_data.tag = lsu_mem_req_tag;
    assign lsu_mem_req_ready = lsu_mem_if.req_ready;
    assign lsu_mem_rsp_valid = lsu_mem_if.rsp_valid;
    assign lsu_mem_rsp_mask = lsu_mem_if.rsp_data.mask;
    assign lsu_mem_rsp_data = lsu_mem_if.rsp_data.data;
    assign lsu_mem_rsp_tag = lsu_mem_if.rsp_data.tag;
    assign lsu_mem_if.rsp_ready = lsu_mem_rsp_ready;
    wire [1-1:0] rsp_uuid;
    wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0] rsp_wid;
    wire [(32-1)-1:0] rsp_pc;
    wire rsp_wb;
    wire [$clog2(32)-1:0] rsp_rd;
    wire [4-1:0] rsp_op_type;
    wire [NUM_LANES-1:0][REQ_ASHIFT-1:0] rsp_align;
    wire [PID_WIDTH-1:0] rsp_pid;
    assign {
        rsp_uuid,
        rsp_wid,
        rsp_pc,
        rsp_wb,
        rsp_rd,
        rsp_op_type,
        rsp_align,
        rsp_pid,
        pkt_raddr,
        rsp_is_fence
    } = mem_rsp_tag;
    reg [NUM_LANES-1:0][32-1:0] rsp_data;
    for (genvar i = 0; i < NUM_LANES; i++) begin
        wire [31:0] rsp_data32 = mem_rsp_data[i];
        wire [15:0] rsp_data16 = rsp_align[i][1] ? rsp_data32[31:16] : rsp_data32[15:0];
        wire [7:0]  rsp_data8  = rsp_align[i][0] ? rsp_data16[15:8] : rsp_data16[7:0];
        always @(*) begin
            case (rsp_op_type[2:0])
            3'b000:  rsp_data[i] = 32'(signed'(rsp_data8));
            3'b001:  rsp_data[i] = 32'(signed'(rsp_data16));
            3'b100: rsp_data[i] = 32'(unsigned'(rsp_data8));
            3'b101: rsp_data[i] = 32'(unsigned'(rsp_data16));
            3'b010:  rsp_data[i] = 32'(signed'(rsp_data32));
            default: rsp_data[i] = 'x;
            endcase
        end
    end
    VX_elastic_buffer #(
        .DATAW (1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + NUM_LANES + (32-1) + 1 + $clog2(32) + (NUM_LANES * 32) + PID_WIDTH + 1 + 1),
        .SIZE  (2)
    ) rsp_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (mem_rsp_valid),
        .ready_in  (mem_rsp_ready),
        .data_in   ({rsp_uuid, rsp_wid, mem_rsp_mask, rsp_pc, rsp_wb, rsp_rd, rsp_data, rsp_pid, mem_rsp_sop_pkt, mem_rsp_eop_pkt}),
        .data_out  ({commit_rsp_if.data.uuid, commit_rsp_if.data.wid, commit_rsp_if.data.tmask, commit_rsp_if.data.PC, commit_rsp_if.data.wb, commit_rsp_if.data.rd, commit_rsp_if.data.data, commit_rsp_if.data.pid, commit_rsp_if.data.sop, commit_rsp_if.data.eop}),
        .valid_out (commit_rsp_if.valid),
        .ready_out (commit_rsp_if.ready)
    );
    VX_elastic_buffer #(
        .DATAW (1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + NUM_LANES + (32-1) + PID_WIDTH + 1 + 1),
        .SIZE  (2)
    ) no_rsp_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (no_rsp_buf_valid),
        .ready_in  (no_rsp_buf_ready),
        .data_in   ({execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.PC, execute_if.data.pid, execute_if.data.sop, execute_if.data.eop}),
        .data_out  ({commit_no_rsp_if.data.uuid, commit_no_rsp_if.data.wid, commit_no_rsp_if.data.tmask, commit_no_rsp_if.data.PC, commit_no_rsp_if.data.pid, commit_no_rsp_if.data.sop, commit_no_rsp_if.data.eop}),
        .valid_out (commit_no_rsp_if.valid),
        .ready_out (commit_no_rsp_if.ready)
    );
    assign commit_no_rsp_if.data.rd   = '0;
    assign commit_no_rsp_if.data.wb   = 1'b0;
    assign commit_no_rsp_if.data.data = commit_rsp_if.data.data;  
    VX_stream_arb #(
        .NUM_INPUTS (2),
        .DATAW      (RSP_ARB_DATAW),
        .ARBITER    ("P"),  
        .OUT_BUF    (3)
    ) rsp_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  ({commit_no_rsp_if.valid, commit_rsp_if.valid}),
        .ready_in  ({commit_no_rsp_if.ready, commit_rsp_if.ready}),
        .data_in   ({commit_no_rsp_if.data, commit_rsp_if.data}),
        .data_out  (commit_if.data),
        .valid_out (commit_if.valid),
        .ready_out (commit_if.ready),
        . sel_out ()
    );
endmodule
