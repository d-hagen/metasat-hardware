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
use gaisler.l2c_lite.all;
use gaisler.noelv.all;

library vortex;
use vortex.libvx.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;
use work.config_local.all;
use work.rev.REVISION;
use work.cfgmap.all;

entity metasatcore is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    cpu_freq                : integer := 10000;
    devid                   : integer := NOELV_SOC;
    disas                   : integer := CFG_LOCAL_DISAS     -- Enable disassembly to console
    );
  port (
    -- Clock & reset
    clkm        : in  std_ulogic;
    resetn      : in  std_ulogic;
    lock        : in  std_ulogic;
    rstno       : out std_ulogic;
    -- misc
    dmen        : in  std_ulogic;
    dmbreak     : in  std_ulogic;
    dmreset     : out std_ulogic;
    cpu0errn    : out std_ulogic;
    -- GPIO
    --gpio_i      : in  std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
    --gpio_o      : out std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
    --gpio_oe     : out std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
    -- UART
    uart_rx     : in  std_logic_vector(0 downto 0);
    uart_ctsn   : in  std_logic_vector(0 downto 0);
    uart_tx     : out std_logic_vector(0 downto 0);
    uart_rtsn   : out std_logic_vector(0 downto 0);
    -- Memory controller
    cpu_mem_aximi   : in  axi_somi_type;
    cpu_mem_aximo   : out axi4_mosi_type;
    gpu_mem_reset   : out std_logic;
    gpu_mem_aximi   : in  axi_somi_type;
    gpu_mem_aximo   : out axi4_mosi_type;
    mem_ahbsi0  : out ahb_slv_in_type;
    mem_ahbso0  : in  ahb_slv_out_type;
    mem_apbi0   : out apb_slv_in_type;
    mem_apbo0   : in  apb_slv_out_type;
    -- PROM controller
    rom_ahbsi1  : out ahb_slv_in_type;
    rom_ahbso1  : in  ahb_slv_out_type;
    -- Ethernet PHY
    ethi        : in  eth_in_type;
    etho        : out eth_out_type;
    eth_apbi    : out apb_slv_in_type;
    eth_apbo    : in  apb_slv_out_type;
    -- Debug UART
    duart_rx    : in  std_ulogic;
    duart_tx    : out std_ulogic;
    -- UART RS-485
    uart485_i   : in uart_in_vector_type(1 downto 0);
    uart485_o   : out uart_out_vector_type(1 downto 0);
    -- Debug JTAG
    trst        : in std_ulogic := '1';
    tck         : in std_ulogic;
    tms         : in std_ulogic;
    tdi         : in std_ulogic;
    tdo         : out std_ulogic
  );
end;

architecture rtl of metasatcore is
  
  -- Constants ------------------------
  
  constant ncpu     : integer := CFG_LOCAL_NCPU;

  constant nextmst  : integer := 1;

  constant nextslv  : integer := 4;


  constant GPU_RAMADDR      : integer := GPU_RAMADDR_SYN
-- pragma translate_off
  - GPU_RAMADDR_SYN + GPU_RAMADDR_SIM
-- pragma translate_on
  ;
  constant GPU_RAMSIZE      : integer := GPU_RAMSIZE_SYN
-- pragma translate_off
  - GPU_RAMSIZE_SYN + GPU_RAMSIZE_SIM
-- pragma translate_on
  ;

  constant ndbgmst  : integer := 3 + CFG_LOCAL_AHB_JTAG_RV ;

  constant mig_hconfig : ahb_config_type := (
    0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_MIG_7SERIES, 0, 0, 0),
    4 => ahb_membar(L2C_HADDR, '1', '1', L2C_HMASK),
    others => zero32);
  
  -- Signals --------------------------

  -- Misc
  signal vcc        : std_ulogic;
  signal gnd        : std_ulogic;
  signal rstn       : std_ulogic;
  signal reset      : std_ulogic;
  signal rstnraw    : std_logic;
  signal stati      : ahbstat_in_type;

  -- APB
  signal apbi       : apb_slv_in_type;
  signal apbo       : apb_slv_out_vector := (others => apb_none);

  -- AHB
  signal ahbsi      : ahb_slv_in_type;
  signal ahbso      : ahb_slv_out_vector := (others => ahbs_none);
  signal ahbmi      : ahb_mst_in_type;
  signal ahbmo      : ahb_mst_out_vector := (others => ahbm_none);
  signal dbgmi      : ahb_mst_in_vector_type(ndbgmst-1 downto 0);
  signal dbgmo      : ahb_mst_out_vector_type(ndbgmst-1 downto 0);
  -- AHB memory bus
  signal mem_ahbsi  : ahb_slv_in_type;
  signal mem_ahbso  : ahb_slv_out_vector := (others => ahbs_none);
  signal mem_ahbmi  : ahb_mst_in_type;
  signal mem_ahbmo  : ahb_mst_out_vector := (others => ahbm_none);

  -- AXI GPU <-> CPU
  signal gpu_ctrl_aximi     : axi_somi_type;
  signal gpu_ctrl_aximo     : axi_mosi_type;

  -- GPU interrupt signal
  signal gpu_interrupt      : std_logic;
  
  -- Memory
  signal u1i, dui   : uart_in_type;
  signal u1o, duo   : uart_out_type;

  -- GPIOs
  --signal gpioi      : gpio_in_type;
  --signal gpioo      : gpio_out_type;

  -- Ethernet
  signal ethi_int   : eth_in_type;

  
  -- Attributes -----------------------
  attribute keep                     : boolean;
  attribute syn_keep                 : boolean;
  attribute syn_preserve             : boolean;
  attribute syn_keep of lock         : signal is true;
  attribute syn_keep of clkm         : signal is true;
  attribute syn_preserve of clkm     : signal is true;
  attribute keep of lock             : signal is true;
  attribute keep of clkm             : signal is true;

begin
  vcc         <= '1';
  gnd         <= '0';

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------

  rst0 : rstgen
    generic map(acthigh => 0)
    port map (resetn, clkm, lock, rstn, rstnraw);

    rstno <= rstn;
    reset <= not rstn;

  ----------------------------------------------------------------------
  ---  NOEL-V SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  cpusys : noelvsys 
    generic map (
      fabtech   => fabtech,
      memtech   => memtech,
      ncpu      => ncpu,
      nextmst   => nextmst,
      nextslv   => nextslv,
      nextapb   => 9,
      ndbgmst   => ndbgmst,
      cached    => 0,
      wbmask    => CFG_LOCAL_WBMASK,
      busw      => AHBDW,
      cmemconf  => CFG_LOCAL_CMEMCONF,
      fpuconf   => CFG_LOCAL_FPUCONF,
      rfconf    => CFG_LOCAL_RFCONF,
      --tcmconf   => CFG_LOCAL_TCMCONF,
      mulconf   => CFG_LOCAL_MULCONF,
      disas     => disas,
      ahbtrace  => 0,
      cfg       => CFG_LOCAL_CFG,
      devid     => devid,
      nodbus    => CFG_LOCAL_NODBUS
      )
    port map(
      clk       => clkm, -- : in  std_ulogic;
      rstn      => rstn, -- : in  std_ulogic;
      -- AHB bus interface for other masters (DMA units)
      ahbmi     => ahbmi, -- : out ahb_mst_in_type;
      ahbmo     => ahbmo(ncpu+nextmst-1 downto ncpu), -- : in  ahb_mst_out_vector_type(ncpu+nextmst-1 downto ncpu);
      -- AHB bus interface for slaves (memory controllers, etc)
      ahbsi     => ahbsi, -- : out ahb_slv_in_type;
      ahbso     => ahbso(nextslv-1 downto 0), -- : in  ahb_slv_out_vector_type(nextslv-1 downto 0);
      -- AHB master interface for debug links
      dbgmi     => dbgmi, -- : out ahb_mst_in_vector_type(ndbgmst-1 downto 0);
      dbgmo     => dbgmo, -- : in  ahb_mst_out_vector_type(ndbgmst-1 downto 0);
      -- APB interface for external APB slaves
      apbi      => apbi, -- : out apb_slv_in_type;
      apbo      => apbo, -- : in  apb_slv_out_vector;
      -- Bootstrap signals
      dsuen     => dmen, -- : in  std_ulogic;
      dsubreak  => dmbreak, -- : in  std_ulogic;
      cpu0errn  => cpu0errn, -- : out std_ulogic;
      --dmreset   => dmreset, 
      -- UART connection
      uarti     => u1i, -- : in  uart_in_type;
      uarto     => u1o  -- : out uart_out_type
      );
  
    uart_rtsn(0)  <= u1o.rtsn;
    uart_tx(0)    <= u1o.txd;
    u1i.ctsn      <= uart_ctsn(0);
    u1i.rxd       <= uart_rx(0);

  -----------------------------------------------------------------------------
  -- Debug UART ---------------------------------------------------------------
  -----------------------------------------------------------------------------
  
  dcomgen : if CFG_AHB_UART = 1 generate
    dcom0 : ahbuart
      generic map(
        hindex => UART_DM_HMINDEX,
        pindex => AHBUART_PINDEX,
        paddr => AHBUART_PADDR,
        pmask => AHBUART_PMASK)
      port map(
        rstn,
        clkm,
        dui,
        duo,
        apbi,
        apbo(AHBUART_PINDEX),
        dbgmi(UART_DM_HMINDEX),
        dbgmo(UART_DM_HMINDEX));
    dui.extclk <= '0';
  end generate;

  nouah : if CFG_AHB_UART = 0 generate
    apbo(1)    <= apb_none;
    duo.txd    <= '0';
    duo.rtsn   <= '0';
    dui.extclk <= '0';
  end generate;

  dui.rxd   <= duart_rx; -- AHB input data
  duart_tx  <= duo.txd;  -- AHB output data

----------------------------------------------------------------------
---  RS-485 UARTs  ---------------------------------------------------
----------------------------------------------------------------------
  rs485_en : if (CFG_APB_UART /= 0) generate
    rs485_loop : for i in 0 to 1 generate
      rs485_apbuart : apbuart
        generic map (
          pindex   => APBUART_PINDEX+i,
          paddr    => APBUART_PADDR + i * 16#100#, --16#E00#,
          pmask    => APBUART_PMASK, --16#FFF#,
          console  => CFG_DUART,
          pirq     => APBUART_PIRQ+i,
          parity   => 1,
          flow     => 0,
          fifosize => 1, 
          abits    => 8,
          sbits    => 12)
        port map (
          rst   => rstn,
          clk   => clkm,
          apbi  => apbi,
          apbo  => apbo(APBUART_PINDEX+i),
          uarti => uart485_i(i),
          uarto => uart485_o(i));
    end generate;
  end generate;

  nouap : if CFG_APB_UART = 0 generate
    apbo(APBUART_PINDEX) <= apb_none;
    apbo(APBUART_PINDEX+1) <= apb_none;
  end generate;

  -----------------------------------------------------------------------------
  -- JTAG debug link ----------------------------------------------------------
  -----------------------------------------------------------------------------
  
  ahbjtaggen0 : if CFG_AHB_JTAG = 1 generate
    ahbjtag0 : ahbjtag
      generic map(
        tech    => fabtech,
        nsync   => CFG_LOCAL_JTAG_NSYNC,
        versel  => CFG_LOCAL_JTAG_VERSEL,
        hindex  => JTAG_DM_HMINDEX,
        ainst   => CFG_LOCAL_JTAG_AINST,
        dinst   => CFG_LOCAL_JTAG_DINST)
      port map(rstn, clkm, tck, tms, tdi, tdo,
               dbgmi(JTAG_DM_HMINDEX), dbgmo(JTAG_DM_HMINDEX),
               open, open, open, open, open, open, open, gnd, trst, open,
               gnd, open, open, open);
  end generate;


  -----------------------------------------------------------------------------
  -- Memory Controller (AXI or (hindex = 0 abd pindex = 0)) -------------------
  -----------------------------------------------------------------------------

  axi_gen : if (CFG_L2_AXI = 1) generate
    gen_l2c : if CFG_L2_EN /= 0 generate
      l2c0 : l2c_lite_axi4
        generic map (
          tech 	    => memtech,
          hsindex   => L2C_HSINDEX,
          ways	    => CFG_L2_WAYS,
          waysize   => CFG_L2_SIZE,
          linesize  => CFG_L2_LSZ,
          repl      => CFG_L2_REPL,
          haddr     => L2C_HADDR,
          hmask     => L2C_HMASK,
          ioaddr    => L2C_IOADDR,
	  cached    => CFG_L2_MAP,
          be_dw     => CFG_AHBDW)
        port map(
          rstn   => rstn,
          clk   => clkm,
          ahbsi => ahbsi,
          ahbso => ahbso(L2C_HSINDEX),
          aximi => cpu_mem_aximi,
          aximo => cpu_mem_aximo);
    end generate;
    nogen_l2c : if CFG_L2_EN = 0 generate
      bridge: ahb2axi4b
        generic map (
          hindex          => L2C_HSINDEX,
          aximid          => 0,
          wbuffer_num     => 8,
          rprefetch_num   => 8,
          endianness_mode => 0,
          narrow_acc_mode => 0,
          vendor          => VENDOR_GAISLER,
          device          => GAISLER_MIG_7SERIES,
          bar0            => ahb2ahb_membar(L2C_HADDR, '1', '1', L2C_HMASK)
          )
        port map (
          rstn  => rstn,
          clk   => clkm,
          ahbsi => ahbsi,
          ahbso => ahbso(L2C_HSINDEX),
          aximi => cpu_mem_aximi,
          aximo => cpu_mem_aximo);
    end generate;
    
    mem_ahbsi0  <= ahbs_in_none;
    mem_apbi0   <= apb_slv_in_none;
    -- No APB interface on memory controller  
    apbo(MEM_PINDEX)  <= apb_none;
  end generate;
  noaxi_gen : if (CFG_L2_AXI = 0) generate
    gen_l2c : if CFG_L2_EN /= 0 generate
      l2c0 : l2c_lite_ahb
        generic map (
          tech 	    => memtech,
          hsindex   => L2C_HSINDEX,
          ways	    => CFG_L2_WAYS,
          waysize   => CFG_L2_SIZE,
          linesize  => CFG_L2_LSZ,
          repl      => CFG_L2_REPL,
          haddr     => L2C_HADDR,
          hmask     => L2C_HMASK,
          ioaddr    => L2C_IOADDR,
	  cached    => CFG_L2_MAP,
          be_dw     => CFG_AHBDW)
        port map(
          rstn    => rstn,
          clk     => clkm,
          ahbsi   => ahbsi,
          ahbso   => ahbso(L2C_HSINDEX),
          ahbmi   => mem_ahbmi,
          ahbmo   => mem_ahbmo(0));
      
      ahb_men : ahbctrl                -- AHB arbiter/multiplexer
        generic map (
          defmast => CFG_DEFMST,
          split   => CFG_SPLIT, 
          rrobin  => CFG_RROBIN,
          ioaddr  => 16#FFD#,
          ioen    => 1,
          nahbm   => 1, nahbs => 1,
          fpnpen  => CFG_FPNPEN,
          ahbendian => 0)
        port map (
          rstn,
          clkm,
          mem_ahbmi,
          mem_ahbmo,
          mem_ahbsi,
          mem_ahbso);
      
      mem_ahbmo(NAHBMST-1 downto 1) <= (others => ahbm_none);
      mem_ahbso(NAHBMST-1 downto 1) <= (others => ahbs_none);
      mem_ahbsi0              <= mem_ahbsi;
      mem_ahbso(MEM_HSINDEX)  <= mem_ahbso0;
    end generate;
    nogen_l2c : if CFG_L2_EN = 0 generate
      mem_ahbsi0          <= ahbsi;
      ahbso(L2C_HSINDEX)  <= mem_ahbso0;
    end generate;
    mem_apbi0         <= apbi;
    apbo(MEM_PINDEX)  <= mem_apbo0;
  end generate;

  -----------------------------------------------------------------------
  ---  AHB ROM (slave hindex = 1)
  -----------------------------------------------------------------------
      rom_ahbsi1          <= ahbsi;
      ahbso(ROM_HSINDEX)  <= rom_ahbso1;

  ----------------------------------------------------------------------
  --- APB Bridge and various periherals --------------------------------
  ----------------------------------------------------------------------

  --  AHB Status Register
  ahbs : if CFG_AHBSTAT = 1 generate  
    stati <= ahbstat_in_none;
    ahbstat0 : ahbstat
      generic map(
        pindex  => AHBSTAT_PINDEX,
        paddr   => AHBSTAT_PADDR,
        pmask   => AHBSTAT_PMASK,
        pirq    => AHBSTAT_PIRQ,
        nftslv  => CFG_AHBSTATN)
      port map(
        rstn,
        clkm,
        ahbmi,
        ahbsi,
        stati,
        apbi,
        apbo(AHBSTAT_PINDEX));
  end generate;

  -- GPIO units
  --gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate

  --  grgpio_ledsw : grgpio
  --    generic map(
  --      pindex  => GRGPIO_PINDEX,
  --      paddr   => GRGPIO_PADDR,
  --      pmask   => GRGPIO_PMASK,
  --      imask   => CFG_GRGPIO_IMASK,
  --      nbits   => CFG_GRGPIO_WIDTH)
  --    port map(
  --      rst   => rstn,
  --      clk   => clkm,
  --      apbi  => apbi,
  --      apbo  => apbo(GRGPIO_PINDEX),
  --      gpioi => gpioi,
  --      gpioo => gpioo);

  --  -- Tie-off alternative output enable signals
  --  gpioi.sig_en        <= (others => '0');
  --  gpioi.sig_in        <= (others => '0');

  --  gpio_o  <= gpioo.dout(CFG_GRGPIO_WIDTH-1 downto 0);
  --  gpio_oe <= gpioo.oen(CFG_GRGPIO_WIDTH-1 downto 0);
  --  gpioi.din(CFG_GRGPIO_WIDTH-1 downto 0)  <= gpio_i;
  --end generate;

  -- Version
  grver0 : grversion
    generic map(
      pindex      => GRVER_PINDEX,
      paddr       => GRVER_PADDR,
      pmask       => GRVER_PMASK,
      versionnr   => CFG_LOCAL_CFG,
      revisionnr  => REVISION)
    port map(
      rstn  => rstn,
      clk   => clkm,
      apbi  => apbi,
      apbo  => apbo(GRVER_PINDEX));

-----------------------------------------------------------------------
---  GPU SYS -------------------------------------------------------------------
-----------------------------------------------------------------------
    gpusys : if CFG_VX_EN = 1 generate
        vortex : Vortex_if
          port map(
            clk   => clkm, --in
            reset => reset, --in
            ctrl_aximi => gpu_ctrl_aximi,  --out
            ctrl_aximo => gpu_ctrl_aximo, --in
            mem_aximi  => gpu_mem_aximi, --in
            mem_aximo  => gpu_mem_aximo, --out
            interrupt  => gpu_interrupt);  --out

        gpu_mem_reset <= '0';

        ahb2axi: ahb2axi_l
          generic map (
            hindex    => GPU_HSINDEX,
            aximid    => 0,
            axisecure => true,
            scantest  => 0,
            vendor    => VENDOR_GAISLER,
            device    => GAISLER_AHB2AXI,
            bar0      => ahb2ahb_iobar(GPU_IOADDR, GPU_IOMASK)
          )
          port map (
            rst   => rstn,
            clk   => clkm,
            ahbsi => ahbsi,
            ahbso => ahbso(GPU_HSINDEX),
            aximi => gpu_ctrl_aximi,
            aximo => gpu_ctrl_aximo);
    end generate;

---------------------------------------------------------------------
---  ETHERNET ---------------------------------------------------------
-----------------------------------------------------------------------

  eth0 : if CFG_GRETH = 1 generate -- Gaisler ethernet MAC
    e1 : grethm_mb
      generic map(
        hindex => GRETH_HMINDEX, ehindex => GRETH_DM_HMINDEX,
        pindex => GRETH_PINDEX, paddr => GRETH_PADDR, pmask => GRETH_PMASK, pirq => GRETH_PIRQ,
        memtech => memtech,
        mdcscaler => CPU_FREQ/1000, rmii => 0, enable_mdio => 1, fifosize => CFG_ETH_FIFO,
        nsync => 2, edcl => CFG_DSU_ETH, edclbufsz => CFG_ETH_BUF, phyrstadr => CFG_ETH_PHY_ADDR,
        macaddrh => CFG_ETH_ENM, macaddrl => CFG_LOCAL_ETH_ENL, enable_mdint => 1,
        ipaddrh => CFG_ETH_IPM, ipaddrl => CFG_LOCAL_ETH_IPL,
        giga => CFG_GRETH1G, ramdebug => 0, gmiimode => CFG_LOCAL_ETH_GMII,
        edclsepahb => 1)
      port map( rst => rstn, clk => clkm, 
                ahbmi => ahbmi, ahbmo => ahbmo(GRETH_HMINDEX),
                ahbmi2 => dbgmi(GRETH_DM_HMINDEX), ahbmo2 => dbgmo(GRETH_DM_HMINDEX),
                apbi => apbi, apbo => apbo(GRETH_PINDEX), ethi => ethi_int, etho => etho);
    
    eth_in_sig : process (ethi)
    begin
      ethi_int <= ethi;  
      ethi_int.edclsepahb <= '1';
    end process;

    -- ETH PHY interface
    eth_apbi  <= apbi;
    apbo(GRETH_PHY_PINDEX)  <= eth_apbo;

  end generate;

  noeth0 : if CFG_GRETH = 0 generate
    -- TODO:
  end generate;


  -----------------------------------------------------------------------
  ---  Fake MIG PNP -----------------------------------------------------
  -----------------------------------------------------------------------

  fake_mig_gen : if (CFG_L2_AXI /= 0) and (CFG_L2_EN /= 0) generate
    ahbso(MIG_HSINDEX).hindex  <= MIG_HSINDEX;
    ahbso(MIG_HSINDEX).hconfig <= mig_hconfig;
    ahbso(MIG_HSINDEX).hready  <= '1';
    ahbso(MIG_HSINDEX).hresp   <= "00";
    ahbso(MIG_HSINDEX).hirq    <= (others => '0');
    ahbso(MIG_HSINDEX).hrdata  <= (others => '0');
  end generate;
  no_fake_mig_gen : if (CFG_L2_AXI = 0) or (CFG_L2_EN = 0) generate
    ahbso(MIG_HSINDEX) <= ahbs_none;
  end generate;

end rtl;
