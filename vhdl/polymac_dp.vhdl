-----
-- Actually a Z/KYBER_Q MAC datapath
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;


use work.kyber_pkg.all;

entity polymac_dp is
	port(
		clk : in std_logic;
		rst : in std_logic;
		---
		nega : std_logic;
		r_en : std_logic;
		r_load : std_logic;
		---
		a  : in std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
		b  : in std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
		rin  : in std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
		rout  : out std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0)
	);
end entity polymac_dp;

architecture RTL of polymac_dp is
	signal a_times_b : std_logic_vector(2 * log2ceil(KYBER_Q) - 1 downto 0);
	signal a_times_b_reduced : t_coef;
	signal t : unsigned(log2ceil(KYBER_Q) + 1 downto 0);
	signal sum : std_logic_vector(log2ceil(KYBER_Q) + 2 downto 0);
	signal sum_reduced : t_coef;
	------
	signal r_reg : unsigned(log2ceil(KYBER_Q) - 1 downto 0);
	
begin
	a_times_b <= a * b; -- TODO replace with mult module
	
	reduce0: entity work.divider
		generic map(
			G_IN_WIDTH  => 2 * log2ceil(KYBER_Q)
		)
		port map(
			i_u => a_times_b,
			o_rem => a_times_b_reduced
		);
		
	reduce1: entity work.divider
		generic map(
			G_IN_WIDTH  => sum'length
		)
		port map(
			i_u => sum,
			o_rem => sum_reduced
		);
	
	t <= to_unsigned(3*KYBER_Q, t'length) - unsigned(a_times_b_reduced) when nega else "00" & unsigned(a_times_b_reduced);
	sum <= std_logic_vector( ('0' & t) + r_reg);
	
	name : process (clk) is
	begin
		if rising_edge(clk) then
			if r_load then
				r_reg <= unsigned(rin);
			else
				r_reg <= unsigned(sum_reduced);
			end if;
		end if;
	end process name;
	
	rout <= std_logic_vector(r_reg);
end architecture RTL;
