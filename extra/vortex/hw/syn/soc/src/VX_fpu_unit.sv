module VX_fpu_unit import VX_fpu_pkg::*; #(
    parameter  INSTANCE_ID = ""
) (
    input wire clk,
    input wire reset,
    VX_dispatch_if.slave    dispatch_if [(((2 / 8) != 0) ? (2 / 8) : 1)],
    VX_commit_if.master     commit_if [(((2 / 8) != 0) ? (2 / 8) : 1)],
    VX_fpu_csr_if.master    fpu_csr_if[(((2 / 8) != 0) ? (2 / 8) : 1)]
);
    localparam BLOCK_SIZE = (((2 / 8) != 0) ? (2 / 8) : 1);
    localparam NUM_LANES  = 2;
    localparam PID_BITS   = $clog2(2 / NUM_LANES);
    localparam PID_WIDTH  = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam TAG_WIDTH  = ((((2 * (2 / 2))) > 1) ? $clog2((2 * (2 / 2))) : 1);
    localparam PARTIAL_BW = (BLOCK_SIZE != (((2 / 8) != 0) ? (2 / 8) : 1)) || (NUM_LANES != 2);
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) per_block_execute_if[BLOCK_SIZE]();
    VX_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (PARTIAL_BW ? 1 : 0)
    ) dispatch_unit (
        .clk        (clk),
        .reset      (reset),
        .dispatch_if(dispatch_if),
        .execute_if (per_block_execute_if)
    );
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) per_block_commit_if[BLOCK_SIZE]();
    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin
    wire [1-1:0] block_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT((((BLOCK_SIZE > 1)) ? 0 : -1))) __block_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (block_reset)                          
    );
        wire fpu_req_valid, fpu_req_ready;
        wire fpu_rsp_valid, fpu_rsp_ready;
        wire [NUM_LANES-1:0][32-1:0] fpu_rsp_result;
        fflags_t fpu_rsp_fflags;
        wire fpu_rsp_has_fflags;
        wire [1-1:0]  fpu_rsp_uuid;
        wire [((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:0]    fpu_rsp_wid;
        wire [NUM_LANES-1:0]    fpu_rsp_tmask;
        wire [(32-1)-1:0]     fpu_rsp_PC;
        wire [$clog2(32)-1:0]     fpu_rsp_rd;
        wire [PID_WIDTH-1:0]    fpu_rsp_pid;
        wire                    fpu_rsp_sop;
        wire                    fpu_rsp_eop;
        wire [TAG_WIDTH-1:0] fpu_req_tag, fpu_rsp_tag;
        wire mdata_full;
        wire [2-1:0] fpu_fmt = per_block_execute_if[block_idx].data.op_args.fpu.fmt;
        wire [3-1:0] fpu_frm = per_block_execute_if[block_idx].data.op_args.fpu.frm;
        wire execute_fire = per_block_execute_if[block_idx].valid && per_block_execute_if[block_idx].ready;
        wire fpu_rsp_fire = fpu_rsp_valid && fpu_rsp_ready;
        VX_index_buffer #(
            .DATAW  (1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + NUM_LANES + (32-1) + $clog2(32) + PID_WIDTH + 1 + 1),
            .SIZE   ((2 * (2 / 2)))
        ) tag_store (
            .clk          (clk),
            .reset        (block_reset),
            .acquire_en   (execute_fire),
            .write_addr   (fpu_req_tag),
            .write_data   ({per_block_execute_if[block_idx].data.uuid, per_block_execute_if[block_idx].data.wid, per_block_execute_if[block_idx].data.tmask, per_block_execute_if[block_idx].data.PC, per_block_execute_if[block_idx].data.rd, per_block_execute_if[block_idx].data.pid, per_block_execute_if[block_idx].data.sop, per_block_execute_if[block_idx].data.eop}),
            .read_data    ({fpu_rsp_uuid, fpu_rsp_wid, fpu_rsp_tmask, fpu_rsp_PC, fpu_rsp_rd, fpu_rsp_pid, fpu_rsp_sop, fpu_rsp_eop}),
            .read_addr    (fpu_rsp_tag),
            .release_en   (fpu_rsp_fire),
            .full         (mdata_full),
            . empty ()
        );
        wire [3-1:0] fpu_req_frm;
    if ((((2 / 8) != 0) ? (2 / 8) : 1) != 1) begin 
        if ((((2 / 8) != 0) ? (2 / 8) : 1) != 2) begin 
            assign fpu_csr_if[block_idx].read_wid = {per_block_execute_if[block_idx].data.wid[((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:$clog2((((2 / 8) != 0) ? (2 / 8) : 1))], $clog2((((2 / 8) != 0) ? (2 / 8) : 1))'(block_idx)}; 
        end else begin 
            assign fpu_csr_if[block_idx].read_wid = ((($clog2(2)) != 0) ? ($clog2(2)) : 1)'(block_idx); 
        end 
    end else begin 
        assign fpu_csr_if[block_idx].read_wid = per_block_execute_if[block_idx].data.wid; 
    end
        assign fpu_req_frm = (per_block_execute_if[block_idx].data.op_type != 4'b0111
                           && fpu_frm == 3'b111) ? fpu_csr_if[block_idx].read_frm : fpu_frm;
        assign fpu_req_valid = per_block_execute_if[block_idx].valid && ~mdata_full;
        assign per_block_execute_if[block_idx].ready = fpu_req_ready && ~mdata_full;
        VX_fpu_dsp #(
            .NUM_LANES  (NUM_LANES),
            .TAG_WIDTH  (TAG_WIDTH),
            .OUT_BUF    (PARTIAL_BW ? 1 : 3)
        ) fpu_dsp (
            .clk        (clk),
            .reset      (block_reset),
            .valid_in   (fpu_req_valid),
            .mask_in    (per_block_execute_if[block_idx].data.tmask),
            .op_type    (per_block_execute_if[block_idx].data.op_type),
            .fmt        (fpu_fmt),
            .frm        (fpu_req_frm),
            .dataa      (per_block_execute_if[block_idx].data.rs1_data),
            .datab      (per_block_execute_if[block_idx].data.rs2_data),
            .datac      (per_block_execute_if[block_idx].data.rs3_data),
            .tag_in     (fpu_req_tag),
            .ready_in   (fpu_req_ready),
            .valid_out  (fpu_rsp_valid),
            .result     (fpu_rsp_result),
            .has_fflags (fpu_rsp_has_fflags),
            .fflags     (fpu_rsp_fflags),
            .tag_out    (fpu_rsp_tag),
            .ready_out  (fpu_rsp_ready)
        );
        fflags_t fpu_rsp_fflags_q;
        if (PID_BITS != 0) begin
            fflags_t fpu_rsp_fflags_r;
            always @(posedge clk) begin
                if (block_reset) begin
                    fpu_rsp_fflags_r <= '0;
                end else if (fpu_rsp_fire) begin
                    fpu_rsp_fflags_r <= fpu_rsp_eop ? '0 : (fpu_rsp_fflags_r | fpu_rsp_fflags);
                end
            end
            assign fpu_rsp_fflags_q = fpu_rsp_fflags_r | fpu_rsp_fflags;
        end else begin
            assign fpu_rsp_fflags_q = fpu_rsp_fflags;
        end
        assign fpu_csr_if[block_idx].write_enable = fpu_rsp_fire && fpu_rsp_eop && fpu_rsp_has_fflags;
    if ((((2 / 8) != 0) ? (2 / 8) : 1) != 1) begin 
        if ((((2 / 8) != 0) ? (2 / 8) : 1) != 2) begin 
            assign fpu_csr_if[block_idx].write_wid = {fpu_rsp_wid[((($clog2(2)) != 0) ? ($clog2(2)) : 1)-1:$clog2((((2 / 8) != 0) ? (2 / 8) : 1))], $clog2((((2 / 8) != 0) ? (2 / 8) : 1))'(block_idx)}; 
        end else begin 
            assign fpu_csr_if[block_idx].write_wid = ((($clog2(2)) != 0) ? ($clog2(2)) : 1)'(block_idx); 
        end 
    end else begin 
        assign fpu_csr_if[block_idx].write_wid = fpu_rsp_wid; 
    end
        assign fpu_csr_if[block_idx].write_fflags = fpu_rsp_fflags_q;
        VX_elastic_buffer #(
            .DATAW (1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + NUM_LANES + (32-1) + $clog2(32) + (NUM_LANES * 32) + PID_WIDTH + 1 + 1),
            .SIZE  (0)
        ) rsp_buf (
            .clk       (clk),
            .reset     (block_reset),
            .valid_in  (fpu_rsp_valid),
            .ready_in  (fpu_rsp_ready),
            .data_in   ({fpu_rsp_uuid, fpu_rsp_wid, fpu_rsp_tmask, fpu_rsp_PC, fpu_rsp_rd, fpu_rsp_result, fpu_rsp_pid, fpu_rsp_sop, fpu_rsp_eop}),
            .data_out  ({per_block_commit_if[block_idx].data.uuid, per_block_commit_if[block_idx].data.wid, per_block_commit_if[block_idx].data.tmask, per_block_commit_if[block_idx].data.PC, per_block_commit_if[block_idx].data.rd, per_block_commit_if[block_idx].data.data, per_block_commit_if[block_idx].data.pid, per_block_commit_if[block_idx].data.sop, per_block_commit_if[block_idx].data.eop}),
            .valid_out (per_block_commit_if[block_idx].valid),
            .ready_out (per_block_commit_if[block_idx].ready)
        );
        assign per_block_commit_if[block_idx].data.wb = 1'b1;
    end
    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (PARTIAL_BW ? 3 : 0)
    ) gather_unit (
        .clk           (clk),
        .reset         (reset),
        .commit_in_if  (per_block_commit_if),
        .commit_out_if (commit_if)
    );
endmodule
