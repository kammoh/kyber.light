library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;
use work.kyber_pkg.all;

-- Centered Binomial Distribution with Eta=4 centered around 0 (mod KYBER_Q)
-- Combinational

entity cbd is
	port(
		-- in word stream
		i_din_data       : in  T_byte_slv; -- keccak interface
		o_coeffout_data  : out T_coef_slv
	);
end entity cbd;

architecture RTL of cbd is

	signal a, b : unsigned(log2ceilnz(KYBER_ETA + 1) - 1 downto 0); -- each 0..KYBER_ETA
begin

	a <= popcount(i_din_data(KYBER_ETA - 1 downto 0));
	b <= popcount(i_din_data(2 * KYBER_ETA - 1 downto KYBER_ETA));

	o_coeffout_data <= std_logic_vector(KYBER_Q_US + a - b); -- cannot be more than width of Q TODO?

end architecture RTL;
