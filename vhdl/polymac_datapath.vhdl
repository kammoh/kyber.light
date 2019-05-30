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
		G_PIPELINE_LEVELS  : integer := 7; -- number of pipelining levels
		G_INTERNAL_DIVIDER : boolean := True
	);
	port(
		clk             : in  std_logic;
		rst             : in  std_logic;
		--- Control
		i_nega          : in  std_logic;
		i_ld_v          : in  std_logic; -- enable and load now
		--- Data
		--
		i_abin_valid    : in  std_logic;
		o_abin_ready    : out std_logic;
		i_ain_data      : in  T_coef_us;
		i_bin_data      : in  T_coef_us;
		--
		i_vin_data      : in  T_coef_us;
		--
		o_vout_data     : out T_coef_us;
		-- to divider
		o_remin_data    : out unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
		o_remin_valid   : out std_logic;
		i_remin_ready   : in  std_logic;
		-- from divider
		i_remout_data   : in  T_coef_us;
		i_remout_valid  : in  std_logic;
		o_remout_ready  : out std_logic;
		--
		o_divider_empty : out std_logic
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
	--	signal add_sub                          : unsigned(r_reg'length + 1 downto 0);
	--	signal add_sub_minus_q                  : unsigned(r_reg'length downto 0);
	signal rc                               : unsigned(KYBER_COEF_BITS - 1 downto 0);
	signal mc, qc, r_signed                 : unsigned(KYBER_COEF_BITS downto 0);
	signal sc0, s1                          : unsigned(KYBER_COEF_BITS + 1 downto 0);
	--	signal ss1                              : unsigned(KYBER_COEF_BITS downto 0);
	signal sc1                              : unsigned(KYBER_COEF_BITS + 1 downto 0);
	signal neg, c0, c1                      : std_logic;
	--
	signal remin_data                       : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal remin_valid                      : std_logic;
	signal remin_ready                      : std_logic;
	signal remout_data                      : T_coef_us;
	signal remout_valid                     : std_logic;
	signal remout_ready                     : std_logic;

begin

	gen_internal_divider : if G_INTERNAL_DIVIDER generate -- used only for unit test
		internal_divider : entity work.divider
			generic map(
				G_IN_WIDTH => 2 * KYBER_COEF_BITS
			)
			port map(
				clk               => clk,
				rst               => rst,
				i_uin_data        => remin_data,
				i_uin_valid       => remin_valid,
				o_uin_ready       => remin_ready,
				o_remout_data     => remout_data,
				o_remdivout_valid => remout_valid,
				i_remdivout_ready => remout_ready
			);

		o_divider_empty <= not remout_valid;

	end generate;

	gen_external_divider_connect : if not G_INTERNAL_DIVIDER generate
		o_remin_data   <= remin_data;
		o_remin_valid  <= remin_valid;
		remin_ready    <= i_remin_ready;
		--
		remout_data    <= i_remout_data;
		remout_valid   <= i_remout_valid;
		o_remout_ready <= remout_ready;

		o_divider_empty <= not i_remout_valid;

	end generate;

	r_signed <= "0" & r_reg;

	neg <= msb(nega_delayed);
	mc  <= ("0" & a_times_b_reduced) xor (mc'length - 1 downto 0 => neg);
	qc  <= to_unsigned(KYBER_Q + 1, qc'length) when neg = '1' else unsigned(to_signed(0 - KYBER_Q, qc'length));

	sc0 <= ("00" & r_reg) + (mc(mc'length - 1) & mc) + ("0" & neg);
	c0  <= sc0(sc0'length - 1);

	-- 1:
	--	carry_save_adder(r_signed, mc, qc, s1);
	-- 2:
	sc1 <= "0" & r_signed + (mc(mc'length - 1) & mc) + (qc(qc'length - 1) & qc);
	s1  <= sc1(s1'length - 1 downto 0);
	-- /

	c1 <= s1(rc'length);
	rc <= s1(rc'length - 1 downto 0) when ((not neg and not c1) or (neg and c0)) = '1' else sc0(r_reg'length - 1 downto 0);

	--	add_sub <= ("00" & r_reg) - a_times_b_reduced when msb(nega_delayed) = '1' else ("00" & r_reg) + a_times_b_reduced;
	--
	--	add_sub_minus_q <= resize(add_sub - KYBER_Q, add_sub_minus_q'length);

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

				elsif remout_valid = '1' then -- ONLY when valid data coming from divider pipeline! no back-pressure here

					--					if msb(add_sub) = '1' then -- add_sub < 0
					--						r_reg <= resize(add_sub + KYBER_Q, r_reg'length);
					--					elsif add_sub_minus_q(r_reg'length) = '0' then -- add_sub >= q
					--						r_reg <= resize(add_sub_minus_q, r_reg'length);
					--					else
					--						r_reg <= resize(add_sub, r_reg'length);
					--					end if;
					r_reg <= rc;

				end if;
			end if;
		end if;
	end process reg_proc;

	a_times_b_reduced <= remout_data;

	o_abin_ready <= remin_ready or not msb(i_valid_piped);

	-- control --
	remout_ready <= '1';                -- no back-pressure to divider

	remin_valid <= msb(i_valid_piped);

	-- data --
	o_vout_data <= r_reg;
	-- to divider
	remin_data  <= a_times_b_reg_1;

end architecture RTL;
