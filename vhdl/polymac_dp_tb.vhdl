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
		G_TEST_ITERATIONS : integer := 2 ** 17
	);
end entity polymac_dp_tb;

architecture TB of polymac_dp_tb is
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
		variable RndR  : RandomPType;
		variable rin_v : std_logic_vector(rin'length - 1 downto 0);
		variable a_v   : std_logic_vector(a'length - 1 downto 0);
		variable b_v   : std_logic_vector(b'length - 1 downto 0);
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
				for i in 0 to G_TEST_ITERATIONS loop
					wait until falling_edge(clk);
					r_en   <= '1';
					r_load <= '1';
					rin_v  := RndR.RandSlv(KYBER_Q - 1, rin'length);
					rin    <= rin_v;
					wait until falling_edge(clk);
					r_load <= '0';
					r_en   <= '0';
					nega   <= '0';
					a_v    := RndR.RandSlv(KYBER_Q - 1, a'length);
					a      <= a_v;
					b_v    := RndR.RandSlv(KYBER_Q - 1, b'length);
					b      <= b_v;
					wait until falling_edge(clk);
					r_en   <= '1';
					wait until falling_edge(clk);

					check_equal(unsigned(rout), resize((rin_v + (a_v * b_v)) mod KYBER_Q, rout'length));

				end loop;
			elsif run("negative") then
				for i in 0 to G_TEST_ITERATIONS loop
					wait until falling_edge(clk);
					r_en   <= '1';
					r_load <= '1';
					rin_v  := RndR.RandSlv(KYBER_Q - 1, rin'length);
					rin    <= rin_v;
					wait until falling_edge(clk);
					r_load <= '0';
					r_en   <= '0';
					nega   <= '1';
					a_v    := RndR.RandSlv(KYBER_Q - 1, a'length);
					a      <= a_v;
					b_v    := RndR.RandSlv(KYBER_Q - 1, b'length);
					b      <= b_v;
					wait until falling_edge(clk);
					r_en   <= '1';
					wait until falling_edge(clk);

					check_equal(unsigned(rout), resize((("00" & rin) + KYBER_Q - ((a * b) mod KYBER_Q)) mod KYBER_Q, rout'length), " for a=" & to_string(to_integer(a)) & " b=" & to_String(to_integer(b)) & " r0=" & to_string(to_integer(rin))
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
			nega   => nega,
			en_r   => r_en,
			ld_r => r_load,
			in_a      => a,
			in_b      => b,
			in_r    => rin,
			out_r   => rout
		);

end architecture TB;
