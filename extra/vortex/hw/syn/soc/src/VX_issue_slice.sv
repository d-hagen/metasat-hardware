module VX_issue_slice import VX_gpu_pkg::*, VX_trace_pkg::*; #(
    parameter  INSTANCE_ID = "",
    parameter ISSUE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    VX_decode_if.slave      decode_if,
    VX_writeback_if.slave   writeback_if,
    VX_dispatch_if.master   dispatch_if [(3 + 0)]
);
    VX_ibuffer_if ibuffer_if [PER_ISSUE_WARPS]();
    VX_scoreboard_if scoreboard_if();
    VX_operands_if operands_if();
    wire [1-1:0] ibuf_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __ibuf_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (ibuf_reset)                          
    );
    wire [1-1:0] scoreboard_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __scoreboard_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (scoreboard_reset)                          
    );
    wire [1-1:0] operands_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __operands_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (operands_reset)                          
    );
    wire [1-1:0] dispatch_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __dispatch_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (dispatch_reset)                          
    );
    VX_ibuffer #(
        .INSTANCE_ID ($sformatf("%s-ibuffer", INSTANCE_ID))
    ) ibuffer (
        .clk            (clk),
        .reset          (ibuf_reset),
        .decode_if      (decode_if),
        .ibuffer_if     (ibuffer_if)
    );
    VX_scoreboard #(
        .INSTANCE_ID ($sformatf("%s-scoreboard", INSTANCE_ID))
    ) scoreboard (
        .clk            (clk),
        .reset          (scoreboard_reset),
        .writeback_if   (writeback_if),
        .ibuffer_if     (ibuffer_if),
        .scoreboard_if  (scoreboard_if)
    );
    VX_operands #(
        .INSTANCE_ID ($sformatf("%s-operands", INSTANCE_ID))
    ) operands (
        .clk            (clk),
        .reset          (operands_reset),
        .writeback_if   (writeback_if),
        .scoreboard_if  (scoreboard_if),
        .operands_if    (operands_if)
    );
    VX_dispatch #(
        .INSTANCE_ID ($sformatf("%s-dispatch", INSTANCE_ID))
    ) dispatch (
        .clk            (clk),
        .reset          (dispatch_reset),
        .operands_if    (operands_if),
        .dispatch_if    (dispatch_if)
    );
endmodule
