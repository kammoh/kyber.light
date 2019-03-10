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
-----
-- Polynomial Vector Multiply Accumulate Datapath
--
-- Performs on Z/q
--
-- Pipelined (1-stage)
-- 
-- out_r <- in_r +/- 
-----

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity polymac_datapath is
	generic(
		G_PIPELINE_LEVELS : integer := 7 -- number of pipelining levels
	);
	port(
		clk              : in  std_logic;
		--- Control
		i_nega           : in  std_logic;
		i_en_v           : in  std_logic; -- enable piped
		i_ld_v           : in  std_logic; -- enable and load now
		--- Data
		in_a             : in  T_coef_us;
		in_b             : in  T_coef_us;
		in_v             : in  T_coef_us;
		out_v            : out T_coef_us;
		-- Div
		i_ext_div_select : in  std_logic;
		i_ext_div        : in  unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
		o_ext_div        : out T_coef_us
	);
end entity polymac_datapath;

architecture RTL of polymac_datapath is
	-- Registers/FF
	signal r_reg                            : T_coef_us;
	signal in_a_reg, in_b_reg               : T_coef_us;
	signal a_times_b_reg_0, a_times_b_reg_1 : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal nega_delayed                     : std_logic_vector(G_PIPELINE_LEVELS - 1 downto 0); -- including load a, b stage
	signal en_r_delayed                     : std_logic_vector(G_PIPELINE_LEVELS - 1 downto 0);
	signal ld_r_delayed                     : std_logic; -- just 1 cycle delay
	-- Wires
	signal divider_input                    : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal a_times_b_reduced                : T_coef_us;
	signal add_sub                          : unsigned(r_reg'length + 1 downto 0);
	signal add_sub_minus_q                  : unsigned(r_reg'length downto 0);

begin

	reduce0 : entity work.divider
		generic map(
			G_IN_WIDTH        => 2 * KYBER_COEF_BITS,
			G_PIPELINE_LEVELS => minimum(G_PIPELINE_LEVELS - 1, 3) -- we do at least one level in this module, don't decrease divider pipe levels unless G_PIPELINE_LEVELS < 4
		)
		port map(
			clk   => clk,
			i_u   => divider_input,
			o_rem => a_times_b_reduced,
			o_div => o_ext_div
		);

	divider_input <= i_ext_div when i_ext_div_select = '1'  else a_times_b_reg_1;

	add_sub         <= ("00" & r_reg) - a_times_b_reduced when nega_delayed(0) = '1'  else ("00" & r_reg) + a_times_b_reduced;
	add_sub_minus_q <= resize(add_sub - KYBER_Q, add_sub_minus_q'length);

	pipe_7_gen : if G_PIPELINE_LEVELS >= 7 generate
		pipe_7_gen_proc : process(clk)
		begin
			if rising_edge(clk) then
				a_times_b_reg_1 <= a_times_b_reg_0;
			end if;
		end process;
	end generate;
	pipe_lt7_gen : if G_PIPELINE_LEVELS < 7 generate
		a_times_b_reg_1 <= a_times_b_reg_0;
	end generate pipe_lt7_gen;

	pipe_6_gen : if G_PIPELINE_LEVELS >= 6 generate
		pipe_6_gen_proc : process(clk)
		begin
			if rising_edge(clk) then
				in_a_reg <= in_a;
				in_b_reg <= in_b;
			end if;
		end process;
	end generate;
	pipe_lt6_gen : if G_PIPELINE_LEVELS < 6 generate
		in_a_reg <= in_a;
		in_b_reg <= in_b;
	end generate pipe_lt6_gen;

	reg_proc : process(clk) is
	begin
		if rising_edge(clk) then

			-- pipeline:
			a_times_b_reg_0 <= in_a_reg * in_b_reg; -- TODO replace with mult module

			--
			nega_delayed <= i_nega & nega_delayed(nega_delayed'length - 1 downto 1);
			en_r_delayed <= i_en_v & en_r_delayed(en_r_delayed'length - 1 downto 1);
			ld_r_delayed <= i_ld_v;
			--
			if ld_r_delayed = '1'  then
				r_reg <= in_v;
			elsif en_r_delayed(0) = '1'  then
				if add_sub(add_sub'length - 1) = '1'  then -- add_sub < 0
					r_reg <= resize(add_sub + KYBER_Q, r_reg'length);
				--				elsif add_sub >= KYBER_Q then
				elsif add_sub_minus_q(r_reg'length) = '0' then -- add_sub >= q
					r_reg <= resize(add_sub_minus_q, r_reg'length);
				else
					r_reg <= resize(add_sub, r_reg'length);
				end if;
			end if;
		end if;
	end process reg_proc;

	out_v <= r_reg;
end architecture RTL;
