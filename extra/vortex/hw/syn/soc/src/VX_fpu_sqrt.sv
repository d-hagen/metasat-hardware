module VX_fpu_sqrt import VX_fpu_pkg::*; #( 
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
    input wire [NUM_LANES-1:0][31:0]  dataa,
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
        .DEPTH  (28),
        .RESETW (1)
    ) shift_reg (
        .clk(clk),
        .reset    (reset),
        .enable   (enable),
        .data_in  ({valid_in, lane_mask, tag_in}),
        .data_out ({valid_out, lane_mask_out, tag_out})
    );
    assign ready_in = enable;    
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        wire tuser;       
        xil_fsqrt fsqrt (
            .aclk                (clk),
            .aclken              (enable),
            .s_axis_a_tvalid     (1'b1),
            .s_axis_a_tdata      (dataa[i][31:0]),
            . m_axis_result_tvalid (),
            .m_axis_result_tdata (result[i][31:0]),
            .m_axis_result_tuser (tuser)
        );
        assign per_lane_fflags[i] = {tuser, 1'b0, 1'b0, 1'b0, 1'b0};
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
