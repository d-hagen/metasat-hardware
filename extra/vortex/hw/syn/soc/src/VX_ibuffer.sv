module VX_ibuffer import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire          clk,
    input wire          reset,
    VX_decode_if.slave  decode_if,
    VX_ibuffer_if.master ibuffer_if [PER_ISSUE_WARPS]
);
    localparam DATAW = 23 + 4 + (32-1) + 1 + $clog2((3 + 0)) + 4 + $bits(op_args_t) + ($clog2(32) * 4);
    wire [PER_ISSUE_WARPS-1:0] ibuf_ready_in;
    assign decode_if.ready = ibuf_ready_in[decode_if.data.wid];
    for (genvar w = 0; w < PER_ISSUE_WARPS; ++w) begin
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    (4),
            .OUT_REG (2)  
        ) instr_buf (
            .clk      (clk),
            .reset    (reset),
            .valid_in (decode_if.valid && decode_if.data.wid == ISSUE_WIS_W'(w)),
            .data_in  ({
                decode_if.data.uuid,
                decode_if.data.tmask,
                decode_if.data.PC,
                decode_if.data.ex_type,
                decode_if.data.op_type,
                decode_if.data.op_args,
                decode_if.data.wb,
                decode_if.data.rd,
                decode_if.data.rs1,
                decode_if.data.rs2,
                decode_if.data.rs3
            }),
            .ready_in (ibuf_ready_in[w]),
            .valid_out(ibuffer_if[w].valid),
            .data_out (ibuffer_if[w].data),
            .ready_out(ibuffer_if[w].ready)
        );
    end
endmodule
