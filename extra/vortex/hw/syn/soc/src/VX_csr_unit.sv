module VX_csr_unit import VX_gpu_pkg::*; #(
    parameter  INSTANCE_ID = "",
    parameter CORE_ID = 0,
    parameter NUM_LANES = 1
) (
    input wire                  clk,
    input wire                  reset,
    input base_dcrs_t           base_dcrs,
    VX_commit_csr_if.slave      commit_csr_if,
    VX_sched_csr_if.slave       sched_csr_if,
    VX_execute_if.slave         execute_if,
    VX_commit_if.master         commit_if
);
    localparam PID_BITS   = $clog2(2 / NUM_LANES);
    localparam PID_WIDTH  = (((PID_BITS) != 0) ? (PID_BITS) : 1);
    localparam DATAW      = 1 + ((($clog2(2)) != 0) ? ($clog2(2)) : 1) + NUM_LANES + (32-1) + $clog2(32) + 1 + NUM_LANES * 32 + PID_WIDTH + 1 + 1;
    reg [NUM_LANES-1:0][32-1:0]  csr_read_data;
    reg  [32-1:0]                csr_write_data;
    wire [32-1:0]                csr_read_data_ro, csr_read_data_rw;
    wire [32-1:0]                csr_req_data;
    reg                             csr_rd_enable;
    wire                            csr_wr_enable;
    wire                            csr_req_ready;
    wire [12-1:0] csr_addr = execute_if.data.op_args.csr.addr;
    wire [$clog2(32)-1:0] csr_imm = execute_if.data.op_args.csr.imm;
    wire is_fpu_csr = (csr_addr <= 12'h003);
    assign sched_csr_if.alm_empty_wid = execute_if.data.wid;
    wire no_pending_instr = sched_csr_if.alm_empty || ~is_fpu_csr;
    wire csr_req_valid = execute_if.valid && no_pending_instr;
    assign execute_if.ready = csr_req_ready && no_pending_instr;
    wire [NUM_LANES-1:0][32-1:0] rs1_data;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        assign rs1_data[i] = execute_if.data.rs1_data[i];
    end
    wire csr_write_enable = (execute_if.data.op_type == 4'h6);
    VX_csr_data #(
        .INSTANCE_ID (INSTANCE_ID),
        .CORE_ID     (CORE_ID)
    ) csr_data (
        .clk            (clk),
        .reset          (reset),
        .base_dcrs      (base_dcrs),
        .commit_csr_if  (commit_csr_if),
        .cycles         (sched_csr_if.cycles),
        .active_warps   (sched_csr_if.active_warps),
        .thread_masks   (sched_csr_if.thread_masks),
        .read_enable    (csr_req_valid && csr_rd_enable),
        .read_uuid      (execute_if.data.uuid),
        .read_wid       (execute_if.data.wid),
        .read_addr      (csr_addr),
        .read_data_ro   (csr_read_data_ro),
        .read_data_rw   (csr_read_data_rw),
        .write_enable   (csr_req_valid && csr_wr_enable),
        .write_uuid     (execute_if.data.uuid),
        .write_wid      (execute_if.data.wid),
        .write_addr     (csr_addr),
        .write_data     (csr_write_data)
    );
    wire [NUM_LANES-1:0][32-1:0] wtid, gtid;
    for (genvar i = 0; i < NUM_LANES; ++i) begin
        if (PID_BITS != 0) begin
            assign wtid[i] = 32'(execute_if.data.pid * NUM_LANES + i);
        end else begin
            assign wtid[i] = 32'(i);
        end
        assign gtid[i] = (32'(CORE_ID) << ($clog2(2) + $clog2(2))) + (32'(execute_if.data.wid) << $clog2(2)) + wtid[i];
    end
    always @(*) begin
        csr_rd_enable = 0;
        case (csr_addr)
        12'hCC0 : csr_read_data = wtid;
        12'hF14   : csr_read_data = gtid;
        default : begin
            csr_read_data = {NUM_LANES{csr_read_data_ro | csr_read_data_rw}};
            csr_rd_enable = 1;
        end
        endcase
    end
    assign csr_req_data = execute_if.data.op_args.csr.use_imm ? 32'(csr_imm) : rs1_data[0];
    assign csr_wr_enable = (csr_write_enable || (| csr_req_data));
    always @(*) begin
        case (execute_if.data.op_type)
            4'h6: begin
                csr_write_data = csr_req_data;
            end
            4'h7: begin
                csr_write_data = csr_read_data_rw | csr_req_data;
            end
            default: begin
                csr_write_data = csr_read_data_rw & ~csr_req_data;
            end
        endcase
    end
    assign sched_csr_if.unlock_warp = csr_req_valid && csr_req_ready && execute_if.data.eop && is_fpu_csr;
    assign sched_csr_if.unlock_wid = execute_if.data.wid;
    VX_elastic_buffer #(
        .DATAW (DATAW),
        .SIZE  (2)
    ) rsp_buf (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (csr_req_valid),
        .ready_in  (csr_req_ready),
        .data_in   ({execute_if.data.uuid, execute_if.data.wid, execute_if.data.tmask, execute_if.data.PC, execute_if.data.rd, execute_if.data.wb, csr_read_data,       execute_if.data.pid, execute_if.data.sop, execute_if.data.eop}),
        .data_out  ({commit_if.data.uuid,  commit_if.data.wid,  commit_if.data.tmask,  commit_if.data.PC,  commit_if.data.rd,  commit_if.data.wb,  commit_if.data.data, commit_if.data.pid,  commit_if.data.sop,  commit_if.data.eop}),
        .valid_out (commit_if.valid),
        .ready_out (commit_if.ready)
    );
endmodule
