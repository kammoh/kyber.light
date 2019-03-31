
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pkg is
	component SRAM128x13sp
		port(
			A   : in  std_logic_vector(6 downto 0);
			O   : out std_logic_vector(12 downto 0);
			I   : in  std_logic_vector(12 downto 0);
			WEB : in  std_logic;
			CSB : in  std_logic;
			OEB : in  std_logic;
			CE  : in  std_logic
		);
	end component SRAM128x13sp;
end package pkg;
