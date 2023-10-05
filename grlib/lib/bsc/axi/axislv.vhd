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
-- Entity:      axislv
-- File:        axislv.vhd
-- Author:      Marc Solé I Bonet - Barcelona Supercomputing Center
-- Edited from: axinullslv.vhd 
-- By:          Magnus Hjorth - Cobham Gaisler
-- Description: Generic AXI slave
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library grlib;
use grlib.amba.all;
library bsc;
use bsc.axi.all;

entity axislv is
  generic (
    size            : natural range 4 to 131072 := 256 -- Total size, in bytes
    -- TODO: add generic for address and mask to check validity
  );
  port(
    clk             : in std_ulogic; -- Input clock 
    reset           : in std_ulogic; -- Reset signal
    -- Control AXI-Lite
    axiso	    : out axi_somi_type; -- AXI slave output
    axisi           : in  axi_mosi_type; -- AXI slave input
    -- Registers
    regs            : out axislv_reg_array(0 to (size/4)-1) -- Access is provided in 32 bit registers
    -- TODO: do inout registers to read signals
    );
end;

architecture rtl of axislv is


  -- TODO: Ensure size is multiple of AHBDW
  constant LSIZE  : integer := AHBDW;			-- Bit length of a line
  constant BXLINE : integer := LSIZE/8;                 -- Bytes per line
  constant RXLINE : integer := BXLINE/4;                -- Registers per line
  constant NLINES : integer := maximum(1,size/BXLINE);  -- Number of lines, at least 1

  constant BBITS : natural := integer(ceil(log2(real(BXLINE)))); -- bits to identify the byte
  constant LBITS : natural := integer(ceil(log2(real(NLINES)))); -- bits to identify the line

  subtype LINE_RANGE is Natural range BBITS+LBITS-1 downto BBITS; -- Range to access the line

  subtype slvline is std_logic_vector(LSIZE-1 downto 0);
  type slvline_array is array (0 to NLINES-1) of slvline;

  type axi_signals is record
    aw_ready: std_ulogic;
    wrid: std_logic_vector(3 downto 0);
    wrlen : std_logic_vector(3 downto 0);
    wraddr : std_logic_vector(31 downto 0);
    w_ready: std_ulogic;
    b_valid: std_ulogic;
    ar_ready: std_ulogic;
    rdid: std_logic_vector(3 downto 0);
    rdlen: std_logic_vector(3 downto 0);
    rdaddr: std_logic_vector(31 downto 0);
    r_valid: std_ulogic;
    r_last: std_ulogic;
  end record;

  type slv_regs is record
    a : axi_signals;
    r : slvline_array;
  end record;

  signal r, nr : slv_regs;

begin

  comb: process(reset,axisi,r)
    variable v : slv_regs;    
    variable rd_data : slvline;
    variable rd_line : integer := to_integer(unsigned(r.a.rdaddr(LINE_RANGE)));
    variable wr_line : integer := to_integer(unsigned(r.a.wraddr(LINE_RANGE)));
  begin
    v := r;

    if axisi.aw.valid='1' and r.a.aw_ready='1' then
      v.a.aw_ready := '0';
      v.a.w_ready := '1';
      v.a.wrid := axisi.aw.id;
      v.a.wraddr := axisi.aw.addr;
    end if;
    if axisi.w.valid='1' and axisi.w.last='1' and r.a.w_ready='1' then
      for i in 0 to BXLINE-1 loop
          if axisi.w.strb(i) = '1' then
            v.r(wr_line)(8*i+7 downto 8*i) := axisi.w.data(8*i+7 downto 8*i);
          end if;
      end loop;
      v.a.b_valid := '1';
      v.a.w_ready := '0';
    end if;
    if axisi.b.ready='1' and r.a.b_valid='1' then
      v.a.b_valid := '0';
      v.a.aw_ready := '1';
    end if;

    if axisi.ar.valid='1' and r.a.ar_ready='1' then
      v.a.ar_ready := '0';
      v.a.r_valid := '1';
      v.a.rdid := axisi.ar.id;
      v.a.rdlen := axisi.ar.len;
      v.a.rdaddr := axisi.ar.addr;
    end if;
    if axisi.r.ready='1' and r.a.r_valid='1' then
      rd_data := r.r(rd_line);
      v.a.rdlen := std_logic_vector(unsigned(r.a.rdlen)-1);
      if r.a.r_last='1' then
        v.a.r_valid := '0';
        v.a.ar_ready := '1';
      end if;
    end if;

    v.a.r_last := '0';
    if v.a.rdlen="0000" then v.a.r_last:='1'; end if;

    if reset='0' then
      v.a.aw_ready := '1';
      v.a.w_ready := '0';
      v.a.b_valid := '0';
      v.a.ar_ready := '1';
      v.a.r_valid := '0';
      v.r := (others => (others => '0'));
    end if;

    nr <= v;
    axiso <= (
      aw => (ready => r.a.aw_ready),
      w => (ready => r.a.w_ready),
      b => (id => r.a.wrid, resp => "00", valid => r.a.b_valid),
      ar => (ready => r.a.ar_ready),
      r => (id => r.a.rdid, data => rd_data, resp => "00", last => r.a.r_last, valid => r.a.r_valid)
    );
    for l in 0 to NLINES-1 loop
      for i in 0 to RXLINE-1 loop
        if i < size/4 then
          regs(i+l*RXLINE) <= r.r(l)(32*i+31 downto 32*i);
        end if;
      end loop;
    end loop;
  end process;

  update: process(clk)
  begin
    if rising_edge(clk) then
      r <= nr;
    end if;
  end process;

end;
