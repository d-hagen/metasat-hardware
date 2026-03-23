module VX_issue #(
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    output wire [32-1:0] debug_stall [(((4) < (4)) ? (4) : (4))],
    VX_decode_if.slave      decode_if,
    VX_writeback_if.slave   writeback_if [(((4) < (4)) ? (4) : (4))],
    VX_dispatch_if.master   alu_dispatch_if [(((4) < (4)) ? (4) : (4))],
    VX_dispatch_if.master   lsu_dispatch_if [(((4) < (4)) ? (4) : (4))],
    VX_dispatch_if.master   sfu_dispatch_if [(((4) < (4)) ? (4) : (4))]
);
    VX_ibuffer_if  ibuffer_if [(((4) < (4)) ? (4) : (4))]();
    VX_ibuffer_if  scoreboard_if [(((4) < (4)) ? (4) : (4))]();
    VX_operands_if operands_if [(((4) < (4)) ? (4) : (4))]();
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
        .CORE_ID (CORE_ID)
    ) ibuffer (
        .clk            (clk),
        .reset          (ibuf_reset), 
        .decode_if      (decode_if),
        .ibuffer_if     (ibuffer_if)
    );
    VX_scoreboard #(
        .CORE_ID (CORE_ID)
    ) scoreboard (
        .clk            (clk),
        .reset          (scoreboard_reset),
        .debug_stall    (debug_stall),
        .writeback_if   (writeback_if),
        .ibuffer_if     (ibuffer_if),
        .scoreboard_if  (scoreboard_if)
    );
    VX_operands #(
        .CORE_ID (CORE_ID)
    ) operands (
        .clk            (clk), 
        .reset          (operands_reset), 
        .writeback_if   (writeback_if),
        .scoreboard_if  (scoreboard_if),
        .operands_if    (operands_if)
    );
    VX_dispatch #(
        .CORE_ID (CORE_ID)
    ) dispatch (
        .clk            (clk), 
        .reset          (dispatch_reset),
        .operands_if    (operands_if),
        .alu_dispatch_if(alu_dispatch_if),
        .lsu_dispatch_if(lsu_dispatch_if),
        .sfu_dispatch_if(sfu_dispatch_if)
    ); 
endmodule
