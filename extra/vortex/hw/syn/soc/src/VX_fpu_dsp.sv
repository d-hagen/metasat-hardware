module VX_fpu_dsp import VX_fpu_pkg::*; #(
    parameter NUM_LANES = 4,
    parameter TAG_WIDTH = 4,
    parameter OUT_BUF   = 0
) (
    input wire clk,
    input wire reset,
    input wire  valid_in,
    output wire ready_in,
    input wire [NUM_LANES-1:0] mask_in,
    input wire [TAG_WIDTH-1:0] tag_in,
    input wire [4-1:0] op_type,
    input wire [2-1:0] fmt,
    input wire [3-1:0] frm,
    input wire [NUM_LANES-1:0][32-1:0]  dataa,
    input wire [NUM_LANES-1:0][32-1:0]  datab,
    input wire [NUM_LANES-1:0][32-1:0]  datac,
    output wire [NUM_LANES-1:0][32-1:0] result,
    output wire has_fflags,
    output wire [$bits(VX_fpu_pkg::fflags_t)-1:0] fflags,
    output wire [TAG_WIDTH-1:0] tag_out,
    input wire  ready_out,
    output wire valid_out
);
    localparam FPU_FMA     = 0;
    localparam FPU_DIVSQRT = 1;
    localparam FPU_CVT     = 2;
    localparam FPU_NCP     = 3;
    localparam NUM_FPC     = 4;
    localparam FPC_BITS    = (((NUM_FPC) > 1) ? $clog2(NUM_FPC) : 1);
    localparam RSP_DATAW = (NUM_LANES * 32) + 1 + $bits(fflags_t) + TAG_WIDTH;
    wire [NUM_FPC-1:0] per_core_ready_in;
    wire [NUM_FPC-1:0][NUM_LANES-1:0][31:0] per_core_result;
    wire [NUM_FPC-1:0][TAG_WIDTH-1:0] per_core_tag_out;
    wire [NUM_FPC-1:0] per_core_ready_out;
    wire [NUM_FPC-1:0] per_core_valid_out;
    wire [NUM_FPC-1:0] per_core_has_fflags;
    fflags_t [NUM_FPC-1:0] per_core_fflags;
    wire div_ready_in, sqrt_ready_in;
    wire [NUM_LANES-1:0][31:0] div_result, sqrt_result;
    wire [TAG_WIDTH-1:0] div_tag_out, sqrt_tag_out;
    wire div_ready_out, sqrt_ready_out;
    wire div_valid_out, sqrt_valid_out;
    wire div_has_fflags, sqrt_has_fflags;
    fflags_t div_fflags, sqrt_fflags;
    reg [FPC_BITS-1:0] core_select;
    reg is_madd, is_sub, is_neg, is_div, is_itof, is_signed;
    always @(*) begin
        is_madd   = 0;
        is_sub    = 0;
        is_neg    = 0;
        is_div    = 0;
        is_itof   = 0;
        is_signed = 0;
        case (op_type)
            4'b0000:    begin core_select = FPU_FMA; end
            4'b0001:    begin core_select = FPU_FMA; is_sub = 1; end
            4'b0010:    begin core_select = FPU_FMA; is_neg = 1; end
            4'b1100:   begin core_select = FPU_FMA; is_madd = 1; end
            4'b1101:   begin core_select = FPU_FMA; is_madd = 1; is_sub = 1; end
            4'b1111:  begin core_select = FPU_FMA; is_madd = 1; is_neg = 1; end
            4'b1110:  begin core_select = FPU_FMA; is_madd = 1; is_sub = 1; is_neg = 1; end
            4'b0011:    begin core_select = FPU_DIVSQRT; is_div = 1; end
            4'b0100:   begin core_select = FPU_DIVSQRT; end
            4'b1000:    begin core_select = FPU_CVT; is_signed = 1; end
            4'b1001:    begin core_select = FPU_CVT; end
            4'b1010:    begin core_select = FPU_CVT; is_itof = 1; is_signed = 1; end
            4'b1011:    begin core_select = FPU_CVT; is_itof = 1; end
            default:          begin core_select = FPU_NCP; end
        endcase
    end
    wire [1-1:0] fma_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __fma_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (fma_reset)                          
    );
    wire [1-1:0] div_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __div_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (div_reset)                          
    );
    wire [1-1:0] sqrt_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __sqrt_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (sqrt_reset)                          
    );
    wire [1-1:0] cvt_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __cvt_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (cvt_reset)                          
    );
    wire [1-1:0] ncp_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __ncp_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (ncp_reset)                          
    );
    wire [NUM_LANES-1:0][31:0] dataa_s;
    wire [NUM_LANES-1:0][31:0] datab_s;
    wire [NUM_LANES-1:0][31:0] datac_s;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign dataa_s[i] = dataa[i][31:0];
        assign datab_s[i] = datab[i][31:0];
        assign datac_s[i] = datac[i][31:0];
    end
    VX_fpu_fma #(
        .NUM_LANES (NUM_LANES),
        .TAG_WIDTH (TAG_WIDTH)
    ) fpu_fma (
        .clk        (clk),
        .reset      (fma_reset),
        .valid_in   (valid_in && (core_select == FPU_FMA)),
        .ready_in   (per_core_ready_in[FPU_FMA]),
        .mask_in    (mask_in),
        .tag_in     (tag_in),
        .frm        (frm),
        .is_madd    (is_madd),
        .is_sub     (is_sub),
        .is_neg     (is_neg),
        .dataa      (dataa_s),
        .datab      (datab_s),
        .datac      (datac_s),
        .has_fflags (per_core_has_fflags[FPU_FMA]),
        .fflags     (per_core_fflags[FPU_FMA]),
        .result     (per_core_result[FPU_FMA]),
        .tag_out    (per_core_tag_out[FPU_FMA]),
        .ready_out  (per_core_ready_out[FPU_FMA]),
        .valid_out  (per_core_valid_out[FPU_FMA])
    );
    VX_fpu_div #(
        .NUM_LANES (NUM_LANES),
        .TAG_WIDTH (TAG_WIDTH)
    ) fpu_div (
        .clk        (clk),
        .reset      (div_reset),
        .valid_in   (valid_in && (core_select == FPU_DIVSQRT) && is_div),
        .ready_in   (div_ready_in),
        .mask_in    (mask_in),
        .tag_in     (tag_in),
        .frm        (frm),
        .dataa      (dataa_s),
        .datab      (datab_s),
        .has_fflags (div_has_fflags),
        .fflags     (div_fflags),
        .result     (div_result),
        .tag_out    (div_tag_out),
        .valid_out  (div_valid_out),
        .ready_out  (div_ready_out)
    );
    VX_fpu_sqrt #(
        .NUM_LANES (NUM_LANES),
        .TAG_WIDTH (TAG_WIDTH)
    ) fpu_sqrt (
        .clk        (clk),
        .reset      (sqrt_reset),
        .valid_in   (valid_in && (core_select == FPU_DIVSQRT) && ~is_div),
        .ready_in   (sqrt_ready_in),
        .mask_in    (mask_in),
        .tag_in     (tag_in),
        .frm        (frm),
        .dataa      (dataa_s),
        .has_fflags (sqrt_has_fflags),
        .fflags     (sqrt_fflags),
        .result     (sqrt_result),
        .tag_out    (sqrt_tag_out),
        .valid_out  (sqrt_valid_out),
        .ready_out  (sqrt_ready_out)
    );
    wire cvt_ret_int_in = ~is_itof;
    wire cvt_ret_int_out;
    VX_fpu_cvt #(
        .NUM_LANES (NUM_LANES),
        .TAG_WIDTH (TAG_WIDTH+1)
    ) fpu_cvt (
        .clk        (clk),
        .reset      (cvt_reset),
        .valid_in   (valid_in && (core_select == FPU_CVT)),
        .ready_in   (per_core_ready_in[FPU_CVT]),
        .mask_in    (mask_in),
        .tag_in     ({cvt_ret_int_in, tag_in}),
        .frm        (frm),
        .is_itof    (is_itof),
        .is_signed  (is_signed),
        .dataa      (dataa_s),
        .has_fflags (per_core_has_fflags[FPU_CVT]),
        .fflags     (per_core_fflags[FPU_CVT]),
        .result     (per_core_result[FPU_CVT]),
        .tag_out    ({cvt_ret_int_out, per_core_tag_out[FPU_CVT]}),
        .valid_out  (per_core_valid_out[FPU_CVT]),
        .ready_out  (per_core_ready_out[FPU_CVT])
    );
    wire ncp_ret_int_in = (op_type == 4'b0101)
                      || (op_type == 4'b0111 && frm == 3)
                      || (op_type == 4'b0111 && frm == 4);
    wire ncp_ret_int_out;
    wire ncp_ret_sext_in = (op_type == 4'b0111 && frm == 4);
    wire ncp_ret_sext_out;
    VX_fpu_ncp #(
        .NUM_LANES (NUM_LANES),
        .TAG_WIDTH (TAG_WIDTH+2)
    ) fpu_ncp (
        .clk        (clk),
        .reset      (ncp_reset),
        .valid_in   (valid_in && (core_select == FPU_NCP)),
        .ready_in   (per_core_ready_in[FPU_NCP]),
        .mask_in    (mask_in),
        .tag_in     ({ncp_ret_sext_in, ncp_ret_int_in, tag_in}),
        .op_type    (op_type),
        .frm        (frm),
        .dataa      (dataa_s),
        .datab      (datab_s),
        .result     (per_core_result[FPU_NCP]),
        .has_fflags (per_core_has_fflags[FPU_NCP]),
        .fflags     (per_core_fflags[FPU_NCP]),
        .tag_out    ({ncp_ret_sext_out, ncp_ret_int_out, per_core_tag_out[FPU_NCP]}),
        .valid_out  (per_core_valid_out[FPU_NCP]),
        .ready_out  (per_core_ready_out[FPU_NCP])
    );
    assign per_core_ready_in[FPU_DIVSQRT] = is_div ? div_ready_in : sqrt_ready_in;
    VX_stream_arb #(
        .NUM_INPUTS (2),
        .DATAW      (RSP_DATAW),
        .ARBITER    ("R"),
        .OUT_BUF    (0)
    ) div_sqrt_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  ({sqrt_valid_out, div_valid_out}),
        .ready_in  ({sqrt_ready_out, div_ready_out}),
        .data_in   ({{sqrt_result, sqrt_has_fflags, sqrt_fflags, sqrt_tag_out},
                     {div_result, div_has_fflags, div_fflags, div_tag_out}}),
        .data_out  ({
            per_core_result[FPU_DIVSQRT],
            per_core_has_fflags[FPU_DIVSQRT],
            per_core_fflags[FPU_DIVSQRT],
            per_core_tag_out[FPU_DIVSQRT]
        }),
        .valid_out (per_core_valid_out[FPU_DIVSQRT]),
        .ready_out (per_core_ready_out[FPU_DIVSQRT]),
        . sel_out ()
    );
    reg [NUM_FPC-1:0][RSP_DATAW+2-1:0] per_core_data_out;
    always @(*) begin
        for (integer i = 0; i < NUM_FPC; ++i) begin
            per_core_data_out[i][RSP_DATAW+1:2] = {
                per_core_result[i],
                per_core_has_fflags[i],
                per_core_fflags[i],
                per_core_tag_out[i]
            };
            per_core_data_out[i][1:0] = '0;
        end
        per_core_data_out[FPU_CVT][1:0] = {1'b1, cvt_ret_int_out};
        per_core_data_out[FPU_NCP][1:0] = {ncp_ret_sext_out, ncp_ret_int_out};
    end
    wire [NUM_LANES-1:0][31:0] result_s;
    wire [1:0] op_ret_int_out;
    VX_stream_arb #(
        .NUM_INPUTS (NUM_FPC),
        .DATAW      (RSP_DATAW + 2),
        .ARBITER    ("F"),
        .OUT_BUF    (OUT_BUF)
    ) rsp_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (per_core_valid_out),
        .ready_in  (per_core_ready_out),
        .data_in   (per_core_data_out),
        .data_out  ({result_s, has_fflags, fflags, tag_out, op_ret_int_out}),
        .valid_out (valid_out),
        .ready_out (ready_out),
        . sel_out ()
    );
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign result[i] = result_s[i];
    end
    assign ready_in = per_core_ready_in[core_select];
endmodule
