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
--! @details   
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
use work.kyber_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;

--context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity divider_tb is
	generic(
		runner_cfg       : string;
		G_EXMAX          : positive := 2**19 - 1;
		G_IN_WIDTH       : positive := 26; -- FIXME only works for 26 now :(
		G_CLK_PERIOD     : time     := 1 ns;
		G_EXTRA_RND_SEED : string   := "a0W7"
	);

end entity divider_tb;

architecture TB of divider_tb is
	signal clk : std_logic := '0';
	signal rst : std_logic;

	constant exmax           : positive := minimum(G_EXMAX, 2**G_IN_WIDTH - 1);
	signal i_uin_data        : unsigned(G_IN_WIDTH - 1 downto 0);
	signal i_uin_valid       : std_logic;
	signal o_uin_ready       : std_logic;
	signal o_remout_data     : T_coef_us;
	signal o_divout_data     : unsigned(G_IN_WIDTH - KYBER_COEF_BITS - 1 downto 0);
	signal o_remdivout_valid : std_logic;
	signal i_remdivout_ready : std_logic;

begin
	clk <= not clk after G_CLK_PERIOD / 2;

	rst_proc : process
	begin
		wait until falling_edge(clk);
		rst <= '1';
		wait until falling_edge(clk);
		rst <= '0';
		wait;                           -- forever
	end process rst_proc;

	divider_inst : entity work.divider
		generic map(
			G_IN_WIDTH => G_IN_WIDTH
		)
		port map(
			clk               => clk,
			rst               => rst,
			i_uin_data        => i_uin_data,
			i_uin_valid       => i_uin_valid,
			o_uin_ready       => o_uin_ready,
			o_remout_data     => o_remout_data,
			o_divout_data     => o_divout_data,
			o_remdivout_valid => o_remdivout_valid,
			i_remdivout_ready => i_remdivout_ready
		);

	tb : process
		variable RndR     : RandomPType;
		variable i        : natural;
		variable max_rand : positive;
	begin
		test_runner_setup(runner, runner_cfg);

		wait for 0 ns;                  -- make sure bins are added. -- 11
		RndR.InitSeed(G_EXTRA_RND_SEED & RndR'instance_name);

		set_stop_level(error);          -- or failure if should continue with error

		--		show(get_logger(default_checker), display_handler, pass); -- log passing tests 

		if G_IN_WIDTH = 26 then
			max_rand := (KYBER_Q - 1)**2;
		elsif G_IN_WIDTH = 27 then
			max_rand := (KYBER_Q - 1)**2 + KYBER_Q - 1;
		else
			max_rand := 2**G_IN_WIDTH - 1;
		end if;

		while_test_suite_loop : while test_suite loop
			reset_checker_stat;

			if run("small_exhaustive") then
				for_i_loop : for i in 0 to exmax loop
					i_uin_valid       <= '0';
					i_remdivout_ready <= '0';
					wait until falling_edge(clk);
					wait until falling_edge(clk);
					i_uin_data        <= to_unsigned(i, i_uin_data);
					i_uin_valid       <= '1';
					i_remdivout_ready <= '1';
					while i_remdivout_ready /= '1' or o_remdivout_valid /= '1' loop
						wait until rising_edge(clk);
						i_uin_valid <= '0';
					end loop;

					check_equal(to_integer(unsigned(o_remout_data)), i mod KYBER_Q, "Failed with a=" & to_string(i));
					check_equal(to_integer(unsigned(o_divout_data)), i / KYBER_Q, "Failed with a=" & to_string(i));

					while o_remdivout_valid = '1' loop
						wait until rising_edge(clk);
					end loop;
				end loop for_i_loop;

			elsif run("random_big") then
				for cnt in 0 to exmax / 2 loop
					i                 := RndR.FavorBig(minimum(exmax, max_rand - 1), max_rand);
					i_uin_valid       <= '0';
					i_remdivout_ready <= '0';
					wait until falling_edge(clk);
					wait until falling_edge(clk);
					i_uin_data        <= to_unsigned(i, i_uin_data);
					i_uin_valid       <= '1';
					i_remdivout_ready <= '1';
					while i_remdivout_ready /= '1' or o_remdivout_valid /= '1' loop
						wait until rising_edge(clk);
						i_uin_valid <= '0';
					end loop;

					check_equal(to_integer(unsigned(o_remout_data)), i mod KYBER_Q, "Failed with a=" & to_string(i));
					check_equal(to_integer(unsigned(o_divout_data)), i / KYBER_Q, "Failed with a=" & to_string(i));

					while o_remdivout_valid = '1' loop
						wait until rising_edge(clk);
					end loop;

				end loop;
			elsif run("random_small") then
				for cnt in 0 to exmax / 2 loop
					i                 := RndR.FavorSmall(minimum(exmax, max_rand - 1), max_rand);
					i_remdivout_ready <= '0';
					wait until falling_edge(clk);
					wait until falling_edge(clk);
					i_uin_data        <= to_unsigned(i, i_uin_data);
					i_uin_valid       <= '1';
					i_remdivout_ready <= '1';
					while i_remdivout_ready /= '1' or o_remdivout_valid /= '1' loop
						wait until rising_edge(clk);
						i_uin_valid <= '0';
					end loop;

					check_equal(to_integer(unsigned(o_remout_data)), i mod KYBER_Q, "Failed with a=" & to_string(i));
					check_equal(to_integer(unsigned(o_divout_data)), i / KYBER_Q, "Failed with a=" & to_string(i));

					while o_remdivout_valid = '1' loop
						wait until rising_edge(clk);
					end loop;
				end loop;
			elsif run("max_value") then
				i                 := max_rand;
				i_remdivout_ready <= '0';
				wait until falling_edge(clk);
				wait until falling_edge(clk);
				i_uin_data        <= to_unsigned(i, i_uin_data);
				i_uin_valid       <= '1';
				i_remdivout_ready <= '1';
				while i_remdivout_ready /= '1' or o_remdivout_valid /= '1' loop
					wait until rising_edge(clk);
					i_uin_valid <= '0';
				end loop;

				check_equal(to_integer(unsigned(o_remout_data)), i mod KYBER_Q, "Failed with a=" & to_string(i));
				check_equal(to_integer(unsigned(o_divout_data)), i / KYBER_Q, "Failed with a=" & to_string(i));

				while o_remdivout_valid = '1' loop
					wait until rising_edge(clk);
				end loop;
			end if;

		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;

	--	test_runner_watchdog(runner, 1000 ms);

end architecture TB;
