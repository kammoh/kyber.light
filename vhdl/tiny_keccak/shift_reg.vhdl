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

use work.keccak_pkg.all;

entity shift_reg is
	generic(
		G_NUM_VERTICAL_IO: positive	
	);
	port(
		clk                : in  std_logic;
		-- control
		in_do_shift_en     : in  std_logic; -- enable horizontal shift in/out, horizontal rotate, or vertical shifting
		in_do_hrotate      : in  std_logic;
		in_do_vertical     : in  std_logic;
		in_do_rho_out      : in  std_logic;
		-- data
		hword_in           : in  T_halfword;
		in_rho_mod         : in  unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		hword_out          : out T_halfword;
		slice_vertical_in  : in std_logic_vector(G_NUM_VERTICAL_IO - 1 downto 0);
		slice_vertical_out : out std_logic_vector(G_NUM_VERTICAL_IO - 1 downto 0)
	);
end entity shift_reg;

architecture RTL of shift_reg is
	constant NUM_REGS : positive := C_LANE_WIDTH / T_halfword'length; -- assuming LANE_WIDTH is a multiple of half_word_type'length
	type shift_reg_array_type is array (0 to NUM_REGS - 1) of T_halfword;

	signal shift_reg_array : shift_reg_array_type;
	signal rho_in          : std_logic_vector(6 downto 0);
	signal rho_out         : std_logic_vector(3 downto 0);
begin
	name : process(clk) is
	begin
		if rising_edge(clk) then
			if in_do_shift_en = '1'  then
				if in_do_vertical = '1'  then
					for i in 0 to G_NUM_VERTICAL_IO - 1 loop
						shift_reg_array(G_NUM_VERTICAL_IO - 1 - i) <= slice_vertical_in(i) & shift_reg_array(G_NUM_VERTICAL_IO - 1 - i)(C_HALFWORD_WIDTH - 1 downto 1); -- shift UP 
					end loop;
				else                    -- horizontal shift/rotate
					if in_do_hrotate = '1'  then
						shift_reg_array(0) <= shift_reg_array(shift_reg_array_type'length - 1);
					else
						shift_reg_array(0) <= hword_in;
					end if;

					for i in 1 to shift_reg_array'length - 1 loop
						shift_reg_array(i) <= shift_reg_array(i - 1);
					end loop;
				end if;
			end if;
		end if;
	end process name;

	generate_slice_vertical_out : for i in 0 to G_NUM_VERTICAL_IO - 1 generate
		slice_vertical_out(i) <= shift_reg_array(G_NUM_VERTICAL_IO - 1 - i)(0);
	end generate generate_slice_vertical_out;

	rho_in  <= shift_reg_array(shift_reg_array'length - 2)(T_halfword'length - 2 downto 0) & shift_reg_array(shift_reg_array'length - 1);
	rho_out <= rho_in(to_integer(in_rho_mod) + 3 downto to_integer(in_rho_mod));

	hword_out <= rho_out when in_do_rho_out = '1'  else shift_reg_array(12); -- always 12

end architecture RTL;
