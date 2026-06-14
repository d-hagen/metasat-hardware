module VX_mem_switch import VX_gpu_pkg::*; #(
    parameter NUM_REQS       = 1,
    parameter DATA_SIZE      = 1,
    parameter TAG_WIDTH      = 1,
    parameter ADDR_WIDTH     = 1,
    parameter REQ_OUT_BUF    = 0,
    parameter RSP_OUT_BUF    = 0,
    parameter  ARBITER = "R",
    parameter LOG_NUM_REQS   = $clog2(NUM_REQS)
) (
    input wire              clk,
    input wire              reset,
    input wire [(((LOG_NUM_REQS) != 0) ? (LOG_NUM_REQS) : 1)-1:0] bus_sel,
    VX_mem_bus_if.slave     bus_in_if,
    VX_mem_bus_if.master    bus_out_if [NUM_REQS]
);
    localparam DATA_WIDTH = (8 * DATA_SIZE);
    localparam REQ_DATAW  = TAG_WIDTH + ADDR_WIDTH + (2 + 1) + 1 + DATA_SIZE + DATA_WIDTH;
    localparam RSP_DATAW  = TAG_WIDTH + DATA_WIDTH;
    wire [NUM_REQS-1:0]                req_valid_out;
    wire [NUM_REQS-1:0][REQ_DATAW-1:0] req_data_out;
    wire [NUM_REQS-1:0]                req_ready_out;
    VX_stream_switch #(
        .NUM_OUTPUTS (NUM_REQS),
        .DATAW       (REQ_DATAW),
        .OUT_BUF     (REQ_OUT_BUF)
    ) req_switch (
        .clk       (clk),
        .reset     (reset),
        .sel_in    (bus_sel),
        .valid_in  (bus_in_if.req_valid),
        .data_in   (bus_in_if.req_data),
        .ready_in  (bus_in_if.req_ready),
        .valid_out (req_valid_out),
        .data_out  (req_data_out),
        .ready_out (req_ready_out)
    );
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign bus_out_if[i].req_valid = req_valid_out[i];
        assign bus_out_if[i].req_data = req_data_out[i];
        assign req_ready_out[i] = bus_out_if[i].req_ready;
    end
    wire [NUM_REQS-1:0]              rsp_valid_in;
    wire [NUM_REQS-1:0][RSP_DATAW-1:0] rsp_data_in;
    wire [NUM_REQS-1:0]              rsp_ready_in;
    for (genvar i = 0; i < NUM_REQS; ++i) begin
        assign rsp_valid_in[i] = bus_out_if[i].rsp_valid;
        assign rsp_data_in[i] = bus_out_if[i].rsp_data;
        assign bus_out_if[i].rsp_ready = rsp_ready_in[i];
    end
    VX_stream_arb #(
        .NUM_INPUTS (NUM_REQS),
        .DATAW      (RSP_DATAW),
        .ARBITER    (ARBITER),
        .OUT_BUF    (RSP_OUT_BUF)
    ) rsp_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (rsp_valid_in),
        .data_in   (rsp_data_in),
        .ready_in  (rsp_ready_in),
        .valid_out (bus_in_if.rsp_valid),
        .data_out  (bus_in_if.rsp_data),
        .ready_out (bus_in_if.rsp_ready),
        . sel_out ()
    );
endmodule
