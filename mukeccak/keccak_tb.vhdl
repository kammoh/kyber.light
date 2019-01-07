
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;
use work.keccak_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;
--context vunit_lib.vc_context;
library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity keccak_tb is
	generic(
		runner_cfg : string;
		G_IN_FILE  : string := "../../keccak/test_vectors/Sources/keccak_in.txt";
		G_OUT_FILE : string := "../../keccak/test_vectors/keccak_out_compact_mid_vhdl.out.txt"
	);
end keccak_tb;

architecture tb of keccak_tb is


	-- signal declarations

	signal clk   : std_logic;
	signal rst : std_logic;

	signal init, go, absorb, ready, squeeze : std_logic;
	signal din, dout                        : std_logic_vector(C_WORD_WIDTH - 1 downto 0);

	type st_type is (initial, read_first_input, st0, st1, st1a, END_HASH1, END_HASH2, STOP);
	signal st : st_type;
	signal do_squeeze : std_logic;
	signal din_valid : std_logic;
	signal din_ready : std_logic;
	signal dout_valid : std_logic;
	signal dout_ready : std_logic;
	signal from_mem_dout : std_logic_vector(C_WORD_WIDTH - 1 downto 0);
	signal to_mem_din : std_logic_vector(C_WORD_WIDTH - 1 downto 0);
	signal mem_addr : unsigned(log2ceil(C_NUM_MEM_WORDS) - 1 downto 0);
	signal mem_we : std_logic;
	signal mem_re : std_logic;

begin                                   -- Rtl

	-- port map

	keccak: entity work.keccak_core
		port map(
			do_squeeze => do_squeeze,
			clk           => clk,
			rst           => rst,
			din           => din,
			din_valid     => din_valid,
			din_ready     => din_ready,
			dout          => dout,
			dout_valid    => dout_valid,
			dout_ready    => dout_ready,
			from_mem_dout => from_mem_dout,
			to_mem_din    => to_mem_din,
			mem_addr      => mem_addr,
			mem_we        => mem_we,
			mem_re        => mem_re
		);

	rst <= '1', '0' after 19 ns;

	vu_proc : process
	begin
		test_runner_setup(runner, runner_cfg);
		wait until st = STOP;
		test_runner_cleanup(runner);
		wait;
	end process vu_proc;

	--main process
	p_main : process(clk, rst)
		variable counter, count_hash, num_test : integer;
		variable line_in, line_out             : line;
		variable temp                          : std_logic_vector(63 downto 0);
		file filein                            : text open read_mode is G_IN_FILE;
		file fileout                           : text open write_mode is G_OUT_FILE;
	begin
		if rst = '1' then             -- asynchronous rst_n (active low)
			st         <= initial;
			counter    := 0;
			din        <= (others => '0');
			count_hash := 0;
			init       <= '0';
			absorb     <= '0';
			squeeze    <= '0';
			go         <= '0';

		elsif rising_edge(clk) then
			case st is
				when initial =>
					readline(filein, line_in);
					read(line_in, num_test);
					st   <= read_first_input;
					init <= '1';

				when read_first_input =>
					init <= '0';
					readline(filein, line_in);
					if endfile(filein) or (line_in(1) = '.') then
						FILE_CLOSE(filein);
						FILE_CLOSE(fileout);

						st <= STOP;
					--						assert false report "Simulation completed" severity failure;

					else
						if (line_in(1) = '-') then
							st <= END_HASH1;

						else
							hread(line_in, temp);
							din    <= temp;
							absorb <= '1';

							st      <= st0;
							counter := 0;
						end if;

					end if;

				when st0 =>

					if (counter < 16) then
						if (counter < 15) then
							readline(filein, line_in);
							hread(line_in, temp);
							din    <= temp;
							absorb <= '1';
						end if;

						counter := counter + 1;
						st      <= st0;
					else
						st     <= st1;
						absorb <= '0';
						go     <= '1';
					end if;
				when st1 =>
					go <= '0';
					-- wait one clock cycle before checking if the core is ready or not
					st <= st1a;
				when st1a =>
					if (ready = '0') then

						st <= st1;
					else
						st <= read_first_input;
					end if;
				when END_HASH1 =>
					if (ready = '0') then
						st <= END_HASH1;
					else
						squeeze <= '1';
						st      <= END_HASH2;
						counter := 0;
					end if;
				when END_HASH2 =>
					squeeze <= '1';

					temp := dout;
					hwrite(line_out, temp);
					writeline(fileout, line_out);
					if (counter < 3) then
						counter := counter + 1;
					else
						squeeze <= '0';
						init    <= '1';
						st      <= read_first_input;
						write(line_out, string'("-"));
						writeline(fileout, line_out);
					end if;
				when STOP =>
					null;
			end case;

		end if;
	end process;

	-- clock generation
	clkgen : process
	begin
		clk <= '1';
		loop
			wait for 10 ns;
			clk <= not clk;
		end loop;
	end process;

end tb;
