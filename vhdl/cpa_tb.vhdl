library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

use work.kyber_pkg.all;

entity cpa_tb is
end entity cpa_tb;

architecture RTL of cpa_tb is
	constant IN_FILENAME       : string := "in.txt";
	constant COINS_IN_FILENAME : string := "coins.txt";
	constant OUT_FILENAME      : string := "out.txt";
	constant CLOCK_PERIOD      : time   := 10 ns;

	signal i_start_enc   : std_logic;
	signal o_done        : std_logic;
	signal i_coins_data  : T_byte_slv;
	signal i_coins_valid : std_logic;
	signal o_coins_ready : std_logic;
	signal i_pkmsg_data  : T_byte_slv;
	signal i_pkmsg_valid : std_logic;
	signal o_pkmsg_ready : std_logic;
	signal o_ct_data     : T_byte_slv;
	signal o_ct_valid    : std_logic;
	signal i_ct_ready    : std_logic;
	signal clk           : std_logic;
	signal rst           : std_logic;
	signal i_start_dec   : std_logic;
	signal i_recv_pk     : std_logic;
	signal i_recv_sk     : std_logic;

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
		rst <= '0';
		wait until rising_edge(clk);
		wait until falling_edge(clk);
		rst <= not rst;
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until rising_edge(clk);
		wait until falling_edge(clk);
		rst <= not rst;
		wait;                           -- forever
	end process;

	pk_at_input : process(clk)
		file filein      : text open read_mode is IN_FILENAME;
		variable line_in : line;
		variable temp    : std_logic_vector(7 downto 0);
	begin
		if rising_edge(clk) then
			if rst = '1' then
				i_pkmsg_valid <= '0';
			else
				if not endfile(filein) then
					if i_pkmsg_valid = '0' or o_pkmsg_ready = '1' then
						readline(filein, line_in);
						hread(line_in, temp);
						i_pkmsg_data  <= temp;
						i_pkmsg_valid <= '1'; -- TODO random
					end if;
				else
					if o_pkmsg_ready = '1' then
						i_pkmsg_valid <= '0';
					end if;
				end if;

			end if;

		end if;
	end process;

	coins_input : process(clk)
		file filein      : text open read_mode is COINS_IN_FILENAME;
		variable line_in : line;
		variable temp    : std_logic_vector(7 downto 0);
	begin
		if rising_edge(clk) then
			if rst = '1' then
				i_coins_valid <= '0';
			else
				if not endfile(filein) then
					if i_coins_valid = '0' or o_coins_ready = '1' then
						readline(filein, line_in);
						hread(line_in, temp);
						i_coins_data  <= temp;
						i_coins_valid <= '1'; -- TODO random
					end if;
				else
					if o_coins_ready = '1' then
						i_coins_valid <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;

	start_done_proc : process(o_done)
	begin
		i_start_enc <= '1';
		if o_done = '1' then
			i_start_enc <= '0';

			assert false report "Done!" severity failure;
		end if;
	end process;

	ct_output : process(clk)
		file fileout      : text open write_mode is OUT_FILENAME;
		variable line_out : line;
		variable temp     : std_logic_vector(7 downto 0);
	begin
		if rising_edge(clk) then

			i_ct_ready <= '1';          -- TODO
			if i_ct_ready = '1' and o_ct_valid = '1' then
				temp := o_ct_data;
				report "received " & to_hstring(temp) severity note;
				hwrite(line_out, temp);
				writeline(fileout, line_out);
			end if;

		end if;
	end process;

	cpa_enc_inst : entity work.cpa_enc
		port map(
			i_start_dec   => i_start_dec,
			i_recv_pk     => i_recv_pk,
			i_recv_sk     => i_recv_sk,
			clk           => clk,
			rst           => rst,
			i_start_enc   => i_start_enc,
			o_done        => o_done,
			i_coins_data  => i_coins_data,
			i_coins_valid => i_coins_valid,
			o_coins_ready => o_coins_ready,
			i_pk_data  => i_pkmsg_data,
			i_pk_valid => i_pkmsg_valid,
			o_pk_ready => o_pkmsg_ready,
			o_ct_data     => o_ct_data,
			o_ct_valid    => o_ct_valid,
			i_ct_ready    => i_ct_ready
		);

end architecture RTL;
