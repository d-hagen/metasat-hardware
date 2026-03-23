module VX_commit import VX_gpu_pkg::*; #(
    parameter CORE_ID = 0
) (
    input wire              clk,
    input wire              reset,
    VX_commit_if.slave      alu_commit_if [(((4) < (4)) ? (4) : (4))],
    VX_commit_if.slave      lsu_commit_if [(((4) < (4)) ? (4) : (4))],
    VX_commit_if.slave      sfu_commit_if [(((4) < (4)) ? (4) : (4))],
    VX_writeback_if.master  writeback_if  [(((4) < (4)) ? (4) : (4))],
    VX_commit_csr_if.master commit_csr_if,
    VX_commit_sched_if.master commit_sched_if,
    output wire [32-1:0][32-1:0] sim_wb_value
);
    localparam DATAW = 1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + 4 + 32 + 1 + $clog2(32) + 4 * 32 + 1 + 1 + 1;
    localparam COMMIT_SIZEW = $clog2(4 + 1);
    localparam COMMIT_ALL_SIZEW = COMMIT_SIZEW + (((4) < (4)) ? (4) : (4)) - 1;
    VX_commit_if commit_if[(((4) < (4)) ? (4) : (4))]();
    wire [(((4) < (4)) ? (4) : (4))-1:0] commit_fire;    
    wire [(((4) < (4)) ? (4) : (4))-1:0][((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0] commit_wid;
    wire [(((4) < (4)) ? (4) : (4))-1:0][4-1:0] commit_tmask;
    wire [(((4) < (4)) ? (4) : (4))-1:0] commit_eop;
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
    wire [1-1:0] arb_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __arb_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (arb_reset)                          
    );
        VX_stream_arb #(
            .NUM_INPUTS ((3 + 0)),
            .DATAW      (DATAW),
            .ARBITER    ("R"),
            .OUT_REG    (1)
        ) commit_arb (
            .clk       (clk),
            .reset     (arb_reset),
            .valid_in  ({            
                sfu_commit_if[i].valid,
                alu_commit_if[i].valid,
                lsu_commit_if[i].valid
            }),
            .ready_in  ({           
                sfu_commit_if[i].ready,
                alu_commit_if[i].ready,
                lsu_commit_if[i].ready                
            }),
            .data_in   ({
                sfu_commit_if[i].data,
                alu_commit_if[i].data,
                lsu_commit_if[i].data       
            }),
            .data_out  (commit_if[i].data),
            .valid_out (commit_if[i].valid),
            .ready_out (commit_if[i].ready),
            . sel_out ()
        );
        assign commit_fire[i]  = commit_if[i].valid && commit_if[i].ready;        
        assign commit_tmask[i] = {4{commit_fire[i]}} & commit_if[i].data.tmask;
        assign commit_wid[i]   = commit_if[i].data.wid;
        assign commit_eop[i]   = commit_if[i].data.eop;
    end
    wire [(((4) < (4)) ? (4) : (4))-1:0][COMMIT_SIZEW-1:0] commit_size, commit_size_r;
    wire [COMMIT_ALL_SIZEW-1:0] commit_size_all, commit_size_all_r;
    wire commit_fire_any, commit_fire_any_r, commit_fire_any_rr;
    assign commit_fire_any = (| commit_fire);
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        wire [COMMIT_SIZEW-1:0] pop_count;
    VX_popcount #( 
        .N ($bits(commit_tmask[i])), 
        .MODEL (1) 
    ) __pop_count ( 
        .data_in  (commit_tmask[i]), 
        .data_out (pop_count) 
    );
        assign commit_size[i] = pop_count;
    end
    VX_pipe_register #(
        .DATAW  (1 + (((4) < (4)) ? (4) : (4)) * COMMIT_SIZEW),
        .RESETW (1)
    ) commit_size_reg1 (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({commit_fire_any, commit_size}),
        .data_out ({commit_fire_any_r, commit_size_r})
    );
    VX_reduce #(
        .DATAW_IN (COMMIT_SIZEW),
        .DATAW_OUT (COMMIT_ALL_SIZEW),
        .N  ((((4) < (4)) ? (4) : (4))),
        .OP ("+")
    ) commit_size_reduce (
        .data_in  (commit_size_r),
        .data_out (commit_size_all)
    );
    VX_pipe_register #(
        .DATAW  (1 + COMMIT_ALL_SIZEW),
        .RESETW (1)
    ) commit_size_reg2 (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({commit_fire_any_r, commit_size_all}),
        .data_out ({commit_fire_any_rr, commit_size_all_r})
    );
    reg [44-1:0] instret;
    always @(posedge clk) begin
       if (reset) begin
            instret <= '0;
        end else begin
            if (commit_fire_any_rr) begin
                instret <= instret + 44'(commit_size_all_r);
            end
        end
    end
    assign commit_csr_if.instret = instret;
    VX_pipe_register #(
        .DATAW  ((((4) < (4)) ? (4) : (4)) * (1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1))),
        .RESETW ((((4) < (4)) ? (4) : (4)))
    ) committed_pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({(commit_fire & commit_eop), commit_wid}),
        .data_out ({commit_sched_if.committed, commit_sched_if.committed_wid})
    );
    for (genvar i = 0; i < (((4) < (4)) ? (4) : (4)); ++i) begin
        assign writeback_if[i].valid = commit_if[i].valid && commit_if[i].data.wb;
        assign writeback_if[i].data.uuid = commit_if[i].data.uuid; 
        assign writeback_if[i].data.wis = wid_to_wis(commit_if[i].data.wid);
        assign writeback_if[i].data.PC = commit_if[i].data.PC; 
        assign writeback_if[i].data.tmask = commit_if[i].data.tmask; 
        assign writeback_if[i].data.rd = commit_if[i].data.rd; 
        assign writeback_if[i].data.data = commit_if[i].data.data; 
        assign writeback_if[i].data.sop = commit_if[i].data.sop; 
        assign writeback_if[i].data.eop = commit_if[i].data.eop;
        assign commit_if[i].ready = 1'b1;
    end
    reg [32-1:0][32-1:0] sim_wb_value_r;
    always @(posedge clk) begin
        if (writeback_if[0].valid) begin
            sim_wb_value_r[writeback_if[0].data.rd] <= writeback_if[0].data.data[0];
        end
    end
    assign sim_wb_value = sim_wb_value_r;
endmodule
