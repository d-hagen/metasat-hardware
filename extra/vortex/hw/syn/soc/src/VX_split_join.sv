module VX_split_join import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0
) (
    input  wire                     clk,
    input  wire                     reset,
    input  wire                     valid,
    input  wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]     wid,
    input  split_t                  split,
    input  join_t                   sjoin,
    output wire                     join_valid,
    output wire                     join_is_dvg,
    output wire                     join_is_else,
    output wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]     join_wid,
    output wire [4-1:0]  join_tmask,
    output wire [32-1:0]         join_pc
);
    wire [(32+4)-1:0] ipdom_data [4-1:0];
    wire ipdom_set [4-1:0];
    wire [(32+4)-1:0] ipdom_q0 = {split.then_tmask | split.else_tmask, 32'(0)};
    wire [(32+4)-1:0] ipdom_q1 = {split.else_tmask, split.next_pc};
    wire ipdom_push = valid && split.valid && split.is_dvg;
    wire ipdom_pop = valid && sjoin.valid && sjoin.is_dvg;
    for (genvar i = 0; i < 4; ++i) begin
    wire [1-1:0] ipdom_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __ipdom_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (ipdom_reset)                          
    );
        VX_ipdom_stack #(
            .WIDTH (32+4), 
            .DEPTH ((((4-1) != 0) ? (4-1) : 1))
        ) ipdom_stack (
            .clk   (clk),
            .reset (ipdom_reset),
            .push  (ipdom_push && (i == wid)),
            .pop   (ipdom_pop && (i == wid)),
            .q0    (ipdom_q0),
            .q1    (ipdom_q1),
            .d     (ipdom_data[i]),
            .d_set (ipdom_set[i]),
            . empty (),
            . full ()
        );
    end
    VX_pipe_register #(
        .DATAW  (1 + 1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + 1 + 32 + 4),
        .DEPTH  (1),
        .RESETW (1)
    ) pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({valid && sjoin.valid, sjoin.is_dvg, ipdom_set[wid], wid, ipdom_data[wid]}),
        .data_out ({join_valid, join_is_dvg, join_is_else, join_wid, join_tmask, join_pc})
    );
endmodule
