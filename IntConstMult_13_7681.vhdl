--------------------------------------------------------------------------------
--                        IntConstMult_13_7681_F0_uid2
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
entity IntConstMult_13_7681_F0_uid2 is
    port (X : in  std_logic_vector(12 downto 0);
          R : out  std_logic_vector(25 downto 0)   );
end entity;

architecture arch of IntConstMult_13_7681_F0_uid2 is
signal M1X :  std_logic_vector(13 downto 0);
signal M511X_High_L :  std_logic_vector(13 downto 0);
signal M511X_High_R :  std_logic_vector(13 downto 0);
signal M511X :  std_logic_vector(22 downto 0);
signal P7681X_High_L :  std_logic_vector(12 downto 0);
signal P7681X_High_R :  std_logic_vector(12 downto 0);
signal P7681X :  std_logic_vector(25 downto 0);
begin
   M1X <= (13 downto 0 => '0') - X;

   -- M511X <-  M1X<<9  + X
   M511X_High_L <= M1X(13 downto 0) ;
   M511X_High_R <=  (22 downto 13 => '0') & X(12 downto 9); 
   M511X(22 downto 9) <= M511X_High_R + M511X_High_L;   -- sum of higher bits
   M511X(8 downto 0) <= X(8 downto 0);   -- lower bits untouched

   -- P7681X <-  X<<13  + M511X
   P7681X_High_L <= X(12 downto 0) ;
   P7681X_High_R <=  (25 downto 23 => M511X(22)) & M511X(22 downto 13); 
   P7681X(25 downto 13) <= P7681X_High_R + P7681X_High_L;   -- sum of higher bits
   P7681X(12 downto 0) <= M511X(12 downto 0);   -- lower bits untouched

   R <= P7681X(25 downto 0);
end architecture;

