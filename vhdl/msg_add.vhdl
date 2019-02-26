library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity msg_add is
	port(
		clk             : in  std_logic;
		rst             : in  std_logic;
		--
		i_polyin_data   : in  T_coef_us;
		i_polyin_valid  : in  std_logic;
		o_polyin_ready  : out std_logic;
		--
		i_msgin_data    : in  T_byte_slv;
		i_msgin_valid   : in  std_logic;
		o_msgin_ready   : out std_logic;
		--
		o_polyout_data  : out T_coef_us;
		o_polyout_valid : out std_logic;
		i_polyout_ready : in  std_logic
	);
end entity msg_add;

architecture RTL of msg_add is
	signal msg_bit_data  : std_logic_vector(0 downto 0);
	signal msg_bit_valid : std_logic;

begin

	eight2one : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_byte_slv'length,
			G_OUT_WIDTH => 1
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => i_msgin_data,
			i_din_valid  => i_msgin_valid,
			o_din_ready  => o_msgin_ready,
			o_dout_data  => msg_bit_data,
			o_dout_valid => msg_bit_valid,
			i_dout_ready => i_polyout_ready
		);

	o_polyout_valid <= msg_bit_valid and i_polyin_valid;
	o_polyin_ready  <= i_polyout_ready;

	comb_proc : process(all) is
	begin
		if msg_bit_data(0) then
			if i_polyin_data > KYBER_Q / 2 then
				o_polyout_data <= i_polyin_data - KYBER_Q / 2;
			else
				o_polyout_data <= i_polyin_data + KYBER_Q / 2;
			end if;
		else
			o_polyout_data <= i_polyin_data;
		end if;

	end process comb_proc;

end architecture RTL;
