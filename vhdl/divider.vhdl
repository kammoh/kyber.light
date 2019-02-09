library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

-- divide and remainder on KYBER_Q = 7681
-- based on: Moller and Granlund, "Improved Division by Invariant Integers," IEEE Transactions on Computers, Feb. 2011
-- using 3 adders (14, 18, add by 1), 3 subtraction (13, 13 by constant, 4), 1x13-bit <= comparator, and 2x13 2:1 muxes

entity divider is
	generic(
		G_IN_WIDTH : positive := 25;     -- <= 26 bits, while u = <u1,u0> u0,u1 < 2^13 , u1 < KYBER_Q
		G_PIPELINE_LEVELS                : integer := 3 -- TODO
	);
	port(
		clk   : in  std_logic;
		i_u   : in  unsigned(G_IN_WIDTH - 1 downto 0);
		o_rem : out t_coef_us;
		o_div : out t_coef_us
	);
end entity divider;

architecture RTL of divider is
	signal u0, u1                                        : t_coef_us;
	signal u1_times_v                                    : unsigned(17 downto 0); -- u1 * v,  23 bits >= (G_IN_WIDTH -13) + 10
	signal q                                             : unsigned(25 downto 0); -- q = u1 * v + u , G_IN_WIDTH
	signal q0, q1, q1_times_d                            : t_coef_us;
	signal r0, r0_minus_d                                : t_coef_us;
	signal adjust                                        : boolean;
	-- piplne registers
	signal r0_reg, q0_reg, q1_reg, u0_reg, remainder_reg : t_coef_us;
	signal q_reg                                         : unsigned(25 downto 0);
begin
	-- i_u = <u1,u0>
	u0 <= i_u(12 downto 0);
	u1 <= resize(i_u(G_IN_WIDTH - 1 downto 13), 13);

	-- v (reciprocal of 7681) = 544 = 2^9 + 2^5 (10 bit)
	u1_times_v <= ((17 downto 13 => '0') & u1(12 downto 4) + u1(12 downto 0)) & u1(3 downto 0);
	-- q = u1 * v + u
	q          <= ((u1 & u0(12 downto 5)) + u1_times_v) & u0(4 downto 0);
	-- q = <q1, q0>
	q0         <= q_reg(12 downto 0);
	q1         <= q_reg(25 downto 13);

	-- d = KYBER_Q = 2^13 - 2^9 + 1 
	q1_times_d <= (q1(12 downto 9) - q1(3 downto 0)) & q1(8 downto 0);

	-- choice of remainder
	r0 <= u0_reg - q1_times_d;

	-- correction
	r0_minus_d <= r0_reg - KYBER_Q;
	adjust     <= (r0_minus_d <= q0_reg);

	pipe_reg_proc : process(clk) is
	begin
		if rising_edge(clk) then
			r0_reg        <= r0;
			q0_reg        <= q0;
			q1_reg        <= q1;
			q_reg         <= q;
			u0_reg        <= u0;
			remainder_reg <= r0_minus_d when adjust else r0_reg;
		end if;
	end process pipe_reg_proc;

	o_div <= q1_reg + 1 when adjust else q1_reg;
	o_rem <= remainder_reg;
end architecture RTL;
