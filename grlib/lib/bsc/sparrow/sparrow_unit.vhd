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
-- Entity:      sparrow_unit
-- File:        sparrow_unit.vhd
-- Author:      Marc Solé Bonet, Barcelona Supercomputing Center
-- Description: SPARROW module pipeline
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;

library bsc;
use bsc.sparrow.all;
use bsc.vector_utils.all;
use bsc.sprw_opcodes.all;

entity sparrow_unit is 
    port(
            clk   : in  std_ulogic;
            rstn  : in  std_ulogic;
            holdn : in  std_ulogic;
            sdi   : in  sprw_in_type;
            sdo   : out sprw_out_type
        );
end;

architecture rtl of sparrow_unit is
    ---------------------------------------------------------------
    -- REGISTER TYPES DEFINITION --
    --------------------------------------------------------------
    type lpmul_in_array is array (0 to WAYS-1) of lpmul_in_type;
    type lpmul_out_array is array (0 to WAYS-1) of lpmul_out_type;

    type l1_sum_array is array (0 to WAYS/2) of std_logic_vector(DLEN downto 0);
    type l2_sum_array is array (0 to WAYS/4) of std_logic_vector(DLEN+1 downto 0);

    -- Stage1 entry register
    type s1_reg_type is record
        ra : vector_reg_type;
        rb : vector_reg_type;
        op1: std_logic_vector(4 downto 0);
        op2: std_logic_vector(2 downto 0);
        en : std_logic;
    end record; 
    
    -- Stage2 entry register
    type s2_reg_type is record
        ra :  inter_reg_type;
        op2:  std_logic_vector(2 downto 0);
        sign: std_logic;
        en :  std_logic;
    end record;

    -- Stage3 entry register
    type s3_reg_type is record
        rc : wordv;
    end record;


    -- Group of pipeline registers
    type registers is record
        s1 : s1_reg_type;
        s2 : s2_reg_type;
        s3 : s3_reg_type;
    end record;

    ---------------------------------------------------------------
    -- CONSTANTS FOR PIPELINE REGISTERS RESET --
    --------------------------------------------------------------
    constant vector_reg_res : vector_reg_type := (others => (others => '0'));
    constant inter_reg_res : inter_reg_type := (others => (others => '0'));

    -- set the 1st stage registers reset
    constant s1_reg_res : s1_reg_type := (
        ra => vector_reg_res,
        rb => vector_reg_res,
        op1 => (others => '0'),
        op2 => (others => '0'),
        en => '0'
    );

    -- set the 2nd stage registers reset
    constant s2_reg_res : s2_reg_type := (
        ra => inter_reg_res,
        op2 => (others => '0'),
        sign => '0',
        en => '0'
    );

    -- set the 3rd stage registers reset
    constant s3_reg_res : s3_reg_type := (
        rc => (others => '0')
    );


    -- reset all registers
    constant RRES : registers := (
        s1 => s1_reg_res,
        s2 => s2_reg_res,
        s3 => s3_reg_res
    );

    ---------------------------------------------------------------
    -- SIGNALS DEFINITIONS
    --------------------------------------------------------------
    --signals for the registers r -> current, rin -> next
    signal r, rin: registers;

    signal lpmuli : lpmul_in_array;
    signal lpmulo : lpmul_out_array;

    ---------------------------------------------------------------
    -- MUX FUNCTION --
    --------------------------------------------------------------
    function op_mux(vec, bpv : vector_reg_type; bp_sel : std_logic_vector; reg_sel : integer) return vector_reg_type is 
    begin
        if bp_sel(reg_sel) = '1' then
            return bpv;
        else 
            return vec;
        end if;
    end op_mux;

    ---------------------------------------------------------------
    -- SWIZZLING FUNCTION --
    --------------------------------------------------------------
    function swizzling(data : vector_reg_type; sz : swizzling_reg_type) return vector_reg_type is
        variable result : vector_reg_type;
    begin
        for i in result'range loop
            result(i) := data(sz(i)); 
        end loop;
        return result;
    end function swizzling;

    ---------------------------------------------------------------
    -- MASK FUNCTION --
    --------------------------------------------------------------
    procedure mask(vector, original : in inter_reg_type;
                   msk : in std_logic_vector(WAYS-1 downto 0);
                   pas_ra : in std_logic;
                   msk_res : out inter_reg_type) is
    begin 
        if pas_ra = '1' then 
            msk_res := original;
        else 
            msk_res := (others => (others => '0'));
        end if;
        for i in msk'range loop
            if msk(i) = '1' then
                msk_res(i) := vector(i);
            end if;
        end loop;
    end mask;

    ---------------------------------------------------------------
    -- TWO OPERANDS OPERATIONS (S1) --
    --------------------------------------------------------------

    -- s1 result multiplexor and sign setter
    procedure s1_mux(op : in std_logic_vector(4 downto 0);
                     sel: out std_logic_vector(2 downto 0);
                     sign: out std_logic) is
    begin
        case op is
            when S1_AND | S1_OR | S1_XOR | S1_NAND | S1_NOR | S1_XNOR => 
                sel := "000";
                sign := '0';
            when others =>
              sel := op(2 downto 0);
              sign := not op(4); 
        end case;
    end s1_mux;

    procedure s1_select(sel: in std_logic_vector(2 downto 0); 
                        rs2, add_res, sub_res, max_res, min_res, logic_res, shift_res,  mul_res : in inter_reg_type;
                        s1_res : out inter_reg_type) is
    begin
        case sel is
            when "001" => s1_res := add_res;
            when "010" => s1_res := sub_res;
            when "011" => s1_res := mul_res;
            when "100" => s1_res := shift_res;
            when "101" => s1_res := max_res;
            when "110" => s1_res := min_res;
            when "111" => s1_res := rs2;
            when "000" => s1_res := logic_res;
            when others => s1_res := (others => (others => '0'));
        end case;
    end s1_select;

    function add(a, b : vector_component;
                 sign, sat : std_logic) return std_logic_vector is
        variable z : integer;
    begin
        if sign = '1' then 
            z := to_integer(signed(a)) + to_integer(signed(b));
            return signed_sat(z, high_prec_component'length, sat);
        else 
            z := to_integer(unsigned(a)) + to_integer(unsigned(b));
            return unsigned_sat(z, high_prec_component'length, sat);
        end if;
    end add;


    function sub(a, b : vector_component;
                 sign, sat : std_logic) return std_logic_vector is
        variable z : integer range -512 to 512;
    begin
        if sign = '1' then 
            z := to_integer(signed(a)) - to_integer(signed(b));
            return signed_sat(z, high_prec_component'length, sat);
        else 
            z := to_integer(unsigned(a)) - to_integer(unsigned(b));
            return unsigned_sat(z, high_prec_component'length, sat);
        end if;
    end sub;

    -- max function
    function max(a, b : vector_component;
                 sign : std_logic) return high_prec_component is 
        variable z : vector_component;
    begin
        if sign = '1' then 
            if signed(a) > signed(b) then z := a;
            else z := b;
            end if;
        else 
            if a > b then z := a;
            else z := b;
            end if;
        end if;
        return extend(z, sign, high_prec_component'length);
    end max;
        

    -- min function
    function min(a, b : vector_component;
                 sign : std_logic) return high_prec_component is 
        variable z : vector_component;
    begin
        if sign = '1' then 
            if signed(a) > signed(b) then z := b;
            else z := a;
            end if;
        else 
            if a > b then z := b;
            else z := a;
            end if;
        end if;
        return extend(z, sign, high_prec_component'length);
    end min;

    --logic operations
    function logic_op(a, b : vector_component;
                      op : std_logic_vector(2 downto 0)) return high_prec_component is
        variable z : vector_component;
    begin
        case op is 
            when "000" => z := a and b;
            when "001" => z := a or b;
            when "010" => z := a xor b;
            when "100" => z := a nand b;
            when "101" => z := a nor b;
            when "110" => z := a xnor b;
            when others => z := (others => '0');
        end case;
        return extend(z, '0', high_prec_component'length);
    end logic_op;

    function shift(a, b : vector_component; sign, sat : std_logic) return high_prec_component is
        variable z : integer;
        variable i : integer;
        variable logic : std_logic;
        variable c : high_prec_component;
    begin
        logic := not sign;
        i := to_integer(signed(b(b'left downto 0)));
        c := (vector_component'range => (sign and a(a'left))) & a;
        if (i < 0) then 
            if logic = '0' then -- arithmetic
                return std_logic_vector(shift_right(signed(c), -i));
            else 
                return std_logic_vector(shift_right(unsigned(c), -i));
            end if;
        else 
            z := to_integer(shift_left(unsigned(c), i));
            if sign = '1' then -- signed
                return signed_sat(z, high_prec_component'length, sat);
            else 
                return unsigned_sat(z, high_prec_component'length, sat);
            end if;
        end if;
    end shift;

    -- Works with words, a and b. Clips a to 0,b if unsigned and to -b,b if signed
    -- b is always unsigned
    function clip(a,b : wordv; sign : std_logic) return wordv is
        variable z, w : signed(wordv'length downto 0);
        variable zu, wu : unsigned(wordv'range);
        variable zero : unsigned(wordv'range) := (others => '0');
    begin
        if sign = '1' then
            z := signed(a(a'left)&a);
            w := signed('0'&b);
            return std_logic_vector(signed_clipping(z, w, -w)(wordv'range));
        else 
            zu := unsigned(a);
            wu := unsigned(b);
            return std_logic_vector(unsigned_clipping(zu, wu, zero));
        end if;
    end clip;

    ---------------------------------------------------------------
    -- REDUCTION OPERATIONS (S2) --
    --------------------------------------------------------------
    procedure s2_select(sel : in std_logic_vector(2 downto 0);
                        ra, sum_res, max_res, min_res, xor_res, msk_res : in wordv;
                        rc : out wordv) is 
    begin
        case sel is
            when "000" |
                 "100" => rc := ra;
            when "001" |
                 "101" => rc := sum_res;
            when "010" => rc := max_res;
            when "011" => rc := min_res;
            when "110" => rc := xor_res;
            when "111" => rc := msk_res;
            when others =>rc := ra;
        end case;
    end s2_select;
    
    -- set ith bit to 1 if the ith compoenent is not zero
    function to_mask(a : inter_reg_type) return wordv is
        variable c : wordv := (others => '0');
    begin
        for i in 0 to WAYS-1 loop
            if a(i) /= (a(i)'range => '0') then
                c(i) := '1';
            end if;
        end loop;
        return c;
    end to_mask;

    function sum(a : inter_reg_type; sign, sat : std_logic) return wordv is 
        variable acc : integer := 0;
    begin 
        if sign = '1' then 
            for i in 0 to WAYS-1 loop
                acc := acc + to_integer(signed(a(i)));
            end loop;
            return signed_sat(acc, wordv'length, sat);
        else 
            for i in 0 to WAYS-1 loop
                acc := acc + to_integer(unsigned(a(i)));
            end loop;
            return unsigned_sat(acc, wordv'length, sat);
        end if;
    end sum;

    --max reduction function
    function max_red(a : inter_reg_type; sign : std_logic) return wordv is
        variable acc : integer;
    begin
        if sign = '1' then 
            acc := to_integer(signed(a(0)));
            for i in 1 to WAYS-1 loop
                if to_integer(signed(a(i))) > acc then 
                    acc := to_integer(signed(a(i)));
                end if;
            end loop;
        else 
            acc := to_integer(unsigned(a(0)));
            for i in 1 to WAYS-1 loop
                if to_integer(unsigned(a(i))) > acc then 
                    acc := to_integer(unsigned(a(i)));
                end if;
            end loop;
        end if;
        return unsigned_sat(acc, wordv'length, '0');
    end max_red;

    --min reduction function
    function min_red(a : inter_reg_type; sign : std_logic) return wordv is
        variable acc : integer;
    begin
        if sign = '1' then 
            acc := to_integer(signed(a(0)));
            for i in 1 to WAYS-1 loop
                if to_integer(signed(a(i))) < acc then 
                    acc := to_integer(signed(a(i)));
                end if;
            end loop;
        else 
            acc := to_integer(unsigned(a(0)));
            for i in 1 to WAYS-1 loop
                if to_integer(unsigned(a(i))) < acc then 
                    acc := to_integer(unsigned(a(i)));
                end if;
            end loop;
        end if;
        return unsigned_sat(acc, wordv'length, '0');
    end min_red;

    function xor_red(a : inter_reg_type) return wordv is
        variable acc : vector_component;
    begin
        acc := a(0)(vector_component'range);
        for i in 1 to WAYS-1 loop
            acc := a(i)(vector_component'range) xor acc;
        end loop;
        return std_logic_vector(resize(unsigned(acc), wordv'length));
    end xor_red;

begin
    ---------------------------------------------------------------
    -- MAIN BODY --
    --------------------------------------------------------------
    genmul : for i in 0 to VLEN/DLEN-1 generate
        mul : lpmul
            port map(lpmuli(i), lpmulo(i));
        end generate genmul;


    comb: process(r, sdi, lpmulo)
        variable v : registers;
        variable op1, op2 : vector_reg_type;
        variable rs1, rs2 : vector_reg_type;
        variable s1_res : inter_reg_type;
        variable s1_msk_res : inter_reg_type;
        variable rs1_res, rs2_res, clip_wrd, nop_res, add_res, sub_res, mul_res, max_res, min_res, logic_res, shift_res: inter_reg_type;
        variable s1_alusel : std_logic_vector(2 downto 0);
        variable log_mux : std_logic_vector(2 downto 0);
        variable s2_sum_res, s2_max_res, s2_min_res, s2_xor_res, s2_msk_res: wordv;

        variable s1_sign, s1_sat, s2_sign, s2_sat : std_logic;
        variable s2_res : wordv;
    begin
        v := r;

        -- INPUT TO S1 --
        v.s1.ra := to_vector(sdi.ra);
        v.s1.rb := to_vector(sdi.rb);
        v.s1.en := sdi.rc_we; v.s1.op1 := sdi.op1; v.s1.op2 := sdi.op2;

        -- S1 TO S2 --

        -- MUX BP from memory 
        op1 := to_vector(sdi.ra); --op_mux(r.s1.ra, to_vector(sdi.bpv), sdi.bp, 0);
        op2 := to_vector(sdi.rb); --op_mux(r.s1.rb, to_vector(sdi.bpv), sdi.bp, 1);

        --Swizzling
        rs1 := swizzling(op1, sdi.ctrl.sa);
        rs2 := swizzling(op2, sdi.ctrl.sb);

        -- MUX result from computing units
        -- Sign type set
        s1_mux(r.s1.op1, s1_alusel, s1_sign);


        -- Saturation type set
        s1_sat  := r.s1.op2(2);
        -- Logic MUX
        log_mux := r.s1.op1(4) & r.s1.op1(1 downto 0);

        -- To lpmul
        for i in vector_reg_type'range loop
            lpmuli(i).opA <= rs1(i);
            lpmuli(i).opB <= rs2(i);
            lpmuli(i).sign <= s1_sign;
            lpmuli(i).mix <= r.s1.op1(3);
            lpmuli(i).sat <= s1_sat;
        end loop;
        
        -- Get result of computing units
        for i in vector_reg_type'range loop
            add_res(i) := add(rs1(i), rs2(i), s1_sign, s1_sat);
            sub_res(i) := sub(rs1(i), rs2(i), s1_sign, s1_sat);
            mul_res(i) := lpmulo(i).mul_res;
            max_res(i) := max(rs1(i), rs2(i), s1_sign);
            min_res(i) := min(rs1(i), rs2(i), s1_sign);
            shift_res(i) := shift(rs1(i), rs2(i), s1_sign, s1_sat);
            logic_res(i) := logic_op(rs1(i), rs2(i), log_mux);
            nop_res(i)   := extend(op1(i), s1_sign, high_prec_component'length);
            rs1_res(i)   := extend(rs1(i), s1_sign, high_prec_component'length);
            rs2_res(i)   := extend(rs2(i), s1_sign, high_prec_component'length);
        end loop;
        clip_wrd := to_vector(clip(to_word(op1), to_word(op2) ,s1_sign), s1_sign);

        s1_select(s1_alusel, rs2_res, add_res, sub_res, max_res,
                  min_res, logic_res, shift_res, mul_res, s1_res);
        mask(s1_res, rs1_res, sdi.ctrl.mk, sdi.ctrl.ms, s1_msk_res);

        if (r.s1.op1 = S1_NOP) or (r.s1.op1 = S1_UNOP) then
            v.s2.ra := nop_res;
        elsif (r.s1.op1 = S1_CLIP) or (r.s1.op1 = S1_UCLIP) then
            v.s2.ra := clip_wrd;
        else
            v.s2.ra := s1_msk_res;
        end if;

        v.s2.op2 := r.s1.op2; v.s2.sign := s1_sign; v.s2.en := r.s1.en;


        -- S2 TO S3 --

        -- Sign type set
        s2_sign := r.s2.sign;
        -- Saturation type set
        s2_sat  := r.s2.op2(2);
        
        s2_msk_res := to_mask(r.s2.ra);
        s2_sum_res := sum(r.s2.ra, s2_sign, s2_sat);
        s2_max_res := max_red(r.s2.ra, s2_sign);
        s2_min_res := min_red(r.s2.ra, s2_sign);
        s2_xor_res := xor_red(r.s2.ra);

        s2_select(r.s2.op2, to_word(r.s2.ra), s2_sum_res, s2_max_res, s2_min_res, s2_xor_res, s2_msk_res, s2_res);
        v.s3.rc := s2_res;


        -- S3 TO OUTPUT --
        sdo.result <= r.s3.rc;
        sdo.s1bp <= to_word(v.s2.ra);
        sdo.s2bp <= v.s3.rc;

        -- Outputs
        rin <= v;
    end process;

    ---------------------------------------------------------------
    -- DEBUG --
    --------------------------------------------------------------
-- pragma translate_off
--    dbg : process (clk)
--    begin
--        if falling_edge(clk) then
--        -- Debug S2
--            if (r.s2.en = '1') then
--                report " ---- STAGE 2 ---- ";
--                report "op: " & tost(r.s2.op2);
--                for i in vector_reg_type'range loop
--                    report "reg(" & tost(i) & "): " & tost(r.s2.ra(i));
--                end loop;
--                report "res: " & tost(rin.s3.rc);
--            end if;
--        -- Debug S1
--            if (r.s1.en = '1') then
--                report "";
--                report " New SPARROW instruction: ";
--                report " ---- STAGE 1 ---- ";
--                report "op: " & tost(r.s1.op1);
--                report "rs1: " & tost(to_word(r.s1.ra));
--                report "rs2: " & tost(to_word(r.s1.rb));
--                report "res: " & tost(to_word(rin.s2.ra));
--            end if;
--        end if;
--    end process;
-- pragma translate_on

    ---------------------------------------------------------------
    -- REGISTER UPDATING --
    --------------------------------------------------------------
    reg : process (clk) 
    begin
        if rising_edge(clk) then
            if (holdn = '1') then
                r <= rin;
            --else 
            end if;
            if (rstn = '0') then 
                r <= RRES;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------
    -- PRINT SPARROW VERSION --
    --------------------------------------------------------------
    x : process
    begin
        wait for 5 * 1 ns;
        print("sparrow: SPARROW SIMD module version " & sprw_version & ", precision: " & integer'image(DLEN) & "-bit, ways: " & integer'image(WAYS));
--        print("UMAX: " & integer'image(UMAX) & " SMAX: " & integer'image(SMAX) & " SMIN: " & integer'image(SMIN) & " BITS LOG: " & integer'image(WBIT));
        wait;
    end process;

end; 


