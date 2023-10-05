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
-------------------------------------------------------------------------------
-- Entity:      ahb2axi_mig4_ultrascale
-- File:        ahb2axi_mig4_ultrascale.vhd
-- Author:      Johan Klockars - Cobham Gaisler AB
-- 
-- Adapted from: ahb2axi_mig4_7series 
-- Adapted by: Marc Solé Bonet - Barcelona Supecomputer Center (BSC)
--
--  Interface to convert AHB-2.0 to AXI4 interface of Xilinx Zynq Ultrascale+ MIG
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config_types.all;
use grlib.config.all;
library gaisler;
use gaisler.misc.all;
use gaisler.axi.all;


entity ahb2axi_mig4_ultrascale is
  generic (
    pipelined               : boolean := false;   -- Pipeline stage before AXI CDC?
    hindex                  : integer := 0;
    haddr                   : integer := 0;
    hmask                   : integer := 16#f00#;
    pindex                  : integer := 0;
    paddr                   : integer := 0;
    pmask                   : integer := 16#fff#
  );
  port (
    calib_done          : out   std_logic;
    sys_clk_p           : in    std_logic;
    sys_clk_n           : in    std_logic;
    ddr4_addr           : out   std_logic_vector(13 downto 0);
    ddr4_we_n           : out   std_logic;
    ddr4_cas_n          : out   std_logic;
    ddr4_ras_n          : out   std_logic;
    ddr4_ba             : out   std_logic_vector(1 downto 0);
    ddr4_cke            : out   std_logic_vector(0 downto 0);
    ddr4_cs_n           : out   std_logic_vector(0 downto 0);
    ddr4_dm_n           : inout std_logic_vector(1 downto 0);
    ddr4_dq             : inout std_logic_vector(15 downto 0);
    ddr4_dqs_c          : inout std_logic_vector(1 downto 0);
    ddr4_dqs_t          : inout std_logic_vector(1 downto 0);
    ddr4_odt            : out   std_logic_vector(0 downto 0);
    ddr4_bg             : out   std_logic_vector(0 downto 0);
    ddr4_reset_n        : out   std_logic;
    ddr4_act_n          : out   std_logic;
    ddr4_ck_c           : out   std_logic_vector(0 downto 0);
    ddr4_ck_t           : out   std_logic_vector(0 downto 0);
    ddr4_ui_clk         : out   std_logic;
    ddr4_ui_clk_sync_rst: out   std_logic;
    rst_n_syn           : in    std_logic;
    rst_n_async         : in    std_logic;

    ahbso               : out   ahb_slv_out_type;
    ahbsi               : in    ahb_slv_in_type;
    apbi                : in    apb_slv_in_type;
    apbo                : out   apb_slv_out_type;
    clk_amba            : in    std_logic;

    -- Misc
    ddr4_ui_clkout1     : out   std_logic;
    clk_ref_i           : in    std_logic
  );
end ;


architecture rtl of ahb2axi_mig4_ultrascale is

  constant zero : std_logic_vector(31 downto 0) := (others => '0');
  
  constant pconfig : apb_config_type := (
       0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
       1 => apb_iobar(paddr, pmask));

  signal fpga_clk     : std_ulogic;
  signal ddr4_clk     : std_ulogic;
  signal ddr4_rstn    : std_ulogic;
  signal ddr4_rst     : std_ulogic;
  signal rst_async     : std_ulogic;
  signal ddr4_adr     : std_logic_vector( 16 downto 0 );

  signal aximi        : axi_somi_type;
  signal aximo        : axi4_mosi_type;

  signal ddr4_aximi   : axi_somi_type;
  signal ddr4_aximo   : axi4_mosi_type;
  
  signal ddr4_arlock    : std_logic_vector(0 downto 0);
  signal ddr4_arprot    : std_logic_vector(2 downto 0);
  signal ddr4_arqos     : std_logic_vector(3 downto 0);
  
  signal ddr4_awlock    : std_logic_vector(0 downto 0);
  signal ddr4_awprot    : std_logic_vector(2 downto 0);
  signal ddr4_awqos     : std_logic_vector(3 downto 0);

    component mig
        port(
                sys_rst 	        	: in std_logic;
                c0_sys_clk_p       		: in std_logic;
                c0_sys_clk_n       		: in std_logic;
                c0_ddr4_act_n      		: out std_logic;
                c0_ddr4_adr            	: out std_logic_vector ( 16 downto 0 );
                c0_ddr4_ba 	        	: out std_logic_vector ( 1 downto 0 );
                c0_ddr4_bg 	        	: out std_logic_vector ( 0 to 0 );
                c0_ddr4_cke     		: out std_logic_vector ( 0 to 0 );
                c0_ddr4_odt     		: out std_logic_vector ( 0 to 0 );
                c0_ddr4_cs_n     		: out std_logic_vector ( 0 to 0 );
                c0_ddr4_ck_t     		: out std_logic_vector ( 0 to 0 );
                c0_ddr4_ck_c     		: out std_logic_vector ( 0 to 0 );
                c0_ddr4_reset_n 		: out std_logic;
                c0_ddr4_dm_dbi_n 		: inout std_logic_vector ( 1 downto 0 );
                c0_ddr4_dq 		        : inout std_logic_vector ( 15 downto 0 );
                c0_ddr4_dqs_c 	    	: inout std_logic_vector ( 1 downto 0 );
                c0_ddr4_dqs_t 	    	: inout std_logic_vector ( 1 downto 0 );
                c0_init_calib_complete 	: out std_logic;
                c0_ddr4_ui_clk 		    : out std_logic;
                c0_ddr4_ui_clk_sync_rst	: out std_logic;
                addn_ui_clkout1 		: out std_logic;
                dbg_clk 	        	: out std_logic;
                c0_ddr4_aresetn 		: in std_logic;
                c0_ddr4_s_axi_awid 		: in std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_awaddr 	: in std_logic_vector ( 28 downto 0 );
                c0_ddr4_s_axi_awlen 	: in std_logic_vector ( 7 downto 0 );
                c0_ddr4_s_axi_awsize 	: in std_logic_vector ( 2 downto 0 );
                c0_ddr4_s_axi_awburst 	: in std_logic_vector ( 1 downto 0 );
                c0_ddr4_s_axi_awlock 	: in std_logic_vector ( 0 to 0 );
                c0_ddr4_s_axi_awcache 	: in std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_awprot 	: in std_logic_vector ( 2 downto 0 );
                c0_ddr4_s_axi_awqos 	: in std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_awvalid 	: in std_logic;
                c0_ddr4_s_axi_awready 	: out std_logic;
                c0_ddr4_s_axi_wdata 	: in std_logic_vector ( 31 downto 0 );
                c0_ddr4_s_axi_wstrb 	: in std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_wlast 	: in std_logic;
                c0_ddr4_s_axi_wvalid 	: in std_logic;
                c0_ddr4_s_axi_wready 	: out std_logic;
                c0_ddr4_s_axi_bready 	: in std_logic;
                c0_ddr4_s_axi_bid 		: out std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_bresp 	: out std_logic_vector ( 1 downto 0 );
                c0_ddr4_s_axi_bvalid 	: out std_logic;
                c0_ddr4_s_axi_arid 		: in std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_araddr 	: in std_logic_vector ( 28 downto 0 );
                c0_ddr4_s_axi_arlen 	: in std_logic_vector ( 7 downto 0 );
                c0_ddr4_s_axi_arsize 	: in std_logic_vector ( 2 downto 0 );
                c0_ddr4_s_axi_arburst 	: in std_logic_vector ( 1 downto 0 );
                c0_ddr4_s_axi_arlock 	: in std_logic_vector ( 0 to 0 );
                c0_ddr4_s_axi_arcache 	: in std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_arprot    : in std_logic_vector ( 2 downto 0 );
                c0_ddr4_s_axi_arqos     : in std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_arvalid   : in std_logic;
                c0_ddr4_s_axi_arready   : out std_logic;
                c0_ddr4_s_axi_rready 	: in std_logic;
                c0_ddr4_s_axi_rid 		: out std_logic_vector ( 3 downto 0 );
                c0_ddr4_s_axi_rdata 	: out std_logic_vector ( 31 downto 0 );
                c0_ddr4_s_axi_rresp 	: out std_logic_vector ( 1 downto 0 );
                c0_ddr4_s_axi_rlast 	: out std_logic;
                c0_ddr4_s_axi_rvalid	: out std_logic;
                dbg_bus          		: out std_logic_vector ( 511 downto 0 )
            );
    end component;

--    component ahb2axi_bridge
--        port(
--                s_ahb_hclk 	    	: in std_logic;
--                s_ahb_hresetn 		: in std_logic;
--                s_ahb_hsel      	: in std_logic;
--                s_ahb_haddr 		: in std_logic_vector ( 31 downto 0 );
--                s_ahb_hprot 		: in std_logic_vector ( 3 downto 0 );
--                s_ahb_htrans 		: in std_logic_vector ( 1 downto 0 );
--                s_ahb_hsize 		: in std_logic_vector ( 2 downto 0 );
--                s_ahb_hwrite 		: in std_logic;
--                s_ahb_hburst 		: in std_logic_vector ( 2 downto 0 );
--                s_ahb_hwdata 		: in std_logic_vector ( 31 downto 0 );
--                s_ahb_hready_out 	: out std_logic;
--                s_ahb_hready_in 	: in std_logic;
--                s_ahb_hrdata 		: out std_logic_vector ( 31 downto 0 );
--                s_ahb_hresp 		: out std_logic;
--                m_axi_awid 		    : out std_logic_vector ( 3 downto 0 );
--                m_axi_awlen 		: out std_logic_vector ( 7 downto 0 );
--                m_axi_awsize 		: out std_logic_vector ( 2 downto 0 );
--                m_axi_awburst 		: out std_logic_vector ( 1 downto 0 );
--                m_axi_awcache 		: out std_logic_vector ( 3 downto 0 );
--                m_axi_awaddr 		: out std_logic_vector ( 31 downto 0 );
--                m_axi_awprot 		: out std_logic_vector ( 2 downto 0 );
--                m_axi_awvalid 		: out std_logic;
--                m_axi_awready 		: in std_logic;
--                m_axi_awlock 		: out std_logic;
--                m_axi_wdata 		: out std_logic_vector ( 31 downto 0 );
--                m_axi_wstrb 		: out std_logic_vector ( 3 downto 0 );
--                m_axi_wlast 		: out std_logic;
--                m_axi_wvalid 		: out std_logic;
--                m_axi_wready 		: in std_logic;
--                m_axi_bid 		    : in std_logic_vector ( 3 downto 0 );
--                m_axi_bresp 		: in std_logic_vector ( 1 downto 0 );
--                m_axi_bvalid 		: in std_logic;
--                m_axi_bready 		: out std_logic;
--                m_axi_arid  		: out std_logic_vector ( 3 downto 0 );
--                m_axi_arlen 		: out std_logic_vector ( 7 downto 0 );
--                m_axi_arsize 		: out std_logic_vector ( 2 downto 0 );
--                m_axi_arburst 		: out std_logic_vector ( 1 downto 0 );
--                m_axi_arprot 		: out std_logic_vector ( 2 downto 0 );
--                m_axi_arcache 		: out std_logic_vector ( 3 downto 0 );
--                m_axi_arvalid 		: out std_logic;
--                m_axi_araddr 		: out std_logic_vector ( 31 downto 0 );
--                m_axi_arlock 		: out std_logic;
--                m_axi_arready 		: in std_logic;
--                m_axi_rid   		: in std_logic_vector ( 3 downto 0 );
--                m_axi_rdata 		: in std_logic_vector ( 31 downto 0 );
--                m_axi_rresp 		: in std_logic_vector ( 1 downto 0 );
--                m_axi_rvalid 		: in std_logic;
--                m_axi_rlast 		: in std_logic;
--                m_axi_rready 		: out std_logic
--            );
--    end component;

    component mig_cdc
        port( 
                s_axi_aclk 		    : in std_logic;
                s_axi_aresetn 		: in std_logic;
                s_axi_awid 		    : in std_logic_vector ( 3 downto 0 );
                s_axi_awaddr 		: in std_logic_vector ( 28 downto 0 );
                s_axi_awlen 		: in std_logic_vector ( 7 downto 0 );
                s_axi_awsize 		: in std_logic_vector ( 2 downto 0 );
                s_axi_awburst 		: in std_logic_vector ( 1 downto 0 );
                s_axi_awlock 		: in std_logic_vector ( 0 to 0 );
                s_axi_awcache 		: in std_logic_vector ( 3 downto 0 );
                s_axi_awprot 		: in std_logic_vector ( 2 downto 0 );
                s_axi_awregion 		: in std_logic_vector ( 3 downto 0 );
                s_axi_awqos 		: in std_logic_vector ( 3 downto 0 );
                s_axi_awvalid 		: in std_logic;
                s_axi_awready 		: out std_logic;
                s_axi_wdata 		: in std_logic_vector ( 31 downto 0 );
                s_axi_wstrb 		: in std_logic_vector ( 3 downto 0 );
                s_axi_wlast 		: in std_logic;
                s_axi_wvalid 		: in std_logic;
                s_axi_wready 		: out std_logic;
                s_axi_bid 		    : out std_logic_vector ( 3 downto 0 );
                s_axi_bresp 		: out std_logic_vector ( 1 downto 0 );
                s_axi_bvalid 		: out std_logic;
                s_axi_bready 		: in std_logic;
                s_axi_arid 		    : in std_logic_vector ( 3 downto 0 );
                s_axi_araddr 		: in std_logic_vector ( 28 downto 0 );
                s_axi_arlen 		: in std_logic_vector ( 7 downto 0 );
                s_axi_arsize 		: in std_logic_vector ( 2 downto 0 );
                s_axi_arburst 		: in std_logic_vector ( 1 downto 0 );
                s_axi_arlock 		: in std_logic_vector ( 0 to 0 );
                s_axi_arcache 		: in std_logic_vector ( 3 downto 0 );
                s_axi_arprot 		: in std_logic_vector ( 2 downto 0 );
                s_axi_arregion 		: in std_logic_vector ( 3 downto 0 );
                s_axi_arqos 		: in std_logic_vector ( 3 downto 0 );
                s_axi_arvalid 		: in std_logic;
                s_axi_arready 		: out std_logic;
                s_axi_rid 		    : out std_logic_vector ( 3 downto 0 );
                s_axi_rdata 		: out std_logic_vector ( 31 downto 0 );
                s_axi_rresp 		: out std_logic_vector ( 1 downto 0 );
                s_axi_rlast 		: out std_logic;
                s_axi_rvalid 		: out std_logic;
                s_axi_rready 		: in std_logic;
                m_axi_aclk 		    : in std_logic;
                m_axi_aresetn 		: in std_logic;
                m_axi_awid 		    : out std_logic_vector ( 3 downto 0 );
                m_axi_awaddr 		: out std_logic_vector ( 28 downto 0 );
                m_axi_awlen 		: out std_logic_vector ( 7 downto 0 );
                m_axi_awsize 		: out std_logic_vector ( 2 downto 0 );
                m_axi_awburst 		: out std_logic_vector ( 1 downto 0 );
                m_axi_awlock 		: out std_logic_vector ( 0 to 0 );
                m_axi_awcache 		: out std_logic_vector ( 3 downto 0 );
                m_axi_awprot 		: out std_logic_vector ( 2 downto 0 );
                m_axi_awregion 		: out std_logic_vector ( 3 downto 0 );
                m_axi_awqos 		: out std_logic_vector ( 3 downto 0 );
                m_axi_awvalid 		: out std_logic;
                m_axi_awready 		: in std_logic;
                m_axi_wdata 		: out std_logic_vector ( 31 downto 0 );
                m_axi_wstrb 		: out std_logic_vector ( 3 downto 0 );
                m_axi_wlast 		: out std_logic;
                m_axi_wvalid 		: out std_logic;
                m_axi_wready 		: in std_logic;
                m_axi_bid 		    : in std_logic_vector ( 3 downto 0 );
                m_axi_bresp 		: in std_logic_vector ( 1 downto 0 );
                m_axi_bvalid 		: in std_logic;
                m_axi_bready 		: out std_logic;
                m_axi_arid 	    	: out std_logic_vector ( 3 downto 0 );
                m_axi_araddr 		: out std_logic_vector ( 28 downto 0 );
                m_axi_arlen 		: out std_logic_vector ( 7 downto 0 );
                m_axi_arsize 		: out std_logic_vector ( 2 downto 0 );
                m_axi_arburst 		: out std_logic_vector ( 1 downto 0 );
                m_axi_arlock 		: out std_logic_vector ( 0 to 0 );
                m_axi_arcache 		: out std_logic_vector ( 3 downto 0 );
                m_axi_arprot 		: out std_logic_vector ( 2 downto 0 );
                m_axi_arregion 		: out std_logic_vector ( 3 downto 0 );
                m_axi_arqos 		: out std_logic_vector ( 3 downto 0 );
                m_axi_arvalid 		: out std_logic;
                m_axi_arready 		: in std_logic;
                m_axi_rid   		: in std_logic_vector ( 3 downto 0 );
                m_axi_rdata 		: in std_logic_vector ( 31 downto 0 );
                m_axi_rresp 		: in std_logic_vector ( 1 downto 0 );
                m_axi_rlast 		: in std_logic;
                m_axi_rvalid 		: in std_logic;
                m_axi_rready 		: out std_logic
            );
      end component;
begin

    apbo.pindex  <= pindex;
    apbo.pconfig <= pconfig;
    apbo.pirq    <= (others => '0');
    apbo.prdata  <= (others => '0');

    ahbso.hirq    <= (others => '0');
    ahbso.hindex  <= hindex;
    ahbso.hsplit  <= (others => '0');
    
    bridge: ahb2axi4b
    generic map (
                    hindex => hindex,
                    aximid => 0,
                    wbuffer_num => 8,
                    rprefetch_num => 8,
                    endianness_mode => 0,
                    narrow_acc_mode => 0,
                    vendor  => VENDOR_GAISLER,
                    device  => GAISLER_MIG_7SERIES,
                    bar0    => ahb2ahb_membar(haddr, '1', '1', hmask)
                )
    port map (
                 rstn  => rst_n_syn,
                 clk   => clk_amba,
                 ahbsi => ahbsi,
                 ahbso => ahbso,
                 aximi => aximi,
                 aximo => aximo
             );

--    bridge: ahb2axi_bridge
--    port map(
--                s_ahb_hclk 	    	=> clk_amba,
--                s_ahb_hresetn 		=> rst_n_syn,
--                s_ahb_hsel      	=> ahbsi.hsel(hindex),
--                s_ahb_haddr 		=> ahbsi.haddr,
--                s_ahb_hprot 		=> ahbsi.hprot,
--                s_ahb_htrans 		=> ahbsi.htrans,
--                s_ahb_hsize 		=> ahbsi.hsize,
--                s_ahb_hwrite 		=> ahbsi.hwrite,
--                s_ahb_hburst 		=> ahbsi.hburst,
--                s_ahb_hwdata 		=> ahbsi.hwdata,
--                s_ahb_hready_out 	=> ahbso.hready,
--                s_ahb_hready_in 	=> ahbsi.hready,
--                s_ahb_hrdata 		=> ahbso.hrdata,
--                s_ahb_hresp 		=> ahbso.hresp(0),
--                m_axi_awid 		    => aximo.aw.id,
--                m_axi_awlen 		=> aximo.aw.len,
--                m_axi_awsize 		=> aximo.aw.size,
--                m_axi_awburst 		=> aximo.aw.burst,
--                m_axi_awcache 		=> aximo.aw.cache,
--                m_axi_awaddr 		=> aximo.aw.addr,
--                m_axi_awprot 		=> open,
--                m_axi_awvalid 		=> aximo.aw.valid,
--                m_axi_awready 		=> aximi.aw.ready,
--                m_axi_awlock 		=> open,
--                m_axi_wdata 		=> aximo.w.data,
--                m_axi_wstrb 		=> aximo.w.strb,
--                m_axi_wlast 		=> aximo.w.last,
--                m_axi_wvalid 		=> aximo.w.valid,
--                m_axi_wready 		=> aximi.w.ready,
--                m_axi_bid 		    => aximi.b.id,
--                m_axi_bresp 		=> aximi.b.resp,
--                m_axi_bvalid 		=> aximi.b.valid,
--                m_axi_bready 		=> aximo.b.ready,
--                m_axi_arid  		=> aximo.ar.id,
--                m_axi_arlen 		=> aximo.ar.len,
--                m_axi_arsize 		=> aximo.ar.size,
--                m_axi_arburst 		=> aximo.ar.burst,
--                m_axi_arprot 		=> open,
--                m_axi_arcache 		=> aximo.ar.cache,
--                m_axi_arvalid 		=> aximo.ar.valid,
--                m_axi_araddr 		=> aximo.ar.addr,
--                m_axi_arlock 		=> open,
--                m_axi_arready 		=> aximi.ar.ready,
--                m_axi_rid   		=> aximi.r.id,
--                m_axi_rdata 		=> aximi.r.data,
--                m_axi_rresp 		=> aximi.r.resp,
--                m_axi_rvalid 		=> aximi.r.valid,
--                m_axi_rlast 		=> aximi.r.last,
--                m_axi_rready 		=> aximo.r.ready
--            );

    axi_conv: mig_cdc
        port map( 
                s_axi_aclk 		    => fpga_clk,
                s_axi_aresetn 		=> rst_n_syn,
                s_axi_awid 		    => aximo.aw.id,
                s_axi_awaddr 		=> aximo.aw.addr(28 downto 0),
                s_axi_awlen 		=> aximo.aw.len,
                s_axi_awsize 		=> aximo.aw.size,
                s_axi_awburst 		=> aximo.aw.burst,
                s_axi_awlock 		=> zero(0 downto 0),
                s_axi_awcache 		=> aximo.aw.cache,
                s_axi_awprot 		=> zero(2 downto 0),
                s_axi_awregion 		=> zero(3 downto 0),
                s_axi_awqos 		=> zero(3 downto 0),
                s_axi_awvalid 		=> aximo.aw.valid,
                s_axi_awready 		=> aximi.aw.ready,
                s_axi_wdata 		=> aximo.w.data, 
                s_axi_wstrb 		=> aximo.w.strb, 
                s_axi_wlast 		=> aximo.w.last, 
                s_axi_wvalid 		=> aximo.w.valid,
                s_axi_wready 		=> aximi.w.ready,
                s_axi_bid 		    => aximi.b.id,   
                s_axi_bresp 		=> aximi.b.resp, 
                s_axi_bvalid 		=> aximi.b.valid,
                s_axi_bready 		=> aximo.b.ready,
                s_axi_arid 		    => aximo.ar.id,   
                s_axi_araddr 		=> aximo.ar.addr(28 downto 0), 
                s_axi_arlen 		=> aximo.ar.len,  
                s_axi_arsize 		=> aximo.ar.size, 
                s_axi_arburst 		=> aximo.ar.burst,
                s_axi_arlock 		=> zero(0 downto 0),
                s_axi_arcache 		=> aximo.ar.cache,
                s_axi_arprot 		=> zero(2 downto 0),
                s_axi_arregion 		=> zero(3 downto 0),
                s_axi_arqos 		=> zero(3 downto 0),
                s_axi_arvalid 		=> aximo.ar.valid,
                s_axi_arready 		=> aximi.ar.ready,
                s_axi_rid 		    => aximi.r.id,   
                s_axi_rdata 		=> aximi.r.data, 
                s_axi_rresp 		=> aximi.r.resp, 
                s_axi_rlast 		=> aximi.r.last, 
                s_axi_rvalid 		=> aximi.r.valid,
                s_axi_rready 		=> aximo.r.ready,   
                m_axi_aclk 		    => ddr4_clk,
                m_axi_aresetn 		=> ddr4_rstn,
                m_axi_awid 		    => ddr4_aximo.aw.id,
                m_axi_awaddr 		=> ddr4_aximo.aw.addr(28 downto 0),
                m_axi_awlen 		=> ddr4_aximo.aw.len,
                m_axi_awsize 		=> ddr4_aximo.aw.size,
                m_axi_awburst 		=> ddr4_aximo.aw.burst,
                m_axi_awlock 		=> ddr4_awlock,
                m_axi_awcache 		=> ddr4_aximo.aw.cache,
                m_axi_awprot 		=> ddr4_awprot,
                m_axi_awregion 		=> open,
                m_axi_awqos 		=> ddr4_awqos,
                m_axi_awvalid 		=> ddr4_aximo.aw.valid,
                m_axi_awready 		=> ddr4_aximi.aw.ready,
                m_axi_wdata 		=> ddr4_aximo.w.data, 
                m_axi_wstrb 		=> ddr4_aximo.w.strb, 
                m_axi_wlast 		=> ddr4_aximo.w.last, 
                m_axi_wvalid 		=> ddr4_aximo.w.valid,
                m_axi_wready 		=> ddr4_aximi.w.ready,
                m_axi_bid 		    => ddr4_aximi.b.id,   
                m_axi_bresp 		=> ddr4_aximi.b.resp, 
                m_axi_bvalid 		=> ddr4_aximi.b.valid,
                m_axi_bready 		=> ddr4_aximo.b.ready,
                m_axi_arid 	    	=> ddr4_aximo.ar.id,   
                m_axi_araddr 		=> ddr4_aximo.ar.addr(28 downto 0), 
                m_axi_arlen 		=> ddr4_aximo.ar.len,  
                m_axi_arsize 		=> ddr4_aximo.ar.size, 
                m_axi_arburst 		=> ddr4_aximo.ar.burst,
                m_axi_arlock 		=> ddr4_arlock,
                m_axi_arcache 		=> ddr4_aximo.ar.cache,
                m_axi_arprot 		=> ddr4_arprot,
                m_axi_arregion 		=> open,
                m_axi_arqos 		=> ddr4_arqos,
                m_axi_arvalid 		=> ddr4_aximo.ar.valid,
                m_axi_arready 		=> ddr4_aximi.ar.ready,
                m_axi_rid   		=> ddr4_aximi.r.id,   
                m_axi_rdata 		=> ddr4_aximi.r.data, 
                m_axi_rresp 		=> ddr4_aximi.r.resp, 
                m_axi_rlast 		=> ddr4_aximi.r.last, 
                m_axi_rvalid 		=> ddr4_aximi.r.valid,
                m_axi_rready 		=> ddr4_aximo.r.ready
            );

    mig_inst: mig
        port map(
                sys_rst 	        	=> rst_async,
                c0_sys_clk_p       		=> sys_clk_p,
                c0_sys_clk_n       		=> sys_clk_n,
                c0_ddr4_act_n      		=> ddr4_act_n,
                c0_ddr4_adr            	=> ddr4_adr,
                c0_ddr4_ba 	        	=> ddr4_ba,
                c0_ddr4_bg 	        	=> ddr4_bg,
                c0_ddr4_cke     		=> ddr4_cke,
                c0_ddr4_odt     		=> ddr4_odt,
                c0_ddr4_cs_n     		=> ddr4_cs_n,
                c0_ddr4_ck_t     		=> ddr4_ck_t,
                c0_ddr4_ck_c     		=> ddr4_ck_c,
                c0_ddr4_reset_n 		=> ddr4_reset_n,
                c0_ddr4_dm_dbi_n 		=> ddr4_dm_n,
                c0_ddr4_dq 		        => ddr4_dq,
                c0_ddr4_dqs_c 	    	=> ddr4_dqs_c,
                c0_ddr4_dqs_t 	    	=> ddr4_dqs_t,
                c0_init_calib_complete 	=> calib_done,
                c0_ddr4_ui_clk 		    => ddr4_clk,
                c0_ddr4_ui_clk_sync_rst	=> ddr4_rst,
                addn_ui_clkout1 		=> fpga_clk,
                dbg_clk 	        	=> open,
                c0_ddr4_aresetn 		=> ddr4_rstn,
                c0_ddr4_s_axi_awid 		=> ddr4_aximo.aw.id,
                c0_ddr4_s_axi_awaddr 	=> ddr4_aximo.aw.addr(28 downto 0),
                c0_ddr4_s_axi_awlen 	=> ddr4_aximo.aw.len,
                c0_ddr4_s_axi_awsize 	=> ddr4_aximo.aw.size,
                c0_ddr4_s_axi_awburst 	=> ddr4_aximo.aw.burst,
                c0_ddr4_s_axi_awlock 	=> ddr4_awlock,
                c0_ddr4_s_axi_awcache 	=> ddr4_aximo.aw.cache,
                c0_ddr4_s_axi_awprot 	=> ddr4_awprot,
                c0_ddr4_s_axi_awqos 	=> ddr4_awqos,
                c0_ddr4_s_axi_awvalid 	=> ddr4_aximo.aw.valid,
                c0_ddr4_s_axi_awready 	=> ddr4_aximi.aw.ready,
                c0_ddr4_s_axi_wdata 	=> ddr4_aximo.w.data, 
                c0_ddr4_s_axi_wstrb 	=> ddr4_aximo.w.strb, 
                c0_ddr4_s_axi_wlast 	=> ddr4_aximo.w.last, 
                c0_ddr4_s_axi_wvalid 	=> ddr4_aximo.w.valid,
                c0_ddr4_s_axi_wready 	=> ddr4_aximi.w.ready,
                c0_ddr4_s_axi_bready 	=> ddr4_aximo.b.ready,
                c0_ddr4_s_axi_bid 		=> ddr4_aximi.b.id,   
                c0_ddr4_s_axi_bresp 	=> ddr4_aximi.b.resp,
                c0_ddr4_s_axi_bvalid 	=> ddr4_aximi.b.valid,
                c0_ddr4_s_axi_arid 		=> ddr4_aximo.ar.id,  
                c0_ddr4_s_axi_araddr 	=> ddr4_aximo.ar.addr(28 downto 0),
                c0_ddr4_s_axi_arlen 	=> ddr4_aximo.ar.len, 
                c0_ddr4_s_axi_arsize 	=> ddr4_aximo.ar.size,
                c0_ddr4_s_axi_arburst 	=> ddr4_aximo.ar.burst,
                c0_ddr4_s_axi_arlock 	=> ddr4_arlock,
                c0_ddr4_s_axi_arcache 	=> ddr4_aximo.ar.cache,
                c0_ddr4_s_axi_arprot    => ddr4_arprot,
                c0_ddr4_s_axi_arqos     => ddr4_arqos,
                c0_ddr4_s_axi_arvalid   => ddr4_aximo.ar.valid,
                c0_ddr4_s_axi_arready   => ddr4_aximi.ar.ready,
                c0_ddr4_s_axi_rready 	=> ddr4_aximo.r.ready,
                c0_ddr4_s_axi_rid 		=> ddr4_aximi.r.id,   
                c0_ddr4_s_axi_rdata 	=> ddr4_aximi.r.data, 
                c0_ddr4_s_axi_rresp 	=> ddr4_aximi.r.resp, 
                c0_ddr4_s_axi_rlast 	=> ddr4_aximi.r.last, 
                c0_ddr4_s_axi_rvalid	=> ddr4_aximi.r.valid,
                dbg_bus          		=> open
            );                            
        rst_async             <= not(rst_n_async);
        ddr4_ui_clkout1       <= fpga_clk;
        ddr4_ui_clk           <= ddr4_clk;
        ddr4_ui_clk_sync_rst  <= ddr4_rst;
        ddr4_rstn             <= not(ddr4_rst);
        ddr4_addr             <= ddr4_adr(13 downto 0);
        ddr4_we_n             <= ddr4_adr(14);
        ddr4_cas_n            <= ddr4_adr(15);
        ddr4_ras_n            <= ddr4_adr(16);
    end;
