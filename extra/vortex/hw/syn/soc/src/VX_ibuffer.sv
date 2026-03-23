module VX_ibuffer import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0
) (
    input wire          clk,
    input wire          reset,
    VX_decode_if.slave  decode_if,
    VX_ibuffer_if.master ibuffer_if [(((4) < (4)) ? (4) : (4))]
);
    localparam ISW_WIDTH  = ((((((4) < (4)) ? (4) : (4))) > 1) ? $clog2((((4) < (4)) ? (4) : (4))) : 1);
    localparam DATAW = 1 + ISSUE_WIS_W + 4 + 32 + 1 + $clog2((3 + 0)) + 4 + 3 + 1 + 1 + 32 + ($clog2(32) * 4);
    wire [(((4) < (4)) ? (4) : (4))-1:0] ibuf_ready_in;
    wire [ISW_WIDTH-1:0] decode_isw = wid_to_isw(decode_if.data.wid);
    wire [ISSUE_WIS_W-1:0] decode_wis = wid_to_wis(decode_if.data.wid);
    assign decode_if.ready = ibuf_ready_in[decode_isw];
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    ((2 * (4 / (((4) < (4)) ? (4) : (4))))),
            .OUT_REG (1)
        ) instr_buf (
            .clk      (clk),
            .reset    (reset),
            .valid_in (decode_if.valid && decode_isw == i),
            .ready_in (ibuf_ready_in[i]),
            .data_in  ({
                decode_if.data.uuid,
                decode_wis,
                decode_if.data.tmask,
                decode_if.data.ex_type,
                decode_if.data.op_type,
                decode_if.data.op_mod,
                decode_if.data.wb,
                decode_if.data.use_PC,
                decode_if.data.use_imm,
                decode_if.data.PC,
                decode_if.data.imm,
                decode_if.data.rd, 
                decode_if.data.rs1, 
                decode_if.data.rs2, 
                decode_if.data.rs3}),
            .data_out(ibuffer_if[i].data),
            .valid_out (ibuffer_if[i].valid),
            .ready_out(ibuffer_if[i].ready)
        );        
        assign decode_if.ibuf_pop[i] = ibuffer_if[i].valid && ibuffer_if[i].ready;
    end
endmodule
