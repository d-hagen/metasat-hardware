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
-- Entity:      axisplit
-- File:        axisplit.vhd
-- Author:      Marc Solé I Bonet - Barcelona Supercomputing Center
-- Description: AXI merger, multiple masters but a single slave
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library grlib;
use grlib.amba.all;
library bsc;
use bsc.axi.all;

entity aximerge is
  generic (
    NoMasters  : integer := 2
  );
  port (
    clk        : in std_logic;
    reset      : in std_logic;
    -- Masters signals
    aximo      : in axi4_mosi_vector_type(0 to NoMasters-1);  -- AXI from the masters
    aximi      : out axi_somi_vector_type(0 to NoMasters-1);  -- AXI to the masters
    -- Slave signals
    axisi      : out axi4_mosi_type; -- AXI to the slave
    axiso      : in axi_somi_type    -- AXI from the slave
  );
end;
architecture rtl of aximerge is

  type aximerge_regs is record
    read : integer;
    write : integer;
  end record;

  signal r : aximerge_regs := (0,0);
  signal nr : aximerge_regs;

begin
  
  comb: process(reset, aximo, axiso, r)
    variable v : aximerge_regs;
    variable masters : axi4_mosi_vector_type(0 to NoMasters);
    variable slave : axi_somi_vector_type(0 to NoMasters);
  begin
    -- INIT --
    v := r;
    masters(1 to NoMasters) := aximo;
    masters(0) := zero_mosi;
    slave := (others => zero_somi);

    -- BODY --
    -- TODO: Add array with ordered masters to avoid starvation
    for i in 1 to NoMasters loop
      -- Lock read
      if masters(i).ar.valid = '1' and r.read = 0 then
        v.read := i;
      end if;
      -- Lock write
      if masters(i).aw.valid = '1' and r.write = 0 then
        v.write := i;
      end if;
    end loop;
    -- Free read
    if r.read > 0 then
      if masters(r.read).r.ready = '1' and axiso.r.valid = '1' and axiso.r.last = '1' then
        v.read := 0;
      end if;
    end if;
    -- Free write
    if r.write > 0 then
      if masters(r.write).b.ready = '1' and axiso.b.valid = '1' then
        v.write := 0;
      end if;
    end if;

    slave(r.write).aw := axiso.aw;
    slave(r.write).w  := axiso.w;
    slave(r.write).b  := axiso.b;
    slave(r.read).ar  := axiso.ar;
    slave(r.read).r   := axiso.r;

    -- RESET --
    if reset = '0' then
      v.read := 0;
      v.write := 0;
    end if;

    -- OUTPUTS --
    nr <= v;
    axisi <= (
      aw => masters(r.write).aw,
      w  => masters(r.write).w,
      b  => masters(r.write).b,
      ar => masters(r.read).ar,
      r  => masters(r.read).r
    );

    aximi <= slave(1 to NoMasters);
  end process;	

  update: process (clk)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
  end process;
end;
