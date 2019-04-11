library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.kyber_pkg.all;

entity cpa_tb is
end entity cpa_tb;

architecture RTL of cpa_tb is
	constant PK_IN_FILENAME    : string := "pk.in.txt";
	constant PT_IN_FILENAME    : string := "pt.in.txt";
	constant COINS_IN_FILENAME : string := "coins.in.txt";
	constant CT_OUT_FILENAME   : string := "ct.out.txt";
	constant CLOCK_PERIOD      : time   := 10 ns;

	signal i_start_enc   : std_logic;
	signal o_done        : std_logic;
	signal i_coins_data  : T_byte_slv;
	signal i_coins_valid : std_logic;
	signal o_coins_ready : std_logic;
	signal i_pk_data     : T_byte_slv;
	signal i_pk_valid    : std_logic;
	signal o_pk_ready    : std_logic;
	signal o_ct_data     : T_byte_slv;
	signal o_ct_valid    : std_logic;
	signal i_ct_ready    : std_logic;
	signal clk           : std_logic;
	signal rst           : std_logic;
	signal i_start_dec   : std_logic;
	signal i_recv_pk     : std_logic;
	signal i_recv_sk     : std_logic;
	signal i_pt_data     : T_byte_slv;
	signal i_pt_valid    : std_logic;
	signal o_pt_ready    : std_logic;

	type T_state is (init, send_pk, send_pk_done, encrypt, encrypt_done);
	signal state : T_state;

	signal reseted : boolean := False;
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
		file_open(filein, PK_IN_FILENAME, read_mode);
		while not endfile(filein) loop
			readline(filein, line_in);
			hread(line_in, temp);
			i_pk_data <= temp;
			wait until rising_edge(clk) and i_pk_valid = '1' and o_pk_ready = '1';
		end loop;
		file_close(filein);
		wait;                           -- forever
	end process;

	pt_input : process
		file filein      : text;
		variable line_in : line;
		variable temp    : std_logic_vector(7 downto 0);
	begin
		file_open(filein, PT_IN_FILENAME, read_mode);
		while not endfile(filein) loop
			readline(filein, line_in);
			hread(line_in, temp);
			i_pt_data <= temp;
			wait until rising_edge(clk) and i_pt_valid = '1' and o_pt_ready = '1';
		end loop;
		file_close(filein);
		wait;                           -- forever
	end process;

	coins_input : process
		file filein      : text;
		variable line_in : line;
		variable temp    : std_logic_vector(7 downto 0);
	begin
		file_open(filein, COINS_IN_FILENAME, read_mode);

		while not endfile(filein) loop
			readline(filein, line_in);
			hread(line_in, temp);
			i_coins_data <= temp;
			wait until rising_edge(clk) and i_coins_valid = '1' and o_coins_ready = '1';
		end loop;
		file_close(filein);
		wait;                           -- forever
	end process;

	fsm_proc : process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= init;
			else

				case state is
					when init =>
						if reseted then
							state <= send_pk;
						end if;
					when send_pk =>
						if o_done = '1' then
							state <= send_pk_done;
						end if;

					when send_pk_done =>
						state <= encrypt;

					when encrypt =>
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
		i_start_enc   <= '0';
		i_start_dec   <= '0';
		i_recv_pk     <= '0';
		i_recv_sk     <= '0';
		i_ct_ready    <= '0';
		i_pk_valid    <= '0';
		i_pt_valid    <= '0';
		i_coins_valid <= '0';

		case state is
			when init =>
				null;

			when send_pk =>
				i_recv_pk  <= '1';
				i_pk_valid <= '1';

			when send_pk_done =>
				null;

			when encrypt =>
				i_start_enc   <= '1';
				i_coins_valid <= '1';
				i_pt_valid    <= '1';
				i_ct_ready    <= '1';

			when encrypt_done =>
				null;

		end case;
	end process;

	ct_output : process
		file fileout      : text;
		variable line_out : line;
		variable temp     : std_logic_vector(7 downto 0);
	begin
		file_open(fileout, CT_OUT_FILENAME, write_mode);
		while state /= encrypt_done loop
			wait until rising_edge(clk) and i_ct_ready = '1' and o_ct_valid = '1';
			temp := o_ct_data;
--			report "received " & to_hstring(temp) severity note;
			hwrite(line_out, temp);
			writeline(fileout, line_out);
		end loop;
		file_close(fileout);
		wait;                           -- forever
	end process;

	cpa_enc_inst : entity work.cpa
		port map(
			clk         => clk,
			rst         => rst,
			--
			i_start_enc => i_start_enc,
			i_recv_pk   => i_recv_pk,
			o_done      => o_done,
			--
			i_rdi_data  => i_coins_data,
			i_rdi_valid => i_coins_valid,
			o_rdi_ready => o_coins_ready,
			--
			i_msg_data   => i_pt_data,
			i_msg_valid  => i_pt_valid,
			o_msg_ready  => o_pt_ready,
			--
			i_pk_data   => i_pk_data,
			i_pk_valid  => i_pk_valid,
			o_pk_ready  => o_pk_ready,
			o_pdo_data   => o_ct_data,
			o_pdo_valid  => o_ct_valid,
			i_pdo_ready  => i_ct_ready
		);

end architecture RTL;
