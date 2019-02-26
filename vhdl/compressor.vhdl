library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity compressor is
	port(
		clk          : in  std_logic;
		rst          : in  std_logic;
		--
		i_din_data   : in  T_coef_us;
		i_din_valid  : in  std_logic;
		o_din_ready  : out std_logic;
		--
		o_dout_data  : out T_byte_slv;
		o_dout_valid : out std_logic;
		i_dout_ready : in  std_logic
	);
end entity compressor;

architecture RTL of compressor is

begin
	asym_fifo_inst : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_coef_us'length,
			G_OUT_WIDTH => T_byte_slv'length
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => std_logic_vector(i_din_data),
			i_din_valid  => i_din_valid,
			o_din_ready  => o_din_ready,
			o_dout_data  => o_dout_data,
			o_dout_valid => o_dout_valid,
			i_dout_ready => i_dout_ready
		);

end architecture RTL;
