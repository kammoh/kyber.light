--===================================================================================================================--
-----------------------------------------------------------------------------------------------------------------------
--                                  
--                                  
--                                    8"""""o   8"""""   8""""o    8"""""o 
--                                    8     "   8        8    8    8     " 
--                                    8e        8eeeee   8eeee8o   8o     
--                                    88        88       88    8   88   ee 
--                                    88    e   88       88    8   88    8 
--                                    68eeee9   888eee   88    8   888eee8 
--                                  
--                                  
--                                  Cryptographic Engineering Research Group
--                                          George Mason University
--                                       https://cryptography.gmu.edu/
--                                  
--                                  
-----------------------------------------------------------------------------------------------------------------------
--
--  unit name: full name (shortname / entity name)
--              
--! @file      .vhdl
--
--! @brief     <file content, behavior, purpose, special usage notes>
--
--! @author    <Kamyar Mohajerani (kamyar@ieee.org)>
--
--! @company   Cryptographic Engineering Research Group, George Mason University
--
--! @project   KyberLight: Lightweight hardware implementation of CRYSTALS-KYBER PQC
--
--! @context   Post-Quantum Cryptography
--
--! @license   
--
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--  
--! @date      <02/01/2019>
--
--! @version   <v0.1>
--
--! @details   blah blah
--!
--
--
--! <b>Dependencies:</b>\n
--! <Entity Name,...>
--!
--! <b>References:</b>\n
--! <reference one> \n
--! <reference two>
--!
--! <b>Modified by:</b>\n
--! Author: Kamyar Mohajerani
-----------------------------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! <date> KM: <log>\n
--! <extended description>
-----------------------------------------------------------------------------------------------------------------------
--! @todo <next thing to do> \n
--
-----------------------------------------------------------------------------------------------------------------------
--===================================================================================================================--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package keccak_pkg is

	---------------------------------------------------------------- Functions/Procedures --------------------------------------------------------
	function ij_to_linear(i, j : natural) return natural;
	function linear_to_i(l : natural) return natural;
	function linear_to_j(l : natural) return natural;
	function is_powerof_two(n : natural) return boolean;
	function log2ceil(arg : positive) return natural;
	function reversed(slv : in std_logic_vector) return std_logic_vector;

	---------------------------------------------------------------- Constants -------------------------------------------------------------------
	constant C_LANE_WIDTH      : positive := 64;
	constant C_ROW_WIDTH       : positive := 5;
	constant C_COLUMN_WIDTH    : positive := 5;
	constant C_SLICE_WIDTH     : positive := C_ROW_WIDTH * C_COLUMN_WIDTH;
	constant C_WORD_WIDTH      : positive := 8;
	constant C_NUM_MEM_WORDS   : positive := ((C_ROW_WIDTH * C_COLUMN_WIDTH * C_LANE_WIDTH) + C_WORD_WIDTH - 1) / C_WORD_WIDTH;
	constant C_LANE0_WORDS     : positive := C_LANE_WIDTH / C_WORD_WIDTH;
	constant C_LANEPAIRS_WORDS : positive := 2 * C_LANE_WIDTH / C_WORD_WIDTH;
	constant C_HALFWORD_WIDTH  : positive := C_WORD_WIDTH / 2;
	constant C_NUM_ROUNDS      : positive := 12 + 2 * log2ceil(C_LANE_WIDTH);
	constant C_NUM_SLICEBLOCKS : positive := C_LANE_WIDTH / C_HALFWORD_WIDTH;

	---------------------------------------------------------------- Types -----------------------------------------------------------------------
	subtype T_slice is std_logic_vector(C_SLICE_WIDTH - 1 downto 0);
	subtype T_row is std_logic_vector(C_ROW_WIDTH - 1 downto 0);
	subtype T_column is std_logic_vector(C_COLUMN_WIDTH - 1 downto 0);
	subtype T_lane is std_logic_vector(C_LANE_WIDTH - 1 downto 0);
	subtype T_word is std_logic_vector(C_WORD_WIDTH - 1 downto 0);
	subtype T_halfword is std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);

end package keccak_pkg;

package body keccak_pkg is
	function ij_to_linear(i, j : natural)
	return natural is
	begin
		return  (i mod 5 ) * 5 + (j mod 5);
	end function ij_to_linear;
	
	function linear_to_i(l : natural)
	return natural is
	begin
		return l / 5;
	end function linear_to_i;
	
	function linear_to_j(l : natural)
	return natural is
	begin
		return l mod 5;
	end function linear_to_j;

	function is_powerof_two(n : natural)
	return boolean is
		variable x : unsigned(31 downto 0);
	begin
		x := to_unsigned(n, x'length);

		return (x /= 0) and ((x and (x - 1)) = 0);
	end function is_powerof_two;

	function log2ceil(arg : positive) return natural is
		variable tmp : positive;
		variable log : natural;
	begin
		if arg = 1 then
			return 0;
		end if;
		tmp := 1;
		log := 0;
		while arg > tmp loop
			tmp := tmp * 2;
			log := log + 1;
		end loop;
		return log;
	end function;

	function reversed(slv : in std_logic_vector) return std_logic_vector is
		variable result : std_logic_vector(slv'RANGE);
		alias ret       : std_logic_vector(slv'REVERSE_RANGE) is slv;
	begin
		for i in ret'RANGE loop
			result(i) := ret(i);
		end loop;
		return result;
	end;

end package body keccak_pkg;
