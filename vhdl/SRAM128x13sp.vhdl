use std.textio.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity SRAM128x13sp is
	port(
		A   : in  std_logic_vector(6 downto 0); -- address 
		O   : out std_logic_vector(12 downto 0); -- data output
		I   : in  std_logic_vector(12 downto 0); -- data input
		WEB : in  std_logic;            -- write enable, active low
		CSB : in  std_logic;            -- chip select, active low
		OEB : in  std_logic;            -- output enable (read-enable), active low
		CE  : in  std_logic             -- clock
	);

end SRAM128x13sp;

architecture BEHAVIOURAL of SRAM128x13sp is
begin
	proc_mem : process
		constant numWords     : natural := 128;
		constant wordLength   : natural := 13;
		constant nw_m         : natural := numWords - 1;
		constant wl_m         : natural := wordLength - 1;
		constant low_address  : natural := 0;
		constant high_address : natural := nw_m;
		subtype word is std_logic_vector(wl_m downto 0);
		type memory_array is array (natural range low_address to high_address) of word;
		variable mem          : memory_array;
		variable address      : natural;
		variable data_out1    : word;

	begin
		O <= "ZZZZZZZZZZZZZ";

		loop
			if rising_edge(CE) then
				if CSB = '0' then
					address := to_integer(unsigned(A));
					if WEB = '0' then
						mem(address) := I(wl_m downto 0);
					elsif WEB = '1' then
						data_out1 := mem(address);
						if OEB = '0' then
							O <= data_out1;
						else
							O <= "ZZZZZZZZZZZZZ";
						end if;
					else
						O <= "ZZZZZZZZZZZZZ";
					end if;
				end if;
			end if;

			if (OEB = '0') then
				O <= data_out1;
			else
				O <= "ZZZZZZZZZZZZZ";
			end if;
			wait on CE, OEB;
		end loop;
	end process;

end architecture BEHAVIOURAL;
