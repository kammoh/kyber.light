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

use work.kyber_pkg.all;

entity polymac_datapath is
	port(
		clk              : in  std_logic;
		--- Control
		nega             : in  std_logic;
		en_r             : in  std_logic;
		ld_r             : in  std_logic;
		--- Data
		in_a             : in  t_coef_us;
		in_b             : in  t_coef_us;
		in_r             : in  t_coef_us;
		out_r            : out t_coef_us;
		-- Div
		i_ext_div_select : in  std_logic;
		i_ext_div        : in  unsigned(2 * log2ceil(KYBER_Q) - 1 downto 0);
		o_ext_div        : out t_coef_us
	);
end entity polymac_datapath;

architecture RTL of polymac_datapath is
	-- Registers/FF
	signal r_reg                          : t_coef_us;
	signal a_times_b_reg, divider_input   : unsigned(2 * log2ceil(KYBER_Q) - 1 downto 0);
	signal nega_delayed_1, nega_delayed_2 : std_logic;

	-- Wires
	signal a_times_b_reduced : t_coef_us;
	signal add_sub           : unsigned(r_reg'length + 1 downto 0);
	signal add_sub_minus_q   : unsigned(r_reg'length downto 0);

begin

	reduce0 : entity work.divider
		generic map(
			G_IN_WIDTH => 2 * log2ceil(KYBER_Q)
		)
		port map(
			i_u   => divider_input,
			o_rem => a_times_b_reduced,
			o_div => o_ext_div
		);

	divider_input <= i_ext_div when i_ext_div_select else a_times_b_reg;

	add_sub         <= ("00" & r_reg) - a_times_b_reduced when nega_delayed_2 else ("00" & r_reg) + a_times_b_reduced;
	add_sub_minus_q <= resize(add_sub - KYBER_Q, add_sub_minus_q'length);

	name : process(clk) is
	begin
		if rising_edge(clk) then
			-- pipeline:
			a_times_b_reg  <= in_a * in_b; -- TODO replace with mult module
			nega_delayed_1 <= nega;
			nega_delayed_2 <= nega_delayed_1;

			if en_r then                -- register enable
				if ld_r then
					r_reg <= in_r;
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

	out_r <= r_reg;
end architecture RTL;
