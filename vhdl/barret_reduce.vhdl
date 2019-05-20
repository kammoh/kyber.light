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

entity barret_reduce is
	generic(
		G_IN_WIDTH : positive := 2 * KYBER_COEF_BITS
	);
	port(
		clk : in  std_logic;
		rst : in  std_logic;
		a   : in  std_logic_vector(G_IN_WIDTH - 1 downto 0);
		r   : out std_logic_vector(KYBER_COEF_BITS - 1 downto 0)
	);
end entity barret_reduce;

architecture rtl of barret_reduce is
	constant CC : positive := (2**G_IN_WIDTH) / KYBER_Q;
	--	constant C        : unsigned(G_IN_WIDTH - KYBER_COEF_BITS downto 0) := to_unsigned((2**G_IN_WIDTH) / KYBER_Q, G_IN_WIDTH - KYBER_COEF_BITS + 1);

	signal a_hi          : unsigned(G_IN_WIDTH - KYBER_COEF_BITS downto 0);
	signal cm0_out       : unsigned(G_IN_WIDTH - KYBER_COEF_BITS + log2ceil(CC) downto 0);
	signal cm1_out       : unsigned(2 * KYBER_COEF_BITS + 1 downto 0);
	signal quotient      : unsigned(KYBER_COEF_BITS + 1 downto 0);
	signal product       : unsigned(KYBER_COEF_BITS + 1 downto 0);
	attribute mult_style : string;

	attribute use_dsp48 : string;
	attribute use_dsp48 OF cm0_out : SIGNAL IS "no";
	attribute use_dsp48 OF cm1_out : SIGNAL IS "no";

	attribute mult_style of cm0_out : signal is "auto"; --"{auto|block|pipe_block|kcm|csd|lut|pipe_lut}";
	attribute mult_style of cm1_out : signal is "auto";
	signal y0 : unsigned(KYBER_COEF_BITS + 1 downto 0);
	signal y1 : unsigned(KYBER_COEF_BITS + 2 downto 0);
	signal y2 : unsigned(KYBER_COEF_BITS + 2 downto 0);
	signal y  : unsigned(KYBER_COEF_BITS - 1 downto 0);

	function pair(first, second : integer) return unsigned is
	begin
		return to_unsigned(first, 32) & to_unsigned(second, 32);
	end function;

begin

	a_hi <= unsigned(a(G_IN_WIDTH - 1 downto KYBER_COEF_BITS - 1));

	quotient <= resize(cm0_out(minimum(cm0_out'length - 1, G_IN_WIDTH + 2) downto G_IN_WIDTH - KYBER_COEF_BITS + 1), quotient'length);

	generate_const_mults_26_13 : if pair(G_IN_WIDTH, KYBER_COEF_BITS) = pair(26, 13) generate
		cm0_8736_15 : entity work.ConstMult_8736_14
			port map(
				X => a_hi,
				R => cm0_out
			);
		cm1_7681_14 : entity work.ConstMult_7681_14 -- KYBER_Q, 
			port map(
				X => quotient,
				R => cm1_out
			);
	end generate;

	generate_const_mults_24_12 : if pair(G_IN_WIDTH, KYBER_COEF_BITS) = pair(24, 12) generate
		cm0_8736_15 : entity work.ConstMult_5039_13
			port map(
				X => a_hi,
				R => cm0_out
			);
		cm1_7681_14 : entity work.ConstMult_3329_14
			port map(
				X => quotient,
				R => cm1_out
			);
	end generate;

	generate_const_mults_other : if pair(G_IN_WIDTH, KYBER_COEF_BITS) /= pair(26, 13) and pair(G_IN_WIDTH, KYBER_COEF_BITS) /= pair(24, 12) generate
		assert false Report "No optimized constant multipliers for parameters G_IN_WIDTH=" & integer'image(G_IN_WIDTH) &
				   " KYBER_COEF_BITS=" & integer'image(KYBER_COEF_BITS) &
					" Using unoptimized implementation" severity warning;
		cm0_out <= resize(unsigned(a_hi) * CC, cm0_out'length);
		--				cm0_out <= std_logic_vector(resize( unsigned(cm0_in) * CC, cm0_out'length));
		cm1_out <= resize(unsigned(quotient) * KYBER_Q, cm1_out'length);

	end generate;

	product <= unsigned(cm1_out(KYBER_COEF_BITS + 1 downto 0));

	reg_proc : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then

			else
				
			end if;
		end if;
	end process reg_proc;

	y0 <= unsigned(a(KYBER_COEF_BITS + 1 downto 0)) - product;

	y1 <= ('0' & y0) - KYBER_Q;
	y2 <= ('0' & y0) - (2 * KYBER_Q);
	--	y1 <= ('0' & y0) - M;
	--	y2 <= ('0' & y0) - (M & '0');
	--
	y  <= y0(KYBER_COEF_BITS - 1 downto 0) when y1(y1'left) = '1'
		else y1(KYBER_COEF_BITS - 1 downto 0) when y2(y1'left) = '1'
		else y2(KYBER_COEF_BITS - 1 downto 0);
	--
	r  <= std_logic_vector(y);

end rtl;
