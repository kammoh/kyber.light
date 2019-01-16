library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

-- Centered Binomial Distribution with Eta=4 centered arround KYBER_Q
-- Streaming I/O

entity cbd4 is
	port(
		clk             : in  std_logic;
		rst             : in  std_logic;
		-- in word stream
		in_hword_data   : in  std_logic_vector(3 downto 0); -- keccak interface i.e. t_halfword
		in_hword_valid  : in  std_logic;
		in_hword_ready  : out std_logic;
		-- out coefficient stream
		out_coeff_data  : out t_coef;
		out_coeff_valid : out std_logic;
		out_coeff_ready : in  std_logic
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
			in_hword_data  => in_hword_data,
			out_coeff_data => out_coeff_data
		);

	cbd4_controller_inst : entity work.cbd4_controller
		port map(
			clk             => clk,
			rst             => rst,
			in_hword_valid  => in_hword_valid,
			in_hword_ready  => in_hword_ready,
			out_coeff_valid => out_coeff_valid,
			out_coeff_ready => out_coeff_ready,
			en_a            => en_a,
			en_b            => en_b
		);

end architecture RTL;
