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

library poc;
use poc.ocram_sp;

entity polyvec_mac_tb is
	generic(
		runner_cfg       : string;
		G_EXMAX          : positive := 2**22;
		G_CLK_PERIOD     : time     := 1 ns;
		G_EXTRA_RND_SEED : string   := "0W7x9@"
	);
end entity polyvec_mac_tb;

architecture TB of polyvec_mac_tb is
	constant COEF_W: positive := log2ceilnz(KYBER_Q);
	constant D_BITS: positive := COEF_W;
	
	signal clk : std_logic := '0';
	signal rst : std_logic;
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

	a_mem : entity poc.ocram_sp
		generic map(
			A_BITS   => A_BITS,
			D_BITS   => D_BITS,
			FILENAME => "a.mem"
		)
		port map(
			clk => clk,
			ce  => ce,
			we  => we,
			a   => a,
			d   => d,
			q   => q
		);

	b_mem : entity poc.ocram_sp
		generic map(
			A_BITS   => A_BITS,
			D_BITS   => D_BITS,
			FILENAME => "b.mem"
		)
		port map(
			clk => clk,
			ce  => ce,
			we  => we,
			a   => a,
			d   => d,
			q   => q
		);

	c_mem : entity poc.ocram_sp
		generic map(
			A_BITS   => A_BITS,
			D_BITS   => D_BITS
		)
		port map(
			clk => clk,
			ce  => ce,
			we  => we,
			a   => a,
			d   => d,
			q   => q
		);

	pv_mult0 : entity work.polyvec_mac
		port map(
			clk     => clk,
			rst     => rst,
			a_addr  => a_addr,
			a_rdata => a_rdata,
			b_addr  => b_addr,
			b_rdata => b_rdata,
			c_read_addr  => c_addr,
			c_wdata => c_wdata,
			go      => go,
			busy    => busy
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

		while_test_suite_loop : while test_suite loop
			reset_checker_stat;

			if run("small_exhaustive") then

			end if;

		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;

	test_runner_watchdog(runner, 100 ms);

end architecture TB;
