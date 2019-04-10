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
--! @file      slice.vhdl
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

use work.keccak_pkg.all;

entity slice_unit is
	port(
		clk             : in  std_logic;
		slice_in        : in  T_slice;
		slice_out       : out T_slice;
		bypass_iochipi  : in  std_logic;
		do_theta        : in  std_logic;
		round_const_bit : in  std_logic
	);
end entity slice_unit;

architecture RTL of slice_unit is
	---------------------------------------------------- Functions ----------------------------------------------------
	function pi(slice : T_slice) return T_slice is
		variable ret : T_slice;
	begin
		for row in 0 to 4 loop
			for col in 0 to 4 loop
				ret(ij_to_linear(row, col)) := slice(ij_to_linear(col, 3 * row + col));
			end loop;
		end loop;
		return ret;
	end function pi;

	function chi(slice : T_slice) return T_slice is
		variable ret : T_slice;
	begin
		for row in 0 to 4 loop
			for col in 0 to 4 loop
				ret(ij_to_linear(row, col)) := slice(ij_to_linear(row, col)) xor (not slice(ij_to_linear(row, col + 1)) and slice(ij_to_linear(row, col + 2)));
			end loop;
		end loop;
		return ret;
	end function chi;

	function iota_o_chi(slice : T_slice; round_constant_bit : std_logic) return T_slice is
		variable ret : T_slice;
	begin
		ret := chi(slice);
		ret(0) := ret(0) xor round_constant_bit;
		return ret;
	end function iota_o_chi;

	function parity(slice : T_slice) return T_row is
		variable ret_parity : T_row := (others => '0');
	begin
		for col in 0 to 4 loop
			for row in 0 to 4 loop
				ret_parity(col) := ret_parity(col) xor slice(ij_to_linear(row, col));
			end loop;
		end loop;
		return ret_parity;
	end function parity;

	function replicate_row_to_slice(in_row : T_row) return T_slice is
		variable ret : T_slice;
	begin
		for row in 0 to 4 loop
			ret(5 * row + 4 downto 5 * row) := in_row;
		end loop;
		return ret;
	end function replicate_row_to_slice;


	---------------------------------------------------- Registers/FF ----------------------------------------------------
	signal prev_parities_reg : T_row;
	---------------------------------------------------- Wires        ----------------------------------------------------

	signal iochipi      : T_slice;
	signal cur_parities : T_row;
	signal theta_row : T_row;
begin

	iochipi <= slice_in when bypass_iochipi = '1'  else iota_o_chi(pi(slice_in), round_const_bit);

	cur_parities <= parity(iochipi);
	theta_row <= std_logic_vector(rotate_left(signed(cur_parities), 1) xor rotate_right(signed(prev_parities_reg), 1));

	process(clk)
	begin
		if rising_edge(clk) then
			if do_theta = '1'  then
				prev_parities_reg <= cur_parities;
			end if;
		end if;
	end process;

	slice_out <= iochipi xor replicate_row_to_slice(theta_row) when do_theta = '1'  else iochipi;

end architecture RTL;
