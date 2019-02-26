library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;
use work.kyber_pkg.all;

-- Centered Binomial Distribution with Eta=4 centered around 0 (mod KYBER_Q)
-- Streaming I/O

entity cbd4 is
	port(
		clk              : in  std_logic;
		rst              : in  std_logic;
		-- in word stream
		i_hwordin_data   : in  T_halfword; -- keccak interface
		i_hwordin_valid  : in  std_logic;
		o_hwordin_ready  : out std_logic;
		-- out coefficient stream
		o_coeffout_data  : out T_coef_slv;
		o_coeffout_valid : out std_logic;
		o_coeffout_ready : in  std_logic
	);
end entity cbd4;

architecture RTL of cbd4 is
	signal en_a : std_logic;
	signal en_b : std_logic;

begin
	cbd4_datapath_inst : entity work.cbd4_datapath
		port map(
			clk            => clk,
			en_a           => en_a,
			en_b           => en_b,
			in_hword_data  => i_hwordin_data,
			out_coeff_data => o_coeffout_data
		);

	cbd4_controller_inst : entity work.cbd4_controller
		port map(
			clk             => clk,
			rst             => rst,
			in_hword_valid  => i_hwordin_valid,
			in_hword_ready  => o_hwordin_ready,
			out_coeff_valid => o_coeffout_valid,
			out_coeff_ready => o_coeffout_ready,
			en_a            => en_a,
			en_b            => en_b
		);

end architecture RTL;
