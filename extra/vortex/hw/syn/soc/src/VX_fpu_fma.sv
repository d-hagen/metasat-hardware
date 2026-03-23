module VX_fpu_fma import VX_fpu_pkg::*; #(
    parameter NUM_LANES = 1, 
    parameter TAGW = 1
) (
    input wire clk,
    input wire reset, 
    output wire ready_in,
    input wire  valid_in,
    input wire [NUM_LANES-1:0] lane_mask,
    input wire [TAGW-1:0] tag_in,
    input wire [3-1:0] frm,
    input wire  is_madd,
    input wire  is_sub,
    input wire  is_neg,
    input wire [NUM_LANES-1:0][31:0]  dataa,
    input wire [NUM_LANES-1:0][31:0]  datab,
    input wire [NUM_LANES-1:0][31:0]  datac,
    output wire [NUM_LANES-1:0][31:0] result, 
    output wire has_fflags,
    output wire [$bits(VX_fpu_pkg::fflags_t)-1:0] fflags,
    output wire [TAGW-1:0] tag_out,
    input wire  ready_out,
    output wire valid_out
);
    wire stall = ~ready_out && valid_out;
    wire enable = ~stall;
    fflags_t [NUM_LANES-1:0] per_lane_fflags;
    wire [NUM_LANES-1:0] lane_mask_out;
    VX_shift_register #(
        .DATAW  (1 + NUM_LANES + TAGW),
        .DEPTH  (16),
        .RESETW (1)
    ) shift_reg (
        .clk(clk),
        .reset    (reset),
        .enable   (enable),
        .data_in  ({valid_in, lane_mask, tag_in}),
        .data_out ({valid_out, lane_mask_out, tag_out})
    );
    assign ready_in = enable;
    reg [NUM_LANES-1:0][31:0] a, b, c;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        always @(*) begin
            if (is_madd) begin
                a[i] = is_neg ? {~dataa[i][31], dataa[i][30:0]} : dataa[i];                    
                b[i] = datab[i];
                c[i] = (is_neg ^ is_sub) ? {~datac[i][31], datac[i][30:0]} : datac[i];
            end else begin
                if (is_neg) begin
                    a[i] = dataa[i];
                    b[i] = datab[i];
                    c[i] = '0;
                end else begin
                    a[i] = 32'h3f800000;  
                    b[i] = dataa[i];
                    c[i] = is_sub ? {~datab[i][31], datab[i][30:0]} : datab[i];
                end
            end    
        end
    end
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire [2:0] tuser;
        xil_fma fma (
            .aclk                (clk),
            .aclken              (enable),
            .s_axis_a_tvalid     (1'b1),
            .s_axis_a_tdata      (a[i]),
            .s_axis_b_tvalid     (1'b1),
            .s_axis_b_tdata      (b[i]),
            .s_axis_c_tvalid     (1'b1),
            .s_axis_c_tdata      (c[i]),
            . m_axis_result_tvalid (),
            .m_axis_result_tdata (result[i]),
            .m_axis_result_tuser (tuser)
        );
        assign per_lane_fflags[i] = {tuser[2], 1'b0, tuser[1], tuser[0], 1'b0};
    end
    assign has_fflags = 1;
    fflags_t __fflags; 
    always @(*) begin 
        __fflags = '0; 
        for (integer __i = 0; __i < NUM_LANES; ++__i) begin 
            if (lane_mask_out[__i]) begin 
                __fflags.NX |= per_lane_fflags[__i].NX; 
                __fflags.UF |= per_lane_fflags[__i].UF; 
                __fflags.OF |= per_lane_fflags[__i].OF; 
                __fflags.DZ |= per_lane_fflags[__i].DZ; 
                __fflags.NV |= per_lane_fflags[__i].NV; 
            end 
        end 
    end 
    assign fflags = __fflags;
endmodule
