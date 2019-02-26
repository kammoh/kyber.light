library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity decompressor is
	port(
		clk             : in  std_logic;
		rst             : in  std_logic;
		--
		i_din_data      : in  T_byte_slv;
		i_din_valid     : in  std_logic;
		o_din_ready     : out std_logic;
		--
		o_coefout_data  : out T_Coef_slv;
		o_coefout_valid : out std_logic;
		i_coefout_ready : in  std_logic
	);
end entity decompressor;

architecture RTL of decompressor is

begin
	asym_fifo : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_byte_slv'length,
			G_OUT_WIDTH => T_Coef_slv'length
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => i_din_data,
			i_din_valid  => i_din_valid,
			o_din_ready  => o_din_ready,
			o_dout_data  => o_coefout_data,
			o_dout_valid => o_coefout_valid,
			i_dout_ready => i_coefout_ready
		);
end architecture RTL;
