-----
-- Polynomial Vector Multiply Accumulate Datapath
--
-- Performs on Z/q
--
-- Pipelined (1-stage)
-- 
-- out_r <- in_r +/- 
-----

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.kyber_pkg.all;

entity polymac_datapath is
	port(
		clk   : in  std_logic;
		--- Control
		nega  :     std_logic;
		en_r  :     std_logic;
		ld_r  :     std_logic;
		--- Data
		in_a  : in  std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
		in_b  : in  std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
		in_r  : in  std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
		out_r : out std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0)
	);
end entity polymac_datapath;

architecture RTL of polymac_datapath is
	-- Registers/FF
	signal r_reg      : t_ucoef;
	signal a_times_b  : std_logic_vector(2 * log2ceil(KYBER_Q) - 1 downto 0);
	signal nega_piped : std_logic;

	-- Wires
	signal a_times_b_reduced : t_coef;
	signal add_sub           : unsigned(r_reg'length + 1 downto 0);
	signal add_sub_minus_q   : unsigned(r_reg'length downto 0);

begin

	reduce0 : entity work.divider
		generic map(
			G_IN_WIDTH => 2 * log2ceil(KYBER_Q)
		)
		port map(
			i_u   => a_times_b,
			o_rem => a_times_b_reduced
		);

	add_sub         <= ("00" & r_reg) - unsigned(a_times_b_reduced) when nega_piped else ("00" & r_reg) + unsigned(a_times_b_reduced);
	add_sub_minus_q <= resize(add_sub - KYBER_Q, add_sub_minus_q'length);

	name : process(clk) is
	begin
		if rising_edge(clk) then
			-- pipeline:
			a_times_b  <= in_a * in_b;  -- TODO replace with mult module
			nega_piped <= nega;

			if en_r then                -- register enable
				if ld_r then
					r_reg <= unsigned(in_r);
				elsif add_sub(add_sub'length - 1) then -- add_sub < 0
					r_reg <= resize(add_sub + KYBER_Q, r_reg'length);
				elsif not add_sub_minus_q(r_reg'length) then -- add_sub > q
					r_reg <= resize(add_sub_minus_q, r_reg'length);
				else
					r_reg <= resize(add_sub, r_reg'length);
				end if;
			end if;
		end if;
	end process name;

	out_r <= std_logic_vector(r_reg);
end architecture RTL;
