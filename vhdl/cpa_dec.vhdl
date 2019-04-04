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
--  unit name: Kyber CPA Encrypt/Decrypt top
--              
--! @file      cpa_enc.vhdl
--
--! @language  VHDL 1993/2002/2008
--
--! @brief     Top Level CPA Encrypt/Decrypt
--
--! @author    <Kamyar Mohajerani (kamyar@ieee.org)>
--
--! @company   Cryptographic Engineering Research Group, George Mason University
--
--! @project   KyberLight: Lightweight hardware implementation of CRYSTALS-KYBER PQC
--
--! @context   Post-Quantum Cryptography
--
--! @license   See file LICENSE distributed with this source
--
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--  
--! @date      <02/01/2019>
--
--! @version   <v0.1>
--
--! @details   Instantiates all the components, connects, and schedules them
--!
-----------------------------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! <date> KM: <log>\n
--! <extended description>
-----------------------------------------------------------------------------------------------------------------------
--! @todo  TODO   see cpa_enc @todo
--!        
-----------------------------------------------------------------------------------------------------------------------
--===================================================================================================================--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity cpa_dec is
	port(
		clk         : in  std_logic;
		rst         : in  std_logic;
		-- commands / done
		i_start_dec : in  std_logic;
		i_recv_sk   : in  std_logic;
		o_done      : out std_logic;
		-- ciphertext in, corresponds to PDI
		i_ct_data   : in  T_byte_slv;
		i_ct_valid  : in  std_logic;
		o_ct_ready  : out std_logic;
		-- secret-key in, corresponds to SDI
		i_sk_data   : in  T_byte_slv;
		i_sk_valid  : in  std_logic;
		o_sk_ready  : out std_logic;
		-- message out, corresponds to SDO
		o_pt_data  : out T_byte_slv;
		o_pt_valid : out std_logic;
		i_pt_ready : in  std_logic
	);
end entity cpa_dec;

architecture RTL of cpa_dec is
	signal polymac_recv_aa         : std_logic;
	signal polymac_recv_bb         : std_logic;
	signal polymac_recv_v          : std_logic;
	signal polymac_send_v          : std_logic;
	signal polymac_do_mac          : std_logic;
	signal polymac_done            : std_logic;
	signal polymac_subtract        : std_logic;
	signal polymac_rama_blk        : unsigned(0 downto 0);
	signal polymac_din_data        : T_coef_us;
	signal polymac_din_valid       : std_logic;
	signal polymac_din_ready       : std_logic;
	signal polymac_dout_data       : T_coef_us;
	signal polymac_dout_valid      : std_logic;
	signal polymac_dout_ready      : std_logic;
	signal polymac_remin_data      : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal polymac_remin_valid     : std_logic;
	signal polymac_remin_ready     : std_logic;
	signal polymac_remout_data     : T_coef_us;
	signal polymac_remout_valid    : std_logic;
	signal polymac_remout_ready    : std_logic;
	signal polymac_divider_busy    : std_logic;
	signal uin_data                : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal uin_valid               : std_logic;
	signal uin_ready               : std_logic;
	signal compressor_divout_data  : T_coef_us;
	signal remdivout_valid         : std_logic;
	signal remdivout_ready         : std_logic;
	signal compressor_is_msg       : std_logic;
	signal compressor_is_polyvec   : std_logic;
	signal compressor_din_data     : T_coef_us;
	signal compressor_din_valid    : std_logic;
	signal compressor_din_ready    : std_logic;
	signal o_ct_data               : T_byte_slv;
	signal compressor_dout_valid   : std_logic;
	signal i_ct_ready              : std_logic;
	signal compressor_divin_data   : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal compressor_divin_valid  : std_logic;
	signal compressor_divin_ready  : std_logic;
	signal compressor_divout_valid : std_logic;
	signal compressor_divout_ready : std_logic;
	signal deserializer_din_data : T_byte_slv;
	signal deserializer_din_valid : std_logic;
	signal deserializer_din_ready : std_logic;
	signal deserializer_coefout_data : T_Coef_slv;
	signal deserializer_coefout_valid : std_logic;
	signal deserializer_coefout_ready : std_logic;
	signal i_din_data : T_byte_slv;
	signal i_din_valid : std_logic;
	signal o_din_ready : std_logic;
	signal o_coefout_data : T_Coef_slv;
	signal o_coefout_valid : std_logic;
	signal i_coefout_ready : std_logic;

begin
	
		deserializer_inst : entity work.deserializer
		port map(
			clk             => clk,
			rst             => rst,
			i_din_data      => deserializer_din_data,
			i_din_valid     => deserializer_din_valid,
			o_din_ready     => deserializer_din_ready,
			o_coefout_data  => deserializer_coefout_data,
			o_coefout_valid => deserializer_coefout_valid,
			i_coefout_ready => deserializer_coefout_ready
		);
		
		decompress_inst : entity work.decompressor
			port map(
				clk             => clk,
				rst             => rst,
				i_din_data      => i_din_data,
				i_din_valid     => i_din_valid,
				o_din_ready     => o_din_ready,
				o_coefout_data  => o_coefout_data,
				o_coefout_valid => o_coefout_valid,
				i_coefout_ready => i_coefout_ready
			);
		

	polyvec_mac_inst : entity work.polyvec_mac
		generic map(
			G_NUM_RAM_A_BLOCKS     => KYBER_K + 1,
			G_USE_EXTERNAL_DIVIDER => True
		)
		port map(
			clk            => clk,
			rst            => rst,
			i_recv_aa      => polymac_recv_aa,
			i_recv_bb      => polymac_recv_bb,
			i_recv_v       => polymac_recv_v,
			i_send_v       => polymac_send_v,
			i_do_mac       => polymac_do_mac,
			o_done         => polymac_done,
			i_subtract     => polymac_subtract,
			i_rama_blk     => polymac_rama_blk,
			i_din_data     => polymac_din_data,
			i_din_valid    => polymac_din_valid,
			o_din_ready    => polymac_din_ready,
			o_dout_data    => polymac_dout_data,
			o_dout_valid   => polymac_dout_valid,
			i_dout_ready   => polymac_dout_ready,
			o_remin_data   => polymac_remin_data,
			o_remin_valid  => polymac_remin_valid,
			i_remin_ready  => polymac_remin_ready,
			i_remout_data  => polymac_remout_data,
			i_remout_valid => polymac_remout_valid,
			o_remout_ready => polymac_remout_ready,
			o_divider_busy => polymac_divider_busy
		);

	divider_inst : entity work.divider
		generic map(
			G_IN_WIDTH => 2 * KYBER_COEF_BITS
		)
		port map(
			clk               => clk,
			rst               => rst,
			i_uin_data        => uin_data,
			i_uin_valid       => uin_valid,
			o_uin_ready       => uin_ready,
			o_remout_data     => polymac_remout_data,
			o_divout_data     => compressor_divout_data,
			o_remdivout_valid => remdivout_valid,
			i_remdivout_ready => remdivout_ready
		);

	polymac_rama_blk <= unsigned("0");

	compressor_inst : entity work.compressor
		generic map(
			G_ENCRYPT => False,
			G_DECRYPT => True
		)
		port map(
			clk            => clk,
			rst            => rst,
			i_is_msg       => compressor_is_msg,
			i_is_polyvec   => compressor_is_polyvec,
			i_din_data     => compressor_din_data,
			i_din_valid    => compressor_din_valid,
			o_din_ready    => compressor_din_ready,
			o_dout_data    => o_ct_data,
			o_dout_valid   => compressor_dout_valid,
			i_dout_ready   => i_ct_ready,
			o_divin_data   => compressor_divin_data,
			o_divin_valid  => compressor_divin_valid,
			i_divin_ready  => compressor_divin_ready,
			i_divout_data  => compressor_divout_data,
			i_divout_valid => compressor_divout_valid,
			o_divout_ready => compressor_divout_ready
		);

	compressor_is_msg     <= '1';
	compressor_is_polyvec <= '0';       -- don't care

end architecture RTL;
