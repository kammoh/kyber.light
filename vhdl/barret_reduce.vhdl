library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.kyber_pkg.all;

entity barret_reduce is
	port(
		a : in  std_logic_vector(25 downto 0);
		r : out std_logic_vector(12 downto 0)
	);
end entity barret_reduce;

architecture rtl of barret_reduce is
	--	constant K : positive := 13;
	--	constant N : positive := 26;
	constant KYBER_Q : positive := 7681;

	signal X          : unsigned(13 downto 0);
	signal quotient   : unsigned(13 downto 0);
	signal y, product : unsigned(14 downto 0);
	signal t1         : unsigned(14 downto 0);
	signal t2         : unsigned(14 downto 0);
	signal y1, y2     : unsigned(15 downto 0);
	signal usr        : unsigned(12 downto 0);
begin

	--  x = (a >> 12) , k = 12
	X <= unsigned(a(25 downto 12));

	----------- generate quotient = x * (2^26/KYBER_Q)
	-- t1 <-  x >> 4  + x
	t1       <= ("00000" & X(13 downto 4)) + ("0" & X);
	--  q = {((x >> 4)  + x) >> 4}  +  (x >> 1) = x * (2^26/KYBER_Q)
	quotient <= ("0000" & t1(14 downto 5)) + ("0" & X(13 downto 1));

	----------- generate product = 7681 * quotient
	-- KYBER_Q = 7681 = 2^13-2^9+1
	t2(14 downto 9) <= ("00" & quotient(12 downto 9)) - quotient(5 downto 0);
	t2(8 downto 0)  <= quotient(8 downto 0);
	-- product = 7681 * quotient
	product         <= ((t2(14 downto 13)) + quotient(1 downto 0)) & (t2(12 downto 0));

	----------- y = (a mod 2^{15} - (7681 * quotient)
	y <= unsigned(a(14 downto 0)) - product;

	y1 <= ('0' & y) - KYBER_Q;
	y2 <= ('0' & y) - (2 * KYBER_Q);

	usr <= y(12 downto 0) when ?? y1(15) -- y < KYBER_Q
		else y1(12 downto 0) when ?? y2(15) -- y < 2 * KYBER_Q
		else y2(12 downto 0);           -- y > 2 * KYBER_Q

	r <= std_logic_vector(usr);

end rtl;
