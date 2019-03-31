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
use work.kyber_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;
--context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity polyvec_mac_tb is
	generic(
		runner_cfg       : string;
		G_CLK_PERIOD     : time   := 10 ns;
		G_EXTRA_RND_SEED : string := "0W7x9@"
	);
end entity polyvec_mac_tb;

architecture TB of polyvec_mac_tb is

	signal clk          : std_logic := '0';
	signal rst          : std_logic;
	signal in_reset     : boolean   := true;
	signal i_rec_a      : std_logic;
	signal i_rec_b      : std_logic;
	signal i_rec_r      : std_logic;
	signal i_snd_r      : std_logic;
	signal i_do_mac     : std_logic;
	signal i_subtract   : std_logic;
	signal o_done       : std_logic;
	signal i_din_data   : T_coef_us;
	signal i_din_valid  : std_logic;
	signal o_din_ready  : std_logic;
	signal o_dout_data  : T_coef_us;
	signal o_dout_valid : std_logic;
	signal i_dout_ready : std_logic;
	signal i_rama_blk   : unsigned(log2ceilnz(1 + KYBER_K) - 1 downto 0);
   	signal i_ext_div_a        : unsigned(2 * log2ceil(KYBER_Q) - 1 downto 0);
	signal o_ext_div_a_div_q  : t_coef_us;
	signal o_ext_div_selected : std_logic;
begin

	clk <= not clk after G_CLK_PERIOD / 2;

	rst_proc : process
	begin
		in_reset <= true;
		wait until falling_edge(clk);
		rst      <= '1';
		wait until falling_edge(clk);
		rst      <= '0';
		wait until rising_edge(clk);
		in_reset <= false;
		wait;                           -- forever
	end process rst_proc;

	pv_mult0 : entity work.polyvec_mac
		port map(
			clk          => clk,
			rst          => rst,
			i_rama_blk   => i_rama_blk,
			i_recv_bb    => i_rec_a,
			i_recv_aa    => i_rec_b,
			i_recv_v     => i_rec_r,
			i_send_v     => i_snd_r,
			i_do_mac     => i_do_mac,
			i_subtract   => i_subtract,
			o_done       => o_done,
			i_din_data   => i_din_data,
			i_din_valid  => i_din_valid,
			o_din_ready  => o_din_ready,
			o_dout_data  => o_dout_data,
			o_dout_valid => o_dout_valid,
			i_dout_ready => i_dout_ready,
			i_extdiv_divin        => i_ext_div_a,
			o_extdiv_divout  => o_ext_div_a_div_q,
			o_divider_busy => o_ext_div_selected
		);

	tb : process
		variable RndR     : RandomPType;
		variable data_var : T_coef_us;
		variable count    : integer;
	begin
		test_runner_setup(runner, runner_cfg);

		wait for 0 ns;                  -- make sure bins are added. -- 11
		RndR.InitSeed(G_EXTRA_RND_SEED & RndR'instance_name);

		set_stop_level(failure);        -- or failure if should continue with error

		--		show(get_logger(default_checker), display_handler, pass); -- log passing tests 

		while_test_suite_loop : while test_suite loop
			reset_checker_stat;

			i_subtract <= '0';

			i_rec_a  <= '0';
			i_rec_b  <= '0';
			i_rec_r  <= '0';
			i_snd_r  <= '0';
			i_snd_r  <= '0';
			i_do_mac <= '0';

			i_dout_ready <= '0';
			i_din_valid  <= '0';

			i_din_data <= resize(X"1BAD", 13);

			wait until not in_reset;
			wait until rising_edge(clk);

			i_rama_blk <= (others => '0'); -- TODO

			if run("receive r then send") then
				i_rec_r <= '1';
				wait until rising_edge(clk);
				count   := 0;
				while o_done /= '1' loop
					data_var   := RndR.RandUnsigned(KYBER_Q - 1, i_din_data'length);
					i_din_data <= data_var;

					l2 : loop
						i_din_valid <= '1' when RndR.RandInt(1) = 1 else '0';
						wait until rising_edge(clk);
						if i_din_valid and o_din_ready then
							exit l2;
						end if;
					end loop;
					report "sent " & to_string(count) & " " & to_hstring(data_var);
					count := count + 1;
				end loop;

				i_rec_r <= '0';
				wait until rising_edge(clk);

				report "i_recv_r completed";

				i_snd_r <= '1';
				wait until rising_edge(clk);

				count := 0;
				while o_done /= '1' loop
					loop
						i_dout_ready <= '1' when RndR.RandInt(1) = 1 else '0';
						wait until rising_edge(clk);
						data_var     := o_dout_data;
						if i_dout_ready and o_dout_valid then
							exit;
						end if;
					end loop;
					report "received " & to_string(count) & " " & to_hstring(data_var);
					count := count + 1;
				end loop;

				report "i_send_r completed";

			elsif run("r <- zeros and a, b non-zeros") then
				for i in 0 to 1000 loop
					wait until rising_edge(clk);
				end loop;

			elsif run("a, b, r non-zeros") then
				for i in 0 to 1000 loop
					wait until rising_edge(clk);
				end loop;
			end if;

		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;

end architecture TB;
