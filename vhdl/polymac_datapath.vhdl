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
--  unit name: Datapath of Polynomial-Vector Multiplier
--              
--! @file      polymac_datapath.vhdl
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
--! @license   See License.txt
--
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--  
--! @date      <02/01/2019>
--
--! @version   <v0.1>
--
--! @details   Implemented as one-way pipeline with no back pressure, a "valid" flag goes down with valid data
--!
--
--
--! <b>Dependencies:</b>\n
--! kyber_pkg
--! (uses external divider)
--!
--! <b>References:</b>\n
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
		clk            : in  std_logic;
		rst            : in  std_logic;
		--- Control
		i_nega         : in  std_logic;
		i_ld_v         : in  std_logic; -- enable and load now
		--- Data
		--
		i_abin_valid   : in  std_logic;
		o_abin_ready   : out std_logic;
		i_ain_data     : in  T_coef_us;
		i_bin_data     : in  T_coef_us;
		--
		i_vin_data     : in  T_coef_us;
		--
		o_vout_data    : out T_coef_us;
		-- to divider
		o_remin_data   : out unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
		o_remin_valid  : out std_logic;
		i_remin_ready  : in  std_logic;
		-- from divider
		i_remout_data  : in  T_coef_us;
		i_remout_valid : in  std_logic;
		o_remout_ready : out std_logic
	);
end entity polymac_datapath;

architecture RTL of polymac_datapath is
	-- Registers/FF
	signal r_reg                            : T_coef_us;
	signal in_a_reg, in_b_reg               : T_coef_us;
	signal a_times_b_reg_0, a_times_b_reg_1 : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	-- including load a, b stage
	signal nega_delayed                     : std_logic_vector(G_PIPELINE_LEVELS - 1 downto 0);
	signal i_valid_piped                    : std_logic_vector(4 - 1 downto 0);
	signal ld_r_delayed                     : std_logic; -- just 1 cycle delay
	-- Wires
	signal a_times_b_reduced                : T_coef_us;
	signal add_sub                          : unsigned(r_reg'length + 1 downto 0);
	signal add_sub_minus_q                  : unsigned(r_reg'length downto 0);

begin

	add_sub <= ("00" & r_reg) - a_times_b_reduced when msb(nega_delayed) = '1' else ("00" & r_reg) + a_times_b_reduced;

	add_sub_minus_q <= resize(add_sub - KYBER_Q, add_sub_minus_q'length);

	--	pipe_7_gen : if G_PIPELINE_LEVELS >= 7 generate
	--		pipe_7_gen_proc : process(clk)
	--		begin
	--			if rising_edge(clk) then
	--				
	--			end if;
	--		end process;
	--	end generate;
	--	pipe_lt7_gen : if G_PIPELINE_LEVELS < 7 generate
	--		a_times_b_reg_1 <= a_times_b_reg_0;
	--	end generate pipe_lt7_gen;

	--	pipe_6_gen : if G_PIPELINE_LEVELS >= 6 generate
	--		pipe_6_gen_proc : process(clk)
	--		begin
	--			if rising_edge(clk) then
	--				in_a_reg <= i_ain_data;
	--				in_b_reg <= i_bin_data;
	--			end if;
	--		end process;
	--	end generate;
	--
	--	pipe_lt6_gen : if G_PIPELINE_LEVELS < 6 generate
	--		in_a_reg <= i_ain_data;
	--		in_b_reg <= i_bin_data;
	--	end generate pipe_lt6_gen;

	reg_proc : process(clk) is
	begin
		if rising_edge(clk) then

			if rst = '1' then
				i_valid_piped <= (others => '0');
			else
				ld_r_delayed <= i_ld_v;

				-- top pipeline
				in_a_reg <= i_ain_data;
				in_b_reg <= i_bin_data;

				a_times_b_reg_0 <= in_a_reg * in_b_reg; -- TODO replace with "multiplier module"

				a_times_b_reg_1 <= a_times_b_reg_0;

				--
				nega_delayed  <= shift_in_left(nega_delayed, i_nega);
				i_valid_piped <= shift_in_left(i_valid_piped, i_abin_valid);

				-- update the sink (bottom) register
				if ld_r_delayed = '1' then -- higher-priority (TODO why needed?) 1-cycle delay load
					r_reg <= i_vin_data;

				elsif i_remout_valid = '1' then -- ONLY when valid data coming from divider pipeline! no back-pressure here

					if msb(add_sub) = '1' then -- add_sub < 0
						r_reg <= resize(add_sub + KYBER_Q, r_reg'length);
					elsif add_sub_minus_q(r_reg'length) = '0' then -- add_sub >= q
						r_reg <= resize(add_sub_minus_q, r_reg'length);
					else
						r_reg <= resize(add_sub, r_reg'length);
					end if;
				end if;
			end if;
		end if;
	end process reg_proc;

	a_times_b_reduced <= i_remout_data;

	o_abin_ready <= i_remin_ready or not msb(i_valid_piped);

	-- control --
	o_remout_ready <= '1';              -- no back-pressure to divider

	o_remin_valid <= msb(i_valid_piped);

	-- data --
	o_vout_data  <= r_reg;
	-- to divider
	o_remin_data <= a_times_b_reg_1;

end architecture RTL;
