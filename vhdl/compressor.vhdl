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
--  unit name: Compressor / Serializer
--              
--! @file      compress.vhdl
--
--! @brief     implements: poly_compress, polyvec_compress, poly_tomsg_nofreeze
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
--! @details   Three different configurations are possible through the generics:
--!
--!              G_ENCRYPT  G_DECRYPT
--!              ---------- ---------
--!              True       False         only encrypt compressions supported, i_is_msg MUST be constant '0'
--!              True       True          both encrypt and decrypt compressions are supported with shared resources
--!              False      True          only decrypt poly_tomsg is supported
--
--
--! <b>Dependencies:</b>\n
--!         divider (external)
--!         asymmetric_fifo
--!
--! <b>References:</b>\n
--!
--! <b>Modified by:</b>\n
--! Author: Kamyar Mohajerani
-----------------------------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! <date> KM: <log>\n
--! <extended description>
-----------------------------------------------------------------------------------------------------------------------
--! @todo \n
--
-----------------------------------------------------------------------------------------------------------------------
--===================================================================================================================--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity compressor is
	generic(
		G_ENCRYPT : boolean := True;
		G_DECRYPT : boolean := False
	);
	port(
		clk             : in  std_logic;
		rst             : in  std_logic;
		-- Control
		i_is_msg        : in  std_logic;
		i_is_polyvec    : in  std_logic;
		--
		i_coeffin_data  : in  T_coef_us;
		i_coeffin_valid : in  std_logic;
		o_coeffin_ready : out std_logic;
		--
		o_byteout_data  : out T_byte_slv;
		o_byteout_valid : out std_logic;
		i_byteout_ready : in  std_logic;
		-- divider
		o_divin_data    : out unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
		o_divin_valid   : out std_logic;
		i_divin_ready   : in  std_logic;
		--
		i_divout_data   : in  T_coef_us;
		i_divout_valid  : in  std_logic;
		o_divout_ready  : out std_logic
	);
end entity compressor;

architecture RTL of compressor is
	signal a_pv_din_data     : std_logic_vector(POLYVEC_SHIFT - 1 downto 0);
	signal a_pv_din_valid    : std_logic;
	signal a_pv_din_ready    : std_logic;
	signal a_pv_dout_data    : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal a_pv_dout_valid   : std_logic;
	signal a_pv_dout_ready   : std_logic;
	signal a_poly_din_data   : std_logic_vector(POLY_SHIFT - 1 downto 0);
	signal a_poly_din_valid  : std_logic;
	signal a_poly_din_ready  : std_logic;
	signal a_poly_dout_data  : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal a_poly_dout_valid : std_logic;
	signal a_poly_dout_ready : std_logic;
	signal shifted           : unsigned(T_coef_us'length + POLYVEC_SHIFT - 1 downto 0);
	signal sel               : std_logic_vector(1 downto 0);
	signal a1_din_data       : std_logic_vector(1 - 1 downto 0);
	signal a1_din_valid      : std_logic;
	signal a1_din_ready      : std_logic;
	signal a1_dout_data      : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal a1_dout_valid     : std_logic;
	signal a1_dout_ready     : std_logic;

	constant Q_halfed : unsigned(log2ceil(KYBER_Q / 2) - 1 downto 0) := to_unsigned(KYBER_Q / 2, log2ceil(KYBER_Q / 2));

begin

	--================================================================================================
	gen_encrypt : if G_ENCRYPT generate -- with or without decrypt

		asym_fifo_pv_to_8 : entity work.asymmetric_fifo
			generic map(
				G_IN_WIDTH  => POLYVEC_SHIFT,
				G_OUT_WIDTH => T_byte_slv'length
			)
			port map(
				clk          => clk,
				rst          => rst,
				i_din_data   => a_pv_din_data,
				i_din_valid  => a_pv_din_valid,
				o_din_ready  => a_pv_din_ready,
				o_dout_data  => a_pv_dout_data,
				o_dout_valid => a_pv_dout_valid,
				i_dout_ready => a_pv_dout_ready
			);

		asym_fifo_poly_to_8 : entity work.asymmetric_fifo
			generic map(
				G_IN_WIDTH  => POLY_SHIFT,
				G_OUT_WIDTH => T_byte_slv'length
			)
			port map(
				clk          => clk,
				rst          => rst,
				i_din_data   => a_poly_din_data,
				i_din_valid  => a_poly_din_valid,
				o_din_ready  => a_poly_din_ready,
				o_dout_data  => a_poly_dout_data,
				o_dout_valid => a_poly_dout_valid,
				i_dout_ready => a_poly_dout_ready
			);

		sel <= i_is_msg & i_is_polyvec;

		with sel select shifted <=
			shift_left(resize(i_coeffin_data, shifted'length), POLYVEC_SHIFT) when "01",
			shift_left(resize(i_coeffin_data, shifted'length), POLY_SHIFT) when "00",
				resize(i_coeffin_data & "0", shifted'length) when others; -- i_is_msg

		-- divider -> a3, a11

		--
		with sel select o_divout_ready <=
			a_pv_din_ready when "01",
			a_poly_din_ready when "00",
			a1_din_ready when others;

		--  a3, a11 -> out

		with sel select o_byteout_data <=
			a_pv_dout_data when "01",
			a_poly_dout_data when "00",
		  a1_dout_data when others;

		with sel select o_byteout_valid <=
			a_pv_dout_valid when "01",
			a_poly_dout_valid when "00",
		  a1_dout_valid when others;

		a_poly_din_data  <= std_logic_vector(i_divout_data(POLY_SHIFT - 1 downto 0));
		a_poly_din_valid <= i_divout_valid and not i_is_polyvec and not i_is_msg;
		--
		a_pv_din_data    <= std_logic_vector(i_divout_data(POLYVEC_SHIFT - 1 downto 0));
		a_pv_din_valid   <= i_divout_valid and i_is_polyvec and not i_is_msg;
		--
		a1_din_data      <= std_logic_vector(i_divout_data(0 downto 0));
		a1_din_valid     <= i_divout_valid and i_is_msg;

		a_poly_dout_ready <= i_byteout_ready and not i_is_polyvec and not i_is_msg;
		a_pv_dout_ready   <= i_byteout_ready and i_is_polyvec and not i_is_msg;
		a1_dout_ready     <= i_byteout_ready and i_is_msg;

	end generate gen_encrypt;
	--================================================================================================

	--================================================================================================
	-- ONLY encrypt:
	--------------------------------------------------------------------------------------------------
	generate_not_decrypt : if G_ENCRYPT and not G_DECRYPT generate
		assert i_is_msg = '0' or i_is_msg = 'U'
		report "compressor ENCRYPT and not DECRYPT: i_is_msg should be tied to 0"
		severity failure;
	end generate generate_not_decrypt;
	--================================================================================================

	--================================================================================================
	generate_decrypt : if G_DECRYPT generate
		asymmetric_fifo_inst : entity work.asymmetric_fifo
			generic map(
				G_IN_WIDTH  => 1,
				G_OUT_WIDTH => T_byte_slv'length
			)
			port map(
				clk          => clk,
				rst          => rst,
				i_din_data   => a1_din_data,
				i_din_valid  => a1_din_valid,
				o_din_ready  => a1_din_ready,
				o_dout_data  => a1_dout_data,
				o_dout_valid => a1_dout_valid,
				i_dout_ready => a1_dout_ready
			);

	end generate generate_decrypt;
	--================================================================================================

	--================================================================================================
	-- ONLY decrypt:
	--------------------------------------------------------------------------------------------------
	generate_dec_noenc : if G_DECRYPT and not G_ENCRYPT generate
		shifted <= shift_left(resize(i_coeffin_data, shifted'length), 1); -- i_is_msg

		-- divider -> a1
		o_divout_ready  <= a1_din_ready;
		a1_din_data     <= std_logic_vector(i_divout_data(0 downto 0));
		a1_din_valid    <= i_divout_valid;
		--  a1 -> out
		o_byteout_data  <= a1_dout_data;
		o_byteout_valid <= a1_dout_valid;
		a1_dout_ready   <= i_byteout_ready;

	end generate generate_dec_noenc;
	--================================================================================================

	-- TODO is there a more efficient implementation?
	--	o_divin_data  <= (shifted(shifted'length - 1 downto POLY_SHIFT) + Q_halfed(Q_halfed'length - 1 downto POLY_SHIFT)) & Q_halfed(POLY_SHIFT - 1 downto 0); 

	o_divin_data    <= resize(shifted + Q_halfed, o_divin_data'length);
	o_divin_valid   <= i_coeffin_valid;
	o_coeffin_ready <= i_divin_ready;

end architecture RTL;
