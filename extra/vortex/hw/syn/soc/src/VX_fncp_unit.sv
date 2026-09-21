module VX_fncp_unit import VX_fpu_pkg::*; #(
    parameter LATENCY  = 2,
    parameter EXP_BITS = 8,
    parameter MAN_BITS = 23
) (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [4-1:0] op_type,
    input wire [3-1:0] frm,
    input wire [31:0]  dataa,
    input wire [31:0]  datab,
    output wire [31:0] result, 
    output wire [$bits(VX_fpu_pkg::fflags_t)-1:0] fflags
);       
    localparam  NEG_INF     = 32'h00000001,
                NEG_NORM    = 32'h00000002,
                NEG_SUBNORM = 32'h00000004,
                NEG_ZERO    = 32'h00000008,
                POS_ZERO    = 32'h00000010,
                POS_SUBNORM = 32'h00000020,
                POS_NORM    = 32'h00000040,
                POS_INF     = 32'h00000080,
                QUT_NAN     = 32'h00000200;
    wire        a_sign, b_sign;
    wire [7:0]  a_exponent, b_exponent;
    wire [22:0] a_mantissa, b_mantissa;
    fclass_t    a_fclass, b_fclass;
    wire        a_smaller, ab_equal;
    assign     a_sign = dataa[31]; 
    assign a_exponent = dataa[30:23];
    assign a_mantissa = dataa[22:0];
    assign     b_sign = datab[31]; 
    assign b_exponent = datab[30:23];
    assign b_mantissa = datab[22:0];
    VX_fp_classifier #( 
        .EXP_BITS (EXP_BITS),
        .MAN_BITS (MAN_BITS)
    ) fp_class_a (
        .exp_i  (a_exponent),
        .man_i  (a_mantissa),
        .clss_o (a_fclass)
    );
    VX_fp_classifier #( 
        .EXP_BITS (EXP_BITS),
        .MAN_BITS (MAN_BITS)
    ) fp_class_b (
        .exp_i  (b_exponent),
        .man_i  (b_mantissa),
        .clss_o (b_fclass)
    );
    assign a_smaller = (dataa < datab) ^ (a_sign || b_sign);
    assign ab_equal  = (dataa == datab) 
                    || (a_fclass.is_zero && b_fclass.is_zero);  
    wire [3:0]   op_mod_s0;
    wire [31:0]  dataa_s0, datab_s0;
    wire         a_sign_s0, b_sign_s0;
    wire [7:0]   a_exponent_s0;
    wire [22:0]  a_mantissa_s0;
    fclass_t     a_fclass_s0, b_fclass_s0;
    wire         a_smaller_s0, ab_equal_s0;
    wire [3:0] op_mod = {(op_type == 4'b0101), frm};
    VX_pipe_register #(
        .DATAW (4 + 2 * 32 + 1 + 1 + 8 + 23 + 2 * $bits(fclass_t) + 1 + 1),
        .DEPTH (LATENCY > 1)
    ) pipe_reg0 (
        .clk      (clk),
        .reset    (reset),
        .enable   (enable),
        .data_in  ({op_mod,    dataa,    datab,    a_sign,    b_sign,    a_exponent,    a_mantissa,    a_fclass,    b_fclass,    a_smaller,    ab_equal}),
        .data_out ({op_mod_s0, dataa_s0, datab_s0, a_sign_s0, b_sign_s0, a_exponent_s0, a_mantissa_s0, a_fclass_s0, b_fclass_s0, a_smaller_s0, ab_equal_s0})
    ); 
    reg [31:0] fclass_mask_s0;   
    always @(*) begin 
        if (a_fclass_s0.is_normal) begin
            fclass_mask_s0 = a_sign_s0 ? NEG_NORM : POS_NORM;
        end 
        else if (a_fclass_s0.is_inf) begin
            fclass_mask_s0 = a_sign_s0 ? NEG_INF : POS_INF;
        end 
        else if (a_fclass_s0.is_zero) begin
            fclass_mask_s0 = a_sign_s0 ? NEG_ZERO : POS_ZERO;
        end 
        else if (a_fclass_s0.is_subnormal) begin
            fclass_mask_s0 = a_sign_s0 ? NEG_SUBNORM : POS_SUBNORM;
        end 
        else if (a_fclass_s0.is_nan) begin
            fclass_mask_s0 = {22'h0, a_fclass_s0.is_quiet, a_fclass_s0.is_signaling, 8'h0};
        end 
        else begin                     
            fclass_mask_s0 = QUT_NAN;
        end
    end
    reg [31:0] fminmax_res_s0;
    always @(*) begin
        if (a_fclass_s0.is_nan && b_fclass_s0.is_nan)
            fminmax_res_s0 = {1'b0, 8'hff, 1'b1, 22'd0};  
        else if (a_fclass_s0.is_nan) 
            fminmax_res_s0 = datab_s0;
        else if (b_fclass_s0.is_nan) 
            fminmax_res_s0 = dataa_s0;
        else begin 
            fminmax_res_s0 = (op_mod_s0[0] ^ a_smaller_s0) ? dataa_s0 : datab_s0;
        end
    end
    reg [31:0] fsgnj_res_s0;     
    always @(*) begin
        case (op_mod_s0[1:0])
            0: fsgnj_res_s0 = { b_sign_s0, a_exponent_s0, a_mantissa_s0};
            1: fsgnj_res_s0 = {~b_sign_s0, a_exponent_s0, a_mantissa_s0};
        default: fsgnj_res_s0 = { a_sign_s0 ^ b_sign_s0, a_exponent_s0, a_mantissa_s0};
        endcase
    end
    reg fcmp_res_s0;         
    reg fcmp_fflags_NV_s0;   
    always @(*) begin
        case (op_mod_s0[1:0])
            0: begin  
                if (a_fclass_s0.is_nan || b_fclass_s0.is_nan) begin
                    fcmp_res_s0       = 0;
                    fcmp_fflags_NV_s0 = 1;
                end else begin
                    fcmp_res_s0       = (a_smaller_s0 | ab_equal_s0);
                    fcmp_fflags_NV_s0 = 0;
                end
            end
            1: begin  
                if (a_fclass_s0.is_nan || b_fclass_s0.is_nan) begin
                    fcmp_res_s0       = 0;
                    fcmp_fflags_NV_s0 = 1;
                end else begin
                    fcmp_res_s0       = (a_smaller_s0 & ~ab_equal_s0);
                    fcmp_fflags_NV_s0 = 0;
                end                    
            end
            2: begin  
                if (a_fclass_s0.is_nan || b_fclass_s0.is_nan) begin
                    fcmp_res_s0       = 0;
                    fcmp_fflags_NV_s0 = a_fclass_s0.is_signaling | b_fclass_s0.is_signaling; 
                end else begin
                    fcmp_res_s0       = ab_equal_s0;
                    fcmp_fflags_NV_s0 = 0;
                end
            end
            default: begin
                fcmp_res_s0       = 'x;
                fcmp_fflags_NV_s0 = 'x;                        
            end
        endcase
    end
    reg [31:0] result_s0;
    reg fflags_NV_s0;
    always @(*) begin
        case (op_mod_s0[2:0])
            0,1,2: begin
                result_s0 = op_mod_s0[3] ? 32'(fcmp_res_s0) : fsgnj_res_s0;
                fflags_NV_s0 = fcmp_fflags_NV_s0;
            end
            3: begin
                result_s0 = fclass_mask_s0;
                fflags_NV_s0 = 0;
            end
            4,5: begin
                result_s0 = dataa_s0;
                fflags_NV_s0 = 0;
            end                
            6,7: begin
                result_s0 = fminmax_res_s0;
                fflags_NV_s0 = a_fclass_s0.is_signaling | b_fclass_s0.is_signaling;
            end
        endcase
    end
    wire fflags_NV;
    VX_pipe_register #(
        .DATAW (32 + 1),
        .DEPTH (LATENCY > 0)
    ) pipe_reg1 (
        .clk      (clk),
        .reset    (reset),
        .enable   (enable),
        .data_in  ({result_s0, fflags_NV_s0}),
        .data_out ({result,    fflags_NV})
    );
    assign fflags = {fflags_NV, 1'b0, 1'b0, 1'b0, 1'b0};
endmodule
