// Copyright © 2019-2023
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "vortex_afu.vh"

module vortex_afu #(
	parameter C_S_AXI_CTRL_ADDR_WIDTH = 8,
	parameter C_S_AXI_CTRL_DATA_WIDTH = 32,
	parameter C_M_AXI_MEM_ID_WIDTH    = 8,
	parameter C_M_AXI_MEM_ADDR_WIDTH  = 64,
	parameter C_M_AXI_MEM_DATA_WIDTH  = `VX_MEM_DATA_WIDTH    
) (
	// System signals
	input wire clk,
	input wire reset,

	// AXI4 master interface
	output wire                                 m_axi_mem_awvalid,
	output wire [C_M_AXI_MEM_ADDR_WIDTH-1:0]    m_axi_mem_awaddr,
	output wire [C_M_AXI_MEM_ID_WIDTH-1:0]      m_axi_mem_awid,
	output wire [7:0]                           m_axi_mem_awlen,
	output wire                                 m_axi_mem_wvalid,
	output wire [C_M_AXI_MEM_DATA_WIDTH-1:0]    m_axi_mem_wdata,
	output wire [C_M_AXI_MEM_DATA_WIDTH/8-1:0]  m_axi_mem_wstrb,
	output wire                                 m_axi_mem_wlast,
	output wire                                 m_axi_mem_arvalid,
	output wire [C_M_AXI_MEM_ADDR_WIDTH-1:0]    m_axi_mem_araddr,
	output wire [C_M_AXI_MEM_ID_WIDTH-1:0]      m_axi_mem_arid,
	output wire [7:0]                           m_axi_mem_arlen,
	output wire                                 m_axi_mem_rready,
	output wire                                 m_axi_mem_bready,
	input  wire                                 m_axi_mem_awready,
	input  wire                                 m_axi_mem_wready,
	input  wire                                 m_axi_mem_arready,
	input  wire                                 m_axi_mem_rvalid,
	input  wire [C_M_AXI_MEM_DATA_WIDTH-1:0]    m_axi_mem_rdata,
	input  wire                                 m_axi_mem_rlast,
	input  wire [C_M_AXI_MEM_ID_WIDTH-1:0]      m_axi_mem_rid,
	input  wire [1:0]                           m_axi_mem_rresp,
	input  wire                                 m_axi_mem_bvalid,
	input  wire [1:0]                           m_axi_mem_bresp,
	input  wire [C_M_AXI_MEM_ID_WIDTH-1:0]      m_axi_mem_bid,

	// AXI4-Lite slave interface
	input  wire                                 s_axi_ctrl_awvalid,
	output wire                                 s_axi_ctrl_awready,
	input  wire [C_S_AXI_CTRL_ADDR_WIDTH-1:0]   s_axi_ctrl_awaddr,
	input  wire                                 s_axi_ctrl_wvalid,
	output wire                                 s_axi_ctrl_wready,
	input  wire [C_S_AXI_CTRL_DATA_WIDTH-1:0]   s_axi_ctrl_wdata,
	input  wire [C_S_AXI_CTRL_DATA_WIDTH/8-1:0] s_axi_ctrl_wstrb,
	input  wire                                 s_axi_ctrl_arvalid,
	output wire                                 s_axi_ctrl_arready,
	input  wire [C_S_AXI_CTRL_ADDR_WIDTH-1:0]   s_axi_ctrl_araddr,
	output wire                                 s_axi_ctrl_rvalid,
	input  wire                                 s_axi_ctrl_rready,
	output wire [C_S_AXI_CTRL_DATA_WIDTH-1:0]   s_axi_ctrl_rdata,
	output wire [1:0]                           s_axi_ctrl_rresp,
	output wire                                 s_axi_ctrl_bvalid,
	input  wire                                 s_axi_ctrl_bready,
	output wire [1:0]                           s_axi_ctrl_bresp,  

	output wire                                 interrupt 
);
	assign interrupt = 0;

	//wire [`XLEN-1:0]                    debug_regs [3+`ISSUE_WIDTH * 3];

	// AXI Control unit
	wire                                m_axi_ctrl_awvalid;
	wire                                m_axi_ctrl_awready;
	wire [C_M_AXI_MEM_ADDR_WIDTH-1:0]   m_axi_ctrl_awaddr;
	wire [C_M_AXI_MEM_ID_WIDTH-1:0]     m_axi_ctrl_awid;
	wire [7:0]                          m_axi_ctrl_awlen;
	wire                                m_axi_ctrl_wvalid; 
	wire                                m_axi_ctrl_wready;
	wire [C_M_AXI_MEM_DATA_WIDTH-1:0]   m_axi_ctrl_wdata;
	wire [C_M_AXI_MEM_DATA_WIDTH/8-1:0] m_axi_ctrl_wstrb;    
	wire                                m_axi_ctrl_wlast;  
	wire                                m_axi_ctrl_bvalid;
	wire                                m_axi_ctrl_bready;
	wire [C_M_AXI_MEM_ID_WIDTH-1:0]     m_axi_ctrl_bid;
	wire [1:0]                          m_axi_ctrl_bresp;
	wire                                m_axi_ctrl_arvalid;
	wire                                m_axi_ctrl_arready;
	wire [C_M_AXI_MEM_ADDR_WIDTH-1:0]   m_axi_ctrl_araddr;
	wire [C_M_AXI_MEM_ID_WIDTH-1:0]     m_axi_ctrl_arid;
	wire [7:0]                          m_axi_ctrl_arlen;
	wire                                m_axi_ctrl_rvalid;
	wire                                m_axi_ctrl_rready;
	wire [C_M_AXI_MEM_DATA_WIDTH-1:0]   m_axi_ctrl_rdata;
	wire                                m_axi_ctrl_rlast;
	wire [C_M_AXI_MEM_ID_WIDTH-1:0]     m_axi_ctrl_rid;
	wire [1:0]                          m_axi_ctrl_rresp;

	//assign inputs
	assign m_axi_ctrl_awready = m_axi_mem_awready;
	assign m_axi_ctrl_wready = m_axi_mem_wready;
	assign m_axi_ctrl_bvalid = m_axi_mem_bvalid;
	assign m_axi_ctrl_bid = m_axi_mem_bid;
	assign m_axi_ctrl_bresp = m_axi_mem_bresp;
	assign m_axi_ctrl_arready = m_axi_mem_arready;
	assign m_axi_ctrl_rvalid = m_axi_mem_rvalid;
	assign m_axi_ctrl_rdata = m_axi_mem_rdata;
	assign m_axi_ctrl_rlast = m_axi_mem_rlast;
	assign m_axi_ctrl_rid = m_axi_mem_rid;
	assign m_axi_ctrl_rresp = m_axi_mem_rresp;

	wire vx_busy;
	wire vx_reset;
	wire vx_dcr_wr_valid;
	wire [`VX_DCR_ADDR_WIDTH-1:0] vx_dcr_wr_addr;
	wire [`VX_DCR_DATA_WIDTH-1:0] vx_dcr_wr_data;

	//debug signals
	wire [`XLEN-1:0] vx_PC = '0;
	wire [31:0]      vx_instr = '0;

	VX_afu_ctrl #(
		.C_S_AXI_CTRL_ADDR_WIDTH (C_S_AXI_CTRL_ADDR_WIDTH),
		.C_S_AXI_CTRL_DATA_WIDTH (C_S_AXI_CTRL_DATA_WIDTH),
		.C_M_AXI_MEM_ID_WIDTH (C_M_AXI_MEM_ID_WIDTH),
		.C_M_AXI_MEM_ADDR_WIDTH (C_M_AXI_MEM_ADDR_WIDTH),
		.C_M_AXI_MEM_DATA_WIDTH (C_M_AXI_MEM_DATA_WIDTH)
	) afu_ctrl (
		.clk            	(clk),
		.reset          	(reset),
		//.debug_regs             (debug_regs),

		.m_axi_mem_awvalid	(m_axi_ctrl_awvalid),
		.m_axi_mem_awaddr	(m_axi_ctrl_awaddr),
		.m_axi_mem_awid		(m_axi_ctrl_awid),
		.m_axi_mem_awlen	(m_axi_ctrl_awlen),
		.m_axi_mem_wvalid	(m_axi_ctrl_wvalid),
		.m_axi_mem_wdata	(m_axi_ctrl_wdata),
		.m_axi_mem_wstrb	(m_axi_ctrl_wstrb),
		.m_axi_mem_wlast	(m_axi_ctrl_wlast),
		.m_axi_mem_arvalid	(m_axi_ctrl_arvalid),
		.m_axi_mem_araddr	(m_axi_ctrl_araddr),
		.m_axi_mem_arid		(m_axi_ctrl_arid),
		.m_axi_mem_arlen	(m_axi_ctrl_arlen),
		.m_axi_mem_rready	(m_axi_ctrl_rready),
		.m_axi_mem_bready	(m_axi_ctrl_bready),
		.m_axi_mem_awready	(m_axi_ctrl_awready),
		.m_axi_mem_wready	(m_axi_ctrl_wready),
		.m_axi_mem_arready	(m_axi_ctrl_arready),
		.m_axi_mem_rvalid	(m_axi_ctrl_rvalid),
		.m_axi_mem_rdata	(m_axi_ctrl_rdata),
		.m_axi_mem_rlast	(m_axi_ctrl_rlast),
		.m_axi_mem_rid		(m_axi_ctrl_rid),
		.m_axi_mem_rresp	(m_axi_ctrl_rresp),
		.m_axi_mem_bvalid	(m_axi_ctrl_bvalid),
		.m_axi_mem_bresp	(m_axi_ctrl_bresp),
		.m_axi_mem_bid		(m_axi_ctrl_bid),

		.s_axi_ctrl_awvalid	(s_axi_ctrl_awvalid),
		.s_axi_ctrl_awready	(s_axi_ctrl_awready),
		.s_axi_ctrl_awaddr	(s_axi_ctrl_awaddr),
		.s_axi_ctrl_wvalid	(s_axi_ctrl_wvalid),
		.s_axi_ctrl_wready	(s_axi_ctrl_wready),
		.s_axi_ctrl_wdata	(s_axi_ctrl_wdata),
		.s_axi_ctrl_wstrb	(s_axi_ctrl_wstrb),
		.s_axi_ctrl_arvalid	(s_axi_ctrl_arvalid),
		.s_axi_ctrl_arready	(s_axi_ctrl_arready),
		.s_axi_ctrl_araddr	(s_axi_ctrl_araddr),
		.s_axi_ctrl_rvalid	(s_axi_ctrl_rvalid),
		.s_axi_ctrl_rready	(s_axi_ctrl_rready),
		.s_axi_ctrl_rdata	(s_axi_ctrl_rdata),
		.s_axi_ctrl_rresp	(s_axi_ctrl_rresp),
		.s_axi_ctrl_bvalid	(s_axi_ctrl_bvalid),
		.s_axi_ctrl_bready	(s_axi_ctrl_bready),
		.s_axi_ctrl_bresp	(s_axi_ctrl_bresp),

		//debug signals
		.PC (vx_PC),
		.instr(vx_instr),


		.vx_reset		(vx_reset),
		.vx_busy		(vx_busy),
		.vx_dcr_wr_valid	(vx_dcr_wr_valid),
		.vx_dcr_wr_addr		(vx_dcr_wr_addr),
		.vx_dcr_wr_data		(vx_dcr_wr_data)
	);

	//Vortex instantiation
	wire                                m_axi_vx_awvalid[1];
	wire                                m_axi_vx_awready[1];
	wire [C_M_AXI_MEM_ADDR_WIDTH-1:0]   m_axi_vx_awaddr [1];
	wire [C_M_AXI_MEM_ID_WIDTH-1:0]     m_axi_vx_awid   [1];
	wire [7:0]                          m_axi_vx_awlen  [1];
	wire                                m_axi_vx_wvalid [1]; 
	wire                                m_axi_vx_wready [1];
	wire [C_M_AXI_MEM_DATA_WIDTH-1:0]   m_axi_vx_wdata  [1];
	wire [C_M_AXI_MEM_DATA_WIDTH/8-1:0] m_axi_vx_wstrb  [1];    
	wire                                m_axi_vx_wlast  [1];  
	wire                                m_axi_vx_bvalid [1];
	wire                                m_axi_vx_bready [1];
	wire [C_M_AXI_MEM_ID_WIDTH-1:0]     m_axi_vx_bid    [1];
	wire [1:0]                          m_axi_vx_bresp  [1];
	wire                                m_axi_vx_arvalid[1];
	wire                                m_axi_vx_arready[1];
	wire [C_M_AXI_MEM_ADDR_WIDTH-1:0]   m_axi_vx_araddr [1];
	wire [C_M_AXI_MEM_ID_WIDTH-1:0]     m_axi_vx_arid   [1];
	wire [7:0]                          m_axi_vx_arlen  [1];
	wire                                m_axi_vx_rvalid [1];
	wire                                m_axi_vx_rready [1];
	wire [C_M_AXI_MEM_DATA_WIDTH-1:0]   m_axi_vx_rdata  [1];
	wire                                m_axi_vx_rlast  [1];
	wire [C_M_AXI_MEM_ID_WIDTH-1:0]     m_axi_vx_rid    [1];
	wire [1:0]                          m_axi_vx_rresp  [1];

	//assign inputs
	assign m_axi_vx_awready[0] = m_axi_mem_awready;
	assign m_axi_vx_wready [0] = m_axi_mem_wready;
	assign m_axi_vx_bvalid [0] = m_axi_mem_bvalid;
	assign m_axi_vx_bid    [0] = m_axi_mem_bid;
	assign m_axi_vx_bresp  [0] = m_axi_mem_bresp;
	assign m_axi_vx_arready[0] = m_axi_mem_arready;
	assign m_axi_vx_rvalid [0] = m_axi_mem_rvalid;
	assign m_axi_vx_rdata  [0] = m_axi_mem_rdata;
	assign m_axi_vx_rlast  [0] = m_axi_mem_rlast;
	assign m_axi_vx_rid    [0] = m_axi_mem_rid;
	assign m_axi_vx_rresp  [0] = m_axi_mem_rresp;

	Vortex_axi #(
		.AXI_DATA_WIDTH (C_M_AXI_MEM_DATA_WIDTH),
		.AXI_ADDR_WIDTH (C_M_AXI_MEM_ADDR_WIDTH),
		.AXI_TID_WIDTH  (C_M_AXI_MEM_ID_WIDTH),
		.AXI_NUM_BANKS  (1)
	) vortex_axi (
		.clk            (clk),
		.reset          (reset || vx_reset),
		//.debug_regs     (debug_regs),

		.m_axi_awvalid (m_axi_vx_awvalid),
		.m_axi_awready (m_axi_vx_awready),
		.m_axi_awaddr (m_axi_vx_awaddr),
		.m_axi_awid (m_axi_vx_awid),
		.m_axi_awlen (m_axi_vx_awlen),
		`UNUSED_PIN (m_axi_awsize),
		`UNUSED_PIN (m_axi_awburst),
		`UNUSED_PIN (m_axi_awlock),
		`UNUSED_PIN (m_axi_awcache),
		`UNUSED_PIN (m_axi_awprot),
		`UNUSED_PIN (m_axi_awqos),
		`UNUSED_PIN (m_axi_awregion),

		.m_axi_wvalid (m_axi_vx_wvalid),
		.m_axi_wready (m_axi_vx_wready),
		.m_axi_wdata (m_axi_vx_wdata),
		.m_axi_wstrb (m_axi_vx_wstrb),
		.m_axi_wlast (m_axi_vx_wlast),

		.m_axi_bvalid (m_axi_vx_bvalid),
		.m_axi_bready (m_axi_vx_bready),
		.m_axi_bid (m_axi_vx_bid),
		.m_axi_bresp (m_axi_vx_bresp),

		.m_axi_arvalid (m_axi_vx_arvalid),
		.m_axi_arready (m_axi_vx_arready),
		.m_axi_araddr (m_axi_vx_araddr),
		.m_axi_arid (m_axi_vx_arid),
		.m_axi_arlen (m_axi_vx_arlen),
		`UNUSED_PIN (m_axi_arsize),
		`UNUSED_PIN (m_axi_arburst),
		`UNUSED_PIN (m_axi_arlock),
		`UNUSED_PIN (m_axi_arcache),
		`UNUSED_PIN (m_axi_arprot),
		`UNUSED_PIN (m_axi_arqos),
		`UNUSED_PIN (m_axi_arregion),

		.m_axi_rvalid (m_axi_vx_rvalid),
		.m_axi_rready (m_axi_vx_rready),
		.m_axi_rdata (m_axi_vx_rdata),
		.m_axi_rlast (m_axi_vx_rlast),
		.m_axi_rid (m_axi_vx_rid),
		.m_axi_rresp (m_axi_vx_rresp),

		.dcr_wr_valid   (vx_dcr_wr_valid),
		.dcr_wr_addr    (vx_dcr_wr_addr),
		.dcr_wr_data    (vx_dcr_wr_data),

		.busy           (vx_busy)
	);

	//arbitrer outputs
	assign m_axi_mem_awvalid = vx_reset ? m_axi_ctrl_awvalid : m_axi_vx_awvalid[0];
	assign m_axi_mem_awaddr  = vx_reset ? m_axi_ctrl_awaddr : m_axi_vx_awaddr [0];
	assign m_axi_mem_awid    = vx_reset ? m_axi_ctrl_awid : m_axi_vx_awid   [0];
	assign m_axi_mem_awlen   = vx_reset ? m_axi_ctrl_awlen : m_axi_vx_awlen  [0];
	assign m_axi_mem_wvalid  = vx_reset ? m_axi_ctrl_wvalid : m_axi_vx_wvalid [0];
	assign m_axi_mem_wdata   = vx_reset ? m_axi_ctrl_wdata : m_axi_vx_wdata  [0];
	assign m_axi_mem_wstrb   = vx_reset ? m_axi_ctrl_wstrb : m_axi_vx_wstrb  [0];
	assign m_axi_mem_wlast   = vx_reset ? m_axi_ctrl_wlast : m_axi_vx_wlast  [0];
	assign m_axi_mem_bready  = vx_reset ? m_axi_ctrl_bready : m_axi_vx_bready [0];
	assign m_axi_mem_arvalid = vx_reset ? m_axi_ctrl_arvalid : m_axi_vx_arvalid[0];
	assign m_axi_mem_araddr  = vx_reset ? m_axi_ctrl_araddr : m_axi_vx_araddr [0];
	assign m_axi_mem_arid    = vx_reset ? m_axi_ctrl_arid : m_axi_vx_arid   [0];
	assign m_axi_mem_arlen   = vx_reset ? m_axi_ctrl_arlen : m_axi_vx_arlen  [0];
	assign m_axi_mem_rready  = vx_reset ? m_axi_ctrl_rready : m_axi_vx_rready [0];
endmodule
