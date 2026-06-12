------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2022, Cobham Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config.all;
use grlib.config_types.all;

library techmap;
use techmap.gencomp.all;

library gaisler;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.axi.all;
use gaisler.plic.all;
use gaisler.l2cache.all;
use gaisler.noelv.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;
use work.rev.REVISION;
use work.cfgmap.all;

entity metasat is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;     -- Enable disassembly to console
    SIMULATION              : integer := 0
    -- pragma translate_off 
    + CFG_MIG_7SERIES_MODEL
    ; ramfile               : string  := "ram.srec"
    ; romfile               : string  := "prom.srec"
    -- pragma translate_on
    );
  port (
    -- Clock and Reset
    reset       : in    std_ulogic;
    clk250p     : in    std_ulogic;  -- 250 MHz clock
    clk250n     : in    std_ulogic;  -- 250 MHz clock
    clk250_2p   : in    std_ulogic;  -- 250 MHz clock _2
    clk250_2n   : in    std_ulogic;  -- 250 MHz clock _2
    -- Switches
    switch      : in    std_logic_vector(3 downto 0);
    -- LEDs
    led         : out   std_logic_vector(7 downto 0);
    -- GPIOs
    --gpio        : inout std_logic_vector(15 downto 0);
    -- Ethernet
    gtrefclk_n  : in    std_logic;
    gtrefclk_p  : in    std_logic;
    txp         : out   std_logic;
    txn         : out   std_logic;
    rxp         : in    std_logic;
    rxn         : in    std_logic;
    emdio       : inout std_logic;
    emdc        : out   std_ulogic;
    eint        : in    std_ulogic;
    erst        : out   std_ulogic;
    -- UART
    dsurx       : in    std_ulogic; 
    dsutx       : out   std_ulogic;
    dsuctsn     : in    std_ulogic; 
    dsurtsn     : out   std_ulogic; 
    -- Push Buttons (Active High)
    button      : in    std_logic_vector(4 downto 0);
    -- RS-485 interfaces
    --uart485_rsde        : out std_logic_vector(1 downto 0);  -- RS-485 UART driver enable
    --uart485_rsre        : out std_logic_vector(1 downto 0);  -- RS-485 UART receiver enable
    --uart485_rstx        : out std_logic_vector(1 downto 0);  -- RS-485 UART tx data
    --uart485_rsrx        : in std_logic_vector(1 downto 0);   -- RS-485 UART rx data
    -- CPU DDR4 (MIG) 
    ddr4_c1_dq     : inout std_logic_vector(63 downto 0);
    ddr4_c1_dqs_c  : inout std_logic_vector(7 downto 0);  -- Data Strobe
    ddr4_c1_dqs_t  : inout std_logic_vector(7 downto 0);  -- Data Strobe
    ddr4_c1_addr   : out   std_logic_vector(13 downto 0); -- Address
    ddr4_c1_ras_n  : out   std_ulogic;
    ddr4_c1_cas_n  : out   std_ulogic;
    ddr4_c1_we_n   : out   std_ulogic;
    ddr4_c1_ba     : out   std_logic_vector(1 downto 0); -- Device bank address per group
    ddr4_c1_bg     : out   std_logic_vector(0 downto 0); -- Device bank group address
    ddr4_c1_dm_n   : inout std_logic_vector(7 downto 0); -- Data Mask
    ddr4_c1_ck_c   : out   std_logic_vector(0 downto 0); -- Clock Negative Edge
    ddr4_c1_ck_t   : out   std_logic_vector(0 downto 0); -- Clock Positive Edge
    ddr4_c1_cke    : out   std_logic_vector(0 downto 0); -- Clock Enable
    ddr4_c1_act_n  : out   std_ulogic;                   -- Command Input
    --ddr4_c1_alert_n: in    std_ulogic;                   -- Alert Output
    ddr4_c1_odt    : out   std_logic_vector(0 downto 0); -- On-die Termination
    ddr4_c1_par    : out   std_ulogic;                   -- Parity for cmd and addr
    ddr4_c1_ten    : out   std_ulogic;                   -- Connectivity Test Mode
    ddr4_c1_cs_n   : out   std_logic_vector(0 downto 0); -- Chip Select
    ddr4_c1_reset_n: out   std_ulogic;                   -- Asynchronous Reset
    -- GPU DDR4 (MIG) 
    ddr4_c2_dq     : inout std_logic_vector(63 downto 0);
    ddr4_c2_dqs_c  : inout std_logic_vector(7 downto 0);  -- Data Strobe
    ddr4_c2_dqs_t  : inout std_logic_vector(7 downto 0);  -- Data Strobe
    ddr4_c2_addr   : out   std_logic_vector(13 downto 0); -- Address
    ddr4_c2_ras_n  : out   std_ulogic;
    ddr4_c2_cas_n  : out   std_ulogic;
    ddr4_c2_we_n   : out   std_ulogic;
    ddr4_c2_ba     : out   std_logic_vector(1 downto 0); -- Device bank address per group
    ddr4_c2_bg     : out   std_logic_vector(0 downto 0); -- Device bank group address
    ddr4_c2_dm_n   : inout std_logic_vector(7 downto 0); -- Data Mask
    ddr4_c2_ck_c   : out   std_logic_vector(0 downto 0); -- Clock Negative Edge
    ddr4_c2_ck_t   : out   std_logic_vector(0 downto 0); -- Clock Positive Edge
    ddr4_c2_cke    : out   std_logic_vector(0 downto 0); -- Clock Enable
    ddr4_c2_act_n  : out   std_ulogic;                   -- Command Input
    --ddr4_c2_alert_n: in    std_ulogic;                   -- Alert Output
    ddr4_c2_odt    : out   std_logic_vector(0 downto 0); -- On-die Termination
    ddr4_c2_par    : out   std_ulogic;                   -- Parity for cmd and addr
    ddr4_c2_ten    : out   std_ulogic;                   -- Connectivity Test Mode
    ddr4_c2_cs_n   : out   std_logic_vector(0 downto 0); -- Chip Select
    ddr4_c2_reset_n: out   std_ulogic                    -- Asynchronous Reset
    );
end;

architecture rtl of metasat is
  constant OEPOL        : integer := padoen_polarity(padtech);
  constant BOARD_FREQ   : integer := CFG_BOARDFRQ; -- input frequency in KHz
  constant CPU_FREQ     : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV; -- cpu frequency in KHz

  -------------------------------------
  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  signal stati          : ahbstat_in_type;
  -- Clocks and Reset
  signal clkm           : std_ulogic
  -- pragma translate_off 
  := '0'
  -- pragma translate_on
  ;
  signal rstn           : std_ulogic;
  signal clk_300        : std_ulogic;
  signal cgi            : clkgen_in_type;
  signal cgo            : clkgen_out_type;
  signal clklock        : std_ulogic;
  signal lock           : std_ulogic;
  signal lclk           : std_ulogic;
  signal rst            : std_ulogic;
  signal resetn         : std_ulogic;
  signal calib_done_c1  : std_ulogic;
  signal calib_done_c2  : std_ulogic;
  signal migrstn        : std_ulogic;
  signal gpu_resetn     : std_ulogic;
  signal gpu_rstn       : std_ulogic;
  signal gpu_migrstn    : std_ulogic;

  -- UART
  signal dsu_sel    : std_ulogic;
  signal uart_rx    : std_logic_vector(0 downto 0);
  signal uart_ctsn  : std_logic_vector(0 downto 0);
  signal uart_tx    : std_logic_vector(0 downto 0);
  signal uart_rtsn  : std_logic_vector(0 downto 0);
  signal duart_rx   : std_ulogic;
  signal duart_tx   : std_ulogic;
  -- GPIO
  --signal gpio_i         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  --signal gpio_o         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  --signal gpio_oe        : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  -- JTAG
  signal tck, tms, tdi, tdo : std_ulogic;
  -- Ethernet
  signal ethi : eth_in_type;
  signal etho : eth_out_type;
  signal eth_apbi       : apb_slv_in_type;
  signal eth_apbo       : apb_slv_out_type;

  -- RS-485 APBUART
  signal uart485_i : uart_in_vector_type(1 downto 0);
  signal uart485_o : uart_out_vector_type(1 downto 0);
  signal uart485_rsre_n   : std_logic_vector(1 downto 0); 

  -- Memory
  signal cpu_mem_aximi      : axi_somi_type;
  signal cpu_mem_aximo      : axi4_mosi_type;
  signal gpu_mem_aximi      : axi_somi_type;
  signal gpu_mem_aximo      : axi4_mosi_type;
  -- pragma translate_off
  signal mem_aximo_sim  : axi_mosi_type;
  signal gpu_aximo_sim  : axi_mosi_type;
  signal gpu_wr_awdone  : std_ulogic := '0';
  signal gpu_wr_wdone   : std_ulogic := '0';
  signal gpu_wr_id      : std_logic_vector(AXI_ID_WIDTH-1 downto 0) := (others => '0');
  -- pragma translate_on
  signal mem_ahbsi0     : ahb_slv_in_type;
  signal mem_ahbso0     : ahb_slv_out_type;
  signal mem_apbi0      : apb_slv_in_type;
  signal mem_apbo0      : apb_slv_out_type;
  signal rom_ahbsi1     : ahb_slv_in_type;
  signal rom_ahbso1     : ahb_slv_out_type;

  signal uart_rx_int    : std_ulogic; 
  signal uart_tx_int    : std_ulogic; 
  signal uart_ctsn_int  : std_ulogic;
  signal uart_rtsn_int  : std_ulogic;

  signal dmen           : std_logic;
  signal dmbreak        : std_logic;
  signal cpu0errn       : std_logic;

  component axi_mig4_7series 
    generic(
      mem_bits  : integer := 30
    );
    port(
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
      ddr4_dm_n           : inout std_logic_vector(7 downto 0);
      ddr4_dq             : inout std_logic_vector(63 downto 0);
      ddr4_dqs_c          : inout std_logic_vector(7 downto 0);
      ddr4_dqs_t          : inout std_logic_vector(7 downto 0);
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
      aximi               : out   axi_somi_type;
      aximo               : in    axi4_mosi_type;
      -- Misc
      ddr4_ui_clkout1     : out   std_logic;
      clk_ref_i           : in    std_logic
      );
  end component;

  component sgmii_vcu118 
    generic(
      pindex          : integer := 0;
      paddr           : integer := 0;
      pmask           : integer := 16#fff#;
      abits           : integer := 8;
      autonegotiation : integer := 1;
      pirq            : integer := 0;
      debugmem        : integer := 0;
      tech            : integer := 0;
      simulation      : integer := 0
      );
    port(
      sgmiii    : in  eth_sgmii_in_type;
      sgmiio    : out eth_sgmii_out_type;
      gmiii     : out eth_in_type;
      gmiio     : in  eth_out_type;
      reset     : in  std_logic;
      clkout0o  : out std_logic;
      clkout1o  : out std_logic;
      clkout2o  : out std_logic;
      apb_clk   : in  std_logic;
      apb_rstn  : in  std_logic;
      apbi      : in  apb_slv_in_type;
      apbo      : out apb_slv_out_type
      );
  end component;
  
begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------
  vcc         <= '1';
  gnd         <= '0';
  cgi.pllctrl <= "00";
  cgi.pllrst  <= resetn;

  -- Clocks
  clk_gen : if (CFG_MIG_7SERIES = 0) or 
               ((CFG_MIG_7SERIES = 1) and (SIMULATION /= 0)) generate
    clk_pad_ds : clkpad_ds generic map (
      tech      => padtech,
      level     => sstl12_dci,
      voltage   => x12v)
      port map (clk250p, clk250n, lclk);
    clkgen0 : clkgen        -- clock generator
      generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, 0,
                   CFG_CLK_NOFB, 0, 0, 0, BOARD_FREQ)
      port map (lclk, lclk, clkm, open, open, open, open, cgi, cgo, open, open, open);
  end generate;

  reset_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (reset, rst);

  resetn <= not rst;
  gpu_resetn <= not rst;

  lock <= calib_done_c1 when CFG_MIG_7SERIES = 1 else cgo.clklock;

  rst1 : rstgen         -- reset generator
    generic map (acthigh => 1)
    port map (rst, clkm, lock, migrstn, open);

  gpu_migrstn <= migrstn;

  gpu_rstn <= rstn;

  ----------------------------------------------------------------------
  ---  METASAT SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  sys : entity work.metasatcore
  generic map (
    fabtech     => CFG_FABTECH,
    memtech     => CFG_MEMTECH,
    padtech     => CFG_PADTECH,
    clktech     => CFG_CLKTECH,
    cpu_freq    => CPU_FREQ,
    disas       => disas)
  port map (
    -- Clock & reset
    clkm        => clkm, 
    resetn      => resetn,
    lock        => lock,
    rstno       => rstn,
    -- misc
    dmen        => '1',
    dmbreak     => dmbreak,
    dmreset     => open,
    cpu0errn    => open,
    -- GPIO
    --gpio_i      => gpio_i,
    --gpio_o      => gpio_o,
    --gpio_oe     => gpio_oe,
    uart_rx     => uart_rx,
    uart_ctsn   => uart_ctsn,
    uart_tx     => uart_tx,
    uart_rtsn   => uart_rtsn,
    -- Memory controller
    cpu_mem_aximi   => cpu_mem_aximi,
    cpu_mem_aximo   => cpu_mem_aximo,
    gpu_mem_aximi   => gpu_mem_aximi,
    gpu_mem_aximo   => gpu_mem_aximo,
    mem_ahbsi0  => mem_ahbsi0,
    mem_ahbso0  => mem_ahbso0,
    mem_apbi0   => mem_apbi0, 
    mem_apbo0   => mem_apbo0, 
    -- PROM controller
    rom_ahbsi1  => rom_ahbsi1,
    rom_ahbso1  => rom_ahbso1,
    -- Ethernet PHY
    ethi        => ethi,
    etho        => etho,
    eth_apbi    => eth_apbi,
    eth_apbo    => eth_apbo,
    -- Debug UART
    duart_rx    => duart_rx,
    duart_tx    => duart_tx,
    -- UART RS-485
    uart485_i	=> uart485_i,
    uart485_o   => uart485_o,
    -- Debug JTAG
    tck         => tck,
    tms         => tms,
    tdi         => tdi,
    tdo         => tdo
  );

  --errorn_pad : odpad
  --  generic map (tech => padtech, oepol => OEPOL)
  --  port map (errorn, cpu0errn);

  --dsuen_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x12v)
  --  port map (switch(2), dmen);
  dmen <= '1';

  -- Button 2,3,4 are still to be assigned
  dmbreak_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (button(4), dmbreak);

  --ndreset_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(4), dsuo.ndmreset);

  --dmactive_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(5), dsuo.dmactive);

  -----------------------------------------------------------------------------
  -- Debug UART / UART --------------------------------------------------------
  -----------------------------------------------------------------------------
  sw4_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x12v)
    port map (switch(3), dsu_sel);

  uart_tx_int     <= duart_tx       when dsu_sel = '1' else uart_tx(0);
  uart_rtsn_int   <= '1'            when dsu_sel = '1' else uart_rtsn(0);  
  uart_rx(0)      <= uart_rx_int    when dsu_sel = '0' else '1';
  uart_ctsn(0)    <= uart_ctsn_int  when dsu_sel = '0' else '1';
  duart_rx        <= uart_rx_int    when dsu_sel = '1' else '1';
  
  dsurx_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsurx, uart_rx_int);
  dsutx_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsutx, uart_tx_int);
  dsuctsn_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsuctsn, uart_ctsn_int);
  dsurtsn_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (dsurtsn, uart_rtsn_int);

  dsusel_pad : outpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(4), dsu_sel);

----------------------------------------------------------------------
---  RS-485 UARTs  ---------------------------------------------------
----------------------------------------------------------------------
--  rs485pads_en : if (CFG_APB_UART /= 0) generate
--    rs485_apbuart_loop : for i in 1 downto 0 generate
--
--      uart485_i(i).extclk <= '0';
--      -- RS-485 UART driver enable
--      uart485_rsde_pad : outpad 
--        generic map (tech => padtech, level => cmos, voltage => x18v)
--        port map (pad => uart485_rsde(i), i => uart485_o(i).txen);
--
--      -- RS-485 UART receiver enable
--      uart485_rsre_n(i) <= not uart485_o(i).rxen; -- RS-485 UART receiver enable is active low
--
--      uart485_rsre_pad : outpad
--        generic map (tech => padtech, level => cmos, voltage => x18v)
--        port map (pad => uart485_rsre(i), i => uart485_rsre_n(i));
--
--      uart485_rxd2_pad : inpad 
-- 	generic map (tech => padtech, level => cmos, voltage => x18v)
-- 	port map (pad => uart485_rsrx(i), o => uart485_i(i).rxd);
--
--      uart485_txd2_pad : outpad 
-- 	generic map (tech => padtech, level => cmos, voltage => x18v)
--	port map (pad => uart485_rstx(i), i => uart485_o(i).txd);
--
--    end generate;
--  end generate;

  -----------------------------------------------------------------------------
  -- DDR4 Memory Controller (MIG) ---------------------------------------------
  -----------------------------------------------------------------------------
  -- No APB interface on memory controller  
  mem_apbo0    <= apb_none;

  mig_gen : if (CFG_MIG_7SERIES = 1) and (SIMULATION = 0) generate
    ddr4c1: axi_mig4_7series generic map (
      mem_bits  => 30
      )
      port map (
        calib_done      => calib_done_c1,
        sys_clk_p       => clk250p,
        sys_clk_n       => clk250n,
        ddr4_addr       => ddr4_c1_addr,
        ddr4_we_n       => ddr4_c1_we_n,
        ddr4_cas_n      => ddr4_c1_cas_n,
        ddr4_ras_n      => ddr4_c1_ras_n,
        ddr4_ba         => ddr4_c1_ba,
        ddr4_cke        => ddr4_c1_cke,
        ddr4_cs_n       => ddr4_c1_cs_n,
        ddr4_dm_n       => ddr4_c1_dm_n,
        ddr4_dq         => ddr4_c1_dq,
        ddr4_dqs_c      => ddr4_c1_dqs_c,
        ddr4_dqs_t      => ddr4_c1_dqs_t,
        ddr4_odt        => ddr4_c1_odt,
        ddr4_bg         => ddr4_c1_bg,
        ddr4_reset_n    => ddr4_c1_reset_n,
        ddr4_act_n      => ddr4_c1_act_n,
        ddr4_ck_c       => ddr4_c1_ck_c,
        ddr4_ck_t       => ddr4_c1_ck_t,
        ddr4_ui_clk     => open,
        ddr4_ui_clk_sync_rst => open,
        rst_n_syn       => migrstn,
        rst_n_async     => resetn,
        aximi           => cpu_mem_aximi,
        aximo           => cpu_mem_aximo,
        -- Misc
        ddr4_ui_clkout1 => clkm,
        clk_ref_i       => clkm
        );

    gpu_mig : if (CFG_VX_EN = 1) generate
      ddr4c2: axi_mig4_7series generic map (
        mem_bits  => 30
        )
        port map (
          calib_done      => calib_done_c2,
          sys_clk_p       => clk250_2p,
          sys_clk_n       => clk250_2n,
          ddr4_addr       => ddr4_c2_addr,
          ddr4_we_n       => ddr4_c2_we_n,
          ddr4_cas_n      => ddr4_c2_cas_n,
          ddr4_ras_n      => ddr4_c2_ras_n,
          ddr4_ba         => ddr4_c2_ba,
          ddr4_cke        => ddr4_c2_cke,
          ddr4_cs_n       => ddr4_c2_cs_n,
          ddr4_dm_n       => ddr4_c2_dm_n,
          ddr4_dq         => ddr4_c2_dq,
          ddr4_dqs_c      => ddr4_c2_dqs_c,
          ddr4_dqs_t      => ddr4_c2_dqs_t,
          ddr4_odt        => ddr4_c2_odt,
          ddr4_bg         => ddr4_c2_bg,
          ddr4_reset_n    => ddr4_c2_reset_n,
          ddr4_act_n      => ddr4_c2_act_n,
          ddr4_ck_c       => ddr4_c2_ck_c,
          ddr4_ck_t       => ddr4_c2_ck_t,
          ddr4_ui_clk     => open,
          ddr4_ui_clk_sync_rst => open,
          rst_n_syn       => gpu_migrstn,
          rst_n_async     => gpu_resetn,
          aximi           => gpu_mem_aximi,
          aximo           => gpu_mem_aximo,
          -- Misc
          ddr4_ui_clkout1 => open,
          clk_ref_i       => clkm
          );
    end generate gpu_mig;

    no_gpu_mig : if (CFG_VX_EN = 0) generate
      ddr4_c2_addr       <= (others => '0');
      ddr4_c2_we_n       <= '0';
      ddr4_c2_cas_n      <= '0';
      ddr4_c2_ras_n      <= '0';
      ddr4_c2_ba         <= (others => '0');
      ddr4_c2_cke        <= (others => '0');
      ddr4_c2_cs_n       <= (others => '0');
      ddr4_c2_dm_n       <= (others => 'Z');
      ddr4_c2_dq         <= (others => 'Z');
      ddr4_c2_dqs_c      <= (others => 'Z');
      ddr4_c2_dqs_t      <= (others => 'Z');
      ddr4_c2_odt        <= (others => '0');
      ddr4_c2_bg         <= (others => '0');
      ddr4_c2_reset_n    <= '1';
      ddr4_c2_act_n      <= '1';

      ddr4_c2_ck_outpad : outpad_ds
        generic map (tech => padtech, level => sstl12_dci, voltage => x12v)
        port map (ddr4_c2_ck_t(0), ddr4_c2_ck_c(0), gnd, gnd);

      calib_done_c2 <= '1';
    end generate no_gpu_mig;
  end generate mig_gen;

  no_mig_gen : if (CFG_MIG_7SERIES = 0) generate  
    -- Tie-Off DDR4 Signals
    ddr4_c1_addr       <= (others => '0');
    ddr4_c1_we_n       <= '0';
    ddr4_c1_cas_n      <= '0';
    ddr4_c1_ras_n      <= '0';
    ddr4_c1_ba         <= (others => '0');
    ddr4_c1_cke        <= (others => '0');
    ddr4_c1_cs_n       <= (others => '0');
    ddr4_c1_dm_n       <= (others => 'Z');
    ddr4_c1_dq         <= (others => 'Z');
    ddr4_c1_dqs_c      <= (others => 'Z');
    ddr4_c1_dqs_t      <= (others => 'Z');
    ddr4_c1_odt        <= (others => '0');
    ddr4_c1_bg         <= (others => '0');
    ddr4_c1_reset_n    <= '1';
    ddr4_c1_act_n      <= '1';

    ddr4_c1_ck_outpad : outpad_ds
      generic map (tech => padtech, level => sstl12_dci, voltage => x12v)
      port map (ddr4_c1_ck_t(0), ddr4_c1_ck_c(0), gnd, gnd);

    calib_done_c1 <= '1';

    no_gpu_mig : if (CFG_VX_EN = 1) generate
      ddr4_c2_addr       <= (others => '0');
      ddr4_c2_we_n       <= '0';
      ddr4_c2_cas_n      <= '0';
      ddr4_c2_ras_n      <= '0';
      ddr4_c2_ba         <= (others => '0');
      ddr4_c2_cke        <= (others => '0');
      ddr4_c2_cs_n       <= (others => '0');
      ddr4_c2_dm_n       <= (others => 'Z');
      ddr4_c2_dq         <= (others => 'Z');
      ddr4_c2_dqs_c      <= (others => 'Z');
      ddr4_c2_dqs_t      <= (others => 'Z');
      ddr4_c2_odt        <= (others => '0');
      ddr4_c2_bg         <= (others => '0');
      ddr4_c2_reset_n    <= '1';
      ddr4_c2_act_n      <= '1';

      ddr4_c2_ck_outpad : outpad_ds
        generic map (tech => padtech, level => sstl12_dci, voltage => x12v)
        port map (ddr4_c2_ck_t(0), ddr4_c2_ck_c(0), gnd, gnd);

      calib_done_c2 <= '1';
    end generate no_gpu_mig;
  end generate no_mig_gen;

  led6_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(6), calib_done_c1);
  led7_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (led(7), lock);

  -- For designs that have PAR connected from the FPGA to a component, SODIMM, or UDIMM,
  -- the PAR output of the FPGA should be driven low using an SSTL12 driver to ensure it
  -- is held low at the memory.

  ddr4_c1_ten      <= gnd;
  ddr4_c1_par      <= gnd;
  
  -- Simulation module
  no_mig_mem_gen : if (CFG_MIG_7SERIES = 0) generate
    axi_mem_gen : if (CFG_L2_AXI = 1) generate
      mem_ahbso0 <= ahbs_none;
    end generate axi_mem_gen;

    ahb_mem_gen : if (CFG_L2_AXI = 0) generate
      ahbram1 : ahbram 
        generic map (
          hindex      => 0,
          haddr       => L2C_HADDR,
          hmask       => L2C_HMASK,
          tech        => CFG_MEMTECH,
          kbytes      => 1024)
        port map (
          rstn,
          clkm,
          mem_ahbsi0,
          mem_ahbso0);
    end generate ahb_mem_gen;
  end generate no_mig_mem_gen;

  -- Simulation module
  -- pragma translate_off
  sim_mem_gen : if (CFG_MIG_7SERIES = 1) and (SIMULATION /= 0) generate
    calib_done_c1 <= '1';
    calib_done_c2 <= '1';

    axi_mem_gen : if (CFG_L2_AXI = 1) generate
      mig_axiram : aximem
      generic map (
                    fname   => ramfile,
                    axibits => AXIDW,
                    rstmode => 0)
      port map (
                 clk   => clkm,
                 rst   => rstn,
                 axisi => mem_aximo_sim,
                 axiso => cpu_mem_aximi);

      mem_ahbso0 <= ahbs_none;

      mem_aximo_sim.aw <= (id => cpu_mem_aximo.aw.id, 
                          addr => cpu_mem_aximo.aw.addr,
                          len => cpu_mem_aximo.aw.len(3 downto 0),
                          size => cpu_mem_aximo.aw.size,
                          burst => cpu_mem_aximo.aw.burst,
                          lock  => '0' & cpu_mem_aximo.aw.lock,
                          cache => cpu_mem_aximo.aw.cache,
                          prot => cpu_mem_aximo.aw.prot,
                          valid => cpu_mem_aximo.aw.valid);
      mem_aximo_sim.w <= (id => cpu_mem_aximo.aw.id,
                         data => cpu_mem_aximo.w.data,
                         strb => cpu_mem_aximo.w.strb,
                         last => cpu_mem_aximo.w.last,
                         valid => cpu_mem_aximo.w.valid);
      mem_aximo_sim.b <= cpu_mem_aximo.b;
      mem_aximo_sim.ar <= (id => cpu_mem_aximo.ar.id, 
                          addr => cpu_mem_aximo.ar.addr,
                          len => cpu_mem_aximo.ar.len(3 downto 0),
                          size => cpu_mem_aximo.ar.size,
                          burst => cpu_mem_aximo.ar.burst,
                          lock  => '0' & cpu_mem_aximo.ar.lock,
                          cache => cpu_mem_aximo.ar.cache,
                          prot => cpu_mem_aximo.ar.prot,
                          valid => cpu_mem_aximo.ar.valid);
      mem_aximo_sim.r <= cpu_mem_aximo.r;

      -- Debug monitor: the parallel-nowrap upload reads zeros for one 32B
      -- block of the embedded kernel array (CPU addr 0xDF020-0xDF03F,
      -- kernel offsets 0x6F0-0x70C). Report every CPU-port access touching
      -- 0xDF000-0xDF05F so one run shows whether the region was zeroed by
      -- a write (glue/aximem write-queue fault) or read back wrong.
      cpumon : process(clkm)
        -- match addr(31:8) = 0x000DF0 -> bytes 0xDF000-0xDF0FF
        constant MON_BLK : std_logic_vector(23 downto 0) := x"000DF0";
        variable rd_flag : boolean := false;
        variable wr_flag : boolean := false;
      begin
        if rising_edge(clkm) then
          if (mem_aximo_sim.aw.valid and cpu_mem_aximi.aw.ready) = '1' then
            if mem_aximo_sim.aw.addr(31 downto 8) = MON_BLK then
              report "CPUMON AW addr=" & tost(mem_aximo_sim.aw.addr)
                   & " id=" & tost(mem_aximo_sim.aw.id)
                   & " len=" & tost(mem_aximo_sim.aw.len);
              wr_flag := true;
            end if;
          end if;
          if wr_flag and (mem_aximo_sim.w.valid and cpu_mem_aximi.w.ready) = '1' then
            report "CPUMON  W data=" & tost(mem_aximo_sim.w.data)
                 & " strb=" & tost(mem_aximo_sim.w.strb)
                 & " id=" & tost(mem_aximo_sim.w.id)
                 & " last=" & tost(mem_aximo_sim.w.last);
            if mem_aximo_sim.w.last = '1' then
              wr_flag := false;
            end if;
          end if;
          if (mem_aximo_sim.ar.valid and cpu_mem_aximi.ar.ready) = '1' then
            if mem_aximo_sim.ar.addr(31 downto 8) = MON_BLK then
              report "CPUMON AR addr=" & tost(mem_aximo_sim.ar.addr)
                   & " id=" & tost(mem_aximo_sim.ar.id)
                   & " len=" & tost(mem_aximo_sim.ar.len);
              rd_flag := true;
            end if;
          end if;
          if rd_flag and (cpu_mem_aximi.r.valid and mem_aximo_sim.r.ready) = '1' then
            report "CPUMON  R data=" & tost(cpu_mem_aximi.r.data)
                 & " id=" & tost(cpu_mem_aximi.r.id)
                 & " last=" & tost(cpu_mem_aximi.r.last);
            if cpu_mem_aximi.r.last = '1' then
              rd_flag := false;
            end if;
          end if;
        end if;
      end process;
    end generate axi_mem_gen;

    ahb_mem_gen : if (CFG_L2_AXI = 0) generate
      mig_ahbram : ahbram_sim
      generic map (
                    hindex   => 0,
                    haddr    => L2C_HADDR,
                    hmask    => L2C_HMASK,
                    tech     => 0,
                    kbytes   => 1024,
                    pipe     => 0,
                    maccsz   => AHBDW,
                    fname    => ramfile)
      port map(
                rst     => rstn,
                clk     => clkm,
                ahbsi   => mem_ahbsi0,
                ahbso   => mem_ahbso0);
    end generate ahb_mem_gen;

    gpu_mem_gen : if (CFG_VX_EN = 1) generate
      gpu_axiram : aximem
      generic map (
                    fname   => ramfile,
                    axibits => AXIDW,
                    rstmode => 0)
      port map (
                 clk   => clkm,
                 rst   => gpu_rstn,
                 axisi => gpu_aximo_sim,
                 axiso => gpu_mem_aximi);

      -- Vortex tags back-to-back write-through stores with the same AXI ID and
      -- aximem matches W beats to AW entries by ID, so overlapping same-ID
      -- writes corrupt its write queue. Stamp each write with a unique local
      -- ID instead; Vortex ignores the B-channel ID so this is transparent.
      gpu_wr_id_gen : process(clkm)
      begin
        if rising_edge(clkm) then
          if gpu_rstn = '0' then
            gpu_wr_awdone <= '0';
            gpu_wr_wdone  <= '0';
            gpu_wr_id     <= (others => '0');
          else
            if ((gpu_wr_awdone or (gpu_aximo_sim.aw.valid and gpu_mem_aximi.aw.ready))
            and (gpu_wr_wdone  or (gpu_aximo_sim.w.valid  and gpu_mem_aximi.w.ready))) = '1' then
              gpu_wr_awdone <= '0';
              gpu_wr_wdone  <= '0';
              gpu_wr_id     <= gpu_wr_id + 1;
            else
              gpu_wr_awdone <= gpu_wr_awdone or (gpu_aximo_sim.aw.valid and gpu_mem_aximi.aw.ready);
              gpu_wr_wdone  <= gpu_wr_wdone  or (gpu_aximo_sim.w.valid  and gpu_mem_aximi.w.ready);
            end if;
          end if;
        end if;
      end process;

      gpu_aximo_sim.aw <= (id => gpu_wr_id,
                          addr => gpu_mem_aximo.aw.addr,
                          len => gpu_mem_aximo.aw.len(3 downto 0),
                          size => gpu_mem_aximo.aw.size,
                          burst => gpu_mem_aximo.aw.burst,
                          lock  => '0' & gpu_mem_aximo.aw.lock,
                          cache => gpu_mem_aximo.aw.cache,
                          prot => gpu_mem_aximo.aw.prot,
                          valid => gpu_mem_aximo.aw.valid);
      gpu_aximo_sim.w <= (id => gpu_wr_id,
                         data => gpu_mem_aximo.w.data,
                         strb => gpu_mem_aximo.w.strb,
                         last => gpu_mem_aximo.w.last,
                         valid => gpu_mem_aximo.w.valid);
      gpu_aximo_sim.b <= gpu_mem_aximo.b;
      gpu_aximo_sim.ar <= (id => gpu_mem_aximo.ar.id, 
                          addr => gpu_mem_aximo.ar.addr,
                          len => gpu_mem_aximo.ar.len(3 downto 0),
                          size => gpu_mem_aximo.ar.size,
                          burst => gpu_mem_aximo.ar.burst,
                          lock  => '0' & gpu_mem_aximo.ar.lock,
                          cache => gpu_mem_aximo.ar.cache,
                          prot => gpu_mem_aximo.ar.prot,
                          valid => gpu_mem_aximo.ar.valid);
      gpu_aximo_sim.r <= gpu_mem_aximo.r;
    end generate gpu_mem_gen;
  end generate sim_mem_gen;
  -- pragma translate_on

  -----------------------------------------------------------------------
  --  PROM
  -----------------------------------------------------------------------

  prom_gen : if (SIMULATION = 0) generate
    rom32 : if CFG_AHBDW = 32 generate
      brom : entity work.ahbrom
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
    rom64 : if CFG_AHBDW = 64 generate
      brom : entity work.ahbrom64
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
    rom128 : if CFG_AHBDW = 128 generate
      brom : entity work.ahbrom128
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi1,
          ahbso   => rom_ahbso1);
    end generate;
  end generate prom_gen;

  -- pragma translate_off
  sim_prom_gen : if (SIMULATION /= 0) generate
    mig_ahbram : ahbram_sim
      generic map (
        hindex   => 1,
        haddr    => ROM_HADDR,
        hmask    => ROM_HMASK,
        tech     => 0,
        kbytes   => 1024,
        pipe     => 0,
        maccsz   => AHBDW,
        fname    => romfile)
      port map(
        rst     => rstn,
        clk     => clkm,
        ahbsi   => rom_ahbsi1,
        ahbso   => rom_ahbso1);
  end generate sim_prom_gen;
  -- pragma translate_on

-----------------------------------------------------------------------
-- GPIO                                                                
-----------------------------------------------------------------------
--  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate
--
--    gpled_pads : for i in 0 to 3 generate
--      gpled_pad : outpad
--        generic map (tech => padtech, level => cmos, voltage => x18v)
--        port map (led(i), gpio_o(i+16));
--    end generate gpled_pads;
--
--    gpsw_pads : for i in 0 to 2 generate
--      gpsw_pad : inpad
--        generic map (tech => padtech, level => cmos, voltage => x12v)
--        port map (switch(i), gpio_i(i));
--    end generate gpsw_pads;
--    gpio_i(3) <= dsu_sel;
--
--    gpb_pads : for i in 0 to 3 generate
--      gpb_pad : inpad
--        generic map (tech => padtech, level => cmos, voltage => x12v)
--        port map (button(i), gpio_i(i+4));
--    end generate gpb_pads;
--
--    pio_pads : for i in 0 to 7 generate
--      gpio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x12v, strength => 8)
--        port map (gpio(i), gpio_o(i+8), gpio_oe(i+8), gpio_i(i+8));
--    end generate;
--
--  end generate;

-----------------------------------------------------------------------
-- ETHERNET PHY
-----------------------------------------------------------------------

  eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC

    eth_block : block
      signal sgmiii         : eth_sgmii_in_type; 
      signal sgmiio         : eth_sgmii_out_type;
      signal sgmiirst       : std_ulogic;
      signal clkout0o       : std_ulogic;
      signal clkout1o       : std_ulogic;
      signal clkout2o       : std_ulogic;
    begin
      sgmiirst <= not resetn;

      sgmii0 : sgmii_vcu118
        generic map (
          pindex          => GRETH_PHY_PINDEX,
          paddr           => GRETH_PHY_PADDR,
          pmask           => GRETH_PHY_PMASK,
          abits           => 8,
          autonegotiation => 1,
          pirq            => GRETH_PHY_PIRQ,
          debugmem        => 1,
          tech            => fabtech
        )
        port map (
          sgmiii   => sgmiii,
          sgmiio   => sgmiio,
          gmiii    => ethi,
          gmiio    => etho,
          reset    => sgmiirst,
          clkout0o => clkout0o,
          clkout1o => clkout1o,
          clkout2o => clkout2o,
          apb_clk  => clkm,
          apb_rstn => rstn,
          apbi     => eth_apbi,
          apbo     => eth_apbo
        );

      emdio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (emdio, sgmiio.mdio_o, sgmiio.mdio_oe, sgmiii.mdio_i);

      emdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (emdc, sgmiio.mdc);

      eint_pad : inpad generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (eint, sgmiii.mdint);

      erst_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
        port map (erst, sgmiio.reset);

      sgmiii.clkp <= gtrefclk_p;
      sgmiii.clkn <= gtrefclk_n;
      txp         <= sgmiio.txp;
      txn         <= sgmiio.txn;
      sgmiii.rxp  <= rxp;
      sgmiii.rxn  <= rxn;

    end block eth_block;
  end generate;

  noeth0 : if CFG_GRETH = 0 generate
    tx_outpad : outpad_ds
      generic map (padtech, hstl_i_18, x18v)
      port map (txp, txn, gnd, gnd);

    emdio_pad : iopad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (emdio, gnd, gnd, open);

    emdc_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (emdc, gnd);

    erst_pad : outpad generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (erst, gnd);

  end generate;

-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map(
      msg1    => "METASAT Platform",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
      );
-- pragma translate_on

end rtl;


