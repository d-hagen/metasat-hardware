module VX_split_join import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input  wire                     clk,
    input  wire                     reset,
    input  wire                     valid,
    input  wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0]     wid,
    input  split_t                  split,
    input  join_t                   sjoin,
    output wire                     join_valid,
    output wire                     join_is_dvg,
    output wire                     join_is_else,
    output wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0]     join_wid,
    output wire [2-1:0]  join_tmask,
    output wire [(32-1)-1:0]      join_pc,
    input  wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0]     stack_wid,
    output wire [((($clog2((((2-1) != 0) ? (2-1) : 1))) != 0) ? ($clog2((((2-1) != 0) ? (2-1) : 1))) : 1)-1:0] stack_ptr
);
    wire [(2+(32-1))-1:0] ipdom_data [2-1:0];
    wire [((($clog2((((2-1) != 0) ? (2-1) : 1))) != 0) ? ($clog2((((2-1) != 0) ? (2-1) : 1))) : 1)-1:0] ipdom_q_ptr [2-1:0];
    wire ipdom_set [2-1:0];
    wire [(2+(32-1))-1:0] ipdom_q0 = {split.then_tmask | split.else_tmask, (32-1)'(0)};
    wire [(2+(32-1))-1:0] ipdom_q1 = {split.else_tmask, split.next_pc};
    wire sjoin_is_dvg = (sjoin.stack_ptr != ipdom_q_ptr[wid]);
    wire ipdom_push = valid && split.valid && split.is_dvg;
    wire ipdom_pop = valid && sjoin.valid && sjoin_is_dvg;
    for (genvar i = 0; i < 2; ++i) begin
    wire [1-1:0] ipdom_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __ipdom_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (ipdom_reset)                          
    );
        VX_ipdom_stack #(
            .WIDTH (2+(32-1)),
            .DEPTH ((((2-1) != 0) ? (2-1) : 1))
        ) ipdom_stack (
            .clk   (clk),
            .reset (ipdom_reset),
            .q0    (ipdom_q0),
            .q1    (ipdom_q1),
            .d     (ipdom_data[i]),
            .d_set (ipdom_set[i]),
            .q_ptr (ipdom_q_ptr[i]),
            .push  (ipdom_push && (i == wid)),
            .pop   (ipdom_pop && (i == wid)),
            . empty (),
            . full ()
        );
    end
    VX_pipe_register #(
        .DATAW  (1 + 1 + 1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + 2 + (32-1)),
        .DEPTH  (1),
        .RESETW (1)
    ) pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({valid && sjoin.valid, sjoin_is_dvg, ipdom_set[wid], wid, ipdom_data[wid]}),
        .data_out ({join_valid, join_is_dvg, join_is_else, join_wid, {join_tmask, join_pc}})
    );
    assign stack_ptr = ipdom_q_ptr[stack_wid];
endmodule
