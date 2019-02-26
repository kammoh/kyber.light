library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;

entity slice_unit is
	port(
		clk             : in  std_logic;
		slice_in        : in  T_slice;
		slice_out       : out T_slice;
		bypass_iochipi  : in  std_logic;
		do_theta        : in  std_logic;
		round_const_bit : in  std_logic
	);
end entity slice_unit;

architecture RTL of slice_unit is
	---------------------------------------------------- Functions ----------------------------------------------------
	function pi(slice : T_slice) return T_slice is
		variable ret : T_slice;
	begin
		for row in 0 to 4 loop
			for col in 0 to 4 loop
				ret(ij_to_linear(row, col)) := slice(ij_to_linear(col, 3 * row + col));
			end loop;
		end loop;
		return ret;
	end function pi;

	function chi(slice : T_slice) return T_slice is
		variable ret : T_slice;
	begin
		for row in 0 to 4 loop
			for col in 0 to 4 loop
				ret(ij_to_linear(row, col)) := slice(ij_to_linear(row, col)) xor (not slice(ij_to_linear(row, col + 1)) and slice(ij_to_linear(row, col + 2)));
			end loop;
		end loop;
		return ret;
	end function chi;

	function iota_o_chi(slice : T_slice; round_constant_bit : std_logic) return T_slice is
		variable ret : T_slice;
	begin
		ret := chi(slice);
		ret(0) := ret(0) xor round_constant_bit;
		return ret;
	end function iota_o_chi;

	function parity(slice : T_slice) return T_row is
		variable ret_parity : T_row := (others => '0');
	begin
		for col in 0 to 4 loop
			for row in 0 to 4 loop
				ret_parity(col) := ret_parity(col) xor slice(ij_to_linear(row, col));
			end loop;
		end loop;
		return ret_parity;
	end function parity;

	function replicate_row_to_slice(in_row : T_row) return T_slice is
		variable ret : T_slice;
	begin
		for row in 0 to 4 loop
			ret(5 * row + 4 downto 5 * row) := in_row;
		end loop;
		return ret;
	end function replicate_row_to_slice;


	---------------------------------------------------- Registers/FF ----------------------------------------------------
	signal prev_parities_reg : T_row;
	---------------------------------------------------- Wires        ----------------------------------------------------

	signal iochipi      : T_slice;
	signal cur_parities : T_row;
	signal theta_row : T_row;
begin

	iochipi <= slice_in when bypass_iochipi else iota_o_chi(pi(slice_in), round_const_bit);

	cur_parities <= parity(iochipi);
	theta_row <= (cur_parities rol 1) xor (prev_parities_reg ror 1);

	process(clk)
	begin
		if rising_edge(clk) then
			if do_theta then
				prev_parities_reg <= cur_parities;
			end if;
		end if;
	end process;

	slice_out <= iochipi xor replicate_row_to_slice(theta_row) when do_theta else iochipi;

end architecture RTL;
