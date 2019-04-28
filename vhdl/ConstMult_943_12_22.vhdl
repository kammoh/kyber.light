
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity ConstMult_943_12_22 is
	port(
		i_x    : in  T_coef_us;
		o_mult : out unsigned(21 downto 0)
	);
end entity;

architecture arch of ConstMult_943_12_22 is
	signal M1X          : unsigned(12 downto 0);
	signal P15X_High_L  : unsigned(11 downto 0);
	signal P15X_High_R  : unsigned(11 downto 0);
	signal P15X         : unsigned(15 downto 0);
	signal M17X_High_L  : unsigned(13 downto 0);
	signal M17X_High_R  : unsigned(13 downto 0);
	signal M17X         : unsigned(17 downto 0);
	signal P943X_High_L : unsigned(15 downto 0);
	signal P943X_High_R : unsigned(15 downto 0);
	signal P943X        : unsigned(21 downto 0);
begin
	M1X <= (12 downto 0 => '0') - i_x;

	-- P15X <-  X<<4  + M1X
	P15X_High_L       <= i_x(11 downto 0);
	P15X_High_R       <= (15 downto 13 => M1X(12)) & M1X(12 downto 4);
	P15X(15 downto 4) <= P15X_High_R + P15X_High_L; -- sum of higher bits
	P15X(3 downto 0)  <= M1X(3 downto 0); -- lower bits untouched

	-- M17X <-  M1X<<4  + M1X
	M17X_High_L       <= (17 downto 17 => M1X(12)) & M1X(12 downto 0);
	M17X_High_R       <= (17 downto 13 => M1X(12)) & M1X(12 downto 4);
	M17X(17 downto 4) <= M17X_High_R + M17X_High_L; -- sum of higher bits
	M17X(3 downto 0)  <= M1X(3 downto 0); -- lower bits untouched

	-- P943X <-  P15X<<6  + M17X
	P943X_High_L       <= P15X(15 downto 0);
	P943X_High_R       <= (21 downto 18 => M17X(17)) & M17X(17 downto 6);
	P943X(21 downto 6) <= P943X_High_R + P943X_High_L; -- sum of higher bits
	P943X(5 downto 0)  <= M17X(5 downto 0); -- lower bits untouched

	o_mult <= P943X(21 downto 0);
end architecture;

