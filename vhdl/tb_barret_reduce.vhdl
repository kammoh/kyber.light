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

entity tb_barret_reduce is
	generic(
		runner_cfg       : string;
		G_EXMAX          : positive := 2**20 - 1;
		G_IN_WIDTH       : positive := 26;
		G_OUT_WIDTH      : positive := 13;
		G_CLK_PERIOD     : time     := 1 ns;
		G_EXTRA_RND_SEED : string   := "a0W7x9@xq"
	);

end entity tb_barret_reduce;

architecture TB of tb_barret_reduce is
	signal clk : std_logic := '0';
	signal rst : std_logic;
	signal a   : std_logic_vector(G_IN_WIDTH - 1 downto 0);
	signal r   : std_logic_vector(G_OUT_WIDTH - 1 downto 0);
	
	constant exmax: positive := minimum(G_EXMAX, 2**G_IN_WIDTH - 1);

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

	br : entity work.barret_reduce
		generic map(
			G_IN_WIDTH  => G_IN_WIDTH,
			G_OUT_WIDTH => G_OUT_WIDTH
		)
		port map(
			a => a,
			r => r
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
					wait until falling_edge(clk);
					a <= std_logic_vector(to_unsigned(i, a'length));
					wait until falling_edge(clk);

					check_equal(to_integer(unsigned(r)) mod KYBER_Q, i mod KYBER_Q, "Failed with a=" & to_string(i));
				end loop for_i_loop;

			elsif run("random_big") then
				for cnt in 0 to exmax / 4 loop
					i := RndR.FavorBig(minimum(exmax, max_rand-1) , max_rand);
					wait until falling_edge(clk);
					a <= std_logic_vector(to_unsigned(i, a'length));
					wait until falling_edge(clk);

					check_equal(to_integer(unsigned(r)) mod KYBER_Q, i mod KYBER_Q, "Failed with a=" & to_string(i));
				end loop;
			elsif run("random_small") then
				for cnt in 0 to exmax / 4 loop
					i := RndR.FavorSmall(minimum(exmax, max_rand-1) , max_rand);
					wait until falling_edge(clk);
					a <= std_logic_vector(to_unsigned(i, a'length));
					wait until falling_edge(clk);

					check_equal(to_integer(unsigned(r)) mod KYBER_Q, i mod KYBER_Q, "Failed with a=" & to_string(i));
				end loop;
			elsif run("max_value") then
				i := max_rand;
				wait until falling_edge(clk);
				a <= std_logic_vector(to_unsigned(i, a'length));
				wait until falling_edge(clk);

				check_equal(to_integer(unsigned(r)) mod KYBER_Q, i mod KYBER_Q, "Failed with a=" & to_string(i));
			end if;

		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;

	test_runner_watchdog(runner, 100 ms);

end architecture TB;
