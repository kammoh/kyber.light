library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;

entity iota_lut is
	port(
		round           : in  unsigned(log2ceil(C_NUM_ROUNDS + 1 - 1) - 1 downto 0);
		k               : out unsigned(log2ceil(C_LANE_WIDTH) - 1 downto 0);
		iota_bit        : out std_logic
	);
end entity iota_lut;

architecture RTL of iota_lut is

	signal iota : std_logic_vector(C_LANE_WIDTH - 1 downto 0);

begin

	iota <= X"0000000000000001" when round = 1 
		else X"0000000000008082" when round = 2 
		else X"800000000000808A" when round = 3 
		else X"8000000080008000" when round = 4 
		else X"000000000000808B" when round = 5 
		else X"0000000080000001" when round = 6 
		else X"8000000080008081" when round = 7 
		else X"8000000000008009" when round = 8 
		else X"000000000000008A" when round = 9 
		else X"0000000000000088" when round = 10
		else X"0000000080008009" when round = 11
		else X"000000008000000A" when round = 12
		else X"000000008000808B" when round = 13
		else X"800000000000008B" when round = 14
		else X"8000000000008089" when round = 15
		else X"8000000000008003" when round = 16
		else X"8000000000008002" when round = 17
		else X"8000000000000080" when round = 18
		else X"000000000000800A" when round = 19
		else X"800000008000000A" when round = 20
		else X"8000000080008081" when round = 21
		else X"8000000000008080" when round = 22
		else X"0000000080000001" when round = 23
		else X"8000000080008008" when round = 24
		else X"0000000000000000";

	iota_bit        <= iota(to_integer(k));

end architecture RTL;
