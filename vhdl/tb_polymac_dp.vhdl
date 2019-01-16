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

entity tb_polymac_dp is
	generic(
		runner_cfg       : string;
		G_CLK_PERIOD     : time   := 1 ns;
		G_EXTRA_RND_SEED : string := "0W7x9@"
	);
end entity tb_polymac_dp;

architecture TB of tb_polymac_dp is
	signal clk    : std_logic := '0';
	signal rst    : std_logic;
	signal nega   : std_logic;
	signal r_en   : std_logic;
	signal r_load : std_logic;
	signal a      : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal b      : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal rin    : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal rout   : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
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

	tb_proc : process
		variable RndR     : RandomPType;
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

			if run("positive") then
				for_i_loop : for i in 0 to 2**12 loop
					wait until falling_edge(clk);
					nega   <= '0';
					r_en   <= '1';
					r_load <= '1';
					rin    <= RndR.RandSlv(KYBER_Q - 1, rin'length);
					wait until falling_edge(clk);
					r_load <= '0';
					a      <= RndR.RandSlv(KYBER_Q - 1, a'length);
					b      <= RndR.RandSlv(KYBER_Q - 1, b'length);
					wait until falling_edge(clk);

					check_equal(unsigned(rout), resize(((a * b) + rin) mod KYBER_Q, rout'length));

				end loop for_i_loop;
			elsif run("negative") then
				for i in 0 to 2**18 loop
					wait until falling_edge(clk);
					nega   <= '1';
					r_en   <= '1';
					r_load <= '1';
					rin    <= RndR.RandSlv(KYBER_Q - 1, rin'length);
					wait until falling_edge(clk);
					r_load <= '0';
					a      <= RndR.RandSlv(KYBER_Q - 1, a'length);
					b      <= RndR.RandSlv(KYBER_Q - 1, b'length);
					wait until falling_edge(clk);

					check_equal(  resize( ((rout) + (a * b)) mod KYBER_Q, rout'length) , resize(rin mod KYBER_Q, rout'length)
						, " for a=" & to_string(to_integer(a)) & " b=" & to_String(to_integer(b)) & " r0=" & to_string(to_integer(rin))
					);

				end loop;

			end if;

		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;

	dut : entity work.polymac_dp
		port map(
			clk    => clk,
			rst    => rst,
			nega   => nega,
			r_en   => r_en,
			r_load => r_load,
			a      => a,
			b      => b,
			rin    => rin,
			rout   => rout
		);

end architecture TB;
