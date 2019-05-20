library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity carry_save_adder_tb is
end entity carry_save_adder_tb;

architecture RTL of carry_save_adder_tb is
	constant w     : positive := 7;     -- bit-width of inputs
	--
	signal x, y, z : unsigned(w - 1 downto 0); -- inputs
	signal sum       : unsigned(w downto 0); 
	signal cout    : std_logic;
	signal error   : integer  := 0;
begin

	carry_save_adder(x, y, z, sum, cout);

	stim_proc : process
	begin
		for i in 0 to 2**w - 1 loop
			for j in 0 to 2**w - 1 loop
				for k in 0 to 2**w - 1 loop
					x <= to_unsigned(i, w);
					y <= to_unsigned(j, w);
					z <= to_unsigned(k, w);
					wait for 10 ns;
					if (to_integer(cout & sum) /= (i + j + k)) then
						report "error";
						error <= error + 1;
					end if;
				end loop;
			end loop;
		end loop;

		wait;
	end process;

end architecture RTL;
