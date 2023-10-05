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
-- Description: AXI splitter, one master and multiple slaves
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.tost;
library bsc;
use bsc.axi.all;

entity axisplit is
  generic (
    NoSlaves   : integer := 2;
    --TODO: Add r/w permission & check
    addr_range : axi_addr_range_array(0 to NoSlaves-1)
  );
  port (
    clk	       : in std_logic;
    reset      : in std_logic;
    -- Master signals
    aximo      : in axi4_mosi_type;  -- AXI from the master
    aximi      : out axi_somi_type;  -- AXI to the master
    -- Slaves signals
    axisi      : out axi4_mosi_vector_type(0 to NoSlaves-1); -- AXI to the slave
    axiso      : in axi_somi_vector_type(0 to NoSlaves-1)    -- AXI from the slave
  );
end;
	
architecture rtl of axisplit is
  type axisplit_regs is record
    read  : integer range 0 to NoSlaves;
    write : integer range 0 to NoSlaves;
  end record;

  signal r, nr : axisplit_regs;
    
begin
  
  comb: process(reset, axiso, aximo, r)
    variable v : axisplit_regs;
    variable slaves : axi_somi_vector_type(0 to NoSlaves);
    variable master : axi4_mosi_vector_type(0 to NoSlaves);

    function valid_addr(addr : std_logic_vector) return integer is
    begin
      for i in 1 to NoSlaves loop
	report "slv:" & tost(i) & ": " & tost(addr) & " & " & tost(addr_range(i-1).mask) & " = " & tost(addr and addr_range(i-1).mask) & " ? " & tost(addr_range(i-1).addr);
        if (addr and addr_range(i-1).mask) = addr_range(i-1).addr then
	  return i;
	end if;
      end loop;
      return 0;
    end valid_addr;

  begin
    -- Init
    v := r;
    slaves(1 to NoSlaves) := axiso(0 to NoSlaves-1);
    slaves(0) := zero_somi;
    master := (others => zero_mosi);
    -- Body
    -- Lock read
    if aximo.ar.valid = '1' and r.read = 0 then
      v.read := valid_addr(aximo.ar.addr);
    end if;
    -- Lock write
    if aximo.aw.valid = '1' and r.write = 0 then
      v.write := valid_addr(aximo.aw.addr);
    end if;
    -- Free read
    if r.read > 0 then
      if aximo.r.ready = '1' and axiso(r.read-1).r.valid = '1' and axiso(r.read-1).r.last = '1' then
        v.read := 0;
      end if;
    end if;
    -- Free write
    if r.write > 0 then
      if aximo.b.ready = '1' and axiso(r.write-1).b.valid = '1' then
        v.write := 0;
      end if;
    end if;

    master(r.write).aw := aximo.aw;
    master(r.write).w := aximo.w;
    master(r.write).b := aximo.b;
    master(r.read).ar := aximo.ar;
    master(r.read).r := aximo.r;

    -- Reset
    if reset = '0' then
      v.read  := 0;
      v.write := 0;
    end if;
    -- Outputs
    nr <= v;

    aximi <= (
      aw => slaves(r.write).aw,
      w  => slaves(r.write).w,
      b  => slaves(r.write).b,
      ar => slaves(r.read).ar,
      r  => slaves(r.read).r
    );

    axisi <= master(1 to NoSlaves);

  end process;

  update: process (clk)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
  end process;
end;
