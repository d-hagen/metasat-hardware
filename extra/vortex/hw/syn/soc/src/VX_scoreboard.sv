module VX_scoreboard import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    output wire [32-1:0] debug_stall [(((4) < (4)) ? (4) : (4))],
    VX_writeback_if.slave   writeback_if [(((4) < (4)) ? (4) : (4))],
    VX_ibuffer_if.slave     ibuffer_if [(((4) < (4)) ? (4) : (4))],
    VX_ibuffer_if.master    scoreboard_if [(((4) < (4)) ? (4) : (4))]
);
    localparam DATAW = 1 + ISSUE_WIS_W + 4 + 32 + $clog2((3 + 0)) + 4 + 3 + 1 + 1 + 32 + ($clog2(32) * 4) + 1;
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        reg [(((ISSUE_RATIO) != 0) ? (ISSUE_RATIO) : 1)-1:0][32-1:0] inuse_regs, inuse_regs_n;
        reg [3:0] ready_masks, ready_masks_n;        
        VX_ibuffer_if staging_if();
        wire writeback_fire = writeback_if[i].valid && writeback_if[i].data.eop;
        always @(*) begin
            inuse_regs_n = inuse_regs;
            ready_masks_n = ready_masks;
            if (writeback_fire) begin
                inuse_regs_n[writeback_if[i].data.wis][writeback_if[i].data.rd] = 0;
                ready_masks_n |= {4{(ISSUE_RATIO == 0) || writeback_if[i].data.wis == staging_if.data.wis}} 
                               & {(writeback_if[i].data.rd == staging_if.data.rd),
                                  (writeback_if[i].data.rd == staging_if.data.rs1),
                                  (writeback_if[i].data.rd == staging_if.data.rs2),
                                  (writeback_if[i].data.rd == staging_if.data.rs3)};
            end   
            if (staging_if.valid && staging_if.ready && staging_if.data.wb) begin
                inuse_regs_n[staging_if.data.wis][staging_if.data.rd] = 1;
                ready_masks_n = '0;
            end
            if (ibuffer_if[i].valid && ibuffer_if[i].ready) begin
                ready_masks_n = ~{inuse_regs_n[ibuffer_if[i].data.wis][ibuffer_if[i].data.rd],
                                  inuse_regs_n[ibuffer_if[i].data.wis][ibuffer_if[i].data.rs1],
                                  inuse_regs_n[ibuffer_if[i].data.wis][ibuffer_if[i].data.rs2],
                                  inuse_regs_n[ibuffer_if[i].data.wis][ibuffer_if[i].data.rs3]};
            end
        end   
        always @(posedge clk) begin
            if (reset) begin
                inuse_regs  <= '0;
                ready_masks <= '0;
            end else begin            
                inuse_regs  <= inuse_regs_n;
                ready_masks <= ready_masks_n;
            end
        end
    wire [1-1:0] stg_buf_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __stg_buf_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (stg_buf_reset)                          
    );
        VX_elastic_buffer #(
            .DATAW (DATAW)
        ) stg_buf (
            .clk       (clk),
            .reset     (stg_buf_reset),
            .valid_in  (ibuffer_if[i].valid),
            .ready_in  (ibuffer_if[i].ready),
            .data_in   (ibuffer_if[i].data),
            .data_out  (staging_if.data),
            .valid_out (staging_if.valid),
            .ready_out (staging_if.ready)
        );
        wire valid_stg, ready_stg;
        wire regs_ready = (& ready_masks);
        assign valid_stg = staging_if.valid && regs_ready;
        assign staging_if.ready = ready_stg && regs_ready;
    wire [1-1:0] out_buf_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __out_buf_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (out_buf_reset)                          
    );
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    (2),
            .OUT_REG (2)
        ) out_buf (
            .clk       (clk),
            .reset     (out_buf_reset),
            .valid_in  (valid_stg),
            .ready_in  (ready_stg),
            .data_in   (staging_if.data),
            .data_out  (scoreboard_if[i].data),
            .valid_out (scoreboard_if[i].valid),
            .ready_out (scoreboard_if[i].ready)
        );
        reg [31:0] timeout_ctr;
	assign debug_stall[i] = (staging_if.valid && ~regs_ready) ? staging_if.data.PC : '0;
        always @(posedge clk) begin
            if (reset) begin
                timeout_ctr <= '0;
            end else begin        
                if (staging_if.valid && ~regs_ready) begin
                    timeout_ctr <= timeout_ctr + 1;
                end else if (staging_if.valid && staging_if.ready) begin
                    timeout_ctr <= '0;
                end
            end
        end
;
;
    end    
endmodule
