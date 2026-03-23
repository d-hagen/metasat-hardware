module VX_dispatch import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    VX_operands_if.slave    operands_if [(((4) < (4)) ? (4) : (4))],
    VX_dispatch_if.master   alu_dispatch_if [(((4) < (4)) ? (4) : (4))],
    VX_dispatch_if.master   lsu_dispatch_if [(((4) < (4)) ? (4) : (4))],
    VX_dispatch_if.master   sfu_dispatch_if [(((4) < (4)) ? (4) : (4))] 
);
    localparam DATAW = 1 + ISSUE_WIS_W + 4 + 4 + 3 + 1 + 1 + 1 + 32 + 32 + $clog2(32) + (3 * 4 * 32) + ((($clog2(4)) != 0) ? ($clog2(4)) : 1);
    wire [(((4) < (4)) ? (4) : (4))-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] last_active_tid;
    wire [4-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] tids;
    for (genvar i = 0; i < 4; ++i) begin                 
        assign tids[i] = ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'(i);
    end
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        VX_find_first #(
            .N (4),
            .DATAW (((($clog2(4)) != 0) ? ($clog2(4)) : 1)),
            .REVERSE (1)
        ) last_tid_select (
            .valid_in (operands_if[i].data.tmask),
            .data_in  (tids),
            .data_out (last_active_tid[i]),
            . valid_out ()
        );
    end
    VX_operands_if alu_operands_if[(((4) < (4)) ? (4) : (4))]();
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        assign alu_operands_if[i].valid = operands_if[i].valid && (operands_if[i].data.ex_type == 0);
        assign alu_operands_if[i].data = operands_if[i].data;
    wire [1-1:0] alu_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __alu_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (alu_reset)                          
    );
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    (2),
            .OUT_REG (2)
        ) alu_buffer (
            .clk        (clk),
            .reset      (alu_reset),
            .valid_in   (alu_operands_if[i].valid),
            .ready_in   (alu_operands_if[i].ready),
            .data_in    (
    {alu_operands_if[i].data.uuid, alu_operands_if[i].data.wis, alu_operands_if[i].data.tmask, alu_operands_if[i].data.op_type, alu_operands_if[i].data.op_mod, alu_operands_if[i].data.wb, alu_operands_if[i].data.use_PC, alu_operands_if[i].data.use_imm, alu_operands_if[i].data.PC, alu_operands_if[i].data.imm, alu_operands_if[i].data.rd, last_active_tid[i], alu_operands_if[i].data.rs1_data, alu_operands_if[i].data.rs2_data, alu_operands_if[i].data.rs3_data}),
            .data_out   (alu_dispatch_if[i].data),
            .valid_out  (alu_dispatch_if[i].valid),
            .ready_out  (alu_dispatch_if[i].ready)
        );
    end
    VX_operands_if lsu_operands_if[(((4) < (4)) ? (4) : (4))]();
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        assign lsu_operands_if[i].valid = operands_if[i].valid && (operands_if[i].data.ex_type == 1);
        assign lsu_operands_if[i].data = operands_if[i].data;
    wire [1-1:0] lsu_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __lsu_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (lsu_reset)                          
    );
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    (2),
            .OUT_REG (2)
        ) lsu_buffer (
            .clk        (clk),
            .reset      (lsu_reset),
            .valid_in   (lsu_operands_if[i].valid),
            .ready_in   (lsu_operands_if[i].ready),
            .data_in    (
    {lsu_operands_if[i].data.uuid, lsu_operands_if[i].data.wis, lsu_operands_if[i].data.tmask, lsu_operands_if[i].data.op_type, lsu_operands_if[i].data.op_mod, lsu_operands_if[i].data.wb, lsu_operands_if[i].data.use_PC, lsu_operands_if[i].data.use_imm, lsu_operands_if[i].data.PC, lsu_operands_if[i].data.imm, lsu_operands_if[i].data.rd, last_active_tid[i], lsu_operands_if[i].data.rs1_data, lsu_operands_if[i].data.rs2_data, lsu_operands_if[i].data.rs3_data}),           
            .data_out   (lsu_dispatch_if[i].data),
            .valid_out  (lsu_dispatch_if[i].valid),
            .ready_out  (lsu_dispatch_if[i].ready)
        );
    end
    VX_operands_if sfu_operands_if[(((4) < (4)) ? (4) : (4))]();
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        assign sfu_operands_if[i].valid = operands_if[i].valid && (operands_if[i].data.ex_type == 2);
        assign sfu_operands_if[i].data = operands_if[i].data;
    wire [1-1:0] sfu_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __sfu_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (sfu_reset)                          
    );
        VX_elastic_buffer #(
            .DATAW   (DATAW),
            .SIZE    (2),
            .OUT_REG (2)
        ) sfu_buffer (
            .clk        (clk),
            .reset      (sfu_reset),
            .valid_in   (sfu_operands_if[i].valid),
            .ready_in   (sfu_operands_if[i].ready),
            .data_in    (
    {sfu_operands_if[i].data.uuid, sfu_operands_if[i].data.wis, sfu_operands_if[i].data.tmask, sfu_operands_if[i].data.op_type, sfu_operands_if[i].data.op_mod, sfu_operands_if[i].data.wb, sfu_operands_if[i].data.use_PC, sfu_operands_if[i].data.use_imm, sfu_operands_if[i].data.PC, sfu_operands_if[i].data.imm, sfu_operands_if[i].data.rd, last_active_tid[i], sfu_operands_if[i].data.rs1_data, sfu_operands_if[i].data.rs2_data, sfu_operands_if[i].data.rs3_data}),           
            .data_out   (sfu_dispatch_if[i].data),
            .valid_out  (sfu_dispatch_if[i].valid),
            .ready_out  (sfu_dispatch_if[i].ready)
        );
    end
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        assign operands_if[i].ready = (alu_operands_if[i].ready && (operands_if[i].data.ex_type == 0)) 
                                   || (lsu_operands_if[i].ready && (operands_if[i].data.ex_type == 1))
                                   || (sfu_operands_if[i].ready && (operands_if[i].data.ex_type == 2));
    end
endmodule
