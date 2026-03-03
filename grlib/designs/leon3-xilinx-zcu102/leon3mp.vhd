-----------------------------------------------------------------------------
--  LEON3 Xilinx ZCU102 Demonstration design
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
--  Adapted from the KCU105 Demonstration design
--  Adapted by: Marc Solé Bonet
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library grlib, techmap;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;
use techmap.gencomp.all;
use techmap.allclkgen.all;

library gaisler;
use gaisler.memctrl.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.spi.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.i2c.all;
use gaisler.l2cache.all;
use gaisler.subsys.all;
use gaisler.axi.all;
use gaisler.spacewire.all;
use gaisler.leon3.all;
-- pragma translate_off
use gaisler.sim.all;

library unisim;
use unisim.all;
-- pragma translate_on

library testgrouppolito;
use testgrouppolito.dprc_pkg.all;

use work.config.all;

entity leon3mp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;   -- Enable disassembly to console
    dbguart                 : integer := CFG_DUART;   -- Print UART on console
    pclow                   : integer := CFG_PCLOW
  );
  port (
    -- Clock and Reset
    reset       : in    std_ulogic;
    clk300p     : in    std_ulogic;  -- 300 MHz clock
    clk300n     : in    std_ulogic;  -- 300 MHz clock
    -- UART
    dsurx       : in    std_ulogic;
    dsutx       : out   std_ulogic;
--    dsuctsn     : in    std_ulogic;
--    dsurtsn     : out   std_ulogic
    -- DDR4 (MIG)
    ddr4_dq     : inout std_logic_vector(15 downto 0);
    ddr4_dqs_c  : inout std_logic_vector(1 downto 0); -- Data Strobe
    ddr4_dqs_t  : inout std_logic_vector(1 downto 0); -- Data Strobe
    ddr4_addr   : out   std_logic_vector(13 downto 0);-- Address
    ddr4_ras_n  : out   std_ulogic;
    ddr4_cas_n  : out   std_ulogic;
    ddr4_we_n   : out   std_ulogic;
    ddr4_ba     : out   std_logic_vector(1 downto 0); -- Device bank address per group
    ddr4_bg     : out   std_logic_vector(0 downto 0); -- Device bank group address
    ddr4_dm_n   : inout std_logic_vector(1 downto 0); -- Data Mask
    ddr4_ck_c   : out   std_logic_vector(0 downto 0); -- Clock Negative Edge
    ddr4_ck_t   : out   std_logic_vector(0 downto 0); -- Clock Positive Edge
    ddr4_cke    : out   std_logic_vector(0 downto 0); -- Clock Enable
    ddr4_act_n  : out   std_ulogic;                   -- Command Input
    ddr4_odt    : out   std_logic_vector(0 downto 0); -- On-die Termination
    ddr4_par    : out   std_ulogic;                   -- Parity for cmd and addr
    ddr4_cs_n   : out   std_logic_vector(0 downto 0); -- Chip Select
    ddr4_reset_n: out   std_ulogic                    -- Asynchronous Reset
  );
end;


architecture rtl of leon3mp is
  -----------------------------------------------------
  -- AHB 2 MIG COMPONENT ------------------------------
  -----------------------------------------------------
  component ahb2axi_mig4_ultrascale
    generic (
      pipelined               : boolean := false;
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
  end component;

  -----------------------------------------------------
  -- Constants ----------------------------------------
  -----------------------------------------------------
  
  constant in_simulation : boolean := false
  --pragma translate_off
                                      or true
  --pragma translate_on
                                      ;
  constant in_synthesis : boolean := not in_simulation;


  -- AHB MASTERS
  constant hi_leon3     : integer := 0; -- In multicore systems ahb index of the first core
  constant hi_ahbuart   : integer := CFG_NCPU;

  -- AHB SLAVES
  constant hi_dsu       : integer := 0;
  constant hi_apbctrl   : integer := 1;
  constant hi_ahbram0   : integer := 2;
  constant hi_ahbrom0   : integer := 3+CFG_NRAM;
  constant hi_ahbrep0   : integer := 4+CFG_NRAM;
  
  constant maxahbm      : integer := CFG_NCPU+1;
  constant maxahbs      : integer := hi_ahbrep0+1;
  
  -- APB SLAVES
  constant pi_ahbuart   : integer := 0;
  constant pi_ahbstat   : integer := 1;
  constant pi_irqgen    : integer := 2;
  constant pi_apbuart   : integer := 3;
  constant pi_l3stat    : integer := 4; --takes 2
  constant pi_ahbmig    : integer := 6;
  constant pi_timer     : integer := 7;

  constant OEPOL        : integer := padoen_polarity(padtech);

  constant BOARD_FREQ   : integer := 300000; -- input frequency in KHz
  constant CPU_FREQ     : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV; -- cpu frequency in KHz

  constant ramfile      : string := "test.srec"; -- ram contents

  -----------------------------------------------------
  -- Signals ------------------------------------------
  -----------------------------------------------------

  signal irqi : irq_in_vector(0 to CFG_NCPU - 1);
  signal irqo : irq_out_vector(0 to CFG_NCPU - 1);

  signal dsui : dsu_in_type;
  signal dsuo : dsu_out_type;

  signal dbgi : l3_debug_in_vector(0 to CFG_NCPU-1);
  signal dbgo : l3_debug_out_vector(0 to CFG_NCPU-1);

  -- Misc
  signal stati          : ahbstat_in_type;
  signal calib_done     : std_logic;

  -- APB
  signal apbi           : apb_slv_in_type;
  signal apbo           : apb_slv_out_vector := (others => apb_none);

  -- AHB
  signal ahbsi          : ahb_slv_in_type;
  signal ahbso          : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi          : ahb_mst_in_type;
  signal ahbmo          : ahb_mst_out_vector := (others => ahbm_none);
  signal mig_ahbsi      : ahb_slv_in_type;
  signal mig_ahbso      : ahb_slv_out_type;

 -- Clocks and Reset
  signal clkm           : std_ulogic := '0';
  signal lock           : std_ulogic;
  signal lclk           : std_ulogic;
  signal migrstn        : std_ulogic;
  signal rst            : std_ulogic;
  signal rstn           : std_ulogic;
  signal rstraw         : std_ulogic;
  signal cgi            : clkgen_in_type;
  signal cgo            : clkgen_out_type;
  
  -- timer signal
  signal gpti : gptimer_in_type;


  attribute keep         : boolean;
  attribute keep of clkm : signal is true;

  -- APB UART
  signal u1i            : uart_in_type;
  signal u1o            : uart_out_type;

  -- AHB UART
  signal dui            : uart_in_type;
  signal duo            : uart_out_type;

component clk_wiz_0 is  
  port(
    clk_out1  : out std_logic;
    clk_in1_p : in  std_logic;
    clk_in1_n : in  std_logic
  );
  end component;
begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------
  
--  clk_gen : if (CFG_MIG_ULTRASCALE = 0) generate
--    -- clock generator
--    clkgen0 : clk_wiz_0
--      port map (clk_out1 => clkm, clk_in1_p => clk300p, clk_in1_n => clk300n);
--  end generate;

  clk_gen : if (CFG_MIG_ULTRASCALE = 0) generate
    clk_pad_ds : clkpad_ds generic map (
      tech      => padtech,
      level     => sstl12_dci,
      voltage   => x12v)
      port map (clk300p, clk300n, lclk);
    clkgen0 : clkgen        -- clock generator
      generic map (clktech, CFG_CLKMUL, CFG_CLKDIV, 0,
                   0, 0, 0, 0, BOARD_FREQ)
      port map (lclk, lclk, clkm, open, open, open, open, cgi, cgo, open, open, open);
  end generate;

  reset_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x18v)
    port map (reset, rst);

  rst0 : rstgen generic map (acthigh => 1, syncin => 0)
    port map (rst, clkm, lock, rstn, rstraw);
  lock <= calib_done when CFG_MIG_ULTRASCALE = 1 else cgo.clklock;
  
  rst1 : rstgen  generic map (acthigh => 1)
        port map (rst, clkm, lock, migrstn, open);


  cgi.pllctrl <= "00";
  cgi.pllrst <= rstraw;

  ----------------------------------------------------------------------
  ---  LEDs and BUTTONs ------------------------------------------------
  ----------------------------------------------------------------------
    -- DISABLED 


  ----------------------------------------------------------------------
  ---  AHB & APB CONTROLLER --------------------------------------------
  ----------------------------------------------------------------------

  ahb0 : ahbctrl  -- AHB arbiter/multiplexer
    generic map (defmast => CFG_DEFMST, split => CFG_SPLIT,
                 rrobin  => CFG_RROBIN, ioaddr => CFG_AHBIO, fpnpen => CFG_FPNPEN,
                 nahbm   => maxahbm, nahbs => maxahbs)
    port map (
      rst  => rstn,
      clk  => clkm,
      msti => ahbmi,
      msto => ahbmo,  -- Incoming accesses
      slvi => ahbsi,  -- Outgoing accesses
      slvo => ahbso
    );

  apb0 : apbctrl
    generic map (hindex => hi_apbctrl, haddr => CFG_APBADDR, nslaves => 16)
    port map (rstn, clkm, ahbsi, ahbso(hi_apbctrl), apbi, apbo);

  -----------------------------------------------------------------------------
  -- AHB & APB UART -----------------------------------------------------------
  -----------------------------------------------------------------------------
  duart_gen: if (CFG_AHB_UART=1) generate
      duart : ahbuart
        generic map (hindex => hi_ahbuart,  pindex => pi_ahbuart, paddr => pi_ahbuart)
        port map (rstn, clkm, dui, duo, apbi, apbo(pi_ahbuart), ahbmi, ahbmo(hi_ahbuart));
  end generate duart_gen;
  dui.rxd    <= dsurx;      -- AHB input data
  dsutx      <= duo.txd;    -- AHB output 
  -- dui.ctsn   <= dsuctsn; 
  --dsurtsn    <= duo.rtsn;

  uart_gen: if (CFG_UART1_ENABLE = 1) generate
      uart1 : apbuart
        generic map (pindex   => pi_apbuart, paddr => pi_apbuart, pirq => 2, console => dbguart,
                     fifosize => CFG_UART1_FIFO)
        port map (rstn, clkm, apbi, apbo(pi_apbuart), u1i, u1o);
  end generate uart_gen;
  u1i.rxd    <= u1o.txd;
  u1i.ctsn   <= '0';
  u1i.extclk <= '0';

  -----------------------------------------------------------------------
  --- TIMER -------------------------------------------------------------
  -----------------------------------------------------------------------
  timer0 : gptimer     -- Time Unit
    generic map (pindex => pi_timer, paddr => pi_timer, pirq => 8,
                 sepirq => 1, ntimers => 2)
    port map (rstn, clkm, apbi, apbo(pi_timer), gpti, open);
    gpti <= gpti_dhalt_drive(dsuo.tstop);

  -----------------------------------------------------------------------
  --- AHB RAM -----------------------------------------------------------
  -----------------------------------------------------------------------
  no_mig_gen: if (CFG_MIG_ULTRASCALE = 0) generate
    ram: if in_synthesis = true generate -- synthesis ram
      bank: for i in 0 to CFG_NRAM-1 generate
          ahbram0 : ahbram
            generic map (hindex => hi_ahbram0+i,
                         haddr => 16#400#+i,
                         tech => CFG_MEMTECH,
                         kbytes => 1024,
                         pipe => 0)
            port map (rstn, clkm, ahbsi, ahbso(hi_ahbram0+i));
        end generate;
    end generate;
    
    sim_ram: if in_simulation = true generate -- simulation ram
      --pragma translate_off
      ahbram0 : ahbram_sim
        generic map (hindex => hi_ahbram0,
                     haddr => 16#400#,
                     hmask => 16#f00#,
                     tech => 0,
                     kbytes => 1024,
                     pipe => 0,
                     endianness => 0,
                     fname => ramfile)
        port map (rstn, clkm, ahbsi, ahbso(hi_ahbram0));
        clkm <= not clkm after 5.0 ns;
     --pragma translate_on
    end generate;

    -- Tie-Off DDR4 Signals
    ddr4_addr       <= (others => '0');
    ddr4_we_n       <= '0';
    ddr4_cas_n      <= '0';
    ddr4_ras_n      <= '0';
    ddr4_ba         <= (others => '0');
    ddr4_cke        <= (others => '0');
    ddr4_cs_n       <= (others => '0');
    ddr4_dm_n       <= (others => 'Z');
    ddr4_dq         <= (others => 'Z');
    ddr4_dqs_c      <= (others => 'Z');
    ddr4_dqs_t      <= (others => 'Z');
    ddr4_odt        <= (others => '0');
    ddr4_bg         <= (others => '0');
    ddr4_reset_n    <= '1';
    ddr4_act_n      <= '1';

    ddr4_ck_outpad : outpad_ds
        generic map (tech => padtech, level => sstl12_dci, voltage => x12v, slew => 1)
        port map (ddr4_ck_t(0), ddr4_ck_c(0), '0', '0');


    calib_done <= '1';
    
  end generate no_mig_gen;
    
  -----------------------------------------------------------------------
  ---  AHB MIG ----------------------------------------------------------
  -----------------------------------------------------------------------
  mig_gen : if (CFG_MIG_ULTRASCALE = 1) generate
        gen_mig : if in_synthesis = true generate --synthesis mig    
        ddrc : ahb2axi_mig4_ultrascale generic map (
          hindex => hi_ahbram0, haddr => 16#400#, hmask => 16#F00#,
          pindex => pi_ahbmig, paddr => pi_ahbmig
          )
          port map (
            calib_done      => calib_done,
            sys_clk_p       => clk300p,
            sys_clk_n       => clk300n,
            ddr4_addr       => ddr4_addr,
            ddr4_we_n       => ddr4_we_n,
            ddr4_cas_n      => ddr4_cas_n,
            ddr4_ras_n      => ddr4_ras_n,
            ddr4_ba         => ddr4_ba,
            ddr4_cke        => ddr4_cke,
            ddr4_cs_n       => ddr4_cs_n,
            ddr4_dm_n       => ddr4_dm_n,
            ddr4_dq         => ddr4_dq,
            ddr4_dqs_c      => ddr4_dqs_c,
            ddr4_dqs_t      => ddr4_dqs_t,
            ddr4_odt        => ddr4_odt,
            ddr4_bg         => ddr4_bg,
            ddr4_reset_n    => ddr4_reset_n,
            ddr4_act_n      => ddr4_act_n,
            ddr4_ck_c       => ddr4_ck_c,
            ddr4_ck_t       => ddr4_ck_t,
            ddr4_ui_clk     => open,
            ddr4_ui_clk_sync_rst => open,
            rst_n_syn       => migrstn,
            rst_n_async     => rstraw,
            ahbsi           => ahbsi,
            ahbso           => ahbso(hi_ahbram0),
            apbi            => apbi,
            apbo            => apbo(pi_ahbmig),
            clk_amba        => clkm,
            -- Misc
            ddr4_ui_clkout1 => clkm,
            clk_ref_i       => '0'
          );
    end generate gen_mig;
    
    sim_mig: if in_simulation = true generate --simulate ahbram instead
    -- pragma translate_off
      ahbram0 : ahbram_sim
        generic map (hindex => hi_ahbram0,
                     haddr => 16#400#,
                     hmask => 16#f00#,
                     tech => 0,
                     kbytes => 1024,
                     pipe => 0,
                     endianness => 0,
                     fname => ramfile)
        port map (rstn, clkm, ahbsi, ahbso(hi_ahbram0));

        -- Tie-Off DDR4 Signals
        ddr4_addr       <= (others => '0');
        ddr4_we_n       <= '0';
        ddr4_cas_n      <= '0';
        ddr4_ras_n      <= '0';
        ddr4_ba         <= (others => '0');
        ddr4_cke        <= (others => '0');
        ddr4_cs_n       <= (others => '0');
        ddr4_dm_n       <= (others => 'Z');
        ddr4_dq         <= (others => 'Z');
        ddr4_dqs_c      <= (others => 'Z');
        ddr4_dqs_t      <= (others => 'Z');
        ddr4_odt        <= (others => '0');
        ddr4_bg         <= (others => '0');
        ddr4_reset_n    <= '1';
        ddr4_act_n      <= '1';
        calib_done <= '1';
        clkm <= not clkm after 5.0 ns;
    --pragma translate_on
    end generate sim_mig;

  end generate mig_gen;
  
  ddr4_par <= '0';


  -----------------------------------------------------------------------
  ---  AHB ROM ----------------------------------------------------------
  -----------------------------------------------------------------------
  brom_gen: if (CFG_AHBROMEN = 1) generate
      brom : entity work.ahbrom
        generic map (hindex => hi_ahbrom0, haddr => CFG_AHBRODDR, pipe => CFG_AHBROPIP)
        port map (rstn, clkm, ahbsi, ahbso(hi_ahbrom0));
  end generate brom_gen;
  ----------------------------------------------------------------------
  --- INTERRUPT CONTROLLER ---------------------------------------------
  ----------------------------------------------------------------------
  irq_gen: if (CFG_IRQ3_ENABLE = 1) generate
      irqctrl0 : irqmp                      -- interrupt controller
        generic map (pindex => pi_irqgen, paddr => pi_irqgen, ncpu => CFG_NCPU)
        port map (rstn, clkm, apbi, apbo(pi_irqgen), irqo, irqi);
  end generate irq_gen;
  -----------------------------------------------------------------------
  ---  AHB Status Register ----------------------------------------------
  -----------------------------------------------------------------------
  stat_gen: if (CFG_AHBSTAT=1) generate  
      stati <= ahbstat_in_none;
      ahbstat0 : ahbstat
        generic map (pindex => pi_ahbstat, paddr => pi_ahbstat, pirq => 7,
                     nftslv => CFG_AHBSTATN)
        port map(rstn, clkm, ahbmi, ahbsi, stati, apbi, apbo(pi_ahbstat));
  end generate stat_gen;
  ----------------------------------------------------------------------
  ---  L3STAT ----------------------------------------------------------
  ----------------------------------------------------------------------
  l3stat_gen: if (CFG_STAT_ENABLE=1) generate
      l3stat0 : l3stat
      generic map (pindex => pi_l3stat, paddr => pi_l3stat , pmask => 16#FFE#, ncnt => CFG_STAT_CNT, ncpu => CFG_NCPU, 
                   nmax => CFG_STAT_NMAX, lahben => 1, dsuen => CFG_DSU, nextev=>0)
      port map (rstn => rstn, clk => clkm, apbi => apbi, apbo => apbo(pi_l3stat), ahbsi => ahbsi, dbgo => dbgo, dsuo => dsuo);
  end generate l3stat_gen;

  ----------------------------------------------------------------------
  ---  LEON3 processor and DSU -----------------------------------------
  ----------------------------------------------------------------------
    leon3 : for i in 0 to CFG_NCPU-1 generate
      u0 : leon3s                       -- LEON3 processor
        generic map (
          hindex      => hi_leon3+i,
          fabtech     => fabtech,      memtech     => memtech,
          nwindows    => CFG_NWIN,
          dsu         => CFG_DSU,
          fpu         => CFG_FPU,
          v8          => CFG_V8,
          cp          => 0,
          mac         => CFG_MAC,
          pclow       => pclow,
          notag       => 0,
          nwp         => CFG_NWP,
          icen        => CFG_ICEN,      irepl       => CFG_IREPL,      isets       => CFG_ISETS,
          ilinesize   => CFG_ILINE,     isetsize    => CFG_ISETSZ,     isetlock    => CFG_ILOCK,
          dcen        => CFG_DCEN,      drepl       => CFG_DREPL,      dsets       => CFG_DSETS,
          dlinesize   => CFG_DLINE,     dsetsize    => CFG_DSETSZ,     dsetlock    => CFG_DLOCK,
          dsnoop      => CFG_DSNOOP,
          ilram       => CFG_ILRAMEN,   ilramsize   => CFG_ILRAMSZ,    ilramstart  => CFG_ILRAMADDR,
          dlram       => CFG_DLRAMEN,   dlramsize   => CFG_DLRAMSZ,    dlramstart  => CFG_DLRAMADDR,
          mmuen       => CFG_MMUEN,
          itlbnum     => CFG_ITLBNUM,   dtlbnum     => CFG_DTLBNUM,
          tlb_type    => CFG_TLB_TYPE,  tlb_rep     => CFG_TLB_REP,
          lddel       => CFG_LDDEL,
          disas       => disas,
          tbuf        => CFG_ITBSZ,
          pwd         => CFG_PWD,
          svt         => CFG_SVT,
          rstaddr     => CFG_RSTADDR,
          smp         => CFG_NCPU-1,
          cached      => CFG_DFIXED,
          scantest    => CFG_SCAN,
          mmupgsz     => CFG_MMU_PAGE,
          bp          => 1,
          npasi       => CFG_NP_ASI,
          pwrpsr      => CFG_WRPSR)
        port map (clkm, rstn, ahbmi, ahbmo(hi_leon3+i), ahbsi, ahbso,
                  irqi(i), irqo(i), dbgi(i), dbgo(i));
    end generate;
 
  dsugen : if CFG_DSU = 1 generate
    dsu0 : dsu3                         -- LEON3 Debug Support Unit
      generic map (hindex => hi_dsu, haddr => 16#900#, hmask => 16#F00#,
                   ncpu   => CFG_NCPU, tbits => 30, tech => memtech, irq => 0, kbytes => CFG_ATBSZ)
      port map (rstn, clkm, ahbmi, ahbsi, ahbso(hi_dsu), dbgo, dbgi, dsui, dsuo);
    dsui.enable <= '1';
  --dsui.break <= gpioi.din(0);
  end generate;

  nodsu : if CFG_DSU = 0 generate
    dsuo.tstop <= '0'; dsuo.active <= '0'; ahbso(hi_dsu) <= ahbs_none;
  end generate;
  -----------------------------------------------------------------------
  ---  Test report module  ----------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  test0 : ahbrep
    generic map (hindex => hi_ahbrep0, haddr => 16#200#)
    port map (rstn, clkm, ahbsi, ahbso(hi_ahbrep0));
  -- pragma translate_on

  -----------------------------------------------------------------------
  ---  Boot message  ----------------------------------------------------
  -----------------------------------------------------------------------

  -- pragma translate_off
  x : report_design
    generic map (
      msg1    => "LEON3/GRLIB Xilinx ZCU102 Demonstration design",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel    => 1
    );
-- pragma translate_on

 end;
