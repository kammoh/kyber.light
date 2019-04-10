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

entity keccak_datapath is
	port(
		clk                  : in  std_logic;
		-- from controller
		in_do_setzero_mem    : in  std_logic;
		in_do_bypass_iochipi : in  std_logic;
		in_do_theta          : in  std_logic;
		in_do_odd_lane       : in  std_logic;
		in_do_shift_en0      : in  std_logic;
		in_do_shift_en1      : in  std_logic;
		in_do_hrotate        : in  std_logic;
		in_do_vertical       : in  std_logic;
		in_do_rho_out        : in  std_logic;
		in_do_xorin             : in  std_logic;
		-- from Rho ROM through controller
		in_rho0_mod          : in  unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		in_rho1_mod          : in  unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		-- from Iota ROM
		in_iota_bit          : in  std_logic;
		-- memory
		in_data_from_mem     : in  T_word;
		out_data_to_mem      : out T_word;
		-- message/digest I/O
		din                  : in  std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
		dout                 : out std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0)
	);
end entity keccak_datapath;

architecture RTL of keccak_datapath is
	---------------------------------------------------------------- Constants -------------------------------------------------------------------

	---------------------------------------------------------------- Functions/Procedures --------------------------------------------------------
	function interleave(sig0, sig1 : T_halfword) return T_word is
		variable interleaved : T_word;
	begin
		for k in 0 to C_HALFWORD_WIDTH - 1 loop
			interleaved(2 * k)     := sig0(k);
			interleaved(2 * k + 1) := sig1(k);
		end loop;
		return interleaved;
	end function;
	---------------------------------------------------------------- Registers/FF ----------------------------------------------------------------
	---------------------------------------------------------------- Wires -----------------------------------------------------------------------
	signal hword_out_0, hword_out_1                                    : T_halfword;
	signal deinterleaved_0, deinterleaved_1                            : T_halfword;
	signal slice_unit_in, slice_unit_out                               : T_slice;
	signal shift_reg_slice_vertical_in0, shift_reg_slice_vertical_out0 : std_logic_vector(11 downto 0);
	signal shift_reg_slice_vertical_in1, shift_reg_slice_vertical_out1 : std_logic_vector(12 downto 0); 

begin

	shift_reg0 : entity work.shift_reg
		generic map(
			G_NUM_VERTICAL_IO => 12
		)
		port map(
			clk                => clk,
			--
			in_do_shift_en     => in_do_shift_en0,
			in_do_hrotate      => in_do_hrotate,
			in_do_vertical     => in_do_vertical,
			in_do_rho_out      => in_do_rho_out,
			--
			hword_in           => deinterleaved_0,
			in_rho_mod         => in_rho0_mod,
			hword_out          => hword_out_0,
			slice_vertical_in  => shift_reg_slice_vertical_in0,
			slice_vertical_out => shift_reg_slice_vertical_out0
		);

	shift_reg1 : entity work.shift_reg
		generic map(
			G_NUM_VERTICAL_IO => 13
		)
		port map(
			clk                => clk,
			--
			in_do_shift_en     => in_do_shift_en1,
			in_do_hrotate      => in_do_hrotate,
			in_do_vertical     => in_do_vertical,
			in_do_rho_out      => in_do_rho_out,
			--
			hword_in           => deinterleaved_1,
			in_rho_mod         => in_rho1_mod,
			hword_out          => hword_out_1,
			slice_vertical_in  => shift_reg_slice_vertical_in1,
			slice_vertical_out => shift_reg_slice_vertical_out1
		);

	slice_unit : entity work.slice_unit
		port map(
			clk             => clk,
			slice_in        => slice_unit_in,
			slice_out       => slice_unit_out,
			bypass_iochipi  => in_do_bypass_iochipi,
			do_theta        => in_do_theta,
			round_const_bit => in_iota_bit
		);

	process(slice_unit_out, deinterleaved_0, deinterleaved_1, din, hword_out_0, hword_out_1, in_data_from_mem, in_do_odd_lane, in_do_setzero_mem, in_do_xorin, shift_reg_slice_vertical_out0, shift_reg_slice_vertical_out1, shift_reg_slice_vertical_out1(0)) is
	begin
		for k in 0 to C_HALFWORD_WIDTH - 1 loop
			-- NOTE: odd lanes are stored in even bits
			deinterleaved_0(k) <= in_data_from_mem(2 * k);
			deinterleaved_1(k) <= in_data_from_mem(2 * k + 1);
		end loop;
		-- NOTE: odd lanes are shifted in shift_reg0
		--

		slice_unit_in(0)                <= shift_reg_slice_vertical_out1(0);
		shift_reg_slice_vertical_in1(0) <= slice_unit_out(0);
		for k in 1 to 12 loop
			slice_unit_in(2 * k - 1)        <= shift_reg_slice_vertical_out0(k - 1);
			slice_unit_in(2 * k)            <= shift_reg_slice_vertical_out1(k);
			shift_reg_slice_vertical_in0(k - 1) <= slice_unit_out(2 * k - 1);
			shift_reg_slice_vertical_in1(k) <= slice_unit_out(2 * k);
		end loop;

		-- out_data_to_mem
		if in_do_setzero_mem = '1' then
			out_data_to_mem <= (others => '0');
		elsif in_do_xorin = '1'  then
			if in_do_odd_lane = '1'  then
				out_data_to_mem <= interleave(deinterleaved_0, deinterleaved_1 xor din);
			else
				out_data_to_mem <= interleave(deinterleaved_0 xor din, deinterleaved_1);
			end if;
		else
			out_data_to_mem <= interleave(hword_out_0, hword_out_1);
		end if;
	end process;

	dout <= deinterleaved_1 when in_do_odd_lane = '1'  else deinterleaved_0;

end architecture RTL;
