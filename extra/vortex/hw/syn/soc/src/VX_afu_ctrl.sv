module VX_afu_ctrl #(
	parameter C_S_AXI_CTRL_ADDR_WIDTH = 8,
	parameter C_S_AXI_CTRL_DATA_WIDTH = 32,
	parameter C_M_AXI_MEM_ID_WIDTH    = 8,
	parameter C_M_AXI_MEM_ADDR_WIDTH  = 64,
	parameter C_M_AXI_MEM_DATA_WIDTH  = (16 * 8)    
) (
	input  wire                                 clk,
	input  wire                                 reset,
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
        input wire [32-1:0] PC,
        input wire [31:0]      instr,
	output wire                                 vx_reset,
	input  wire                                 vx_busy,
	output wire                                 vx_dcr_wr_valid,
	output wire [12-1:0]        vx_dcr_wr_addr,
	output wire [32-1:0]        vx_dcr_wr_data
);
	localparam 
	CMD_NONE   = 0,
	CMD_MEM_RD = 1,
	CMD_MEM_WR = 2,
	CMD_RUN    = 3,
	CMD_DCR_WR = 4,
	CMD_TERMIN = 7,
	CMD_BITS   = 3;
	localparam
	MMIO_CMD_TYPE    = 0,
	MMIO_CMD_ADDR    = 4,
	MMIO_CMD_DATA    = 8,
	MMIO_CMD_SIZE    = 12,
	MMIO_READ_DATA   = 16,
	MMIO_STATUS      = 20,
	MMIO_DEV_CAPS    = 24,
	MMIO_DEV_CAPS_H  = 28,
	MMIO_ISA_CAPS    = 32,
	MMIO_ISA_CAPS_H  = 36,
	MMIO_SCOPE_READ  = 40,
	MMIO_SCOPE_WRITE = 44,
	MMIO_VX_PC       = 48,
	MMIO_VX_INST     = 52,
	MMIO_DEBUG       = 128,
	CTRL_ADDR_BITS   = 8;
	localparam 
	STATE_IDLE   = 0,
	STATE_MEM_RD = 1,
	STATE_MEM_WR = 2,
	STATE_RUN    = 3,
	STATE_DCR    = 4,
	STATE_BITS   = 3;
	localparam ADDR_BITS = CTRL_ADDR_BITS;
	localparam WORDS = C_S_AXI_CTRL_DATA_WIDTH/32;
	wire clk_en = 1;
	localparam NUM_DEBUG_REGS = (2 + 1 + (((4 / 8) != 0) ? (4 / 8) : 1) + (((4 / 8) != 0) ? (4 / 8) : 1) + (((4 / 8) != 0) ? (4 / 8) : 1));  
	reg vx_running;
	reg  vx_busy_wait;
	reg  [STATE_BITS-1:0] state;
	reg  [CMD_BITS-1:0]  cmd_type;
	reg  [31:0] cmd_addr;
	reg  [31:0] cmd_wdata;
	reg  [31:0] cmd_size;
	wire [31:0] cmd_rdata;
	wire [63:0] dev_caps = {16'b0,
		8'(1 ? 14 : 0),
		16'(1 * 1), 
		8'(4), 
		8'(4), 
		8'(0)};
	wire [63:0] isa_caps = {32'((1  << 0) 
                | (1  << 1) 
                | (0      << 2) 
                | (0      << 3) 
                | (1    << 4) 
                | (1 << 5)), 
		2'($clog2(32)-4), 
		30'((0 <<  0)   
                | (0 <<  1)   
                | (0 <<  2)   
                | (0 <<  3)   
                | (0 <<  4)   
                | (0 << 5)   
                | (0 <<  6)   
                | (0 <<  7)   
                | (1 <<  8)   
                | (0 <<  9)   
                | (0 << 10)   
                | (0 << 11)   
                | (1 << 12)   
                | (0 << 13)   
                | (0 << 14)   
                | (0 << 15)   
                | (0 << 16)   
                | (0 << 17)   
                | (0 << 18)   
                | (0 << 19)   
                | (1 << 20)   
                | (0 << 21)   
                | (0 << 22)   
                | (1 << 23)   
                | (0 << 24)   
                | (0 << 25)  )};
	assign vx_reset = ~vx_running;
	assign vx_dcr_wr_valid = (STATE_DCR == state);
	assign vx_dcr_wr_addr = 12'(cmd_addr);
	assign vx_dcr_wr_data = 32'(cmd_wdata);
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
	assign s_axi_ctrl_rresp   = 2'b00;   
	assign s_axi_ctrl_ar_fire = s_axi_ctrl_arvalid && s_axi_ctrl_arready;
	assign raddr = ADDR_BITS'(s_axi_ctrl_araddr);
	wire [$clog2(NUM_DEBUG_REGS)-1:0] debug_sel = ((raddr - MMIO_DEBUG)/4);
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
	always @(posedge clk) begin
		if (clk_en) begin
			if (s_axi_ctrl_ar_fire) begin
				rdata <= '0;
				case (raddr)
					MMIO_CMD_TYPE: begin
						rdata <= {WORDS{32'(cmd_type)}};
					end
					MMIO_CMD_ADDR: begin
						rdata <= {WORDS{32'(cmd_addr)}};
					end
					MMIO_CMD_DATA: begin
						rdata <= {WORDS{32'(cmd_wdata)}};
					end
					MMIO_CMD_SIZE: begin
						rdata <= {WORDS{32'(cmd_size)}};
					end
					MMIO_READ_DATA: begin
						rdata <= {WORDS{32'(cmd_rdata)}};
					end
					MMIO_STATUS: begin  
						rdata <= {WORDS{32'({vx_busy_wait, vx_running, vx_reset, vx_busy, 4'(state)})}};
					end
					MMIO_DEV_CAPS: begin
						rdata <= {WORDS{32'(dev_caps[31:0])}};
					end
					MMIO_DEV_CAPS_H: begin
						rdata <= {WORDS{32'(dev_caps[63:32])}};
					end
					MMIO_ISA_CAPS: begin
						rdata <= {WORDS{32'(isa_caps[31:0])}};
					end
					MMIO_ISA_CAPS_H: begin
						rdata <= {WORDS{32'(isa_caps[63:32])}};
					end
					MMIO_VX_PC: begin
						rdata <= {WORDS{32'(PC)}};
					end
					MMIO_VX_INST: begin
						rdata <= {WORDS{32'(instr)}};
					end
					default: begin
					end
				endcase
			end
		end
	end
	localparam
	WSTATE_IDLE     = 2'd0,
	WSTATE_DATA     = 2'd1,
	WSTATE_RESP     = 2'd2;
	reg  [1:0]   wstate;
	reg  [ADDR_BITS-1:0] waddr;
	wire [31:0] wmask;
	wire [3:0] s_axi_ctrl_mask;
	wire [$clog2(WORDS)-1:0] sel_word;
	wire s_axi_ctrl_aw_fire;
	wire s_axi_ctrl_w_fire;
	assign s_axi_ctrl_awready = (wstate == WSTATE_IDLE);
	assign s_axi_ctrl_wready  = (wstate == WSTATE_DATA);
	assign s_axi_ctrl_bvalid  = (wstate == WSTATE_RESP);
	assign s_axi_ctrl_bresp   = 2'b00;   
	assign s_axi_ctrl_mask    = 4'(s_axi_ctrl_wstrb >> (sel_word*4));
	assign s_axi_ctrl_aw_fire = s_axi_ctrl_awvalid && s_axi_ctrl_awready;
	assign s_axi_ctrl_w_fire  = s_axi_ctrl_wvalid && s_axi_ctrl_wready;
	assign sel_word = $clog2(WORDS)'(waddr >> 2);
	for (genvar i = 0; i < 4; ++i) begin
		assign wmask[8 * i +: 8] = {8{s_axi_ctrl_mask[i]}};
	end
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
	always @(posedge clk) begin
		if (clk_en) begin
			if (s_axi_ctrl_aw_fire)
				waddr <= ADDR_BITS'(s_axi_ctrl_awaddr);
		end
	end
	always @(posedge clk) begin
		if (reset) begin
		end else if (clk_en) begin
			if (s_axi_ctrl_w_fire) begin
				case (waddr)
					MMIO_CMD_TYPE: begin
						cmd_type <= CMD_BITS'(32'(s_axi_ctrl_wdata >> (sel_word * 32)) & wmask) | (cmd_addr & ~wmask);
					end
					MMIO_CMD_ADDR: begin
						cmd_addr <= (32'(s_axi_ctrl_wdata >> (sel_word * 32)) & wmask) | (cmd_addr & ~wmask);
					end
					MMIO_CMD_DATA: begin
						cmd_wdata <= (32'(s_axi_ctrl_wdata >> (sel_word * 32)) & wmask) | (cmd_wdata & ~wmask);
					end
					MMIO_CMD_SIZE: begin
						cmd_size <= (32'(s_axi_ctrl_wdata >> (sel_word * 32)) & wmask) | (cmd_size & ~wmask);
					end
					default: begin
					end
				endcase
			end
		end
	end
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
	reg [$clog2(8+1)-1:0] vx_reset_ctr;
	always @(posedge clk) begin
		if (state == STATE_RUN) begin
			vx_reset_ctr <= vx_reset_ctr + $bits(vx_reset_ctr)'(1);
		end else begin
			vx_reset_ctr <= '0;
		end
	end
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
								state <= STATE_MEM_RD;   
							end 
							CMD_MEM_WR: begin      
								state <= STATE_MEM_WR;
							end
							CMD_DCR_WR: begin      
								state <= STATE_DCR;
							end
							CMD_RUN: begin        
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
					end
				end
				STATE_MEM_WR: begin
					if (dma_wr_done) begin
						state <= STATE_IDLE;
					end
				end
				STATE_DCR: begin
					state <= STATE_IDLE;
				end
				STATE_RUN: begin
					if (vx_running) begin
						if (vx_busy_wait) begin
							if (vx_busy) begin
								vx_busy_wait <= 0;
							end
						end else begin
							if (~vx_busy || cmd_type == CMD_TERMIN) begin                            
								state <= STATE_IDLE;
								vx_running   <= 0; 
							end
						end
					end else begin
						if (vx_reset_ctr == (8-1)) begin
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
