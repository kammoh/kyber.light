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

-- Centered Binomial Distribution with Eta=4 centered around KYBER_Q
-- Streaming I/O
-- Input coming from Keccak
-- 8 random bits in two chunks of 4 bit, sum of bits of each chunk -> a, b
-- B <- Q + a - b

entity cbd4_datapath is
	port(
		clk            : in  std_logic;
		-- from controller
		en_a            : in  std_logic;
		en_b            : in  std_logic;
		-- in word stream
		in_hword_data  : in  std_logic_vector(3 downto 0); -- Keccak interface i.e. t_halfword
		-- out coefficient stream
		out_coeff_data : out T_coef_slv
	);
end entity cbd4_datapath;

architecture RTL of cbd4_datapath is
	function half_adder(a, b: std_logic) return unsigned is
		variable ret: unsigned(1 downto 0);
	begin
		ret(0) := a xor b;
		ret(1) := a and b;
		return ret;
	end function;
	
	function popcount(a: std_logic_vector) return unsigned is
	begin
		return ("0" & half_adder(a(0), a(1))) + half_adder(a(2), a(3));
	end function;
	signal a, b, pop_count_sig : unsigned(log2ceil(KYBER_ETA) - 1 downto 0);
	
	constant q : unsigned := to_unsigned(KYBER_Q, log2ceil(KYBER_Q));
begin
	
	pop_count_sig  <= popcount(in_hword_data);
	
	name : process (clk) is
	begin
		if rising_edge(clk) then
			if en_a then
				a <= pop_count_sig;
			end if;
			if en_b then
				b <= pop_count_sig;				
			end if;
		end if;
	end process name;
	
	
	out_coeff_data  <=  std_logic_vector(q + a - b); -- cannot be more than width of Q
	

end architecture RTL;
