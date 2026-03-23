module VX_lsu_unit import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0
) (    
   input wire               clk,
    input wire              reset,
    VX_mem_bus_if.master    cache_bus_if [DCACHE_NUM_REQS],
    VX_dispatch_if.slave    dispatch_if [(((4) < (4)) ? (4) : (4))],
    VX_commit_if.master     commit_if [(((4) < (4)) ? (4) : (4))]
);
    localparam BLOCK_SIZE   = 1;
    localparam NUM_LANES    = (((4) < (4)) ? (4) : (4));
    localparam PID_BITS     = $clog2(4 / NUM_LANES);
    localparam PID_WIDTH    = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam RSP_ARB_DATAW= 1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + 32 + $clog2(32) + 1 + NUM_LANES * 32 + PID_WIDTH + 1 + 1;
    localparam LSUQ_SIZEW   = ((((2 * (4 / (((4) < (4)) ? (4) : (4))))) > 1) ? $clog2((2 * (4 / (((4) < (4)) ? (4) : (4))))) : 1);
    localparam MEM_ASHIFT   = $clog2(16);    
    localparam MEM_ADDRW    = 32 - MEM_ASHIFT;
    localparam REQ_ASHIFT   = $clog2(DCACHE_WORD_SIZE);
    localparam CACHE_TAG_WIDTH = 1 + (NUM_LANES * (1 + 1)) + LSUQ_TAG_BITS;
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) execute_if[BLOCK_SIZE]();
    wire [1-1:0] dispatch_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __dispatch_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (dispatch_reset)                          
    );
    VX_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_REG    (1)
    ) dispatch_unit (
        .clk        (clk),
        .reset      (dispatch_reset),
        .dispatch_if(dispatch_if),
        .execute_if (execute_if)
    );
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) commit_st_if();
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) commit_ld_if();
    localparam SMEM_START_B = MEM_ADDRW'(32'(2130706432) >> MEM_ASHIFT);
    localparam SMEM_END_B = MEM_ADDRW'((32'(2130706432) + (1 << 14)) >> MEM_ASHIFT);
    localparam TAG_WIDTH = 1 + (NUM_LANES * (1 + 1)) + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + 32 + NUM_LANES + $clog2(32) + 4 + (NUM_LANES * (REQ_ASHIFT)) + 0 + PID_WIDTH + LSUQ_SIZEW;
    wire [NUM_LANES-1:0][(1 + 1)-1:0] lsu_addr_type;
    wire [NUM_LANES-1:0][32-1:0] full_addr;    
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign full_addr[i] = execute_if[0].data.rs1_data[i][32-1:0] + execute_if[0].data.imm;
    end
    wire lsu_is_dup;
    assign lsu_is_dup = 0;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire [MEM_ADDRW-1:0] full_addr_b = full_addr[i][MEM_ASHIFT +: MEM_ADDRW];
        wire is_addr_io = (full_addr_b >= MEM_ADDRW'(32'((2130706432 + (1 << 14))) >> MEM_ASHIFT));
        wire is_addr_sm = (full_addr_b >= SMEM_START_B) && (full_addr_b < SMEM_END_B);
        assign lsu_addr_type[i] = {is_addr_io, is_addr_sm};
    end
    wire mem_req_empty;
    wire st_rsp_ready;
    wire lsu_valid, lsu_ready;
    wire is_fence = (execute_if[0].data.op_type[3:2] == 3);
    wire fence_wait = is_fence && ~mem_req_empty;
    assign lsu_valid = execute_if[0].valid && ~fence_wait;
    assign execute_if[0].ready = lsu_ready && ~fence_wait;
    wire                            mem_req_valid;
    wire [NUM_LANES-1:0]            mem_req_mask;
    wire                            mem_req_rw;  
    wire [NUM_LANES-1:0][32-REQ_ASHIFT-1:0] mem_req_addr;
    reg  [NUM_LANES-1:0][DCACHE_WORD_SIZE-1:0] mem_req_byteen;
    reg  [NUM_LANES-1:0][32-1:0] mem_req_data;
    wire [TAG_WIDTH-1:0]            mem_req_tag;
    wire                            mem_req_ready;
    wire                            mem_rsp_valid;
    wire [NUM_LANES-1:0]            mem_rsp_mask;
    wire [NUM_LANES-1:0][32-1:0] mem_rsp_data;
    wire [TAG_WIDTH-1:0]            mem_rsp_tag;
    wire                            mem_rsp_sop;
    wire                            mem_rsp_eop;
    wire                            mem_rsp_ready;
    assign mem_req_valid = lsu_valid;
    assign lsu_ready = mem_req_ready 
                   && (~mem_req_rw || st_rsp_ready);  
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign mem_req_mask[i] = execute_if[0].data.tmask[i] && (~lsu_is_dup || (i == 0));
    end
    assign mem_req_rw = ~execute_if[0].data.wb;    
    wire mem_req_fire = mem_req_valid && mem_req_ready;
    wire mem_rsp_fire = mem_rsp_valid && mem_rsp_ready;
    wire [NUM_LANES-1:0][REQ_ASHIFT-1:0] req_align;
    for (genvar i = 0; i < NUM_LANES; ++i) begin  
        assign req_align[i] = full_addr[i][REQ_ASHIFT-1:0];
        assign mem_req_addr[i] = full_addr[i][32-1:REQ_ASHIFT];
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        always @(*) begin
            mem_req_byteen[i] = '0;
            case (execute_if[0].data.op_type[1:0])
                0: begin  
                    mem_req_byteen[i][req_align[i]] = 1'b1;
                end
                1: begin  
                    mem_req_byteen[i][{req_align[i][REQ_ASHIFT-1:1], 1'b0}] = 1'b1;
                    mem_req_byteen[i][{req_align[i][REQ_ASHIFT-1:1], 1'b1}] = 1'b1;
                end
                default : mem_req_byteen[i] = {DCACHE_WORD_SIZE{1'b1}};
            endcase
        end
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire lsu_req_fire = execute_if[0].valid && execute_if[0].ready;        
;
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        always @(*) begin
            mem_req_data[i] = execute_if[0].data.rs2_data[i];
            case (req_align[i])
                1: mem_req_data[i][32-1:8]  = execute_if[0].data.rs2_data[i][32-9:0];
                2: mem_req_data[i][32-1:16] = execute_if[0].data.rs2_data[i][32-17:0];
                3: mem_req_data[i][32-1:24] = execute_if[0].data.rs2_data[i][32-25:0];
                default:;
            endcase
        end
    end
    wire [LSUQ_SIZEW-1:0] pkt_waddr, pkt_raddr;
    wire mem_rsp_sop_pkt, mem_rsp_eop_pkt;
    if (PID_BITS != 0) begin
        reg [(2 * (4 / (((4) < (4)) ? (4) : (4))))-1:0][PID_BITS:0] pkt_ctr;
        reg [(2 * (4 / (((4) < (4)) ? (4) : (4))))-1:0] pkt_sop, pkt_eop;
        wire mem_req_rd_fire     = mem_req_fire && execute_if[0].data.wb;
        wire mem_req_rd_sop_fire = mem_req_rd_fire && execute_if[0].data.sop;
        wire mem_req_rd_eop_fire = mem_req_rd_fire && execute_if[0].data.eop;
        wire mem_rsp_eop_fire    = mem_rsp_fire && mem_rsp_eop;
        wire full;
        VX_allocator #(
            .SIZE ((2 * (4 / (((4) < (4)) ? (4) : (4)))))
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
        execute_if[0].data.uuid, lsu_addr_type, execute_if[0].data.wid, execute_if[0].data.tmask, execute_if[0].data.PC, execute_if[0].data.rd, execute_if[0].data.op_type, req_align, execute_if[0].data.pid, pkt_waddr
    };
    wire [DCACHE_NUM_REQS-1:0]              cache_req_valid;
    wire [DCACHE_NUM_REQS-1:0]              cache_req_rw;
    wire [DCACHE_NUM_REQS-1:0][(32/8)-1:0] cache_req_byteen;
    wire [DCACHE_NUM_REQS-1:0][DCACHE_ADDR_WIDTH-1:0] cache_req_addr;
    wire [DCACHE_NUM_REQS-1:0][32-1:0] cache_req_data;
    wire [DCACHE_NUM_REQS-1:0][CACHE_TAG_WIDTH-1:0] cache_req_tag;
    wire [DCACHE_NUM_REQS-1:0]              cache_req_ready;
    wire [DCACHE_NUM_REQS-1:0]              cache_rsp_valid;
    wire [DCACHE_NUM_REQS-1:0][32-1:0] cache_rsp_data;
    wire [DCACHE_NUM_REQS-1:0][CACHE_TAG_WIDTH-1:0] cache_rsp_tag;
    wire [DCACHE_NUM_REQS-1:0]              cache_rsp_ready;
    wire [1-1:0] mem_scheduler_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __mem_scheduler_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (mem_scheduler_reset)                          
    );
    VX_mem_scheduler #(
        .INSTANCE_ID ($sformatf("core%0d-lsu-memsched", CORE_ID)),
        .NUM_REQS    (LSU_MEM_REQS), 
        .NUM_BANKS   (DCACHE_NUM_REQS),
        .ADDR_WIDTH  (DCACHE_ADDR_WIDTH),
        .DATA_WIDTH  (32),
        .QUEUE_SIZE  ((2 * (4 / (((4) < (4)) ? (4) : (4))))),
        .TAG_WIDTH   (TAG_WIDTH),
        .MEM_TAG_ID  (1 + (NUM_LANES * (1 + 1))),
        .UUID_WIDTH  (1),
        .RSP_PARTIAL (1),
        .MEM_OUT_REG (2)
    ) mem_scheduler (
        .clk            (clk),
        .reset          (mem_scheduler_reset),
        .req_valid      (mem_req_valid),
        .req_rw         (mem_req_rw),
        .req_mask       (mem_req_mask),
        .req_byteen     (mem_req_byteen),
        .req_addr       (mem_req_addr),
        .req_data       (mem_req_data),
        .req_tag        (mem_req_tag),
        .req_empty      (mem_req_empty),
        .req_ready      (mem_req_ready),
        . write_notify (),
        .rsp_valid      (mem_rsp_valid),
        .rsp_mask       (mem_rsp_mask),
        .rsp_data       (mem_rsp_data),
        .rsp_tag        (mem_rsp_tag),
        .rsp_sop        (mem_rsp_sop),
        .rsp_eop        (mem_rsp_eop),
        .rsp_ready      (mem_rsp_ready),
        .mem_req_valid  (cache_req_valid),
        .mem_req_rw     (cache_req_rw),
        .mem_req_byteen (cache_req_byteen),
        .mem_req_addr   (cache_req_addr),
        .mem_req_data   (cache_req_data),
        .mem_req_tag    (cache_req_tag),
        .mem_req_ready  (cache_req_ready),
        .mem_rsp_valid  (cache_rsp_valid),
        .mem_rsp_data   (cache_rsp_data),
        .mem_rsp_tag    (cache_rsp_tag),
        .mem_rsp_ready  (cache_rsp_ready)
    );
    for (genvar i = 0; i < DCACHE_NUM_REQS; ++i) begin
        assign cache_bus_if[i].req_valid = cache_req_valid[i];
        assign cache_bus_if[i].req_data.rw = cache_req_rw[i];
        assign cache_bus_if[i].req_data.byteen = cache_req_byteen[i];
        assign cache_bus_if[i].req_data.addr = cache_req_addr[i];
        assign cache_bus_if[i].req_data.data = cache_req_data[i];
        assign cache_req_ready[i] = cache_bus_if[i].req_ready;
        assign cache_rsp_valid[i] = cache_bus_if[i].rsp_valid;
        assign cache_rsp_data[i] = cache_bus_if[i].rsp_data.data;
        assign cache_bus_if[i].rsp_ready = cache_rsp_ready[i];
    end
    for (genvar i = 0; i < DCACHE_NUM_REQS; ++i) begin
        wire [1-1:0]                          cache_req_uuid, cache_rsp_uuid;
        wire [NUM_LANES-1:0][(1 + 1)-1:0] cache_req_type, cache_rsp_type;        
        wire [$clog2((2 * (4 / (((4) < (4)) ? (4) : (4)))))-1:0]                   cache_req_tag_x, cache_rsp_tag_x;
        if (DCACHE_NUM_BATCHES > 1) begin
            wire [DCACHE_NUM_BATCHES-1:0][(1 + 1)-1:0] cache_req_type_b, cache_rsp_type_b;            
            wire [(1 + 1)-1:0] cache_req_type_bi, cache_rsp_type_bi;
            wire [DCACHE_BATCH_SEL_BITS-1:0] cache_req_bid, cache_rsp_bid;
            assign {cache_req_uuid, cache_req_type, cache_req_bid, cache_req_tag_x} = cache_req_tag[i];
            assign cache_req_type_bi = cache_req_type_b[cache_req_bid];
            assign cache_bus_if[i].req_data.tag = {cache_req_uuid, cache_req_bid, cache_req_tag_x, cache_req_type_bi};
            assign {cache_rsp_uuid, cache_rsp_bid, cache_rsp_tag_x, cache_rsp_type_bi} = cache_bus_if[i].rsp_data.tag;
            assign cache_rsp_type_b = {DCACHE_NUM_BATCHES{cache_rsp_type_bi}};
            assign cache_rsp_tag[i] = {cache_rsp_uuid, cache_rsp_type, cache_rsp_bid, cache_rsp_tag_x};
            for (genvar j = 0; j < DCACHE_NUM_BATCHES; ++j) begin
                localparam k = j * DCACHE_NUM_REQS + i;                
                if (k < NUM_LANES) begin
                    assign cache_req_type_b[j] = cache_req_type[k];
                    assign cache_rsp_type[k] = cache_rsp_type_b[j];
                end else begin
                    assign cache_req_type_b[j] = '0;
                end
            end
        end else begin
            assign {cache_req_uuid, cache_req_type, cache_req_tag_x} = cache_req_tag[i];
            assign cache_bus_if[i].req_data.tag = {cache_req_uuid, cache_req_tag_x, cache_req_type[i]};
            assign {cache_rsp_uuid, cache_rsp_tag_x, cache_rsp_type[i]} = cache_bus_if[i].rsp_data.tag;
            assign cache_rsp_tag[i] = {cache_rsp_uuid, cache_rsp_type, cache_rsp_tag_x};        
            for (genvar j = 0; j < DCACHE_NUM_REQS; ++j) begin
                if (i != j) begin
                    assign cache_rsp_type[j] = '0;
                end
            end
        end
    end
    wire [1-1:0] rsp_uuid;
    wire [NUM_LANES-1:0][(1 + 1)-1:0] rsp_addr_type;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] rsp_wid;
    wire [NUM_LANES-1:0] rsp_tmask_uq;
    wire [32-1:0] rsp_pc;
    wire [$clog2(32)-1:0] rsp_rd;
    wire [4-1:0] rsp_op_type;
    wire [NUM_LANES-1:0][REQ_ASHIFT-1:0] rsp_align;
    wire [PID_WIDTH-1:0] rsp_pid;
    wire rsp_is_dup;
    assign rsp_is_dup = 0;
    assign {
        rsp_uuid, rsp_addr_type, rsp_wid, rsp_tmask_uq, rsp_pc, rsp_rd, rsp_op_type, rsp_align, rsp_pid, pkt_raddr
    } = mem_rsp_tag;
    reg [NUM_LANES-1:0][32-1:0] rsp_data;
    wire [NUM_LANES-1:0] rsp_tmask;
    for (genvar i = 0; i < NUM_LANES; i++) begin
        wire [31:0] rsp_data32 = (i == 0 || rsp_is_dup) ? mem_rsp_data[0] : mem_rsp_data[i];
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
    assign rsp_tmask = rsp_is_dup ? rsp_tmask_uq : mem_rsp_mask;
    VX_elastic_buffer #(
        .DATAW (1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + 32 + $clog2(32) + (NUM_LANES * 32) + PID_WIDTH + 1 + 1),
        .SIZE  (2)
    ) ld_rsp_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (mem_rsp_valid),
        .ready_in  (mem_rsp_ready),
        .data_in   ({rsp_uuid, rsp_wid, rsp_tmask, rsp_pc, rsp_rd, rsp_data, rsp_pid, mem_rsp_sop_pkt, mem_rsp_eop_pkt}),
        .data_out  ({commit_ld_if.data.uuid, commit_ld_if.data.wid, commit_ld_if.data.tmask, commit_ld_if.data.PC, commit_ld_if.data.rd, commit_ld_if.data.data, commit_ld_if.data.pid, commit_ld_if.data.sop, commit_ld_if.data.eop}),
        .valid_out (commit_ld_if.valid),
        .ready_out (commit_ld_if.ready)
    );
    assign commit_ld_if.data.wb = 1'b1;
    VX_elastic_buffer #(
        .DATAW (1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + 32 + PID_WIDTH + 1 + 1),
        .SIZE  (2)
    ) st_rsp_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (mem_req_fire && mem_req_rw),
        .ready_in  (st_rsp_ready),
        .data_in   ({execute_if[0].data.uuid, execute_if[0].data.wid, execute_if[0].data.tmask, execute_if[0].data.PC, execute_if[0].data.pid, execute_if[0].data.sop, execute_if[0].data.eop}),
        .data_out  ({commit_st_if.data.uuid, commit_st_if.data.wid, commit_st_if.data.tmask, commit_st_if.data.PC, commit_st_if.data.pid, commit_st_if.data.sop, commit_st_if.data.eop}),
        .valid_out (commit_st_if.valid),
        .ready_out (commit_st_if.ready)
    );
    assign commit_st_if.data.rd   = '0;
    assign commit_st_if.data.wb   = 1'b0;
    assign commit_st_if.data.data = commit_ld_if.data.data;  
    wire [1-1:0] commit_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __commit_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (commit_reset)                          
    );
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) commit_arb_if[1]();
    VX_stream_arb #(
        .NUM_INPUTS (2),
        .DATAW      (RSP_ARB_DATAW),
        .OUT_REG    (1)
    ) rsp_arb (
        .clk       (clk),
        .reset     (commit_reset),
        .valid_in  ({commit_st_if.valid, commit_ld_if.valid}),
        .ready_in  ({commit_st_if.ready, commit_ld_if.ready}),
        .data_in   ({commit_st_if.data, commit_ld_if.data}),
        .data_out  (commit_arb_if[0].data),
        .valid_out (commit_arb_if[0].valid), 
        .ready_out (commit_arb_if[0].ready),        
        . sel_out ()
    );
    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_REG    (3)
    ) gather_unit (
        .clk           (clk),
        .reset         (commit_reset),
        .commit_in_if  (commit_arb_if),
        .commit_out_if (commit_if)
    );
endmodule
