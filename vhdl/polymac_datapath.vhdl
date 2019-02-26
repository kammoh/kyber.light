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
	generic(
		G_PIPELINE_LEVELS : integer := 7 -- number of pipelining levels
	);
	port(
		clk              : in  std_logic;
		--- Control
		i_nega           : in  std_logic;
		i_en_v           : in  std_logic; -- enable piped
		i_ld_v           : in  std_logic; -- enable and load now
		--- Data
		in_a             : in  T_coef_us;
		in_b             : in  T_coef_us;
		in_v             : in  T_coef_us;
		out_v            : out T_coef_us;
		-- Div
		i_ext_div_select : in  std_logic;
		i_ext_div        : in  unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
		o_ext_div        : out T_coef_us
	);
end entity polymac_datapath;

architecture RTL of polymac_datapath is
	-- Registers/FF
	signal r_reg                            : T_coef_us;
	signal in_a_reg, in_b_reg               : T_coef_us;
	signal a_times_b_reg_0, a_times_b_reg_1 : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal nega_delayed                     : std_logic_vector(G_PIPELINE_LEVELS - 1 downto 0); -- including load a, b stage
	signal en_r_delayed                     : std_logic_vector(G_PIPELINE_LEVELS - 1 downto 0);
	signal ld_r_delayed                     : std_logic; -- just 1 cycle delay
	-- Wires
	signal divider_input                    : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal a_times_b_reduced                : T_coef_us;
	signal add_sub                          : unsigned(r_reg'length + 1 downto 0);
	signal add_sub_minus_q                  : unsigned(r_reg'length downto 0);

begin

	reduce0 : entity work.divider
		generic map(
			G_IN_WIDTH        => 2 * KYBER_COEF_BITS,
			G_PIPELINE_LEVELS => minimum(G_PIPELINE_LEVELS - 1, 3) -- we do at least one level in this module, don't decrease divider pipe levels unless G_PIPELINE_LEVELS < 4
		)
		port map(
			clk   => clk,
			i_u   => divider_input,
			o_rem => a_times_b_reduced,
			o_div => o_ext_div
		);

	divider_input <= i_ext_div when i_ext_div_select else a_times_b_reg_1;

	add_sub         <= ("00" & r_reg) - a_times_b_reduced when nega_delayed(0) else ("00" & r_reg) + a_times_b_reduced;
	add_sub_minus_q <= resize(add_sub - KYBER_Q, add_sub_minus_q'length);

	pipe_7_gen : if G_PIPELINE_LEVELS >= 7 generate
		pipe_7_gen_proc : process(clk)
		begin
			if rising_edge(clk) then
				a_times_b_reg_1 <= a_times_b_reg_0;
			end if;
		end process;
	else generate
		a_times_b_reg_1 <= a_times_b_reg_0;
	end generate pipe_7_gen;

	pipe_6_gen : if G_PIPELINE_LEVELS >= 6 generate
		pipe_6_gen_proc : process(clk)
		begin
			if rising_edge(clk) then
				in_a_reg <= in_a;
				in_b_reg <= in_b;
			end if;
		end process;
	else generate
		in_a_reg <= in_a;
		in_b_reg <= in_b;
	end generate pipe_6_gen;

	reg_proc : process(clk) is
	begin
		if rising_edge(clk) then

			-- pipeline:
			a_times_b_reg_0 <= in_a_reg * in_b_reg; -- TODO replace with mult module

			--
			nega_delayed <= i_nega & nega_delayed(nega_delayed'length - 1 downto 1);
			en_r_delayed <= i_en_v & en_r_delayed(en_r_delayed'length - 1 downto 1);
			ld_r_delayed <= i_ld_v;
			--
			if ld_r_delayed then
				r_reg <= in_v;
			elsif en_r_delayed(0) then
				if add_sub(add_sub'length - 1) then -- add_sub < 0
					r_reg <= resize(add_sub + KYBER_Q, r_reg'length);
				--				elsif add_sub >= KYBER_Q then
				elsif not add_sub_minus_q(r_reg'length) then -- add_sub >= q
					r_reg <= resize(add_sub_minus_q, r_reg'length);
				else
					r_reg <= resize(add_sub, r_reg'length);
				end if;
			end if;
		end if;
	end process reg_proc;

	out_v <= r_reg;
end architecture RTL;
