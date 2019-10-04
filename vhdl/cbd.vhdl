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
--  unit name: Centered Binomial Distribution
--              
--! @file      cbd.vhdl
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
--! @details   returns sampled data with a centered binomial distribution eta=KYBER_ETA around KYBER_Q (and not 0)
--!                   this differs from c reference implementation (which is around 0), but is the same after
--!                   modular reduction in polyvec_mac
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

use work.keccak_pkg.all;
use work.kyber_pkg.all;

-- Centered Binomial Distribution with Eta=4 centered around 0 (mod KYBER_Q)
-- Combinational

entity cbd is
	port(
		-- input byte stream, from KECCAK
		i_din_data      : in  T_byte_slv;
		o_coeffout_data : out T_coef_slv
	);
end entity cbd;

architecture RTL of cbd is

	signal a, b      : unsigned(log2ceilnz(KYBER_ETA + 1) - 1 downto 0); -- range: [0..KYBER_ETA]
	signal a_minus_b : signed(log2ceilnz(KYBER_ETA + 1) + 1 - 1 downto 0);
begin

	a         <= popcount(i_din_data(KYBER_ETA - 1 downto 0));
	b         <= popcount(i_din_data(2 * KYBER_ETA - 1 downto KYBER_ETA));
	a_minus_b <= signed(("0" & a) - b);

	o_coeffout_data <= std_logic_vector(KYBER_Q_S + a_minus_b); -- cannot be more than width of Q TODO?
	-- 
	-- this differs from cref implementation but is corrected during polymac

end architecture RTL;
