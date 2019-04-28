library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity ConstMult_544_13_22 is
	port(
		i_x    : in  T_coef_us;
		o_mult : out unsigned(21 downto 0)
	);

end entity;

architecture arch of ConstMult_544_13_22 is
	signal P17X_High_L : unsigned(12 downto 0);
	signal P17X_High_R : unsigned(12 downto 0);
	signal P17X        : unsigned(16 downto 0);
begin

	-- P17X <-  X<<4  + X
	P17X_High_L       <= i_x(12 downto 0);
	P17X_High_R       <= (16 downto 13 => '0') & i_x(12 downto 4);
	P17X(16 downto 4) <= P17X_High_R + P17X_High_L; -- sum of higher bits
	P17X(3 downto 0)  <= i_x(3 downto 0); -- lower bits untouched
	o_mult            <= P17X & (4 downto 0 => '0');

end architecture;

