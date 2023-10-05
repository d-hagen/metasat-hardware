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
-----------------------------------------------------------------------------
-- Entity:      libaxi
-- File:        libaxi.vhd
-- Author:      Marc Solé I Bonet - Barcelona Supercomputing Center
-- Description: AXI utils library
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;

package axi is

  -- AXI SLAVE --
  type axislv_reg_array is array (natural range <>) of std_logic_vector(31 downto 0);

  component axislv is
    generic (
      size            : integer  -- Total size, in bytes
    );
    port(
      clk             : in std_ulogic; -- Input clock 
      reset           : in std_ulogic; -- Reset signal
      -- Control AXI-Lite
      axiso           : out axi_somi_type; -- AXI slave output
      axisi           : in  axi_mosi_type; -- AXI slave input
      -- Registers
      regs            : out axislv_reg_array
    );
  end component;

  -- AXI4 Splitter --
  type axi_addr_range is record
    addr : std_logic_vector(31 downto 0);
    mask : std_logic_vector(31 downto 0);
  end record;

  -- Generate axi_addr_range for a memory location
  function mem_addr_range(addr, mask : ahb_addr_type) return axi_addr_range;
  -- Generate axi_addr_range for a IO location
  function io_addr_range(addr, mask : ahb_addr_type) return axi_addr_range;

  type axi_addr_range_array is array (natural range <>) of axi_addr_range;

  component axisplit is
    generic (
      NoSlaves   : integer := 2;
      addr_range : axi_addr_range_array
    );
    port (
      clk        : in std_logic;
      reset      : in std_logic;
      -- Master signals
      aximo      : in axi4_mosi_type;  -- AXI from the master
      aximi      : out axi_somi_type;  -- AXI to the master
      -- Slaves signals
      axisi      : out axi4_mosi_vector_type; -- AXI to the slave
      axiso      : in axi_somi_vector_type   -- AXI from the slave
    );
  end component;

  -- AXI Merger --
  component aximerge is
    generic (
      NoMasters  : integer := 2
    );
    port (
      clk	 : in std_logic;
      reset      : in std_logic;
      -- Masters signals
      aximo      : in axi4_mosi_vector_type;  -- AXI from the masters
      aximi      : out axi_somi_vector_type;  -- AXI to the masters
      -- Slave signals
      axisi      : out axi4_mosi_type; -- AXI to the slave
      axiso      : in axi_somi_type    -- AXI from the slave
    );
  end component;

  constant zero_somi : axi_somi_type := (
    aw => (ready => '0'),
    w  => (ready => '0'),
    b  => (id => (others => '0'), resp => "00", valid => '0'),
    ar => (ready => '0'),
    r  => (id => (others => '0'), data => (others => '0'), resp => "00", last => '0', valid => '0')
  );

  constant zero_mosi : axi4_mosi_type := (
    aw => (id => (others => '0'), addr => (others => '0'), len => (others => '0'), size => "000", burst => "00", lock => '0', cache => "0000", prot => "000", valid => '0', qos => "0000"),
    w  => (data => (others => '0'), strb => (others => '0'), last => '0', valid => '0'),
    b  => (ready => '0'),
    ar => (id => (others => '0'), addr => (others => '0'), len => (others => '0'), size => "000", burst => "00", lock => '0', cache => "0000", prot => "000", valid => '0', qos => "0000"),
    r  => (ready => '0')
  );


  -- AXI4 to AXI-L --
  function axi4_to_axi(a4 : axi4_mosi_type) return axi_mosi_type;
  -- AXI-L to AXI4 --
  function axi_to_axi4(a : axi_mosi_type) return axi4_mosi_type;

end package;
package body axi is

  -- Generate axi_addr_range for a memory location
  function mem_addr_range(addr, mask : ahb_addr_type) return axi_addr_range is
    variable rge : axi_addr_range;
  begin
    rge.addr(31 downto 20) := std_logic_vector(to_unsigned(addr,12));
    rge.addr(19 downto 0)  := (others => '0');                      
    rge.mask(31 downto 20) := std_logic_vector(to_unsigned(mask,12));
    rge.mask(19 downto 0)  := (others => '0');
    return rge;
  end mem_addr_range;

  -- Generate axi_addr_range for a IO location
  function io_addr_range(addr, mask : ahb_addr_type) return axi_addr_range is
    variable rge : axi_addr_range;
  begin
    rge.addr(31 downto 20) := std_logic_vector(to_unsigned(16#FFF#,12)); -- Must be same value as ahbctrl ioaddr
    rge.addr(19 downto 8)  := std_logic_vector(to_unsigned(addr,12));
    rge.addr(7 downto 0)   := (others => '0');
    rge.mask(31 downto 20) := std_logic_vector(to_unsigned(16#FFF#,12)); -- Must be same value as ahbctrl iomask
    rge.mask(19 downto 8)  := std_logic_vector(to_unsigned(mask,12));
    rge.mask(7 downto 0)   := (others => '0');
    return rge;
  end io_addr_range;

  -- AXI4 to AXI-L --
  function axi4_to_axi(a4 : axi4_mosi_type) return axi_mosi_type is
    variable a : axi_mosi_type;
  begin
    -- b & r (equal)
    a.b := a4.b;
    a.r := a4.r;
    -- aw
    a.aw.id    := a4.aw.id;
    a.aw.addr  := a4.aw.addr;
    a.aw.len   := a4.aw.len(3 downto 0);
    a.aw.size  := a4.aw.size;
    a.aw.burst := a4.aw.burst;
    a.aw.lock  := '0' & a4.aw.lock;
    a.aw.cache := a4.aw.cache;
    a.aw.prot  := a4.aw.prot;
    a.aw.valid := a4.aw.valid;
    -- w (using aw id)
    a.w.id     := a4.aw.id;
    a.w.data   := a4.w.data; 
    a.w.strb   := a4.w.strb;
    a.w.last   := a4.w.last;
    a.w.valid  := a4.w.valid;
    -- ar 
    a.ar.id    := a4.ar.id;
    a.ar.addr  := a4.ar.addr;
    a.ar.len   := a4.ar.len(3 downto 0);
    a.ar.size  := a4.ar.size;
    a.ar.burst := a4.ar.burst;
    a.ar.lock  := '0' & a4.ar.lock;
    a.ar.cache := a4.ar.cache;
    a.ar.prot  := a4.ar.prot;
    a.ar.valid := a4.ar.valid;

    return a;
  end axi4_to_axi;

  -- AXI-L to AXI4 --
  function axi_to_axi4(a : axi_mosi_type) return axi4_mosi_type is
    variable a4 : axi4_mosi_type;
  begin
    -- b & r (equal)
    a4.b := a.b;
    a4.r := a.r;
    -- aw
    a4.aw.id    := a.aw.id;
    a4.aw.addr  := a.aw.addr;
    a4.aw.len   := "0000" & a.aw.len;
    a4.aw.size  := a.aw.size;
    a4.aw.burst := a.aw.burst;
    a4.aw.lock  := a.aw.lock(0);
    a4.aw.cache := a.aw.cache;
    a4.aw.prot  := a.aw.prot;
    a4.aw.valid := a.aw.valid;
    a4.aw.qos   := (others => '0');
    -- w (using aw id)
    a4.w.data   := a.w.data; 
    a4.w.strb   := a.w.strb;
    a4.w.last   := a.w.last;
    a4.w.valid  := a.w.valid;
    -- ar 
    a4.ar.id    := a.ar.id;
    a4.ar.addr  := a.ar.addr;
    a4.ar.len   := "0000" & a.ar.len;
    a4.ar.size  := a.ar.size;
    a4.ar.burst := a.ar.burst;
    a4.ar.lock  := a.ar.lock(0);
    a4.ar.cache := a.ar.cache;
    a4.ar.prot  := a.ar.prot;
    a4.ar.valid := a.ar.valid;
    a4.ar.qos   := (others => '0');

    return a4;
  end axi_to_axi4;
end package body;
