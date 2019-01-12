-- The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
-- Michaï¿½l Peeters and Gilles Van Assche. For more information, feedback or
-- questions, please refer to our website: http://keccak.noekeon.org/

-- Implementation by the designers,
-- hereby denoted as "the implementer".

-- To the extent possible under law, the implementer has waived all copyright
-- and related or neighboring rights to the source code in this file.
-- http://creativecommons.org/publicdomain/zero/1.0/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
use std.textio.all;
use work.keccak_globals.all;

library vunit_lib;
context vunit_lib.vunit_context;
--context vunit_lib.vc_context;
library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity keccak_tb is
	generic(
		runner_cfg : string;
		G_IN_FILE  : string := "../test_vectors/Sources/keccak_in.txt";
		G_OUT_FILE : string := "../test_vectors/keccak_out_compact_mid_vhdl.out.txt"
	);
end keccak_tb;

architecture tb of keccak_tb is

	-- components

	component keccak_core

		port(
			clk     : in  std_logic;
			rst_n   : in  std_logic;
			init    : in  std_logic;
			go      : in  std_logic;
			absorb  : in  std_logic;
			squeeze : in  std_logic;
			din     : in  std_logic_vector(N - 1 downto 0);
			ready   : out std_logic;
			dout    : out std_logic_vector(N - 1 downto 0));

	end component;

	-- signal declarations

	signal clk   : std_logic;
	signal rst_n : std_logic;

	signal init, go, absorb, ready, squeeze : std_logic;
	signal din, dout                        : std_logic_vector(N - 1 downto 0);

	type st_type is (initial, read_first_input, st0, st1, st1a, END_HASH1, END_HASH2, STOP);
	signal st : st_type;

begin                                   -- Rtl

	-- port map

	k_map : keccak_core port map(clk, rst_n, init, go, absorb, squeeze, din, ready, dout);

	rst_n <= '0', '1' after 19 ns;

	vu_proc : process
	begin
		test_runner_setup(runner, runner_cfg);
		wait until st = STOP;
		test_runner_cleanup(runner);
		wait;
	end process vu_proc;

	--main process
	p_main : process(clk, rst_n)
		variable counter, count_hash, num_test : integer;
		variable line_in, line_out             : line;
		variable temp                          : std_logic_vector(63 downto 0);
		file filein                            : text open read_mode is G_IN_FILE;
		file fileout                           : text open write_mode is G_OUT_FILE;
	begin
		if rst_n = '0' then             -- asynchronous rst_n (active low)
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
					-- wait one clock cycle before checking if the core is ready ro not
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
