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

begin
	o_mult <= ((16 downto 13 => '0') & i_x(12 downto 4)) + i_x(12 downto 0) & i_x(3 downto 0)& (4 downto 0 => '0');

end architecture;

