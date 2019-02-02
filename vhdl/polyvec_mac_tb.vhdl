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
		G_CLK_PERIOD     : time     := 1 ns;
		G_EXTRA_RND_SEED : string   := "0W7x9@"
	);
end entity polyvec_mac_tb;

architecture TB of polyvec_mac_tb is
	
	signal clk : std_logic := '0';
	signal rst : std_logic;
	signal i_rec_a : std_logic;
	signal i_rec_b : std_logic;
	signal i_rec_r : std_logic;
	signal i_snd_r : std_logic;
	signal i_do_mac : std_logic;
	signal i_subtract : std_logic;
	signal o_done : std_logic;
	signal i_din_data : t_coef_slv;
	signal i_din_valid : std_logic;
	signal o_din_ready : std_logic;
	signal o_dout_data : t_coef_slv;
	signal o_dout_valid : std_logic;
	signal i_dout_ready : std_logic;
	signal i_ext_div_a : std_logic_vector(2 * log2ceil(KYBER_Q) - 1 downto 0);
	signal o_ext_div_a_div_q : t_coef_slv;
	signal o_ext_div_selected : std_logic;
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


	pv_mult0 : entity work.polyvec_mac
		port map(
			clk                => clk,
			rst                => rst,
			i_recv_a            => i_rec_a,
			i_recv_b            => i_rec_b,
			i_recv_r            => i_rec_r,
			i_send_r            => i_snd_r,
			i_do_mac           => i_do_mac,
			i_subtract         => i_subtract,
			o_done             => o_done,
			i_din_data         => i_din_data,
			i_din_valid        => i_din_valid,
			o_din_ready        => o_din_ready,
			o_dout_data        => o_dout_data,
			o_dout_valid       => o_dout_valid,
			i_dout_ready       => i_dout_ready,
			i_ext_div_a        => i_ext_div_a,
			o_ext_div_a_div_q  => o_ext_div_a_div_q,
			o_ext_div_selected => o_ext_div_selected
		);
		
	tb : process
		variable RndR     : RandomPType;
	begin
		test_runner_setup(runner, runner_cfg);

		wait for 0 ns;                  -- make sure bins are added. -- 11
		RndR.InitSeed(G_EXTRA_RND_SEED & RndR'instance_name);

		set_stop_level(error);          -- or failure if should continue with error

		--		show(get_logger(default_checker), display_handler, pass); -- log passing tests 

		while_test_suite_loop : while test_suite loop
			reset_checker_stat;

			if run("receive r then send") then
			
			elsif run ("r <- zeros and a, b non-zeros") then
				
			elsif run (" a, b, r non-zeros") then
			end if;

		end loop while_test_suite_loop;

		test_runner_cleanup(runner);
		wait;
	end process;


end architecture TB;
