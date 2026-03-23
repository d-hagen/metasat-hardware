module VX_fpu_unit import VX_fpu_pkg::*; #(
    parameter CORE_ID = 0
) (
    input wire clk,
    input wire reset,
    VX_dispatch_if.slave    dispatch_if [(((4) < (4)) ? (4) : (4))],
    VX_fpu_to_csr_if.master fpu_to_csr_if[((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1)],
    VX_commit_if.master     commit_if [(((4) < (4)) ? (4) : (4))]
);
    localparam BLOCK_SIZE = ((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1);
    localparam NUM_LANES  = (((4 / 2) != 0) ? (4 / 2) : 1);
    localparam PID_BITS   = $clog2(4 / NUM_LANES);
    localparam PID_WIDTH  = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam TAG_WIDTH  = ((((2 * (4 / (((4 / 2) != 0) ? (4 / 2) : 1)))) > 1) ? $clog2((2 * (4 / (((4 / 2) != 0) ? (4 / 2) : 1)))) : 1);
    localparam PARTIAL_BW = (BLOCK_SIZE != (((4) < (4)) ? (4) : (4))) || (NUM_LANES != 4);
    VX_execute_if #(
        .NUM_LANES (NUM_LANES)
    ) execute_if[BLOCK_SIZE]();
    wire [1-1:0] dispatch_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __dispatch_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (dispatch_reset)                          
    );
    VX_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_REG    (PARTIAL_BW ? 1 : 0)
    ) dispatch_unit (
        .clk        (clk),
        .reset      (dispatch_reset),
        .dispatch_if(dispatch_if),
        .execute_if (execute_if)
    );
    VX_commit_if #(
        .NUM_LANES (NUM_LANES)
    ) commit_block_if[BLOCK_SIZE]();
    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin
        wire fpu_req_valid, fpu_req_ready;
        wire fpu_rsp_valid, fpu_rsp_ready;    
        wire [NUM_LANES-1:0][32-1:0] fpu_rsp_result;
        fflags_t fpu_rsp_fflags;
        wire fpu_rsp_has_fflags;
        wire [1-1:0]  fpu_rsp_uuid;
        wire [((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:0]    fpu_rsp_wid;
        wire [NUM_LANES-1:0]    fpu_rsp_tmask;
        wire [32-1:0]        fpu_rsp_PC;
        wire [$clog2(32)-1:0]     fpu_rsp_rd;
        wire [PID_WIDTH-1:0]    fpu_rsp_pid;
        wire                    fpu_rsp_sop;
        wire                    fpu_rsp_eop;
        wire [TAG_WIDTH-1:0] fpu_req_tag, fpu_rsp_tag;    
        wire mdata_full;
        wire [2-1:0] fpu_fmt = execute_if[block_idx].data.imm[2-1:0];
        wire [3-1:0] fpu_frm = execute_if[block_idx].data.op_mod[3-1:0];
        wire execute_fire = execute_if[block_idx].valid && execute_if[block_idx].ready;
        wire fpu_rsp_fire = fpu_rsp_valid && fpu_rsp_ready;
        VX_index_buffer #(
            .DATAW  (1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + 32 + $clog2(32) + PID_WIDTH + 1 + 1),
            .SIZE   ((2 * (4 / (((4 / 2) != 0) ? (4 / 2) : 1))))
        ) tag_store (
            .clk          (clk),
            .reset        (reset),
            .acquire_en   (execute_fire), 
            .write_addr   (fpu_req_tag), 
            .write_data   ({execute_if[block_idx].data.uuid, execute_if[block_idx].data.wid, execute_if[block_idx].data.tmask, execute_if[block_idx].data.PC, execute_if[block_idx].data.rd, execute_if[block_idx].data.pid, execute_if[block_idx].data.sop, execute_if[block_idx].data.eop}),
            .read_data    ({fpu_rsp_uuid, fpu_rsp_wid, fpu_rsp_tmask, fpu_rsp_PC, fpu_rsp_rd, fpu_rsp_pid, fpu_rsp_sop, fpu_rsp_eop}),
            .read_addr    (fpu_rsp_tag),
            .release_en   (fpu_rsp_fire), 
            .full         (mdata_full),
            . empty ()
        );
        wire [3-1:0] fpu_req_frm; 
    if (((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1) != 1) begin 
        if (((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1) != 4) begin 
            assign fpu_to_csr_if[block_idx].read_wid = {execute_if[block_idx].data.wid[((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:$clog2(((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1))], $clog2(((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1))'(block_idx)}; 
        end else begin 
            assign fpu_to_csr_if[block_idx].read_wid = ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'(block_idx); 
        end 
    end else begin 
        assign fpu_to_csr_if[block_idx].read_wid = execute_if[block_idx].data.wid; 
    end
        assign fpu_req_frm = (execute_if[block_idx].data.op_type != 4'b0111 
                           && fpu_frm == 3'b111) ? fpu_to_csr_if[block_idx].read_frm : fpu_frm;
        assign fpu_req_valid = execute_if[block_idx].valid && ~mdata_full;
        assign execute_if[block_idx].ready = fpu_req_ready && ~mdata_full;
    wire [1-1:0] fpu_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __fpu_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (fpu_reset)                          
    );   
        VX_fpu_dsp #(
            .NUM_LANES  (NUM_LANES),
            .TAGW       (TAG_WIDTH),
            .OUT_REG    (PARTIAL_BW ? 1 : 3)
        ) fpu_dsp (
            .clk        (clk),
            .reset      (fpu_reset), 
            .valid_in   (fpu_req_valid),
            .lane_mask  (execute_if[block_idx].data.tmask),
            .op_type    (execute_if[block_idx].data.op_type),
            .fmt        (fpu_fmt),
            .frm        (fpu_req_frm),
            .dataa      (execute_if[block_idx].data.rs1_data),
            .datab      (execute_if[block_idx].data.rs2_data),
            .datac      (execute_if[block_idx].data.rs3_data), 
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
                if (reset) begin
                    fpu_rsp_fflags_r <= '0;
                end else if (fpu_rsp_fire) begin
                    fpu_rsp_fflags_r <= fpu_rsp_eop ? '0 : (fpu_rsp_fflags_r | fpu_rsp_fflags);
                end
            end
            assign fpu_rsp_fflags_q = fpu_rsp_fflags_r | fpu_rsp_fflags;
        end else begin
            assign fpu_rsp_fflags_q = fpu_rsp_fflags;
        end
        assign fpu_to_csr_if[block_idx].write_enable = fpu_rsp_fire && fpu_rsp_eop && fpu_rsp_has_fflags;
    if (((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1) != 1) begin 
        if (((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1) != 4) begin 
            assign fpu_to_csr_if[block_idx].write_wid = {fpu_rsp_wid[((($clog2(4)) != 0) ? ($clog2(4)) : 1)-1:$clog2(((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1))], $clog2(((((((4) < (4)) ? (4) : (4)) / 1) != 0) ? ((((4) < (4)) ? (4) : (4)) / 1) : 1))'(block_idx)}; 
        end else begin 
            assign fpu_to_csr_if[block_idx].write_wid = ((($clog2(4)) != 0) ? ($clog2(4)) : 1)'(block_idx); 
        end 
    end else begin 
        assign fpu_to_csr_if[block_idx].write_wid = fpu_rsp_wid; 
    end
        assign fpu_to_csr_if[block_idx].write_fflags = fpu_rsp_fflags_q;
        VX_elastic_buffer #(
            .DATAW (1 + ((($clog2(4)) != 0) ? ($clog2(4)) : 1) + NUM_LANES + 32 + $clog2(32) + (NUM_LANES * 32) + PID_WIDTH + 1 + 1),
            .SIZE  (0)
        ) rsp_buf (
            .clk       (clk),
            .reset     (reset),
            .valid_in  (fpu_rsp_valid),
            .ready_in  (fpu_rsp_ready),
            .data_in   ({fpu_rsp_uuid, fpu_rsp_wid, fpu_rsp_tmask, fpu_rsp_PC, fpu_rsp_rd, fpu_rsp_result, fpu_rsp_pid, fpu_rsp_sop, fpu_rsp_eop}),
            .data_out  ({commit_block_if[block_idx].data.uuid, commit_block_if[block_idx].data.wid, commit_block_if[block_idx].data.tmask, commit_block_if[block_idx].data.PC, commit_block_if[block_idx].data.rd, commit_block_if[block_idx].data.data, commit_block_if[block_idx].data.pid, commit_block_if[block_idx].data.sop, commit_block_if[block_idx].data.eop}),
            .valid_out (commit_block_if[block_idx].valid),
            .ready_out (commit_block_if[block_idx].ready)
        );
        assign commit_block_if[block_idx].data.wb = 1'b1;
    end
    wire [1-1:0] commit_reset;                        
    VX_reset_relay #(.N(1), .MAX_FANOUT(0)) __commit_reset ( 
        .clk     (clk),                         
        .reset   (reset),                         
        .reset_o (commit_reset)                          
    );
    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_REG    (PARTIAL_BW ? 3 : 0)
    ) gather_unit (
        .clk           (clk),
        .reset         (commit_reset),
        .commit_in_if  (commit_block_if),
        .commit_out_if (commit_if)
    );
endmodule
