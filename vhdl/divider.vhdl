library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;
entity divider is
	generic(
		G_IN_WIDTH : positive := 25     -- <= 26 bits, while u = <u1,u0> u0,u1 < 2^13 , u1 < KYBER_Q
	);
	port(
		i_u   : in  std_logic_vector(G_IN_WIDTH - 1 downto 0); -- 
		o_rem : out std_logic_vector(12 downto 0);
		o_div : out std_logic_vector(12 downto 0)
	);
end entity divider;

architecture RTL of divider is
	-- v (reciprocal of 7681) = 544 = 2^9 + 2^5 (10 bit)
	signal u0                                           : unsigned(12 downto 0);
	signal u1                                           : unsigned(12 downto 0);
	signal u1_times_v                                   : unsigned(22 downto 0); -- u1 * v,  23 bits >= (G_IN_WIDTH -13) + 10
	signal q                                            : unsigned(25 downto 0); -- q = u1 * v + u , G_IN_WIDTH
	signal q0, q1, q1_prime, q1_times_d, r0, r0_minus_d : unsigned(12 downto 0);
	signal prime                                        : boolean;

begin
	u0 <= unsigned(i_u(12 downto 0));
	u1 <= resize(unsigned(i_u(G_IN_WIDTH - 1 downto 13)), 13);

	u1_times_v <= ((17 downto 13 => '0') & u1(12 downto 4) + u1(12 downto 0)) & u1(3 downto 0) & (4 downto 0 => '0');
	q          <= (u1 & u0) + u1_times_v;

	q0 <= q(12 downto 0);
	q1 <= q(25 downto 13);

	q1_times_d <= (q1(12 downto 9) + ("0000" - q1(3 downto 0))) & q1(8 downto 0);

	r0         <= u0 - q1_times_d;
	r0_minus_d <= r0 - KYBER_Q;

	prime    <= (r0_minus_d <= q0);
	q1_prime <= q1 + 1;

	o_div <= std_logic_vector(q1_prime) when prime else std_logic_vector(q1);
	o_rem <= std_logic_vector(r0_minus_d) when prime else std_logic_vector(r0);
end architecture RTL;
