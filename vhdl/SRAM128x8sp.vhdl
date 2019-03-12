--*********************************************************************
--  saed_mc : SRAM128x8sp Vhdl description                          *
--  ---------------------------------------------------------------   *
--  Filename      : /src/saed_mc_v2_3_6/saed_mc/mc_128x8sp/SRAM128x8sp.vhdl                         *
--  SRAM name     : SRAM128x8sp                                       *
--  Word width    : 8     bits                                        *
--  Word number   : 128                                               *
--  Adress width  : 7     bits                                        *
--  ---------------------------------------------------------------   *
--  Creation date : Mon March 11 2019                                 *
--*********************************************************************

use std.textio.all;
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM128x8sp is
	port(
		A   : in  std_logic_vector(6 downto 0);
		O   : out std_logic_vector(7 downto 0);
		I   : in  std_logic_vector(7 downto 0);
		WEB : in  std_logic;
		CSB : in  std_logic;
		OEB : in  std_logic;
		CE  : in  std_logic             -- clock
	);

end SRAM128x8sp;

architecture SRAM128x8sp_behaviour of SRAM128x8sp is
begin
	proc_mem : process
		constant numWords   : natural := 128;
		constant wordLength : natural := 8;

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
		O <= "ZZZZZZZZ";

		loop

			if ((CSB = '0') and rising_edge(CE)) then
				address := to_integer(unsigned(A));
				if WEB = '0' then
					mem(address) := I(wl_m downto 0);
				elsif WEB = '1' then
					data_out1 := mem(address);
					if OEB = '0' then
						O <= data_out1;
					else
						O <= "ZZZZZZZZ";
					end if;
				else
					O <= "ZZZZZZZZ";
				end if;
			end if;

			if (OEB = '0') then
				O <= data_out1;
			else
				O <= "ZZZZZZZZ";
			end if;
			wait on CE, OEB;
		end loop;
	end process;

end SRAM128x8sp_behaviour;
