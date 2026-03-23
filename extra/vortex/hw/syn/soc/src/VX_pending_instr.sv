module VX_pending_instr #(
    parameter CTR_WIDTH  = 12,
    parameter ALM_EMPTY  = 1,
    parameter DECR_COUNT = 1
) (
    input wire                  clk,
    input wire                  reset,
    input wire                  incr,
    input wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]  incr_wid,
    input wire [DECR_COUNT-1:0] decr,
    input wire [DECR_COUNT-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] decr_wid,
    input wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]  alm_empty_wid,
    output wire                 empty,
    output wire                 alm_empty
);
    localparam COUNTW = $clog2(DECR_COUNT+1);
    reg [4-1:0][CTR_WIDTH-1:0] pending_instrs;
    reg [4-1:0][COUNTW-1:0] decr_cnt;
    reg [4-1:0][DECR_COUNT-1:0] decr_mask;
    reg [4-1:0] incr_cnt, incr_cnt_n;
    reg [4-1:0] alm_empty_r, empty_r;
    always @(*) begin
        incr_cnt_n = 0;
        decr_mask = 0;
        if (incr) begin
            incr_cnt_n[incr_wid] = 1;
        end
        for (integer i = 0; i < DECR_COUNT; ++i) begin
            if (decr[i]) begin
                decr_mask[decr_wid[i]][i] = 1;
            end
        end
    end
    for (genvar i = 0; i < 4; ++i) begin
        wire [COUNTW-1:0] decr_cnt_n;
    VX_popcount #( 
        .N ($bits(decr_mask[i])), 
        .MODEL (1) 
    ) __decr_cnt_n ( 
        .data_in  (decr_mask[i]), 
        .data_out (decr_cnt_n) 
    );
        wire [CTR_WIDTH-1:0] pending_instrs_n = pending_instrs[i] + CTR_WIDTH'(incr_cnt[i]) - CTR_WIDTH'(decr_cnt[i]);
        always @(posedge clk) begin
            if (reset) begin
                incr_cnt[i]       <= '0;
                decr_cnt[i]       <= '0;
                pending_instrs[i] <= '0;
                alm_empty_r[i]    <= 0;
                empty_r[i]        <= 1;
            end else begin            
                incr_cnt[i]       <= incr_cnt_n[i];
                decr_cnt[i]       <= decr_cnt_n;
                pending_instrs[i] <= pending_instrs_n;
                alm_empty_r[i]    <= (pending_instrs_n == ALM_EMPTY);
                empty_r[i]        <= (pending_instrs_n == 0);
            end
		end
	end
    assign alm_empty = alm_empty_r[alm_empty_wid];
    assign empty = (& empty_r);
endmodule
