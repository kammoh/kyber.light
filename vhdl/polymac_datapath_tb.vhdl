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
--  unit name: Abandoned! Does not work any more!
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
use ieee.numeric_std_unsigned.all;
use work.kyber_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;
--context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity polymac_dp_tb is
	generic(
		runner_cfg        : string;
		G_CLK_PERIOD      : time    := 1 ns;
		G_EXTRA_RND_SEED  : string  := "3.14159265";
		G_TEST_ITERATIONS : integer := 2 ** 14
	);
end entity polymac_dp_tb;

architecture TB of polymac_dp_tb is
	signal clk            : std_logic := '0';
	signal rst            : std_logic;
	signal nega           : std_logic;
	signal in_valid       : std_logic;
	signal r_load         : std_logic;
	signal a              : T_coef_us;
	signal b              : T_coef_us;
	signal rin            : T_coef_us;
	signal o_vout_data    : T_coef_us;
	signal o_remin_data   : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal o_remin_valid  : std_logic;
	signal i_remout_valid : std_logic;
	signal i_remin_ready  : std_logic;
	signal i_remout_data : T_coef_us;
begin
	clk <= not clk after G_CLK_PERIOD / 2;

	reset_proc : process
	begin
		wait until falling_edge(clk);
		rst <= '1';
		wait until falling_edge(clk);
		rst <= '0';
		wait;                           -- forever
	end process reset_proc;

	tb_proc : process
		variable RndR  : RandomPType;
		variable rin_v : T_coef_us;
		variable a_v   : T_coef_us;
		variable b_v   : T_coef_us;
	begin
		test_runner_setup(runner, runner_cfg);

		wait for 0 ns;                  -- make sure bins are added. -- 11
		RndR.InitSeed(G_EXTRA_RND_SEED & RndR'instance_name);

		set_stop_level(error);          -- or failure if should continue with error

		--		show(get_logger(default_checker), display_handler, pass); -- log passing tests 

		while_test_suite_loop : while test_suite loop
			reset_checker_stat;

			wait until rst = '0';
			wait for 2 * G_CLK_PERIOD;

			if run("Add  r <= r + a.b") then
				for i in 0 to G_TEST_ITERATIONS loop
					wait until falling_edge(clk);
					nega     <= '0';
					in_valid <= '0';
					r_load   <= '1';
					rin_v    := RndR.RandUnsigned(KYBER_Q - 1, rin'length);
					rin      <= rin_v;
					wait until rising_edge(clk);
					wait until falling_edge(clk);
					in_valid <= '1';
					r_load   <= '0';
					a_v      := RndR.RandUnsigned(KYBER_Q - 1, a'length);
					a        <= a_v;
					b_v      := RndR.RandUnsigned(KYBER_Q - 1, b'length);
					b        <= b_v;
					wait until falling_edge(clk);
					in_valid <= '0';
					
					for p in 0 to P_DIVIDER_PIPELINE_LEVELS + 3 loop
						wait until falling_edge(clk);
					end loop;

					check_equal(unsigned(o_vout_data), resize((rin_v + (a_v * b_v)) mod KYBER_Q, o_vout_data'length));

				end loop;
			elsif run("Subtract r <= r - a.b") then
				for i in 0 to G_TEST_ITERATIONS loop
					wait until falling_edge(clk);
					nega     <= '1';
					in_valid <= '0';
					r_load   <= '1';
					rin_v    := RndR.RandUnsigned(KYBER_Q - 1, rin'length);
					rin      <= rin_v;
					wait until rising_edge(clk);
					wait until falling_edge(clk);
					in_valid <= '1';
					r_load   <= '0';
					a_v      := RndR.RandUnsigned(KYBER_Q - 1, a'length);
					a        <= a_v;
					b_v      := RndR.RandUnsigned(KYBER_Q - 1, b'length);
					b        <= b_v;
					wait until falling_edge(clk);
					in_valid <= '0';
					
					for p in 0 to P_DIVIDER_PIPELINE_LEVELS + 3 loop
						wait until falling_edge(clk);
					end loop;
					
					check_equal(unsigned(o_vout_data), resize((("00" & rin) + KYBER_Q - ((a * b) mod KYBER_Q)) mod KYBER_Q, o_vout_data'length), " for a=" & to_string(to_integer(a)) & " b=" & to_String(to_integer(b)) & " r0=" & to_string(to_integer(rin))
					);
				end loop;
				nega     <= '0';

			end if;
		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;

	dut : entity work.polymac_datapath
		port map(
			clk            => clk,
			rst            => rst,
			i_nega         => nega,
			i_ld_v         => r_load,
			i_abin_valid   => in_valid,
			i_ain_data     => a,
			i_bin_data     => b,
			i_vin_data     => rin,
			o_vout_data    => o_vout_data,
			o_remin_data   => o_remin_data,
			o_remin_valid  => o_remin_valid,
			i_remin_ready  => i_remin_ready,
			i_remout_data  => i_remout_data,
			i_remout_valid => i_remout_valid
		);
end architecture TB;
