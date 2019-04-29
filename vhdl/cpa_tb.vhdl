library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.kyber_pkg.all;

entity cpa_tb is
end entity cpa_tb;

architecture RTL of cpa_tb is
	constant PDI_FILENAME : string := "pdi.in.txt";
	constant SDI_FILENAME : string := "sdi.in.txt";
	constant SDO_FILENAME : string := "sdo.out.txt";
	constant CLOCK_PERIOD : time   := 10 ns;

	signal o_done : std_logic;

	signal clk : std_logic;
	signal rst : std_logic;

	type T_state is (init, send_sk, send_sk_done, decrypt, encrypt_done);
	signal state : T_state;

	signal reseted     : boolean := False;
	signal i_command   : unsigned(C_CPA_CMD_BITS - 1 downto 0);
	signal i_rdi_data  : T_byte_slv;
	signal i_rdi_valid : std_logic;
	signal o_rdi_ready : std_logic;
	signal i_pdi_data  : T_byte_slv;
	signal i_pdi_valid : std_logic;
	signal o_pdi_ready : std_logic;
	signal i_sdi_data  : T_byte_slv;
	signal i_sdi_valid : std_logic;
	signal o_sdi_ready : std_logic;
	signal o_pdo_data  : T_byte_slv;
	signal o_pdo_valid : std_logic;
	signal i_pdo_ready : std_logic;
	signal o_sdo_data  : T_byte_slv;
	signal o_sdo_valid : std_logic;
	signal i_sdo_ready : std_logic;
begin

	clkgen_proc : process
	begin
		clk <= '1';
		loop
			wait for CLOCK_PERIOD / 2;
			clk <= not clk;
		end loop;
	end process;

	rstgen_proc : process
	begin
		rst     <= '0';
		wait until rising_edge(clk);
		wait until falling_edge(clk);
		rst     <= not rst;
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until falling_edge(clk);
		rst     <= not rst;
		reseted <= True;
		wait;                           -- forever
	end process;

	pk_at_input : process
		file filein      : text;
		variable line_in : line;
		variable temp    : std_logic_vector(7 downto 0);
	begin
		file_open(filein, PDI_FILENAME, read_mode);
		while not endfile(filein) loop
			readline(filein, line_in);
			hread(line_in, temp);
			i_pdi_data <= temp;
			wait until rising_edge(clk) and i_pdi_valid = '1' and o_pdi_ready = '1';
		end loop;
		file_close(filein);
		wait;                           -- forever
	end process;

	pt_input : process
		file filein      : text;
		variable line_in : line;
		variable temp    : std_logic_vector(7 downto 0);
	begin
		file_open(filein, SDI_FILENAME, read_mode);
		while not endfile(filein) loop
			readline(filein, line_in);
			hread(line_in, temp);
			i_sdi_data <= temp;
			wait until rising_edge(clk) and i_sdi_valid = '1' and o_sdi_ready = '1';
		end loop;
		file_close(filein);
		wait;                           -- forever
	end process;

	--	coins_input : process
	--		file filein      : text;
	--		variable line_in : line;
	--		variable temp    : std_logic_vector(7 downto 0);
	--	begin
	--		file_open(filein, COINS_IN_FILENAME, read_mode);
	--
	--		while not endfile(filein) loop
	--			readline(filein, line_in);
	--			hread(line_in, temp);
	--			i_coins_data <= temp;
	--			wait until rising_edge(clk) and i_coins_valid = '1' and o_coins_ready = '1';
	--		end loop;
	--		file_close(filein);
	--		wait;                           -- forever
	--	end process;

	fsm_proc : process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= init;
			else

				case state is
					when init =>
						if reseted then
							state <= send_sk;
						end if;
					when send_sk =>
						if o_done = '1' then
							state <= send_sk_done;
						end if;

					when send_sk_done =>
						state <= decrypt;

					when decrypt =>
						if o_done = '1' then
							state <= encrypt_done;
						end if;
					when encrypt_done =>
						assert false report "Done!" severity failure;
				end case;

			end if;
		end if;
	end process;

	comb_proc : process(state)
	begin
		i_sdo_ready <= '0';
		i_pdi_valid <= '0';
		i_sdi_valid <= '0';
		i_command   <= (others => '0');

		case state is
			when init =>
				null;

			when send_sk =>
				-- FIXME TESTING
--				i_command   <= CMD_RECV_SK_US;
				i_sdi_valid <= '1';

			when send_sk_done =>
				null;

			when decrypt =>
				-- FIXME TESTING
--				i_command   <= CMD_START_DEC_US;
				i_pdi_valid <= '1';
				i_sdo_ready <= '1';

			when encrypt_done =>
				null;

		end case;
	end process;

	ct_output : process
		file fileout      : text;
		variable line_out : line;
		variable temp     : std_logic_vector(7 downto 0);
	begin
		file_open(fileout, SDO_FILENAME, write_mode);
		while state /= encrypt_done loop
			wait until rising_edge(clk) and i_sdo_ready = '1' and o_sdo_valid = '1';
			temp := o_sdo_data;
			--			report "received " & to_hstring(temp) severity note;
			hwrite(line_out, temp);
			writeline(fileout, line_out);
		end loop;
		file_close(fileout);
		wait;                           -- forever
	end process;

	cpa_inst : entity work.cpa
		port map(
			clk         => clk,
			rst         => rst,
			i_command   => i_command,
			o_done      => o_done,
			i_rdi_data  => i_rdi_data,
			i_rdi_valid => i_rdi_valid,
			o_rdi_ready => o_rdi_ready,
			i_pdi_data  => i_pdi_data,
			i_pdi_valid => i_pdi_valid,
			o_pdi_ready => o_pdi_ready,
			i_sdi_data  => i_sdi_data,
			i_sdi_valid => i_sdi_valid,
			o_sdi_ready => o_sdi_ready,
			o_pdo_data  => o_pdo_data,
			o_pdo_valid => o_pdo_valid,
			i_pdo_ready => i_pdo_ready,
			o_sdo_data  => o_sdo_data,
			o_sdo_valid => o_sdo_valid,
			i_sdo_ready => i_sdo_ready
		);

end architecture RTL;
