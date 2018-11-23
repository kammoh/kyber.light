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

entity barret_reduce_tb is
	generic(
		runner_cfg : string;
		G_EXMAX    : positive := 2**19;
		CLK_PERIOD : time     := 1 ns
	);

end entity barret_reduce_tb;

architecture TB of barret_reduce_tb is
	signal clk : std_logic := '0';
	signal rst : std_logic;
	signal a   : std_logic_vector(25 downto 0);
	signal r   : std_logic_vector(12 downto 0);

begin
	clk <= not clk after CLK_PERIOD / 2;

	rst_proc : process
	begin
		wait until falling_edge(clk);
		rst <= '1';
		wait until falling_edge(clk);
		rst <= '0';
		wait;                           -- forever
	end process rst_proc;

	br : barret_reduce
		port map(
			a => a,
			r => r
		);

	tb : process
		variable RndR : RandomPType;
		variable i    : natural;
	begin
		test_runner_setup(runner, runner_cfg);

		wait for 0 ns;                  -- make sure bins are added. -- 11
		RndR.InitSeed(RndR'instance_name);

		set_stop_level(error);          -- or failure if should continue with error

		--		show(get_logger(default_checker), display_handler, pass); -- log passing tests 

		while_test_suite_loop : while test_suite loop
			reset_checker_stat;

			if run("small_exhaustive") then
				for_i_loop : for i in 0 to G_EXMAX - 1 loop
					wait until falling_edge(clk);
					a <= std_logic_vector(to_unsigned(i, a'length));
					wait until falling_edge(clk);

					check_equal(r, i mod KYBER_Q, "Failed with a=" & to_string(a) & " " & to_string(i));
				end loop for_i_loop;

			elsif run("random_big") then
				for cnt in 0 to G_EXMAX/4 loop
					i := RndR.FavorBig(G_EXMAX, (KYBER_Q - 1)**2 + 1);
					wait until falling_edge(clk);
					a <= std_logic_vector(to_unsigned(i, a'length));
					wait until falling_edge(clk);

					check_equal(r, i mod KYBER_Q, "Failed with a=" & to_string(a) & " " & to_string(i));
				end loop;
			elsif run("random_small") then
				for cnt in 0 to G_EXMAX/4 loop
					i := RndR.FavorSmall(G_EXMAX, (KYBER_Q - 1)**2 + 1);
					wait until falling_edge(clk);
					a <= std_logic_vector(to_unsigned(i, a'length));
					wait until falling_edge(clk);

					check_equal(r, i mod KYBER_Q, "Failed with a=" & to_string(a) & " " & to_string(i));
				end loop;
			end if;

		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;

	--	test_runner_watchdog(runner, 10 ms);

end architecture TB;
