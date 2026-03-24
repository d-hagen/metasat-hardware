module VX_axi_adapter #(
    parameter DATA_WIDTH     = 512,
    parameter ADDR_WIDTH     = 32,
    parameter TAG_WIDTH      = 8,
    parameter NUM_BANKS      = 1,
    parameter AVS_ADDR_WIDTH = (ADDR_WIDTH - $clog2(DATA_WIDTH/8)),
    parameter RSP_OUT_BUF    = 0
) (
    input  wire                     clk,
    input  wire                     reset,
    input wire                      mem_req_valid,
    input wire                      mem_req_rw,
    input wire [DATA_WIDTH/8-1:0]   mem_req_byteen,
    input wire [AVS_ADDR_WIDTH-1:0] mem_req_addr,
    input wire [DATA_WIDTH-1:0]     mem_req_data,
    input wire [TAG_WIDTH-1:0]      mem_req_tag,
    output wire                     mem_req_ready,
    output wire                     mem_rsp_valid,
    output wire [DATA_WIDTH-1:0]    mem_rsp_data,
    output wire [TAG_WIDTH-1:0]     mem_rsp_tag,
    input wire                      mem_rsp_ready,
    output wire                     m_axi_awvalid [NUM_BANKS],
    input wire                      m_axi_awready [NUM_BANKS],
    output wire [ADDR_WIDTH-1:0]    m_axi_awaddr [NUM_BANKS],
    output wire [TAG_WIDTH-1:0]     m_axi_awid [NUM_BANKS],
    output wire [7:0]               m_axi_awlen [NUM_BANKS],
    output wire [2:0]               m_axi_awsize [NUM_BANKS],
    output wire [1:0]               m_axi_awburst [NUM_BANKS],
    output wire [1:0]               m_axi_awlock [NUM_BANKS],
    output wire [3:0]               m_axi_awcache [NUM_BANKS],
    output wire [2:0]               m_axi_awprot [NUM_BANKS],
    output wire [3:0]               m_axi_awqos [NUM_BANKS],
    output wire [3:0]               m_axi_awregion [NUM_BANKS],
    output wire                     m_axi_wvalid [NUM_BANKS],
    input wire                      m_axi_wready [NUM_BANKS],
    output wire [DATA_WIDTH-1:0]    m_axi_wdata [NUM_BANKS],
    output wire [DATA_WIDTH/8-1:0]  m_axi_wstrb [NUM_BANKS],
    output wire                     m_axi_wlast [NUM_BANKS],
    input wire                      m_axi_bvalid [NUM_BANKS],
    output wire                     m_axi_bready [NUM_BANKS],
    input wire [TAG_WIDTH-1:0]      m_axi_bid [NUM_BANKS],
    input wire [1:0]                m_axi_bresp [NUM_BANKS],
    output wire                     m_axi_arvalid [NUM_BANKS],
    input wire                      m_axi_arready [NUM_BANKS],
    output wire [ADDR_WIDTH-1:0]    m_axi_araddr [NUM_BANKS],
    output wire [TAG_WIDTH-1:0]     m_axi_arid [NUM_BANKS],
    output wire [7:0]               m_axi_arlen [NUM_BANKS],
    output wire [2:0]               m_axi_arsize [NUM_BANKS],
    output wire [1:0]               m_axi_arburst [NUM_BANKS],
    output wire [1:0]               m_axi_arlock [NUM_BANKS],
    output wire [3:0]               m_axi_arcache [NUM_BANKS],
    output wire [2:0]               m_axi_arprot [NUM_BANKS],
    output wire [3:0]               m_axi_arqos [NUM_BANKS],
    output wire [3:0]               m_axi_arregion [NUM_BANKS],
    input wire                      m_axi_rvalid [NUM_BANKS],
    output wire                     m_axi_rready [NUM_BANKS],
    input wire [DATA_WIDTH-1:0]     m_axi_rdata [NUM_BANKS],
    input wire                      m_axi_rlast [NUM_BANKS],
    input wire [TAG_WIDTH-1:0]      m_axi_rid [NUM_BANKS],
    input wire [1:0]                m_axi_rresp [NUM_BANKS]
);
    localparam AXSIZE = $clog2(DATA_WIDTH/8);
    localparam BANK_ADDRW = (((NUM_BANKS) > 1) ? $clog2(NUM_BANKS) : 1);
    localparam LOG2_NUM_BANKS = $clog2(NUM_BANKS);
    wire [BANK_ADDRW-1:0] req_bank_sel;
    if (NUM_BANKS > 1) begin
        assign req_bank_sel = mem_req_addr[BANK_ADDRW-1:0];
    end else begin
        assign req_bank_sel = '0;
    end
    wire mem_req_fire = mem_req_valid && mem_req_ready;
    reg [NUM_BANKS-1:0] m_axi_aw_ack;
    reg [NUM_BANKS-1:0] m_axi_w_ack;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        wire m_axi_aw_fire = m_axi_awvalid[i] && m_axi_awready[i];
        wire m_axi_w_fire = m_axi_wvalid[i] && m_axi_wready[i];
        always @(posedge clk) begin
            if (reset) begin
                m_axi_aw_ack[i] <= 0;
                m_axi_w_ack[i]  <= 0;
            end else begin
                if (mem_req_fire && (req_bank_sel == i)) begin
                    m_axi_aw_ack[i] <= 0;
                    m_axi_w_ack[i] <= 0;
                end else begin
                    if (m_axi_aw_fire)
                        m_axi_aw_ack[i] <= 1;
                    if (m_axi_w_fire)
                        m_axi_w_ack[i] <= 1;
                end
            end
        end
    end
    wire axi_write_ready [NUM_BANKS];
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign axi_write_ready[i] = (m_axi_awready[i] || m_axi_aw_ack[i])
                                 && (m_axi_wready[i] || m_axi_w_ack[i]);
    end
    if (NUM_BANKS > 1) begin
        assign mem_req_ready = mem_req_rw ? axi_write_ready[req_bank_sel] : m_axi_arready[req_bank_sel];
    end else begin
        assign mem_req_ready = mem_req_rw ? axi_write_ready[0] : m_axi_arready[0];
    end
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign m_axi_awvalid[i] = mem_req_valid && mem_req_rw && (req_bank_sel == i) && ~m_axi_aw_ack[i];
        assign m_axi_awaddr[i]  = (ADDR_WIDTH'(mem_req_addr) >> LOG2_NUM_BANKS) << AXSIZE;
        assign m_axi_awid[i]    = mem_req_tag;
        assign m_axi_awlen[i]   = 8'b00000000;
        assign m_axi_awsize[i]  = 3'(AXSIZE);
        assign m_axi_awburst[i] = 2'b00;
        assign m_axi_awlock[i]  = 2'b00;
        assign m_axi_awcache[i] = 4'b0000;
        assign m_axi_awprot[i]  = 3'b000;
        assign m_axi_awqos[i]   = 4'b0000;
        assign m_axi_awregion[i]= 4'b0000;
    end
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign m_axi_wvalid[i] = mem_req_valid && mem_req_rw && (req_bank_sel == i) && ~m_axi_w_ack[i];
        assign m_axi_wdata[i]  = mem_req_data;
        assign m_axi_wstrb[i]  = mem_req_byteen;
        assign m_axi_wlast[i]  = 1'b1;
    end
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign m_axi_bready[i] = 1'b1;
        ;
    end
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign m_axi_arvalid[i] = mem_req_valid && ~mem_req_rw && (req_bank_sel == i);
        assign m_axi_araddr[i]  = (ADDR_WIDTH'(mem_req_addr) >> LOG2_NUM_BANKS) << AXSIZE;
        assign m_axi_arid[i]    = mem_req_tag;
        assign m_axi_arlen[i]   = 8'b00000000;
        assign m_axi_arsize[i]  = 3'(AXSIZE);
        assign m_axi_arburst[i] = 2'b00;
        assign m_axi_arlock[i]  = 2'b00;
        assign m_axi_arcache[i] = 4'b0000;
        assign m_axi_arprot[i]  = 3'b000;
        assign m_axi_arqos[i]   = 4'b0000;
        assign m_axi_arregion[i]= 4'b0000;
    end
    wire [NUM_BANKS-1:0] rsp_arb_valid_in;
    wire [NUM_BANKS-1:0][DATA_WIDTH+TAG_WIDTH-1:0] rsp_arb_data_in;
    wire [NUM_BANKS-1:0] rsp_arb_ready_in;
    for (genvar i = 0; i < NUM_BANKS; ++i) begin
        assign rsp_arb_valid_in[i] = m_axi_rvalid[i];
        assign rsp_arb_data_in[i] = {m_axi_rdata[i], m_axi_rid[i]};
        assign m_axi_rready[i] = rsp_arb_ready_in[i];
        ;
        ;
    end
    VX_stream_arb #(
        .NUM_INPUTS (NUM_BANKS),
        .DATAW      (DATA_WIDTH + TAG_WIDTH),
        .ARBITER    ("F"),
        .OUT_BUF    (RSP_OUT_BUF)
    ) rsp_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (rsp_arb_valid_in),
        .data_in   (rsp_arb_data_in),
        .ready_in  (rsp_arb_ready_in),
        .data_out  ({mem_rsp_data, mem_rsp_tag}),
        .valid_out (mem_rsp_valid),
        .ready_out (mem_rsp_ready),
        . sel_out ()
    );
endmodule
