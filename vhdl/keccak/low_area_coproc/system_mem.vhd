-- The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
-- Michaï¿½l Peeters and Gilles Van Assche. For more information, feedback or
-- questions, please refer to our website: http://keccak.noekeon.org/

-- Implementation by the designers,
-- hereby denoted as "the implementer".

-- To the extent possible under law, the implementer has waived all copyright
-- and related or neighboring rights to the source code in this file.
-- http://creativecommons.org/publicdomain/zero/1.0/

library IEEE;
use IEEE.std_logic_1164.all;

use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.keccak_globals.all;

entity system_mem is
	port(
		clk        : in  std_logic;
		rst_n      : in  std_logic;
		enR        : in  std_logic;
		enW        : in  std_logic;
		addr       : in  addr_type;
		mem_input  : in  std_logic_vector(63 downto 0);
		mem_output : out std_logic_vector(63 downto 0)
	);
end system_mem;

architecture rtl of system_mem is

	subtype mem_element_type is std_logic_vector(63 downto 0);
	type mem_table_type is array (63 downto 0) of mem_element_type;

	signal ram : mem_table_type;

begin
	process(clk, rst_n)
	begin
		if (rst_n = '0') then
			--reset mem content
			for i in 0 to 63 loop
				ram(i) <= (others => '0');

			end loop;

		--ram(0) <= X"0000000000000001";
		else
			if (clk'event and clk = '1') then
				if (enR = '1') then
					mem_output <= ram(addr);
				else
					mem_output <= (others => '0');
				end if;
				if (enW = '1') then
					ram(addr) <= mem_input;
				end if;
			end if;
		end if;
	end process;
end rtl;
