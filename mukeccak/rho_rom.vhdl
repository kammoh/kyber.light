library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;

entity rho_rom is
	port(
		lane_cntr       : in  unsigned(log2ceil(13) - 1 downto 0);
		rho_shift_const : out unsigned(2 * log2ceil(C_LANE_WIDTH) - 1 downto 0)
	);
end entity rho_rom;

architecture RTL of rho_rom is
	type t_lut is array (0 to 13) of unsigned(rho_shift_const'length - 1 downto 0);

	signal rom : t_lut := (
		-- (MY_RHO[2*i] << 6) | MY_RHO[2*i - 1]
		12X"000", 
		12X"F81", 12X"6DC", 12X"B24", 12X"DC6",
		12X"0D4", 12X"ACA", 12X"9D9", 12X"B69",
		12X"54F", 12X"488", 12X"F42", 12X"3B8",
		12X"000"
	);

begin

	rho_shift_const <= rom(to_integer(lane_cntr));

end architecture RTL;
