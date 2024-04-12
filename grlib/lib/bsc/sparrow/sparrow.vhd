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
-- Entity:      sparrow
-- File:        sparrow.vhd
-- Author:      Marc Solé Bonet, Barcelona Supercomputing Center
-- Description: SPARROW interface package with utilities for integration with
--              the pipeline
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.stdlib.all;

library bsc;
use bsc.vector_utils.all;
use bsc.sprw_opcodes.all;

package sparrow is

    ---------------------------------------------------------------
    -- CONSTANTS --
    --------------------------------------------------------------
    constant sprw_version : string := "2.0";
    constant SWZ_LENGTH : integer := WAYS * WBIT;
    constant SCR_BIT : integer := WAYS  	      -- MASK
    				            + 1               -- Mask selector
				                + SWZ_LENGTH * 2; -- Swizzling

    constant IBITS : integer := 5;  --Immediate bits
				     


    ------------------------------------------------------------
    -- SPARROW CONTROL REGISTER --
    ------------------------------------------------------------
    -- mask registers (predicate)
    subtype mask_reg_type is std_logic_vector(WAYS-1 downto 0);

    -- swizzling registers (reordering)
    subtype log_length is integer range 0 to WAYS-1;
    type swizzling_reg_type is array (0 to WAYS-1) of log_length;

    subtype swizzling_data_a is std_logic_vector(SWZ_LENGTH + WAYS downto WAYS+1);
    subtype swizzling_data_b is std_logic_vector(SCR_BIT-1 downto SWZ_LENGTH + WAYS+1);

    type sprw_ctrl_reg_type is record
        mk : mask_reg_type;      -- mask value
        ms : std_logic;          -- mask selection (ra or 0)
        sa : swizzling_reg_type; -- swizzling ra
        sb : swizzling_reg_type; -- swizzling rb
    end record;

    ------------------------------------------------------------
    -- SPARROW IN/OUT REGISTERS --
    ------------------------------------------------------------
    type sprw_in_type is record
        ra          : wordv;                                      -- operand 1 data
        rb          : wordv;                                      -- operand 2 data
        op1         : std_logic_vector (4 downto 0);              -- operation code stage1
        op2         : std_logic_vector (2 downto 0);              -- operation code stage2
        rc_we       : std_logic;                                  -- we on destination (work)
        ctrl        : sprw_ctrl_reg_type;                         -- special register to control the module behaviour
        bpv         : wordv;                                      -- value comming from memory
        bp          : std_logic_vector(1 downto 0);               -- bp mux value (bit 0 = rs1, bit 1 = rs2)

    end record;

    type sprw_out_type is record
        result      : wordv; -- output data
        s1bp        : wordv; -- s1 bypass output data
        s2bp        : wordv; -- s2 bp output data
    end record;

    type sprw_in_vec  is array (0 to 1) of sprw_in_type;
    type sprw_out_vec  is array (0 to 1) of sprw_out_type;

    ---------------------------------------------------------------
    -- SPARROW MODULE --
    --------------------------------------------------------------
    component sparrow_unit is 
        port(
                clk   : in  std_ulogic;
                rstn  : in  std_ulogic;
                holdn : in  std_ulogic;
                sdi   : in  sprw_in_type;
                sdo   : out sprw_out_type
            );
    end component;


    ---------------------------------------------------------------
    -- FUNCTIONS DECLARATION --
    --------------------------------------------------------------
    function swizzling_init return swizzling_reg_type;
    function swizzling_set(sz_i : std_logic_vector(WAYS*WBIT-1 downto 0)) return swizzling_reg_type;
    function swizzling_get(sz : swizzling_reg_type) return std_logic_vector;
    function to_word(reg : sprw_ctrl_reg_type) return wordv;
    function to_scr(data : wordv) return sprw_ctrl_reg_type;
    function imm_sprw (s1, imm_bits : std_logic_vector(4 downto 0)) return wordv;
    function to_string (a: std_logic_vector) return string;

    ---------------------------------------------------------------
    -- CONSTANTS DECLARATION --
    --------------------------------------------------------------
    constant sprw_ctrl_reg_res : sprw_ctrl_reg_type;
    constant sprw_ctrl_reg_none : sprw_ctrl_reg_type;
    constant sprw_ctrl_reg_word_res : wordv;
    constant sprw_in_none   : sprw_in_type;
    constant sprw_out_none   : sprw_out_type;
      

end package;
package body sparrow is
    ---------------------------------------------------------------
    -- SCR FUNCTIONS --
    --------------------------------------------------------------
    function swizzling_init return swizzling_reg_type is
        variable res_val : swizzling_reg_type;
    begin
        for i in 0 to (VLEN/DLEN)-1 loop
            res_val(i) := i;
        end loop;
        return res_val;
    end function swizzling_init;

    function swizzling_set(sz_i : std_logic_vector(WAYS*WBIT-1 downto 0)) return swizzling_reg_type is
        variable res_val : swizzling_reg_type;
    begin
        for i in 0 to (VLEN/DLEN)-1 loop
            res_val(i) := to_integer(unsigned(sz_i(i*WBIT+WBIT-1 downto i*WBIT)));
        end loop;
        return res_val;
    end function swizzling_set;

    function swizzling_get(sz : swizzling_reg_type) return std_logic_vector is
        variable data : std_logic_vector(WAYS*WBIT-1 downto 0);
    begin
        for i in 0 to WAYS-1 loop
            data(WBIT*i+WBIT-1 downto WBIT*i) := std_logic_vector(to_unsigned(sz(i), WBIT));
        end loop;
        return data;
    end function swizzling_get;

    function to_word(reg : sprw_ctrl_reg_type) return wordv is
    begin
        return (wordv'left downto SCR_BIT => '0') & swizzling_get(reg.sb) & swizzling_get(reg.sa) & reg.ms & reg.mk; 
    end to_word;

    function to_scr(data : wordv) return sprw_ctrl_reg_type is 
        variable reg : sprw_ctrl_reg_type;
    begin
        reg.mk := data(mask_reg_type'range);
        reg.ms := data(mask_reg_type'length);
        reg.sa := swizzling_set(data(swizzling_data_a'range));
        reg.sb := swizzling_set(data(swizzling_data_b'range));
        return reg;
    end to_scr;

    ---------------------------------------------------------------
    -- IMMEDIATE ENCODING --
    --------------------------------------------------------------
    function imm_sprw (s1, imm_bits : std_logic_vector(4 downto 0)) return wordv is
        variable imm : std_logic_vector(IBITS-1 downto 0);
        variable immediate_data : vector_component;
        variable rhzeros : integer range 0 to DLEN-1;
        variable ret : wordv;
    begin
        immediate_data := (others => '0'); 
	imm := imm_bits;
       	ret := (others => '0');
        rhzeros := to_integer(unsigned(imm(IBITS-2 downto 1))); --number of right hand 0s, for pow2
        case s1 is
            when  S1_SLRA | S1_SLRL =>  -- [-16, 15]
                immediate_data := (DLEN-1 downto IBITS => imm(IBITS-1)) & imm(IBITS-1 downto 0);
                ret := to_word(replicate(immediate_data));
            when S1_AND | S1_OR | S1_XOR | S1_NAND | S1_NOR | S1_XNOR => -- [-16, 15]
                immediate_data := (DLEN-1 downto IBITS => imm(IBITS-1)) & imm(IBITS-1 downto 0);
		ret := to_word(replicate(immediate_data));
            when S1_CLIP | S1_UCLIP => --2^imm(4 downto 1) - imm(0) [0, 2^15]
                ret(to_integer(unsigned(imm(IBITS-1 downto 1)))) := '1';
                ret := ret + (ret'range => imm(0));
            when others => -- 2^imm(3 downto 1) - imm(0) [0, 128]
                immediate_data(rhzeros) := '1';
                immediate_data := immediate_data + (immediate_data'range => imm(0));
                if imm(IBITS-1) = '1' then
                    if (s1(4) = '0') then --signed *(-1) [-128, 128]
                        immediate_data := not(immediate_data) + "00000001";
                    else --unsigned +2 [0,130]
                        immediate_data := immediate_data + "10";
                    end if;
                end if;
		ret := to_word(replicate(immediate_data));
        end case;
        return ret;
    end function;

   
    ---------------------------------------------------------------
    -- UTIL FOR DEBUG --
    --------------------------------------------------------------
    function to_string ( a: std_logic_vector) return string is
        variable b : string (1 to a'length) := (others => NUL);
        variable stri : integer := 1;
    begin
        for i in a'range loop
            b(stri) := std_logic'image(a((i)))(2);
            stri := stri+1;
        end loop;
        return b;
    end function;

    ---------------------------------------------------------------
    -- CONSTANTS VALUES --
    --------------------------------------------------------------
    constant sprw_ctrl_reg_res : sprw_ctrl_reg_type := (
        mk => (others => '1'),
        ms => '1',
        sa => swizzling_init,
        sb => swizzling_init
    );

    constant sprw_ctrl_reg_none : sprw_ctrl_reg_type := (
        mk => (others => '0'),
        ms => '0',
        sa => (others => 0),
        sb => (others => 0)
    );

    constant sprw_ctrl_reg_word_res : wordv := to_word(sprw_ctrl_reg_res);

    constant sprw_in_none   : sprw_in_type := (
        ra          => (others => '0'),
        rb          => (others => '0'),
        op1         => (others => '0'),
        op2         => (others => '0'),
        rc_we       => '0',
        ctrl        => sprw_ctrl_reg_none,
        bpv         => (others => '0'),
        bp          => (others => '0')
    );
    constant sprw_out_none   : sprw_out_type := (
        result      => (others => '0'),
        s1bp        => (others => '0'),
        s2bp        => (others => '0')
    );

end package body;
