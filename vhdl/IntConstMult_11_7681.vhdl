library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ConstMult_11_7681 is
	port(i_u    : in  unsigned(10 downto 0);
	     o_mult : out unsigned(23 downto 0));
end entity;

architecture arch of ConstMult_11_7681 is
	signal t : unsigned(20 downto 0);
begin

	t      <= (((9 downto 0 => '0') & i_u(10 downto 9))  - i_u) & i_u(8 downto 0);
	o_mult <= ((23 downto 21 => t(20)) & t(20 downto 13) + i_u(10 downto 0)) & t(12 downto 0);

end architecture;
