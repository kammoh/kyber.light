library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ConstMult_3329_12_12 is
	port(
		i_x    : in  unsigned(11 downto 0);
		o_mult : out unsigned(11 downto 0)
	);
end entity;

architecture arch of ConstMult_3329_12_12 is
	signal P257X : unsigned(11 downto 0);
begin

	P257X <= (i_x(11 downto 8) + i_x(3 downto 0)) & i_x(7 downto 0);

	o_mult(11 downto 10) <= P257X(11 downto 10) + ((i_x(1) xor i_x(0)) & i_x(0));
	o_mult(9 downto 0)   <= P257X(9 downto 0);

end architecture;
