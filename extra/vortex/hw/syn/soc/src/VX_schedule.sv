module VX_schedule import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = "",
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    input base_dcrs_t       base_dcrs,
    VX_warp_ctl_if.slave    warp_ctl_if,
    VX_branch_ctl_if.slave  branch_ctl_if [(((4 / 8) != 0) ? (4 / 8) : 1)],
    VX_decode_sched_if.slave decode_sched_if,
    VX_commit_sched_if.slave commit_sched_if,
    VX_schedule_if.master   schedule_if,
    VX_sched_csr_if.master  sched_csr_if,
    output wire             busy
);
    reg [4-1:0] active_warps, active_warps_n;  
    reg [4-1:0] stalled_warps, stalled_warps_n;   
    reg [4-1:0][4-1:0] thread_masks, thread_masks_n;
    reg [4-1:0][(32-1)-1:0] warp_pcs, warp_pcs_n;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]    schedule_wid;
    wire [4-1:0] schedule_tmask;
    wire [(32-1)-1:0]     schedule_pc;
    wire                    schedule_valid;
    wire                    schedule_ready;
    wire                    join_valid;
    wire                    join_is_dvg;
    wire                    join_is_else;
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]    join_wid;
    wire [4-1:0] join_tmask;
    wire [(32-1)-1:0]     join_pc;
    reg [44-1:0] cycles;
    reg [4-1:0][23-1:0] issued_instrs;
    wire schedule_fire = schedule_valid && schedule_ready;
    wire schedule_if_fire = schedule_if.valid && schedule_if.ready;
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0]                  branch_valid;
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]   branch_wid;
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0]                  branch_taken;
    wire [(((4 / 8) != 0) ? (4 / 8) : 1)-1:0][(32-1)-1:0]    branch_dest;
    for (genvar i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
        assign branch_valid[i] = branch_ctl_if[i].valid;
        assign branch_wid[i]   = branch_ctl_if[i].wid;
        assign branch_taken[i] = branch_ctl_if[i].taken;
        assign branch_dest[i]  = branch_ctl_if[i].dest;
    end
    reg [4-1:0][4-1:0] barrier_masks, barrier_masks_n;
    reg [4-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] barrier_ctrs, barrier_ctrs_n;
    reg [4-1:0] barrier_stalls, barrier_stalls_n;
    reg [4-1:0] curr_barrier_mask_p1;
    wspawn_t wspawn;
    reg [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] wspawn_wid;
    reg is_single_warp;
    wire [$clog2(4+1)-1:0] active_warps_cnt;
    VX_popcount #( 
        .N ($bits(active_warps)), 
        .MODEL (1) 
    ) __active_warps_cnt__ ( 
        .data_in  (active_warps), 
        .data_out (active_warps_cnt) 
    );
    always @(*) begin
        active_warps_n  = active_warps;
        stalled_warps_n = stalled_warps;
        thread_masks_n  = thread_masks;
        barrier_masks_n = barrier_masks;
        barrier_ctrs_n  = barrier_ctrs;
        barrier_stalls_n= barrier_stalls;
        warp_pcs_n      = warp_pcs;
        if (wspawn.valid && is_single_warp) begin
            active_warps_n |= wspawn.wmask;
            for (integer i = 0; i < 4; ++i) begin
                if (wspawn.wmask[i]) begin
                    thread_masks_n[i][0] = 1;
                    warp_pcs_n[i] = wspawn.pc;
                end
            end
            stalled_warps_n[wspawn_wid] = 0;  
        end
        if (warp_ctl_if.valid && warp_ctl_if.tmc.valid) begin
            active_warps_n[warp_ctl_if.wid]  = (warp_ctl_if.tmc.tmask != 0);
            thread_masks_n[warp_ctl_if.wid]  = warp_ctl_if.tmc.tmask;
            stalled_warps_n[warp_ctl_if.wid] = 0;  
        end
        if (warp_ctl_if.valid && warp_ctl_if.split.valid) begin
            if (warp_ctl_if.split.is_dvg) begin
                thread_masks_n[warp_ctl_if.wid] = warp_ctl_if.split.then_tmask;
            end
            stalled_warps_n[warp_ctl_if.wid] = 0;  
        end
        if (join_valid) begin
            if (join_is_dvg) begin
                if (join_is_else) begin
                    warp_pcs_n[join_wid] = join_pc;
                end
                thread_masks_n[join_wid] = join_tmask;
            end
            stalled_warps_n[join_wid] = 0;  
        end
        curr_barrier_mask_p1 = barrier_masks[warp_ctl_if.barrier.id];
        curr_barrier_mask_p1[warp_ctl_if.wid] = 1;
        if (warp_ctl_if.valid && warp_ctl_if.barrier.valid) begin
            if (~warp_ctl_if.barrier.is_noop) begin
                if (~warp_ctl_if.barrier.is_global
                 && (barrier_ctrs[warp_ctl_if.barrier.id] == ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'(warp_ctl_if.barrier.size_m1))) begin
                    barrier_ctrs_n[warp_ctl_if.barrier.id] = '0;  
                    barrier_masks_n[warp_ctl_if.barrier.id] = '0;  
                    stalled_warps_n &= ~barrier_masks[warp_ctl_if.barrier.id];  
                    stalled_warps_n[warp_ctl_if.wid] = 0;  
                end else begin
                    barrier_ctrs_n[warp_ctl_if.barrier.id] = barrier_ctrs[warp_ctl_if.barrier.id] + ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'(1);
                    barrier_masks_n[warp_ctl_if.barrier.id] = curr_barrier_mask_p1;
                end
            end else begin
                stalled_warps_n[warp_ctl_if.wid] = 0;  
            end
        end
        for (integer i = 0; i < (((4 / 8) != 0) ? (4 / 8) : 1); ++i) begin
            if (branch_valid[i]) begin
                if (branch_taken[i]) begin
                    warp_pcs_n[branch_wid[i]] = branch_dest[i];
                end
                stalled_warps_n[branch_wid[i]] = 0;  
            end
        end
        if (decode_sched_if.valid && ~decode_sched_if.is_wstall) begin
            stalled_warps_n[decode_sched_if.wid] = 0;
        end
        if (sched_csr_if.unlock_warp) begin
            stalled_warps_n[sched_csr_if.unlock_wid] = 0;
        end
        if (schedule_fire) begin
            stalled_warps_n[schedule_wid] = 1;
        end
        if (schedule_if_fire) begin
            warp_pcs_n[schedule_if.data.wid] = schedule_if.data.PC + (32-1)'(2);
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            barrier_masks   <= '0;
            barrier_ctrs    <= '0;
            stalled_warps   <= '0;
            warp_pcs        <= '0;
            active_warps    <= '0;
            thread_masks    <= '0;
            barrier_stalls  <= '0;
            issued_instrs   <= '0;
            cycles          <= '0;
            wspawn.valid    <=  0;
            warp_pcs[0]     <= base_dcrs.startup_addr[1 +: (32-1)];
            active_warps[0] <= 1;
            thread_masks[0][0] <= 1;
            is_single_warp  <= 1;
        end else begin
            active_warps   <= active_warps_n;
            stalled_warps  <= stalled_warps_n;
            thread_masks   <= thread_masks_n;
            warp_pcs       <= warp_pcs_n;
            barrier_masks  <= barrier_masks_n;
            barrier_ctrs   <= barrier_ctrs_n;
            barrier_stalls <= barrier_stalls_n;
            is_single_warp <= (active_warps_cnt == $bits(active_warps_cnt)'(1));
            if (warp_ctl_if.valid && warp_ctl_if.wspawn.valid) begin
                wspawn.valid <= 1;
                wspawn.wmask <= warp_ctl_if.wspawn.wmask;
                wspawn.pc    <= warp_ctl_if.wspawn.pc;
                wspawn_wid   <= warp_ctl_if.wid;
            end
            if (wspawn.valid && is_single_warp) begin
                wspawn.valid <= 0;
            end
            if (schedule_if_fire) begin
                issued_instrs[schedule_if.data.wid] <= issued_instrs[schedule_if.data.wid] + 23'(1);
            end
            if (busy) begin
                cycles <= cycles + 1;
            end
        end
    end
    wire [1-1:0] split_join_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __split_join_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (split_join_reset)                          
    );
    VX_split_join #(
        .INSTANCE_ID ($sformatf("%s-splitjoin", INSTANCE_ID))
    ) split_join (
        .clk        (clk),
        .reset      (split_join_reset),
        .valid      (warp_ctl_if.valid),
        .wid        (warp_ctl_if.wid),
        .split      (warp_ctl_if.split),
        .sjoin      (warp_ctl_if.sjoin),
        .join_valid (join_valid),
        .join_is_dvg(join_is_dvg),
        .join_is_else(join_is_else),
        .join_wid   (join_wid),
        .join_tmask (join_tmask),
        .join_pc    (join_pc),
        .stack_wid  (warp_ctl_if.dvstack_wid),
        .stack_ptr  (warp_ctl_if.dvstack_ptr)
    );
    wire [4-1:0] ready_warps = active_warps & ~stalled_warps;
    VX_lzc #(
        .N (4),
        .REVERSE (1)
    ) wid_select (
        .data_in   (ready_warps),
        .data_out  (schedule_wid),
        .valid_out (schedule_valid)
    );
    wire [4-1:0][(4 + (32-1))-1:0] schedule_data;
    for (genvar i = 0; i < 4; ++i) begin
        assign schedule_data[i] = {thread_masks[i], warp_pcs[i]};
    end
    assign {schedule_tmask, schedule_pc} = {
        schedule_data[schedule_wid][(4 + (32-1))-1:(4 + (32-1))-4],
        schedule_data[schedule_wid][(4 + (32-1))-5:0]
    };
    localparam GNW_WIDTH = (((1 * 8 * 4) > 1) ? $clog2(1 * 8 * 4) : 1);
    wire [GNW_WIDTH-1:0] g_wid = (GNW_WIDTH'(CORE_ID) << $clog2(4)) + GNW_WIDTH'(schedule_wid);
    wire [GNW_WIDTH+16-1:0] w_uuid = {g_wid, 16'(schedule_pc)};
    wire [23-1:0] instr_uuid = 23'(w_uuid);
    VX_elastic_buffer #(
        .DATAW (4 + (32-1) + ((($clog2(4)) != 0) ? ($clog2(4)) : 1))
    ) out_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (schedule_valid),
        .ready_in  (schedule_ready),
        .data_in   ({schedule_tmask, schedule_pc, schedule_wid}),
        .data_out  ({schedule_if.data.tmask, schedule_if.data.PC, schedule_if.data.wid}),
        .valid_out (schedule_if.valid),
        .ready_out (schedule_if.ready)
    );
    assign schedule_if.data.uuid = instr_uuid;
    // === METASAT build-liveness probe (sim-only; ignored by synthesis) ===
`ifndef SYNTHESIS
    reg metasat_fix_printed = 1'b0;
    always @(posedge clk) begin
        if (schedule_fire && !metasat_fix_printed) begin
            $display("[METASAT-FIX-LIVE t=%0t] core=%0d uuid_width=%0d first_uuid=0x%0h",
                     $time, CORE_ID, $bits(instr_uuid), instr_uuid);
            metasat_fix_printed <= 1'b1;
        end
    end
`endif
    // === end METASAT probe ===
    reg [4-1:0] per_warp_incr;
    always @(*) begin
        per_warp_incr = 0;
        if (schedule_if_fire) begin
            per_warp_incr[schedule_if.data.wid] = 1;
        end
    end
    wire [4-1:0] pending_warp_empty;
    wire [4-1:0] pending_warp_alm_empty;
    wire [4-1:0] pending_instr_reset;                        
    VX_reset_relay #(.N(4), .MAX_FANOUT(8)) __pending_instr_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (pending_instr_reset)                          
    );
    for (genvar i = 0; i < 4; ++i) begin
        VX_pending_size #(
            .SIZE      (4096),
            .ALM_EMPTY (1)
        ) counter (
            .clk       (clk),
            .reset     (pending_instr_reset[i]),
            .incr      (per_warp_incr[i]),
            .decr      (commit_sched_if.committed_warps[i]),
            .empty     (pending_warp_empty[i]),
            .alm_empty (pending_warp_alm_empty[i]),
            . full (),
            . alm_full (),
            . size ()
        );
	end
    assign sched_csr_if.alm_empty = pending_warp_alm_empty[sched_csr_if.alm_empty_wid];
    wire no_pending_instr = (& pending_warp_empty);
    VX_pipe_register #( 
        .DATAW  ($bits(busy)), 
        .RESETW ($bits(busy)), 
        .DEPTH  (1) 
    ) __busy__ ( 
        .clk      (clk), 
        .reset    (reset), 
        .enable   (1'b1), 
        .data_in  ((active_warps != 0 || ~no_pending_instr)), 
        .data_out (busy) 
    );
    assign sched_csr_if.cycles = cycles;
    assign sched_csr_if.active_warps = active_warps;
    assign sched_csr_if.thread_masks = thread_masks;
    reg [31:0] timeout_ctr;
    reg timeout_enable;
    always @(posedge clk) begin
        if (reset) begin
            timeout_ctr    <= '0;
            timeout_enable <= 0;
        end else begin
            if (decode_sched_if.valid && ~decode_sched_if.is_wstall) begin
                timeout_enable <= 1;
            end
            if (timeout_enable && active_warps !=0 && active_warps == stalled_warps) begin
                timeout_ctr <= timeout_ctr + 1;
            end else if (active_warps == 0 || active_warps != stalled_warps) begin
                timeout_ctr <= '0;
            end
        end
    end
endmodule
