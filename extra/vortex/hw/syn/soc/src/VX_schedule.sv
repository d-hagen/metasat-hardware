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
    reg [4-1:0][1-1:0] issued_instrs;
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
                // synthesis translate_off
                $display("[%0t] WSPAWN ISSUE: wid=%0d wmask=%b pc=0x%h",
                         $time, warp_ctl_if.wid, warp_ctl_if.wspawn.wmask, warp_ctl_if.wspawn.pc);
                // synthesis translate_on
            end
            if (wspawn.valid && is_single_warp) begin
                wspawn.valid <= 0;
                // synthesis translate_off
                $display("[%0t] WSPAWN FIRE: wmask=%b pc=0x%h unstall_wid=%0d active=%b",
                         $time, wspawn.wmask, wspawn.pc, wspawn_wid, active_warps);
                // synthesis translate_on
            end
            if (schedule_if_fire) begin
                issued_instrs[schedule_if.data.wid] <= issued_instrs[schedule_if.data.wid] + 1'(1);
            end
            if (busy) begin
                cycles <= cycles + 1;
            end
        end
    end
    // synthesis translate_off
    reg [4-1:0]      dbg_active_prev;
    reg [4-1:0][4-1:0] dbg_thread_masks_prev;
    always @(posedge clk) begin
        if (reset) begin
            dbg_active_prev <= 4'b0001;
            dbg_thread_masks_prev <= 16'h0001;
        end else begin
            if (active_warps !== dbg_active_prev)
                $display("[%0t] SCHED active_warps: 0x%h -> 0x%h", $time, dbg_active_prev, active_warps);
            for (integer w = 0; w < 4; w = w + 1) begin
                if (thread_masks[w] !== dbg_thread_masks_prev[w])
                    $display("[%0t] SCHED tmc warp %0d: mask 0x%h -> 0x%h pc=0x%h",
                             $time, w, dbg_thread_masks_prev[w], thread_masks[w], warp_pcs[w]);
            end
            dbg_active_prev <= active_warps;
            dbg_thread_masks_prev <= thread_masks;
        end
    end
    // synthesis translate_on

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
    wire [1-1:0] instr_uuid = '0;
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
