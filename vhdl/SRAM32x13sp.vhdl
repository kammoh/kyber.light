--*********************************************************************
--  saed_mc : SRAM32x13sp Vhdl description                          *
--  ---------------------------------------------------------------   *
--  Filename      : /cwd/mc_32x13sp/SRAM32x13sp.vhdl                         *
--  SRAM name     : SRAM32x13sp                                       *
--  Word width    : 13    bits                                        *
--  Word number   : 32                                                *
--  Adress width  : 5     bits                                        *
--  ---------------------------------------------------------------   *
--  Creation date : Mon March 11 2019                                 *
--*********************************************************************

use std.textio.all;
Library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM32x13sp is
	port (
		A   : in  std_logic_vector( 4  downto 0 );
		O   : out std_logic_vector( 12  downto 0 );
		I   : in  std_logic_vector( 12  downto 0 );
		WEB  : in  std_logic;
		CSB  : in  std_logic;
		OEB  : in  std_logic;
		CE  : in  std_logic
	);

end SRAM32x13sp ;

architecture SRAM32x13sp_behaviour of SRAM32x13sp is
begin
	proc_mem: process
		constant numWords: natural := 32;
		constant wordLength: natural := 13;

		constant nw_m: natural := numWords-1;
		constant wl_m: natural := wordLength-1;
		constant low_address: natural := 0;
		constant high_address: natural := nw_m;
		subtype word is std_logic_vector( wl_m downto 0 );
		type memory_array is
			array (natural range low_address to high_address) of word;
		variable mem: memory_array;
		variable address   : natural;
		variable data_out1 : word;
		

	begin
		O <= "ZZZZZZZZZZZZZ";
	

		loop

			if  ((CSB = '0') and (CE= '1') and (CE'event )  and (CE'last_value = '0'))	then
	 			address := to_integer( unsigned(A) );
 				if WEB = '0' then
             			mem( address ) := I(wl_m downto 0);
            				elsif WEB = '1' then
						data_out1 := mem( address );
						if OEB = '0' then
							O <= data_out1;
						else 
							O <= "ZZZZZZZZZZZZZ";
						end if;
					else
						O <= "ZZZZZZZZZZZZZ";
				end if;
			end if;

			if ( OEB = '0') then
				O <= data_out1;
				else
					O <= "ZZZZZZZZZZZZZ";
			    end if;
				wait on CE, OEB;
		end loop;
	end process;

end SRAM32x13sp_behaviour;