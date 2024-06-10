
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

module VX_afu_ctrl #(
	parameter C_S_AXI_CTRL_ADDR_WIDTH = 8,
	parameter C_S_AXI_CTRL_DATA_WIDTH = 32,
	parameter C_M_AXI_MEM_ID_WIDTH    = 8,
	parameter C_M_AXI_MEM_ADDR_WIDTH  = 64,
	parameter C_M_AXI_MEM_DATA_WIDTH  = `VX_MEM_DATA_WIDTH    
) (
	input  wire                                 clk,
	input  wire                                 reset,
	// Debug
        //input wire [`XLEN-1:0]                      debug_regs [3+`ISSUE_WIDTH * 3],

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

	//AXI4-lite slave interface
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

        // debug signals
        input wire [`XLEN-1:0] PC,
        input wire [31:0]      instr,

	output wire                                 vx_reset,
	input  wire                                 vx_busy,
	output wire                                 vx_dcr_wr_valid,
	output wire [`VX_DCR_ADDR_WIDTH-1:0]        vx_dcr_wr_addr,
	output wire [`VX_DCR_DATA_WIDTH-1:0]        vx_dcr_wr_data
);

	localparam 
	CMD_NONE   = `AFU_IMAGE_CMD_NONE,
	CMD_MEM_RD = `AFU_IMAGE_CMD_MEM_READ,
	CMD_MEM_WR = `AFU_IMAGE_CMD_MEM_WRITE,
	CMD_RUN    = `AFU_IMAGE_CMD_RUN,
	CMD_DCR_WR = `AFU_IMAGE_CMD_DCR_WRITE,
	CMD_TERMIN = `AFU_IMAGE_CMD_TERMINATE,
	CMD_BITS   = 3;


	localparam
	MMIO_CMD_TYPE    = `AFU_IMAGE_MMIO_CMD_TYPE,
	MMIO_CMD_ADDR    = `AFU_IMAGE_MMIO_CMD_ADDR,
	MMIO_CMD_DATA    = `AFU_IMAGE_MMIO_CMD_DATA,
	MMIO_CMD_SIZE    = `AFU_IMAGE_MMIO_CMD_SIZE,
	MMIO_READ_DATA   = `AFU_IMAGE_MMIO_DATA_READ,
	MMIO_STATUS      = `AFU_IMAGE_MMIO_STATUS,
	MMIO_DEV_CAPS    = `AFU_IMAGE_MMIO_DEV_CAPS,
	MMIO_DEV_CAPS_H  = `AFU_IMAGE_MMIO_DEV_CAPS_H,
	MMIO_ISA_CAPS    = `AFU_IMAGE_MMIO_ISA_CAPS,
	MMIO_ISA_CAPS_H  = `AFU_IMAGE_MMIO_ISA_CAPS_H,
	MMIO_SCOPE_READ  = `AFU_IMAGE_MMIO_SCOPE_READ,
	MMIO_SCOPE_WRITE = `AFU_IMAGE_MMIO_SCOPE_WRITE,
	MMIO_VX_PC       = `AFU_IMAGE_MMIO_VX_PC,
	MMIO_VX_INST     = `AFU_IMAGE_MMIO_VX_INST,
	MMIO_DEBUG       = `AFU_IMAGE_MMIO_DEBUG,
	CTRL_ADDR_BITS   = 8;

	localparam 
	STATE_IDLE   = `AFU_IMAGE_STATE_IDLE,
	STATE_MEM_RD = `AFU_IMAGE_STATE_MEM_READ,
	STATE_MEM_WR = `AFU_IMAGE_STATE_MEM_WRITE,
	STATE_RUN    = `AFU_IMAGE_STATE_RUN,
	STATE_DCR    = `AFU_IMAGE_STATE_DCR,
	STATE_BITS   = `AFU_IMAGE_STATE_BITS;

	localparam ADDR_BITS = CTRL_ADDR_BITS;
	localparam WORDS = C_S_AXI_CTRL_DATA_WIDTH/32;
	wire clk_en = 1;

	                                                                                  //           0x0     0x4        0x8   0xC-0x18 0x1C-0x28  0x2C-0x38
	localparam NUM_DEBUG_REGS = (2 + 1 + `ISSUE_WIDTH + `ISSUE_WIDTH + `ISSUE_WIDTH); // ((fetch * (PC + instr)) + decode + dispatch + commit + stalling)

	// Vortex signals
	reg vx_running;
	reg  vx_busy_wait;

	reg  [STATE_BITS-1:0] state;
	reg  [CMD_BITS-1:0]  cmd_type;
	reg  [31:0] cmd_addr;
	reg  [31:0] cmd_wdata;
	reg  [31:0] cmd_size;
	wire [31:0] cmd_rdata;
	wire [63:0] dev_caps = {16'b0,
		8'(`SM_ENABLED ? `SMEM_LOG_SIZE : 0),
		16'(`NUM_CORES * `NUM_CLUSTERS), 
		8'(`NUM_WARPS), 
		8'(`NUM_THREADS), 
		8'(`IMPLEMENTATION_ID)};

	wire [63:0] isa_caps = {32'(`MISA_EXT), 
		2'(`CLOG2(`XLEN)-4), 
		30'(`MISA_STD)};

	assign vx_reset = ~vx_running;
	assign vx_dcr_wr_valid = (STATE_DCR == state);
	assign vx_dcr_wr_addr = `VX_DCR_ADDR_WIDTH'(cmd_addr);
	assign vx_dcr_wr_data = `VX_DCR_DATA_WIDTH'(cmd_wdata);


	// AXI Read
	localparam 
	RSTATE_IDLE = 2'd0, 
	RSTATE_DATA = 2'd1;

	reg  [1:0] rstate;
	reg  [C_S_AXI_CTRL_DATA_WIDTH-1:0] rdata;
	wire [ADDR_BITS-1:0] raddr;
	wire s_axi_ctrl_ar_fire;


	assign s_axi_ctrl_arready = (rstate == RSTATE_IDLE);
	assign s_axi_ctrl_rvalid  = (rstate == RSTATE_DATA);
	assign s_axi_ctrl_rdata   = rdata;
	assign s_axi_ctrl_rresp   = 2'b00;  // OKAY

	assign s_axi_ctrl_ar_fire = s_axi_ctrl_arvalid && s_axi_ctrl_arready;
	assign raddr = ADDR_BITS'(s_axi_ctrl_araddr);
	wire [`CLOG2(NUM_DEBUG_REGS)-1:0] debug_sel = ((raddr - MMIO_DEBUG)/4);

	// rstate
	always @(posedge clk) begin
		if (reset) begin
			rstate <= RSTATE_IDLE;
		end else if (clk_en) begin
			case (rstate)
				RSTATE_IDLE: rstate <= s_axi_ctrl_arvalid ? RSTATE_DATA : RSTATE_IDLE;
				RSTATE_DATA: rstate <= (s_axi_ctrl_rready & s_axi_ctrl_rvalid) ? RSTATE_IDLE : RSTATE_DATA;
				default:     rstate <= RSTATE_IDLE;
			endcase
		end
	end

	// rdata
	always @(posedge clk) begin
		if (clk_en) begin
			if (s_axi_ctrl_ar_fire) begin
				rdata <= '0;
				case (raddr)
					MMIO_CMD_TYPE: begin
						rdata <= {WORDS{32'(cmd_type)}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_CMD_TYPE: data=%0d\n", $time, cmd_type));
						`endif
					end
					MMIO_CMD_ADDR: begin
						rdata <= {WORDS{32'(cmd_addr)}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_CMD_ADDR: data=0x%0h\n", $time, cmd_addr));
						`endif
					end
					MMIO_CMD_DATA: begin
						rdata <= {WORDS{32'(cmd_wdata)}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_CMD_DATA: data=%0d\n", $time, cmd_wdata));
						`endif
					end
					MMIO_CMD_SIZE: begin
						rdata <= {WORDS{32'(cmd_size)}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_CMD_SIZE: data=%0d\n", $time, cmd_size));
						`endif
					end
					MMIO_READ_DATA: begin
						rdata <= {WORDS{32'(cmd_rdata)}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_READ_DATA: data=%0d\n", $time, cmd_rdata));
						`endif
					end
					MMIO_STATUS: begin // 1100
						rdata <= {WORDS{32'({vx_busy_wait, vx_running, vx_reset, vx_busy, 4'(state)})}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_STATUS: data=%0d\n", $time, state));
						`endif
					end
					MMIO_DEV_CAPS: begin
						rdata <= {WORDS{32'(dev_caps[31:0])}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_DEV_CAPS: data=0x%0h\n", $time, dev_caps[31:0]));
						`endif
					end
					MMIO_DEV_CAPS_H: begin
						rdata <= {WORDS{32'(dev_caps[63:32])}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_DEV_CAPS + 4: data=0x%0h\n", $time, dev_caps[63:32]));
						`endif
					end
					MMIO_ISA_CAPS: begin
						rdata <= {WORDS{32'(isa_caps[31:0])}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_ISA_CAPS: data=0x%0h\n", $time, isa_caps[31:0]));
						`endif
					end
					MMIO_ISA_CAPS_H: begin
						rdata <= {WORDS{32'(isa_caps[63:32])}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ MMIO_ISA_CAPS + 4: data=0x%0h\n", $time, isa_caps[63:32]));
						`endif
					end
					MMIO_VX_PC: begin
						rdata <= {WORDS{32'(PC)}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ VX_PC: data=0x%0h\n", $time, PC));
						`endif
					end
					MMIO_VX_INST: begin
						rdata <= {WORDS{32'(instr)}};
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: READ VX_INST: data=0x%0h\n", $time, instr));
						`endif
					end
					default: begin
						//if (raddr >= MMIO_DEBUG && raddr < (MMIO_DEBUG + 4 * NUM_DEBUG_REGS)) begin
						//	rdata <= {WORDS{32'(debug_regs[debug_sel])}};
						//	`ifdef DBG_TRACE_AFU
						//		`TRACE(2, ("%d: READ DEBUG Register %d: data=0x%0h\n", $time, raddr[`CLOG2(NUM_DEBUG_REGS)-1:0]/4, instr));
						//	`endif
						//end else begin
							`ifdef DBG_TRACE_AFU
								`TRACE(2, ("%d: Unknown MMIO Rd: addr=0x%0h\n", $time, raddr));
							`endif
						//end
					end
				endcase
			end
		end
	end

	// AXI Write       

	localparam
	WSTATE_IDLE     = 2'd0,
	WSTATE_DATA     = 2'd1,
	WSTATE_RESP     = 2'd2;

	reg  [1:0]   wstate;
	reg  [ADDR_BITS-1:0] waddr;
	wire [31:0] wmask;
	wire [3:0] s_axi_ctrl_mask;
	wire [`CLOG2(WORDS)-1:0] sel_word;
	wire s_axi_ctrl_aw_fire;
	wire s_axi_ctrl_w_fire;

	assign s_axi_ctrl_awready = (wstate == WSTATE_IDLE);
	assign s_axi_ctrl_wready  = (wstate == WSTATE_DATA);
	assign s_axi_ctrl_bvalid  = (wstate == WSTATE_RESP);
	assign s_axi_ctrl_bresp   = 2'b00;  // OKAY
	assign s_axi_ctrl_mask    = 4'(s_axi_ctrl_wstrb >> (sel_word*4));

	assign s_axi_ctrl_aw_fire = s_axi_ctrl_awvalid && s_axi_ctrl_awready;
	assign s_axi_ctrl_w_fire  = s_axi_ctrl_wvalid && s_axi_ctrl_wready;


	assign sel_word = `CLOG2(WORDS)'(waddr >> 2);
	for (genvar i = 0; i < 4; ++i) begin
		assign wmask[8 * i +: 8] = {8{s_axi_ctrl_mask[i]}};
	end

	// wstate
	always @(posedge clk) begin
		if (reset) begin
			wstate <= WSTATE_IDLE;
		end else if (clk_en) begin
			case (wstate)
				WSTATE_IDLE: wstate <= s_axi_ctrl_awvalid ? WSTATE_DATA : WSTATE_IDLE;
				WSTATE_DATA: wstate <= s_axi_ctrl_wvalid ? WSTATE_RESP : WSTATE_DATA;
				WSTATE_RESP: wstate <= s_axi_ctrl_bready ? WSTATE_IDLE : WSTATE_RESP;
				default:     wstate <= WSTATE_IDLE;
			endcase
		end
	end

	// waddr
	always @(posedge clk) begin
		if (clk_en) begin
			if (s_axi_ctrl_aw_fire)
				waddr <= ADDR_BITS'(s_axi_ctrl_awaddr);
		end
	end

	// wdata
	always @(posedge clk) begin
		if (reset) begin

		end else if (clk_en) begin

			if (s_axi_ctrl_w_fire) begin
				case (waddr)
					MMIO_CMD_TYPE: begin
						cmd_type <= CMD_BITS'(32'(s_axi_ctrl_wdata >> (sel_word * 32)) & wmask) | (cmd_addr & ~wmask);
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: WRITE MMIO_CMD_TYPE: data=%0d\n", $time, CMD_BITS'(s_axi_ctrl_wdata >> (sel_word * 32))));
						`endif
					end
					MMIO_CMD_ADDR: begin
						cmd_addr <= (32'(s_axi_ctrl_wdata >> (sel_word * 32)) & wmask) | (cmd_addr & ~wmask);
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: WRITE MMIO_CMD_ADDR: data=0x%0h\n", $time, 32'(s_axi_ctrl_wdata >> (sel_word * 32))));
						`endif
					end
					MMIO_CMD_DATA: begin
						cmd_wdata <= (32'(s_axi_ctrl_wdata >> (sel_word * 32)) & wmask) | (cmd_wdata & ~wmask);
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: WRITE MMIO_CMD_DATA: data=%0d\n", $time, 32'(s_axi_ctrl_wdata >> (sel_word * 32))));
						`endif
					end
					MMIO_CMD_SIZE: begin
						cmd_size <= (32'(s_axi_ctrl_wdata >> (sel_word * 32)) & wmask) | (cmd_size & ~wmask);
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: WRITE MMIO_CMD_SIZE: data=%0d\n", $time, 32'(s_axi_ctrl_wdata >> (sel_word * 32))));
						`endif
					end
					default: begin
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: Unknown MMIO Wr: addr=0x%0h, data=%0d\n", $time, waddr, 32'(s_axi_ctrl_wdata >> (sel_word * 32))));
						`endif
					end
				endcase
			end
		end
	end

	// AXI mem issue

	wire dma_rd_valid = state == STATE_MEM_RD;
	wire dma_wr_valid = state == STATE_MEM_WR;
	wire [C_M_AXI_MEM_ADDR_WIDTH-1:0] dma_addr = C_M_AXI_MEM_ADDR_WIDTH'(cmd_addr);
	wire [C_M_AXI_MEM_DATA_WIDTH-1:0] dma_wdata = {WORDS{32'(cmd_wdata)}};
	wire [3:0] dma_mask = (1'b1 << cmd_size) -1;

	wire dma_rd_done;
	wire dma_wr_done;
	wire [31:0] dma_rdata;

	assign cmd_rdata = (state == STATE_MEM_RD) ? dma_rdata : cmd_rdata;

	VX_afu_dma #(
		.C_M_AXI_MEM_ID_WIDTH	(C_M_AXI_MEM_ID_WIDTH),
		.C_M_AXI_MEM_ADDR_WIDTH	(C_M_AXI_MEM_ADDR_WIDTH),
		.C_M_AXI_MEM_DATA_WIDTH	(C_M_AXI_MEM_DATA_WIDTH),
		.CMD_REG_SIZE (32)
	) afu_dma (
		.clk	(clk),
		.reset	(reset),

		.m_axi_mem_awvalid	(m_axi_mem_awvalid),
		.m_axi_mem_awaddr	(m_axi_mem_awaddr),
		.m_axi_mem_awid		(m_axi_mem_awid),
		.m_axi_mem_awlen	(m_axi_mem_awlen),
		.m_axi_mem_wvalid	(m_axi_mem_wvalid),
		.m_axi_mem_wdata	(m_axi_mem_wdata),
		.m_axi_mem_wstrb	(m_axi_mem_wstrb),
		.m_axi_mem_wlast	(m_axi_mem_wlast),
		.m_axi_mem_arvalid	(m_axi_mem_arvalid),
		.m_axi_mem_araddr	(m_axi_mem_araddr),
		.m_axi_mem_arid		(m_axi_mem_arid),
		.m_axi_mem_arlen	(m_axi_mem_arlen),
		.m_axi_mem_rready	(m_axi_mem_rready),
		.m_axi_mem_bready	(m_axi_mem_bready),
		.m_axi_mem_awready	(m_axi_mem_awready),
		.m_axi_mem_wready	(m_axi_mem_wready),
		.m_axi_mem_arready	(m_axi_mem_arready),
		.m_axi_mem_rvalid	(m_axi_mem_rvalid),
		.m_axi_mem_rdata	(m_axi_mem_rdata),
		.m_axi_mem_rlast	(m_axi_mem_rlast),
		.m_axi_mem_rid		(m_axi_mem_rid),
		.m_axi_mem_rresp	(m_axi_mem_rresp),
		.m_axi_mem_bvalid	(m_axi_mem_bvalid),
		.m_axi_mem_bresp	(m_axi_mem_bresp),
		.m_axi_mem_bid		(m_axi_mem_bid),

		.dma_rd_valid	(dma_rd_valid),
		.dma_wr_valid	(dma_wr_valid),
		.dma_addr		(dma_addr),
		.dma_wdata	    (dma_wdata),
		.dma_mask		(dma_mask),

		.dma_rd_done	(dma_rd_done),
		.dma_rdata	    (dma_rdata),
		.dma_wr_done	(dma_wr_done)
	);

	//VX State Machine

	reg [`CLOG2(`RESET_DELAY+1)-1:0] vx_reset_ctr;
	always @(posedge clk) begin
		if (state == STATE_RUN) begin
			vx_reset_ctr <= vx_reset_ctr + $bits(vx_reset_ctr)'(1);
		end else begin
			vx_reset_ctr <= '0;
		end
	end

	// Get Command if valid write to MMIO_CMD_TYPE
	wire cmd_trigger = s_axi_ctrl_bready && s_axi_ctrl_bvalid && (MMIO_CMD_TYPE == waddr);

	always @(posedge clk) begin
		if (reset) begin
			state        <= STATE_IDLE;
			vx_busy_wait <= 0;
			vx_running   <= 0; 
		end else begin
			case (state)
				STATE_IDLE: begin             
					if (cmd_trigger) begin
						case (cmd_type)
							CMD_MEM_RD: begin     
								`ifdef DBG_TRACE_AFU
									`TRACE(2, ("%d: STATE MEM_READ: addr=0x%0h size=%0d\n", $time, cmd_addr, cmd_size));
								`endif
								state <= STATE_MEM_RD;   
							end 
							CMD_MEM_WR: begin      
								`ifdef DBG_TRACE_AFU
									`TRACE(2, ("%d: STATE MEM_WRITE: addr=0x%0h data=0x%0h size=%0d\n", $time, cmd_addr, cmd_wdata, cmd_size));
								`endif
								state <= STATE_MEM_WR;
							end
							CMD_DCR_WR: begin      
								`ifdef DBG_TRACE_AFU
									`TRACE(2, ("%d: STATE DCR_WRITE: addr=0x%0h data=%0d\n", $time, vx_dcr_wr_addr, vx_dcr_wr_data));
								`endif
								state <= STATE_DCR;
							end
							CMD_RUN: begin        
								`ifdef DBG_TRACE_AFU
									`TRACE(2, ("%d: STATE RUN\n", $time));
								`endif  
								state <= STATE_RUN;      
								vx_running <= 0;
							end
							default: begin
								state <= state;
							end
						endcase
					end
				end
				STATE_MEM_RD: begin
					if (dma_rd_done) begin
						state <= STATE_IDLE;
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: STATE MEM_READ: data=0x%0h\n", $time, dma_rdata));
							`TRACE(2, ("%d: STATE IDLE\n", $time));
						`endif
					end
				end
				STATE_MEM_WR: begin
					if (dma_wr_done) begin
						state <= STATE_IDLE;
						`ifdef DBG_TRACE_AFU
							`TRACE(2, ("%d: STATE IDLE\n", $time));
						`endif
					end
				end
				STATE_DCR: begin
					state <= STATE_IDLE;
					`ifdef DBG_TRACE_AFU
						`TRACE(2, ("%d: STATE IDLE\n", $time));
					`endif
				end
				STATE_RUN: begin
					if (vx_running) begin
						if (vx_busy_wait) begin
							// wait until the gpu goes busy
							if (vx_busy) begin
								vx_busy_wait <= 0;
							end
						end else begin
							// wait until the gpu is not busy or force termination
							if (~vx_busy || cmd_type == CMD_TERMIN) begin                            
								state <= STATE_IDLE;
								vx_running   <= 0; 
								`ifdef DBG_TRACE_AFU
									`TRACE(2, ("%d: AFU: End execution\n", $time));
									`TRACE(2, ("%d: STATE IDLE\n", $time));
								`endif
							end
						end
					end else begin
						// wait until the reset sequence is complete
						if (vx_reset_ctr == (`RESET_DELAY-1)) begin
							`ifdef DBG_TRACE_AFU
								`TRACE(2, ("%d: AFU: Begin execution\n", $time));
							`endif
							vx_running   <= 1;
							vx_busy_wait <= 1;
						end  
					end        
				end
				default:;
			endcase
		end
	end
endmodule
