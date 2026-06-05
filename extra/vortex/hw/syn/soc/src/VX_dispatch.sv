module VX_dispatch import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    VX_operands_if.slave    operands_if,
    VX_dispatch_if.master   dispatch_if [(3 + 1)]
);
    localparam DATAW = 1 + ISSUE_WIS_W + 4 + (32-1) + 4 + $bits(op_args_t) + 1 + $clog2((2 * 32)) + (3 * 4 * 32) + ((($clog2(4)) != 0) ? ($clog2(4)) : 1);
    wire [4-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] tids;
    for (genvar i = 0; i < 4; ++i) begin
        assign tids[i] = ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'(i);
    end
    wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] last_active_tid;
    VX_find_first #(
        .N (4),
        .DATAW (((($clog2(4)) != 0) ? ($clog2(4)) : 1)),
        .REVERSE (1)
    ) last_tid_select (
        .valid_in (operands_if.data.tmask),
        .data_in  (tids),
        .data_out (last_active_tid),
        . valid_out ()
    );
    wire [(3 + 1)-1:0] operands_reset;
    assign operands_if.ready = operands_reset[operands_if.data.ex_type];
    for (genvar i = 0; i < (3 + 1); ++i) begin
    wire [1-1:0] buffer_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __buffer_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (buffer_reset)                          
    );
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    (2),
            .OUT_REG (2),  
            .LUTRAM  (1)
        ) buffer (
            .clk        (clk),
            .reset      (buffer_reset),
            .valid_in   (operands_if.valid && (operands_if.data.ex_type == $clog2((3 + 1))'(i))),
            .ready_in   (operands_reset[i]),
            .data_in    ({
                operands_if.data.uuid,
                operands_if.data.wis,
                operands_if.data.tmask,
                operands_if.data.PC,
                operands_if.data.op_type,
                operands_if.data.op_args,
                operands_if.data.wb,
                operands_if.data.rd,
                last_active_tid,
                operands_if.data.rs1_data,
                operands_if.data.rs2_data,
                operands_if.data.rs3_data
            }),
            .data_out   (dispatch_if[i].data),
            .valid_out  (dispatch_if[i].valid),
            .ready_out  (dispatch_if[i].ready)
        );
    end
endmodule
