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
--------------------------------------------------------------------------------
--                             ConstMult_17473_15
--                      (IntConstMult_15_17473_F0_uid2)
-- VHDL generated for Kintex7 @ 0MHz
-- This operator is part of the Infinite Virtual Library FloPoCoLib
-- All rights reserved 
-- Authors: Florent de Dinechin, Antoine Martinet (2007-2013)
--------------------------------------------------------------------------------
-- combinatorial

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;
entity ConstMult_17473_15 is
    port (X : in  std_logic_vector(14 downto 0);
          R : out  std_logic_vector(29 downto 0)   );
end entity;

architecture arch of ConstMult_17473_15 is
signal P17X_High_L :  std_logic_vector(15 downto 0);
signal P17X_High_R :  std_logic_vector(15 downto 0);
signal P17X :  std_logic_vector(19 downto 0);
signal P65X_High_L :  std_logic_vector(15 downto 0);
signal P65X_High_R :  std_logic_vector(15 downto 0);
signal P65X :  std_logic_vector(21 downto 0);
signal P17473X_High_L :  std_logic_vector(19 downto 0);
signal P17473X_High_R :  std_logic_vector(19 downto 0);
signal P17473X :  std_logic_vector(29 downto 0);
begin

   -- P17X <-  X<<4  + X
   P17X_High_L <=  (19 downto 19 => '0') & X(14 downto 0) ;
   P17X_High_R <=  (19 downto 15 => '0') & X(14 downto 4); 
   P17X(19 downto 4) <= P17X_High_R + P17X_High_L;   -- sum of higher bits
   P17X(3 downto 0) <= X(3 downto 0);   -- lower bits untouched

   -- P65X <-  X<<6  + X
   P65X_High_L <=  (21 downto 21 => '0') & X(14 downto 0) ;
   P65X_High_R <=  (21 downto 15 => '0') & X(14 downto 6); 
   P65X(21 downto 6) <= P65X_High_R + P65X_High_L;   -- sum of higher bits
   P65X(5 downto 0) <= X(5 downto 0);   -- lower bits untouched

   -- P17473X <-  P17X<<10  + P65X
   P17473X_High_L <= P17X(19 downto 0) ;
   P17473X_High_R <=  (29 downto 22 => '0') & P65X(21 downto 10); 
   P17473X(29 downto 10) <= P17473X_High_R + P17473X_High_L;   -- sum of higher bits
   P17473X(9 downto 0) <= P65X(9 downto 0);   -- lower bits untouched

   R <= P17473X(29 downto 0);
end architecture;

