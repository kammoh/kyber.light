--===================================================================================================================--
-----------------------------------------------------------------------------------------------------------------------
--                                  
--                                  
--                                    8"""""o   8"""""   8""""o    8"""""o 
--                                    8     "   8        8    8    8     " 
--                                    8e        8eeeee   8eeee8o   8o     
--                                    88        88       88    8   88   ee 
--                                    88    e   88       88    8   88    8 
--                                    68eeee9   888eee   88    8   888eee8 
--                                  
--                                  
--                                  Cryptographic Engineering Research Group
--                                          George Mason University
--                                       https://cryptography.gmu.edu/
--                                  
--                                  
-----------------------------------------------------------------------------------------------------------------------
--
--  unit name: full name (shortname / entity name)
--              
--! @file      .vhdl
--
--! @brief     <file content, behavior, purpose, special usage notes>
--
--! @author    <Kamyar Mohajerani (kamyar@ieee.org)>
--
--! @company   Cryptographic Engineering Research Group, George Mason University
--
--! @project   KyberLight: Lightweight hardware implementation of CRYSTALS-KYBER PQC
--
--! @context   Post-Quantum Cryptography
--
--! @license   
--
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--  
--! @date      <02/01/2019>
--
--! @version   <v0.1>
--
--! @details   blah blah
--!
--
--
--! <b>Dependencies:</b>\n
--! <Entity Name,...>
--!
--! <b>References:</b>\n
--! <reference one> \n
--! <reference two>
--!
--! <b>Modified by:</b>\n
--! Author: Kamyar Mohajerani
-----------------------------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! <date> KM: <log>\n
--! <extended description>
-----------------------------------------------------------------------------------------------------------------------
--! @todo <next thing to do> \n
--
-----------------------------------------------------------------------------------------------------------------------
--===================================================================================================================--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity ocram_sp is
	generic(
		D_BITS : positive;              -- number of data bits
		DEPTH  : positive               -- number of words in the array
	);
	port(
		clk      : in  std_logic;       -- clock
		ce       : in  std_logic;       -- clock enable
		we       : in  std_logic;       -- write enable
		in_addr  : in  unsigned(log2ceil(DEPTH) - 1 downto 0); -- address
		in_data  : in  std_logic_vector(D_BITS - 1 downto 0); -- write data
		out_data : out std_logic_vector(D_BITS - 1 downto 0) -- read output
	);

	attribute DONT_TOUCH_NETWORK of clk, we, ce, in_addr, in_data : signal is True;
	attribute DONT_TOUCH of clk, we, ce, in_addr, in_data, out_data : signal is True;
end entity;

architecture rtl of ocram_sp is
begin

	gen_xilinx : if (MEM_TECH = "XILINX") generate
		subtype word_t is std_logic_vector(D_BITS - 1 downto 0);
		type ram_t is array (0 to DEPTH - 1) of word_t;

		signal ram : ram_t;

	begin
		-- Xilinx Single-Port Block RAM No-Change Mode
		process(clk)
		begin
			if rising_edge(clk) then
				if ce = '1' then
					if we = '1' then
						ram(to_integer(unsigned(in_addr))) <= in_data;
					else
						out_data <= ram(to_integer(unsigned(in_addr)));
					end if;
				end if;
			end if;
		end process;
	end generate gen_xilinx;

	gen_saed_mc : if (MEM_TECH = "SAED_MC") generate
		subtype word_t is std_logic_vector(D_BITS - 1 downto 0);
		type ram_t is array (0 to DEPTH - 1) of word_t;

		signal ram : ram_t;

	begin
		-- SAED32 Memory Compiler Block RAM No-Change Mode
		process(clk)
		begin
			if rising_edge(clk) then
				if ce = '1' then
					if we = '1' then
						ram(to_integer(unsigned(in_addr))) <= in_data;
					else
						out_data <= ram(to_integer(unsigned(in_addr)));
					end if;
				end if;
			end if;
		end process;
	end generate gen_saed_mc;

end architecture;
