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
--------------------------------------------------------------------------------
-- RISC-V Rocket Xilinx KCU105 Design Testbench
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library gaisler;
use gaisler.libdcom.all;
use gaisler.sim.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
library work;
use work.debug.all;
use work.config.all;

entity testbench is
  generic(
    fabtech : integer := CFG_FABTECH;
    memtech : integer := CFG_MEMTECH;
    padtech : integer := CFG_PADTECH;
    clktech : integer := CFG_CLKTECH;
    disas     : integer := CFG_DISAS;      -- Enable disassembly to console
    dbguart : integer := CFG_DUART; -- Print UART on console
    pclow     : integer := CFG_PCLOW
  -- True       - Use an AHBRAM as main memory located at 16#400#
  -- False      - Use the MIG simulation model
    );
end;

architecture behav of testbench is

  -----------------------------------------------------
  -- Components ---------------------------------------
  -----------------------------------------------------

  component ddr4ram
    generic(
      dq_bits             : natural := 8
    );
    port(
      ddr4_ck             : in    std_logic_vector(1 downto 0);
      ddr4_addr           : in    std_logic_vector(13 downto 0);
      ddr4_we_n           : in    std_logic;
      ddr4_cas_n          : in    std_logic;
      ddr4_ras_n          : in    std_logic;
      ddr4_alert_n        : out   std_logic;
      ddr4_parity         : in    std_logic;
      ddr4_reset_n        : in    std_logic;
      ddr4_ten            : in    std_logic;
      ddr4_ba             : in    std_logic_vector(1 downto 0);
      ddr4_cke            : in    std_logic;
      ddr4_cs_n           : in    std_logic;
      ddr4_dm_n           : inout std_logic_vector(7 downto 0);
      ddr4_dq             : inout std_logic_vector(63 downto 0);
      ddr4_dqs_c          : inout std_logic_vector(7 downto 0);
      ddr4_dqs_t          : inout std_logic_vector(7 downto 0);
      ddr4_odt            : in    std_logic;
      ddr4_bg             : in    std_logic_vector(0 downto 0);
      ddr4_act_n          : in    std_logic
    );
  end component ddr4ram; 

  -----------------------------------------------------
  -- Constant -----------------------------------------
  -----------------------------------------------------

  constant promfile     : string := "prom.srec"; -- rom contents
  constant ramfile      : string := "ram.srec"; -- ram contents

  -----------------------------------------------------
  -- Signals ------------------------------------------
  -----------------------------------------------------

  signal clk            : std_logic := '0';
  signal system_rst     : std_ulogic;

  signal gnd            : std_ulogic := '0';
  signal vcc            : std_ulogic := '1';
  signal nc             : std_ulogic := 'Z';

  signal clk300p        : std_ulogic := '0';
  signal clk300n        : std_ulogic := '1';
  signal clk125p        : std_ulogic := '0';
  signal clk125n        : std_ulogic := '1';

  signal txd1           : std_ulogic;
  signal rxd1           : std_ulogic;
  signal ctsn1          : std_ulogic;
  signal rtsn1          : std_ulogic;


  -- DSU UART
  signal dsutx          : std_ulogic;
  signal dsurx          : std_ulogic;
  signal dsuctsn        : std_ulogic;
  signal dsurtsn        : std_ulogic;

  -- DDR4 Memory Module
  signal ddr4_ck        : std_logic_vector(1 downto 0);
  signal ddr4_dq        : std_logic_vector(15 downto 0);
  signal ddr4_dqs_c     : std_logic_vector(1 downto 0);
  signal ddr4_dqs_t     : std_logic_vector(1 downto 0);
  signal ddr4_addr      : std_logic_vector(13 downto 0);
  signal ddr4_ras_n     : std_logic;
  signal ddr4_cas_n     : std_logic;
  signal ddr4_we_n      : std_logic;
  signal ddr4_ba        : std_logic_vector(1 downto 0);
  signal ddr4_bg        : std_logic_vector(0 downto 0);
  signal ddr4_dm_n      : std_logic_vector(1 downto 0);
  signal ddr4_ck_c      : std_logic_vector(0 downto 0);
  signal ddr4_ck_t      : std_logic_vector(0 downto 0);
  signal ddr4_cke       : std_logic_vector(0 downto 0);
  signal ddr4_act_n     : std_logic;
  signal ddr4_alert_n   : std_logic;
  signal ddr4_odt       : std_logic_vector(0 downto 0);
  signal ddr4_par       : std_logic;
  signal ddr4_ten       : std_logic;
  signal ddr4_cs_n      : std_logic_vector(0 downto 0);
  signal ddr4_reset_n   : std_logic;


  -- Testbench Related Signals
  signal dsurst         : std_ulogic;
  signal errorn         : std_logic;

begin

  -----------------------------------------------------
  -- Clocks and Reset ---------------------------------
  -----------------------------------------------------

  clk300p <= not clk300p after 1.666 ns;
  clk300n <= not clk300n after 1.666 ns;
  clk125p <= not clk125p after 4 ns; -- clkethp
  clk125n <= not clk125n after 4 ns; -- clkethn

  dsurst <= '0', '1' after 200 ns;
  system_rst    <= not dsurst;
  ddr4_ck       <= clk300n & clk300p;

  -----------------------------------------------------
  -- Misc ---------------------------------------------
  -----------------------------------------------------

  errorn                <= 'H'; -- ERROR pull-up


  -----------------------------------------------------
  -- Top ----------------------------------------------
  -----------------------------------------------------

  cpu : entity work.leon3mp
    generic map (
      fabtech              => fabtech,
      memtech              => memtech,
      padtech              => padtech,
      clktech              => clktech,
      disas                => disas,
      dbguart              => dbguart,
      pclow                => pclow
    )
    port map(
      reset             => system_rst,
      clk300p           => clk300p,
      clk300n           => clk300n,
--      switch            => switch,
--      led               => led,
--      gpio              => gpio,
      dsurx             => dsurx,
      dsutx             => dsutx,
--      dsuctsn           => dsuctsn,
--      dsurtsn           => dsurtsn,
--      button            => button,
      ddr4_dq           => ddr4_dq,
      ddr4_dqs_c        => ddr4_dqs_c,
      ddr4_dqs_t        => ddr4_dqs_t,
      ddr4_addr         => ddr4_addr,
      ddr4_ras_n        => ddr4_ras_n,
      ddr4_cas_n        => ddr4_cas_n,
      ddr4_we_n         => ddr4_we_n,
      ddr4_ba           => ddr4_ba,
      ddr4_bg           => ddr4_bg,
      ddr4_dm_n         => ddr4_dm_n,
      ddr4_ck_c         => ddr4_ck_c,
      ddr4_ck_t         => ddr4_ck_t,
      ddr4_cke          => ddr4_cke,
      ddr4_act_n        => ddr4_act_n,
      ddr4_odt          => ddr4_odt,
      ddr4_par          => ddr4_par,
      ddr4_cs_n         => ddr4_cs_n, 
      ddr4_reset_n      => ddr4_reset_n
    );


    ddr4_dq    <= (others => 'Z');
    ddr4_dqs_c <= (others => 'Z');
    ddr4_dqs_t <= (others => 'Z');


  -----------------------------------------------------
  -- Process ------------------------------------------
  -----------------------------------------------------

  iuerr : process
  begin
    wait for 500000 ns;
    if to_x01(errorn) = '1' then
      wait on errorn;
    end if;
    assert (to_x01(errorn) = '1')
      report "*** IU in error mode, simulation halted ***"
      severity failure;			-- this should be a failure
  end process;

  dsucom : process
    
    procedure dsucfg(signal dsurx : in std_ulogic; signal dsutx : out std_ulogic) is
      variable w32   : std_logic_vector(31 downto 0);
      variable w64   : std_logic_vector(63 downto 0);
      variable c8    : std_logic_vector(7 downto 0);

      constant txp   : time := 160 * 1 ns;
      constant lresp : boolean := false;

    begin

      Print("dsucom process starts here");
      -- add here if needed....

    end;

  begin
    dsuctsn <= '0';
    dsucfg(dsutx, dsurx);
    wait;
  end process;
    
end;

