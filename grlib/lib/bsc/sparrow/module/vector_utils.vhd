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
-----------------------------------------------------------------------------
-- Entity:      vector_utils
-- File:        vector_utils.vhd
-- Author:      Marc Solé Bonet, Barcelona Supercomputing Center
-- Description: Vector related types and functions
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;

package vector_utils is

    ---------------------------------------------------------------
    -- CONSTANTS --
    --------------------------------------------------------------
    constant VLEN : integer := 64; -- Vector length
    constant DLEN : integer := 8;  -- Data length
    constant WAYS : integer := VLEN/DLEN;     -- Number of ways (parallel computations)
    constant WBIT : integer := log2(WAYS);    -- Number of bits to represent WAYS

    constant UMAX : integer := 2 ** DLEN - 1;
    constant SMIN : integer := - 2 ** (DLEN - 1);
    constant SMAX : integer := 2 ** (DLEN - 1) - 1;

    ---------------------------------------------------------------
    -- TYPES DEFINITION --
    --------------------------------------------------------------
    --vector register type
    subtype vector_component is std_logic_vector(DLEN-1 downto 0);
    type vector_reg_type is array (0 to WAYS-1) of vector_component;

    --interstage vector register type (high precision);
    subtype high_prec_component is std_logic_vector(2*DLEN-1 downto 0);
    type inter_reg_type is array (0 to WAYS-1) of high_prec_component;

    subtype wordv is std_logic_vector(VLEN-1 downto 0);
    ---------------------------------------------------------------
    -- MULTIPLICATION UNIT IN/OUT --
    --------------------------------------------------------------
    type lpmul_in_type is record
        opA  : vector_component;
        opB  : vector_component;
        sign : std_logic;
        mix  : std_logic;
        sat  : std_logic;
    end record;

    type lpmul_out_type is record
        mul_res : high_prec_component;
    end record;

    ---------------------------------------------------------------
    -- MULTIPLICATION COMPONENT --
    --------------------------------------------------------------
    component lpmul is 
    port(
            muli : in lpmul_in_type;
            mulo : out lpmul_out_type
        );
    end component;
    ---------------------------------------------------------------
    -- FUNCTIONS DEFINITION --
    --------------------------------------------------------------
    -- returns a wordv data as vector
    function to_vector(data : wordv) return vector_reg_type;
    -- returns a wordv data as intermediate vector
    function to_vector(data : wordv; sign : std_logic) return inter_reg_type;

    -- returns a vector vec as wordv
    function to_word(vec : vector_reg_type) return wordv;
    -- returns an intermediate vector vec as wordv
    function to_word(vec : inter_reg_type) return wordv;

    -- returns the closer integer to value within max_val and min_val
    function clipping (value, max_val, min_val : integer) return integer;
    function signed_clipping (value, max_val, min_val : signed) return signed;
    function unsigned_clipping (value, max_val, min_val : unsigned) return unsigned;
    -- returns the value sign extended if set, to size length
    function extend(value : std_logic_vector; sign : std_logic; size : integer) return std_logic_vector;
    -- returns a saturated as signed if sat with length leng
    function signed_sat(a, leng : integer; sat : std_logic) return std_logic_vector;
    -- returns a saturated as unsigned if sat with length leng
    function unsigned_sat(a, leng : integer; sat : std_logic) return std_logic_vector;
    -- replicates a vector component in a vector
    function replicate(data : vector_component) return vector_reg_type;

end package;
package body vector_utils is
    ---------------------------------------------------------------
    -- FUNCTIONS
    --------------------------------------------------------------
    function to_vector(data : wordv) return vector_reg_type is
        variable vec : vector_reg_type;
    begin
        for i in vec'range loop
            vec(i) := data(DLEN*i+DLEN-1 downto DLEN*i);
        end loop;
        return vec;
    end;

    function to_vector(data : wordv; sign : std_logic) return inter_reg_type is 
        variable vec : inter_reg_type;
    begin
        for i in vec'range loop
            vec(i) := extend(data(DLEN*i+DLEN-1 downto DLEN*i), sign, high_prec_component'length);
        end loop;
        return vec;
    end;

    function to_word(vec : vector_reg_type) return wordv is
        variable data : wordv;
    begin
        for i in vec'range loop
            data(DLEN*i+DLEN-1 downto DLEN*i) := vec(i);
        end loop;
        return data;
    end;

    function to_word(vec : inter_reg_type) return wordv is
        variable data : wordv;
    begin
        for i in vec'range loop
            data(DLEN*i+DLEN-1 downto DLEN*i) := vec(i)(vector_component'range);
        end loop;
        return data;
    end;

    ---------------------------------------------------------------
    -- SATURATION FUNCTIONS
    --------------------------------------------------------------
    function clipping (value, max_val, min_val : integer) return integer is
    begin
        if value > max_val then return max_val;
        elsif value < min_val then return min_val;
        else return value;
        end if;
    end clipping;

    function signed_clipping (value, max_val, min_val : signed) return signed is
    begin
        if value > max_val then return max_val;
        elsif value < min_val then return min_val;
        else return value;
        end if;
    end signed_clipping;

    function unsigned_clipping (value, max_val, min_val : unsigned) return unsigned is
    begin
        if value > max_val then return max_val;
        elsif value < min_val then return min_val;
        else return value;
        end if;
    end unsigned_clipping;

    function extend(value : std_logic_vector; sign : std_logic; size : integer) return std_logic_vector is 
    begin
        if sign = '1' then 
            return std_logic_vector(resize(signed(value), size));
        else 
            return std_logic_vector(resize(unsigned(value), size));
        end if;
    end extend;

    function signed_sat(a, leng : integer; sat : std_logic) return std_logic_vector is
    begin
        if sat = '1' then
            return  std_logic_vector(to_signed(clipping(a, SMAX, SMIN), leng));
        else return std_logic_vector(to_signed(a, leng));
        end if;
    end signed_sat;

    function unsigned_sat(a, leng : integer; sat : std_logic) return std_logic_vector is
    begin
        if sat = '1' then
            return std_logic_vector(to_unsigned(clipping(a, UMAX, 0), leng));
        else return std_logic_vector(to_signed(a, leng));
        end if;
    end unsigned_sat;

    function replicate(data : vector_component) return vector_reg_type is
        variable vec : vector_reg_type;
    begin
	vec := (others => data);
        return vec;
    end replicate;
	

end package body;
