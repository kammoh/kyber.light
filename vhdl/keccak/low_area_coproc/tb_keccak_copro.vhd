-- The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
-- Micha�l Peeters and Gilles Van Assche. For more information, feedback or
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

--library vunit_lib;
--context vunit_lib.vunit_context;
----context vunit_lib.vc_context;
--
--library osvvm;
--use osvvm.RandomPkg.all;
--use osvvm.CoveragePkg.all;

use work.keccak_globals.all;

entity keccak_coproc_tb is
	generic(
		runner_cfg   : string := ""
	);
end keccak_coproc_tb;

architecture tb of keccak_coproc_tb is

	-- components
	component keccak_copro
		port(
			clk           : in  std_logic;
			rst_n         : in  std_logic;
			start         : in  std_logic;
			addr          : out addr_type;
			enR           : out std_logic;
			enW           : out std_logic;
			data_from_mem : in  std_logic_vector(63 downto 0);
			data_to_mem   : out std_logic_vector(63 downto 0);
			done          : out std_logic
		);
	end component;

	component system_mem
		port(
			clk        : in  std_logic;
			rst_n      : in  std_logic;
			enR        : in  std_logic;
			enW        : in  std_logic;
			addr       : in  addr_type;
			mem_input  : in  std_logic_vector(63 downto 0);
			mem_output : out std_logic_vector(63 downto 0)
		);
	end component;

	-- signal declarations

	signal clk                                                                 : std_logic;
	signal rst_n                                                               : std_logic;
	signal start, enR_mem, enR_copro, enR_tb, enW_mem, enW_copro, enW_tb, done : std_logic;
	signal data_from_mem, data_to_mem_mem, data_to_mem_copro, data_to_mem_tb   : std_logic_vector(63 downto 0);
	signal addr_mem, addr_copro, addr_tb                                       : addr_type;

	signal counter : integer range 0 to 25;

	type st_type is (st0, st1, st2, st3, st4, STOP);
	signal st : st_type;

begin                                   -- Rtl

	-- port map

	coprocessor_map : keccak_copro port map(clk, rst_n, start, addr_copro, enR_copro, enW_copro, data_from_mem, data_to_mem_copro, done);
	mem_map : system_mem port map(clk, rst_n, enR_mem, enW_mem, addr_mem, data_to_mem_mem, data_from_mem);

	rst_n <= '0', '1' after 19 ns;

	--main process

	tbgen : process(clk, rst_n)
		variable line_in  : line;
		variable line_out : line;

--		variable datain0 : std_logic_vector(15 downto 0);
		variable temp    : std_logic_vector(63 downto 0);
--		variable temp2   : std_logic_vector(63 downto 0);

		file filein  : text open read_mode is "../test_vectors/perm_in.txt";
		file fileout : text open write_mode is "../test_vectors/perm_out_copro_vhdl.txt";

	begin
		if (rst_n = '0') then
			st      <= st0;
			--round_in <= (others=>'0');
			counter <= 0;
			start   <= '0';
			addr_tb <= 0;

		elsif (clk'event and clk = '1') then

			----------------------
			case st is
				when st0 =>
					--continue to read up to the end of file marker.
					readline(filein, line_in);
					if (line_in(1) = '.') then
						FILE_CLOSE(filein);
						FILE_CLOSE(fileout);
						assert false report "Simulation completed" severity failure;
						st <= STOP;
					else
						if (line_in(1) = '-') then
							st    <= st1;
							start <= '1';
						--direct memory to copro

						else

							enW_tb <= '1';
							enR_tb <= '0';

							hread(line_in, temp);
							data_to_mem_tb <= temp;
							counter        <= counter + 1;

							addr_tb <= counter;

						end if;

					end if;
				when st1 =>
					start <= '0';

					-- wait for done
					if (done = '1') then
						st      <= st2;
						counter <= 1;
						addr_tb <= 0;
						enR_tb  <= '1';
						enW_tb  <= '0';

					end if;
				when st2 =>
					st      <= st3;
					addr_tb <= counter;
					counter <= counter + 1;

				when st3 =>
					--write to file memory content
					if counter = 25 then
						st      <= st4;
						counter <= 0;
						temp    := data_from_mem;
						hwrite(line_out, temp);
						writeline(fileout, line_out);

					else
						addr_tb <= counter;
						counter <= counter + 1;
						--set addr
						--read from mem

						temp := data_from_mem;
						hwrite(line_out, temp);
						writeline(fileout, line_out);

					end if;
				when st4 =>
					temp := data_from_mem;
					hwrite(line_out, temp);
					writeline(fileout, line_out);

					write(fileout, string'("-"));
					writeline(fileout, line_out);
					addr_tb <= 0;
					st      <= st0;

				when STOP =>
					null;
			end case;
		end if;
	end process;
	enR_mem         <= enR_copro when st = st1 else enR_tb;
	enw_mem         <= enW_copro when st = st1 else enW_tb;
	data_to_mem_mem <= data_to_mem_copro when st = st1 else data_to_mem_tb;

	addr_mem <= addr_copro when st = st1 else addr_tb;

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
