--------------------------------------------------------------------------------
--                             ConstMult_7681_15
--                       (IntConstMult_15_7681_F0_uid2)
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
entity ConstMult_7681_15 is
    port (X : in  std_logic_vector(14 downto 0);
          R : out  std_logic_vector(27 downto 0)   );
end entity;

architecture arch of ConstMult_7681_15 is
signal M1X :  std_logic_vector(15 downto 0);
signal M511X_High_L :  std_logic_vector(15 downto 0);
signal M511X_High_R :  std_logic_vector(15 downto 0);
signal M511X :  std_logic_vector(24 downto 0);
signal P7681X_High_L :  std_logic_vector(14 downto 0);
signal P7681X_High_R :  std_logic_vector(14 downto 0);
signal P7681X :  std_logic_vector(27 downto 0);
begin
   M1X <= (15 downto 0 => '0') - X;

   -- M511X <-  M1X<<9  + X
   M511X_High_L <= M1X(15 downto 0) ;
   M511X_High_R <=  (24 downto 15 => '0') & X(14 downto 9); 
   M511X(24 downto 9) <= M511X_High_R + M511X_High_L;   -- sum of higher bits
   M511X(8 downto 0) <= X(8 downto 0);   -- lower bits untouched

   -- P7681X <-  X<<13  + M511X
   P7681X_High_L <= X(14 downto 0) ;
   P7681X_High_R <=  (27 downto 25 => M511X(24)) & M511X(24 downto 13); 
   P7681X(27 downto 13) <= P7681X_High_R + P7681X_High_L;   -- sum of higher bits
   P7681X(12 downto 0) <= M511X(12 downto 0);   -- lower bits untouched

   R <= P7681X(27 downto 0);
end architecture;

