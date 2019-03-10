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
		X"000", 
		X"0BF", X"964", X"51C", X"27A",
		X"F6C", X"576", X"667", X"4D7",
		X"AF1", X"BB8", X"0FE", X"C88",
		X"000"
	);

begin

	rho_shift_const <= rom(to_integer(lane_cntr));

end architecture RTL;
