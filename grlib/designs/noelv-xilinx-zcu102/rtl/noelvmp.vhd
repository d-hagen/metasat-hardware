------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2021, Cobham Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
------------------------------------------------------------------------------
--  Design written by: Marc Solé I Bonet (Barcelona Supercomputing Center)
--  2023
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.config.all;
use work.sys.all;

entity noelvmp is
	generic (
		fabtech     : integer := CFG_FABTECH;
		memtech     : integer := CFG_MEMTECH;
		padtech     : integer := CFG_PADTECH;
		clktech     : integer := CFG_CLKTECH;
		disas       : integer := CFG_DISAS;   -- Enable disassembly to console
		dbguart     : integer := CFG_DUART    -- Print UART on console
	);
	port (
		-- Clock and Reset
		reset       : in    std_ulogic;
		clk300p     : in    std_ulogic;  -- 300 MHz clock
		clk300n     : in    std_ulogic;  -- 300 MHz clock
		-- UART
		dsurx       : in    std_ulogic;
		dsutx       : out   std_ulogic 
--		dsuctsn     : in    std_ulogic;
--		dsurtsn     : out   std_ulogic;
		-- DDR4 (MIG)
--		ddr4_dq     : inout std_logic_vector(15 downto 0);
--		ddr4_dqs_c  : inout std_logic_vector(1 downto 0); -- Data Strobe
--		ddr4_dqs_t  : inout std_logic_vector(1 downto 0); -- Data Strobe
--		ddr4_addr   : out   std_logic_vector(13 downto 0); -- Address
--		ddr4_ras_n  : out   std_ulogic;
--		ddr4_cas_n  : out   std_ulogic;
--		ddr4_we_n   : out   std_ulogic;
--		ddr4_ba     : out   std_logic_vector(1 downto 0); -- Device bank address per group
--		ddr4_bg     : out   std_logic_vector(0 downto 0); -- Device bank group address
--		ddr4_dm_n   : inout std_logic_vector(1 downto 0); -- Data Mask
--		ddr4_ck_c   : out   std_logic_vector(0 downto 0); -- Clock Negative Edge
--		ddr4_ck_t   : out   std_logic_vector(0 downto 0); -- Clock Positive Edge
--		ddr4_cke    : out   std_logic_vector(0 downto 0); -- Clock Enable
--		ddr4_act_n  : out   std_ulogic;                   -- Command Input
--		ddr4_odt    : out   std_logic_vector(0 downto 0); -- On-die Termination
--		ddr4_par    : out   std_ulogic;                   -- Parity for cmd and addr
--		ddr4_cs_n   : out   std_logic_vector(0 downto 0); -- Chip Select
--		ddr4_reset_n: out   std_ulogic                    -- Asynchronous Reset
	);
end;

architecture rtl of noelvmp is
	----------------------------------------------------------------------
	---- Constants -------------------------------------------------------
	----------------------------------------------------------------------
	-- AHB Masters
	constant hm_ahbuart   : integer := 0;
	-- AHB Slaves
	constant hs_ahbram    : integer := 0;
	-- APB Slaves
	constant ps_ahbuart   : integer := 0;
	constant ps_apbuart   : integer := 1;

	-- Interrupt Controller (start at 5)
	constant ic_apbuart   : integer := 5;
	
	----------------------------------------------------------------------
	--- CLOCK & RESET ----------------------------------------------------
	----------------------------------------------------------------------
	-- signals
	signal clkm	: std_ulogic := '0';	-- Main clock from gen
	signal migclk	: std_ulogic := '0';	-- Main clock from MIG
	signal rstn     : std_ulogic;			-- Reset inverted
	signal migrstn	: std_ulogic;			-- Reset MIG
	signal rstraw 	: std_ulogic; 			-- Reset async
	signal miglock	: std_ulogic;			-- Lock from MIG
	
	----------------------------------------------------------------------
	--- AHB & APB --------------------------------------------------------
	----------------------------------------------------------------------
	-- AHB
	signal ahbsi          : ahb_slv_in_type;
	signal ahbso          : ahb_slv_out_vector := (others => ahbs_none);
	signal ahbmi          : ahb_mst_in_type;
	signal ahbmo          : ahb_mst_out_vector := (others => ahbm_none);

	-- AHB UART
	signal dui            : uart_in_type;
	signal duo            : uart_out_type;

	-- APB
	signal apbi           : apb_slv_in_type;
	signal apbo           : apb_slv_out_vector := (others => apb_none);

	-- APB UART
	signal u1i            : uart_in_type;
	signal u1o            : uart_out_type;

	----------------------------------------------------------------------
	--- SIGNALS ATTRIBUTE ------------------------------------------------
	----------------------------------------------------------------------
	attribute keep         : boolean;
	attribute keep of clkm : signal is true;

begin
	----------------------------------------------------------------------
	---  Reset and Clock generation  -------------------------------------
	----------------------------------------------------------------------
	clk_rst : clkrst
	generic map (CFG_MIG_EN, padtech, clktech, CFG_CLKDIV, CFG_CLKMUL, CFG_FREQ)
	port map (reset, clk300p, clk300n, migclk, miglock, clkm, rstn, rstraw, migrstn);
	
	-----------------------------------------------------------------------------
	-- AHB & APB UART -----------------------------------------------------------
	-----------------------------------------------------------------------------
	duart_gen: if CFG_AHB_UART = 1 generate
      	duart : ahbuart
        generic map (hindex => hm_ahbuart,  pindex => ps_ahbuart, paddr => ps_ahbuart)
        port map (rstn, clkm, dui, duo, apbi, apbo(ps_ahbuart), ahbmi, ahbmo(hm_ahbuart));
  	end generate duart_gen;


	uart_gen: if CFG_UART1_EN = 1 generate
	uart1 : apbuart
	generic map (pindex   => ps_apbuart, paddr => ps_apbuart, pirq => ic_apbuart, console => dbguart, fifosize => CFG_UART1_FIFO)
	port map (rstn, clkm, apbi, apbo(ps_apbuart), u1i, u1o);
	end generate;

	dui.rxd    <= dsurx;      -- AHB input data
	dsutx      <= duo.txd;    -- AHB output 
	--dui.ctsn   <= dsuctsn;    -- AHB clear to send
	--dsurtsn    <= duo.rtsn;   -- AHB rqst send
	u1i.rxd    <= u1o.txd;
	u1i.ctsn   <= '0'; u1i.extclk <= '0';
end;
