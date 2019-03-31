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

entity compressor is
	port(
		clk            : in  std_logic;
		rst            : in  std_logic;
		-- Control
		i_is_polyvec   : in  std_logic;
		--
		i_din_data     : in  T_coef_us;
		i_din_valid    : in  std_logic;
		o_din_ready    : out std_logic;
		--
		o_dout_data    : out T_byte_slv;
		o_dout_valid   : out std_logic;
		i_dout_ready   : in  std_logic;
		-- divider
		o_divin_data   : out unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
		o_divin_valid  : out std_logic;
		i_divin_ready  : out std_logic;
		i_divout_data  : in  T_coef_us;
		i_divout_valid : in  std_logic;
		o_divout_ready : out std_logic
	);
end entity compressor;

architecture RTL of compressor is
	signal a11_din_data   : std_logic_vector(11 - 1 downto 0);
	signal a11_din_valid  : std_logic;
	signal a11_din_ready  : std_logic;
	signal a11_dout_data  : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal a11_dout_valid : std_logic;
	signal a11_dout_ready : std_logic;
	signal a3_din_data    : std_logic_vector(3 - 1 downto 0);
	signal a3_din_valid   : std_logic;
	signal a3_din_ready   : std_logic;
	signal a3_dout_data   : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal a3_dout_valid  : std_logic;
	signal a3_dout_ready  : std_logic;

begin
	asym_fifo_11_to_8 : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => 11,
			G_OUT_WIDTH => T_byte_slv'length
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => a11_din_data,
			i_din_valid  => a11_din_valid,
			o_din_ready  => a11_din_ready,
			o_dout_data  => a11_dout_data,
			o_dout_valid => a11_dout_valid,
			i_dout_ready => a11_dout_ready
		);

	asym_fifo_3_to_8 : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => 3,
			G_OUT_WIDTH => T_byte_slv'length
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => a3_din_data,
			i_din_valid  => a3_din_valid,
			o_din_ready  => a3_din_ready,
			o_dout_data  => a3_dout_data,
			o_dout_valid => a3_dout_valid,
			i_dout_ready => a3_dout_ready
		);

	-- in -> divider
	o_divin_data <= ("00" & i_din_data & "00000000000") + (KYBER_Q / 2) when i_is_polyvec = '1' else ("0000000000" & i_din_data & "000") + (KYBER_Q / 2);

	o_divin_valid <= i_din_valid;
	o_din_ready   <= i_divin_ready;

	-- divider -> a3, a11
	a3_din_data    <= std_logic_vector(i_divout_data(3 - 1 downto 0));
	a3_din_valid   <= i_divout_valid and not i_is_polyvec;
	--
	a11_din_data   <= std_logic_vector(i_divout_data(11 - 1 downto 0));
	a11_din_valid  <= i_divout_valid and i_is_polyvec;
	--
	o_divout_ready <= a11_dout_ready when i_is_polyvec = '1' else a3_dout_ready;

	--  a3, a11 -> out
	o_dout_data    <= a11_dout_data when i_is_polyvec = '1' else a3_dout_data;
	o_dout_valid   <= a11_dout_valid when i_is_polyvec = '1' else a3_dout_valid;
	a3_dout_ready  <= i_dout_ready and not i_is_polyvec;
	a11_dout_ready <= i_dout_ready and i_is_polyvec;

end architecture RTL;
