module VX_fpu_ncp import VX_fpu_pkg::*; #(
    parameter NUM_LANES = 1,
    parameter NUM_PES   = (((NUM_LANES / 2) != 0) ? (NUM_LANES / 2) : 1),
    parameter TAG_WIDTH = 1
) (
    input wire clk,
    input wire reset,
    output wire ready_in,
    input wire  valid_in,
    input wire [NUM_LANES-1:0] mask_in,
    input wire [TAG_WIDTH-1:0] tag_in,
    input wire [4-1:0] op_type,
    input wire [3-1:0] frm,
    input wire [NUM_LANES-1:0][31:0]  dataa,
    input wire [NUM_LANES-1:0][31:0]  datab,
    output wire [NUM_LANES-1:0][31:0] result,
    output wire has_fflags,
    output wire [$bits(VX_fpu_pkg::fflags_t)-1:0] fflags,
    output wire [TAG_WIDTH-1:0] tag_out,
    input wire  ready_out,
    output wire valid_out
);
    wire [NUM_LANES-1:0][2*32-1:0] data_in;
    wire [NUM_LANES-1:0] mask_out;
    wire [NUM_LANES-1:0][($bits(VX_fpu_pkg::fflags_t)+32)-1:0] data_out;
    fflags_t [NUM_LANES-1:0] fflags_out;
    wire pe_enable;
    wire [NUM_PES-1:0][2*32-1:0] pe_data_in;
    wire [NUM_PES-1:0][($bits(VX_fpu_pkg::fflags_t)+32)-1:0] pe_data_out;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign data_in[i][0  +: 32] = dataa[i];
        assign data_in[i][32 +: 32] = datab[i];
    end
    VX_pe_serializer #(
        .NUM_LANES  (NUM_LANES),
        .NUM_PES    (NUM_PES),
        .LATENCY    (2),
        .DATA_IN_WIDTH(2*32),
        .DATA_OUT_WIDTH($bits(VX_fpu_pkg::fflags_t) + 32),
        .TAG_WIDTH  (NUM_LANES + TAG_WIDTH),
        .PE_REG     (0),
        .OUT_BUF    (((NUM_LANES / NUM_PES) > 2) ? 1 : 0)
    ) pe_serializer (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (valid_in),
        .data_in    (data_in),
        .tag_in     ({mask_in, tag_in}),
        .ready_in   (ready_in),
        .pe_enable  (pe_enable),
        .pe_data_in (pe_data_in),
        .pe_data_out(pe_data_out),
        .valid_out  (valid_out),
        .data_out   (data_out),
        .tag_out    ({mask_out, tag_out}),
        .ready_out  (ready_out)
    );
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign result[i] = data_out[i][0 +: 32];
        assign fflags_out[i] = data_out[i][32 +: $bits(VX_fpu_pkg::fflags_t)];
    end
    for (genvar i = 0; i < NUM_PES; ++i) begin
        VX_fncp_unit #(
            .LATENCY (2)
        ) fncp_unit (
            .clk        (clk),
            .reset      (reset),
            .enable     (pe_enable),
            .frm        (frm),
            .op_type    (op_type),
            .dataa      (pe_data_in[i][0 +: 32]),
            .datab      (pe_data_in[i][32 +: 32]),
            .result     (pe_data_out[i][0 +: 32]),
            .fflags     (pe_data_out[i][32 +: $bits(VX_fpu_pkg::fflags_t)])
        );
    end
    assign has_fflags = 1;
    fflags_t __fflags; 
    always @(*) begin 
        __fflags = '0; 
        for (integer __i = 0; __i < NUM_LANES; ++__i) begin 
            if (mask_out[__i]) begin 
                __fflags.NX |= fflags_out[__i].NX; 
                __fflags.UF |= fflags_out[__i].UF; 
                __fflags.OF |= fflags_out[__i].OF; 
                __fflags.DZ |= fflags_out[__i].DZ; 
                __fflags.NV |= fflags_out[__i].NV; 
            end 
        end 
    end 
    assign fflags = __fflags;
endmodule
