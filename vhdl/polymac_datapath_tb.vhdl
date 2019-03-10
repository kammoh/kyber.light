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
		G_CLK_PERIOD      : time     := 1 ns;
		G_PIPELINE_LEVELS : positive := 7;
		G_EXTRA_RND_SEED  : string   := "3.14159265";
		G_TEST_ITERATIONS : integer  := 2 ** 14
	);
end entity polymac_dp_tb;

architecture TB of polymac_dp_tb is
	signal clk              : std_logic := '0';
	signal rst              : std_logic;
	signal nega             : std_logic;
	signal r_en             : std_logic;
	signal r_load           : std_logic;
	signal a                : T_coef_us;
	signal b                : T_coef_us;
	signal rin              : T_coef_us;
	signal rout             : T_coef_us;
	signal i_ext_div_select : std_logic;
	signal i_ext_div        : unsigned(2 * log2ceil(KYBER_Q) - 1 downto 0);
	signal o_ext_div        : T_coef_us;
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
		variable RndR      : RandomPType;
		variable rin_v     : T_coef_us;
		variable a_v       : T_coef_us;
		variable b_v       : T_coef_us;
      variable ext_div_v : unsigned(2 * log2ceil(KYBER_Q) - 1 downto 0);
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

			i_ext_div_select <= '0';

			if run("Add  r <= r + a.b") then
				for i in 0 to G_TEST_ITERATIONS loop
					wait until falling_edge(clk);
					r_en   <= '0';
					r_load <= '1';
					rin_v  := RndR.RandUnsigned(KYBER_Q - 1, rin'length);
					rin    <= rin_v;
					wait until falling_edge(clk);
					r_load <= '0';
					r_en   <= '1';
					nega   <= '0';
					a_v    := RndR.RandUnsigned(KYBER_Q - 1, a'length);
					a      <= a_v;
					b_v    := RndR.RandUnsigned(KYBER_Q - 1, b'length);
					b      <= b_v;
					wait until falling_edge(clk);
					r_en   <= '0';
					wait until falling_edge(clk);
					
					for p in 0 to G_PIPELINE_LEVELS loop
						wait until falling_edge(clk);
					end loop;

					check_equal(unsigned(rout), resize((rin_v + (a_v * b_v)) mod KYBER_Q, rout'length));

				end loop;
			elsif run("Subtract r <= r - a.b") then
				for i in 0 to G_TEST_ITERATIONS loop
					wait until falling_edge(clk);
					r_en   <= '0';
					r_load <= '1';
					rin_v  := RndR.RandUnsigned(KYBER_Q - 1, rin'length);
					rin    <= rin_v;
					wait until falling_edge(clk);
					r_load <= '0';
					nega   <= '1';
					r_en   <= '1';
					a_v    := RndR.RandUnsigned(KYBER_Q - 1, a'length);
					a      <= a_v;
					b_v    := RndR.RandUnsigned(KYBER_Q - 1, b'length);
					b      <= b_v;
					wait until falling_edge(clk);
					r_en   <= '0';
					
					for p in 0 to G_PIPELINE_LEVELS loop
						wait until falling_edge(clk);
					end loop;

					check_equal(unsigned(rout), resize((("00" & rin) + KYBER_Q - ((a * b) mod KYBER_Q)) mod KYBER_Q, rout'length), " for a=" & to_string(to_integer(a)) & " b=" & to_String(to_integer(b)) & " r0=" & to_string(to_integer(rin))
					);
				end loop;
			elsif run("External access to divider") then
				for i in 0 to 2 * G_TEST_ITERATIONS loop
					i_ext_div_select <= '1';
					ext_div_v        := RndR.RandUnsigned(2**log2ceil(KYBER_Q) * (KYBER_Q - 1), i_ext_div'length);
					i_ext_div        <= ext_div_v;
					for p in 0 to G_PIPELINE_LEVELS - 2 loop
						wait until falling_edge(clk);
					end loop;
					check_equal(unsigned(o_ext_div), ext_div_v / KYBER_Q);
				end loop;
			end if;

		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;

	dut : entity work.polymac_datapath
		generic map(
			G_PIPELINE_LEVELS => G_PIPELINE_LEVELS
		)
		port map(
			clk              => clk,
			i_nega           => nega,
			i_en_v           => r_en,
			i_ld_v           => r_load,
			in_a             => a,
			in_b             => b,
			in_v             => rin,
			out_v            => rout,
			i_ext_div_select => i_ext_div_select,
			i_ext_div        => i_ext_div,
			o_ext_div        => o_ext_div
		);

end architecture TB;
