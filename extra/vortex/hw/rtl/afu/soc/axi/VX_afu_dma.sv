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

module VX_afu_dma #(
	parameter C_M_AXI_MEM_ID_WIDTH    = 8,
	parameter C_M_AXI_MEM_ADDR_WIDTH  = 64,
	parameter C_M_AXI_MEM_DATA_WIDTH  = `VX_MEM_DATA_WIDTH,
	parameter CMD_REG_SIZE            = 32
) (
	input  wire                                 clk,
	input  wire                                 reset,

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

	input  wire                                 dma_rd_valid,
	input  wire                                 dma_wr_valid,
	input  wire [C_M_AXI_MEM_ADDR_WIDTH-1:0]    dma_addr,
	input  wire [C_M_AXI_MEM_DATA_WIDTH-1:0]    dma_wdata,
	input  wire [CMD_REG_SIZE/8-1:0]            dma_mask,

	output wire                                 dma_rd_done,
	output wire [CMD_REG_SIZE-1:0]              dma_rdata,
	output wire                                 dma_wr_done
);
	localparam WORDS = C_M_AXI_MEM_DATA_WIDTH/32;

	//AXI Read
	localparam 
	RSTATE_IDLE = 2'd0, 
	RSTATE_ADDR = 2'd1,
	RSTATE_WAIT = 2'd2,
	RSTATE_DONE = 2'd3;


	reg [1:0] rstate;
	reg [C_M_AXI_MEM_DATA_WIDTH-1:0] rdata;
	reg [C_M_AXI_MEM_ADDR_WIDTH-1:0] raddr;
	reg [CMD_REG_SIZE-1:0] rmask;
	wire [`CLOG2(WORDS)-1:0] rword = `CLOG2(WORDS)'(raddr >> 2);

	assign dma_rd_done = rstate == RSTATE_DONE;
	assign dma_rdata = rdata;

	assign m_axi_mem_arvalid = rstate == RSTATE_ADDR;
	assign m_axi_mem_araddr = raddr;
	assign m_axi_mem_arid = 0;
	assign m_axi_mem_arlen = 0;
	assign m_axi_mem_rready = rstate == RSTATE_WAIT;

	always @(posedge clk) begin
		if (reset || ~dma_rd_valid) begin
			rstate <= RSTATE_IDLE;
			raddr <= 0;
			rdata <= 0;
		end else begin
			case (rstate)
				RSTATE_IDLE: begin
					if (dma_rd_valid) begin
						rstate <= RSTATE_ADDR;
						raddr <= dma_addr;
						for (int i = 0; i < CMD_REG_SIZE/8; ++i) begin
							rmask[8 * i +: 8] = {8{dma_mask[i]}};
						end
					end
				end
				RSTATE_ADDR: begin
					if (m_axi_mem_arready) begin
						rstate <= RSTATE_WAIT;
					end
				end
				RSTATE_WAIT: begin
					if (m_axi_mem_rvalid && m_axi_mem_rlast) begin
						rstate <= RSTATE_DONE;
						rdata <= rmask & CMD_REG_SIZE'(m_axi_mem_rdata >> (rword * 32));
					end
				end
				RSTATE_DONE:;
			endcase
		end
	end

	//AXI Write
	localparam 
	WSTATE_IDLE = 3'd0, 
	WSTATE_ADDR = 3'd1,
	WSTATE_DATA = 3'd2,
	WSTATE_WAIT = 3'd3,
	WSTATE_DONE = 3'd4;


	reg [2:0] wstate;
	reg [C_M_AXI_MEM_DATA_WIDTH-1:0] wdata;
	reg [C_M_AXI_MEM_ADDR_WIDTH-1:0] waddr;
	reg [CMD_REG_SIZE/8-1:0] wmask;
	wire [`CLOG2(WORDS)-1:0] wword = `CLOG2(WORDS)'(waddr >> 2);

	assign dma_wr_done = wstate == WSTATE_DONE;

	assign m_axi_mem_awvalid = wstate == WSTATE_ADDR;
	assign m_axi_mem_awaddr = waddr;
	assign m_axi_mem_awid = 0;
	assign m_axi_mem_awlen = 0;
	assign m_axi_mem_wvalid = wstate == WSTATE_DATA;
	assign m_axi_mem_wdata = wdata;
	assign m_axi_mem_wstrb = wmask << (wword*4);

	assign m_axi_mem_wlast = 1;
	assign m_axi_mem_bready = wstate == WSTATE_WAIT;

	always @(posedge clk) begin
		if (reset || ~dma_wr_valid) begin
			wstate <= WSTATE_IDLE;
			waddr <= 0;
			wmask <= 0;
			wdata <= 0;
		end else begin
			case (wstate)
				WSTATE_IDLE: begin
					if (dma_wr_valid) begin
						wstate <= WSTATE_ADDR;
						waddr <= dma_addr;
						wmask <= dma_mask;
						wdata <= dma_wdata;
					end
				end
				WSTATE_ADDR: begin
					if (m_axi_mem_awready) begin
						wstate <= WSTATE_DATA;
					end
				end
				WSTATE_DATA: begin
					if (m_axi_mem_wready) begin
						wstate <= WSTATE_WAIT;
					end
				end
				WSTATE_WAIT: begin
					if (m_axi_mem_bvalid) begin
						wstate <= WSTATE_DONE;
					end
				end
				WSTATE_DONE:;
			endcase
		end
	end

endmodule










