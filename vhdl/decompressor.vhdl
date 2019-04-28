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
--  unit name: Decompressor
--              
--! @file      decompressor.vhdl
--
--! @brief     Decompressor used in CPA decrypt
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
--! @details   implements poly_decompress (i_is_polyvec = '0') and polyvec_decompress (i_is_polyvec = '1') 
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

entity decompressor is
	port(
		clk             : in  std_logic;
		rst             : in  std_logic;
		--
		i_is_polyvec    : in  std_logic;
		--
		i_bytein_data   : in  T_byte_slv;
		i_bytein_valid  : in  std_logic;
		o_bytein_ready  : out std_logic;
		--
		o_coefout_data  : out T_Coef_us;
		o_coefout_valid : out std_logic;
		i_coefout_ready : in  std_logic
	);
end entity decompressor;

architecture RTL of decompressor is

	signal mutliplier_din_data   : unsigned(POLYVEC_SHIFT - 1 downto 0);
	signal mutliplier_din_valid  : std_logic;
	signal mutliplier_din_ready  : std_logic;
	signal mutliplier_dout_data  : unsigned(KYBER_COEF_BITS + POLYVEC_SHIFT - 1 downto 0);
	signal mutliplier_dout_valid : std_logic;
	signal mutliplier_dout_ready : std_logic;
	signal asym_pv_din_data      : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal asym_pv_din_valid     : std_logic;
	signal asym_pv_din_ready     : std_logic;
	signal asym_pv_dout_data     : std_logic_vector(POLYVEC_SHIFT - 1 downto 0);
	signal asym_pv_dout_valid    : std_logic;
	signal asym_pv_dout_ready    : std_logic;
	signal asym_poly_din_data    : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal asym_poly_din_valid   : std_logic;
	signal asym_poly_din_ready   : std_logic;
	signal asym_poly_dout_data   : std_logic_vector(POLY_SHIFT - 1 downto 0);
	signal asym_poly_dout_valid  : std_logic;
	signal asym_poly_dout_ready  : std_logic;
	signal addition              : unsigned(KYBER_COEF_BITS + POLYVEC_SHIFT - 1 - 1 downto 0);
	--
	signal DUMMY_NIST_ROUND      : positive := NIST_ROUND; -- @suppress "Unused declaration"

begin

	--	mutliplier_dout_data  <= mutliplier_din_data * KYBER_Q_US;
	--	mutliplier_dout_valid <= mutliplier_din_valid;
	--	mutliplier_din_ready  <= mutliplier_dout_ready;

	gen_mult_7681 : if KYBER_Q = 7681 generate

		ConstMult_7681_11_24_inst : entity work.ConstMult_7681_11_24
			port map(
				clk       => clk,
				rst       => rst,
				i_X_data  => mutliplier_din_data,
				i_X_valid => mutliplier_din_valid,
				o_X_ready => mutliplier_din_ready,
				o_R_data  => mutliplier_dout_data,
				o_R_valid => mutliplier_dout_valid,
				i_R_ready => mutliplier_dout_ready
			);

	end generate gen_mult_7681;

	gen_mult_3329 : if KYBER_Q = 3329 generate

		ConstMult_3329_10_22 : entity work.ConstMult_3329_10_22
			port map(
				clk       => clk,
				rst       => rst,
				i_X_data  => mutliplier_din_data,
				i_X_valid => mutliplier_din_valid,
				o_X_ready => mutliplier_din_ready,
				o_R_data  => mutliplier_dout_data,
				o_R_valid => mutliplier_dout_valid,
				i_R_ready => mutliplier_dout_ready
			);

	end generate gen_mult_3329;

	asym_fifo_polyvec : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_byte_slv'length,
			G_OUT_WIDTH => POLYVEC_SHIFT
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => asym_pv_din_data,
			i_din_valid  => asym_pv_din_valid,
			o_din_ready  => asym_pv_din_ready,
			o_dout_data  => asym_pv_dout_data,
			o_dout_valid => asym_pv_dout_valid,
			i_dout_ready => asym_pv_dout_ready
		);

	asym_fifo_poly : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_byte_slv'length,
			G_OUT_WIDTH => POLY_SHIFT
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => asym_poly_din_data,
			i_din_valid  => asym_poly_din_valid,
			o_din_ready  => asym_poly_din_ready,
			o_dout_data  => asym_poly_dout_data,
			o_dout_valid => asym_poly_dout_valid,
			i_dout_ready => asym_poly_dout_ready
		);

	asym_poly_din_data  <= i_bytein_data;
	asym_poly_din_valid <= i_bytein_valid and not i_is_polyvec;

	asym_pv_din_data  <= i_bytein_data;
	asym_pv_din_valid <= i_bytein_valid and i_is_polyvec;

	addition <= resize(shift_right(mutliplier_dout_data, POLY_SHIFT - 1), addition'length) + (i_is_polyvec & to_unsigned(0, POLYVEC_SHIFT - POLY_SHIFT - 1) & not i_is_polyvec);

	mux_proc : process(                 --
	i_is_polyvec, asym_pv_din_ready, asym_poly_din_ready, addition, asym_pv_dout_data, --
	asym_pv_dout_valid, asym_poly_dout_data, asym_poly_dout_valid --
	) is
	begin
		if i_is_polyvec = '1' then
			o_bytein_ready <= asym_pv_din_ready;

			mutliplier_din_data  <= unsigned(asym_pv_dout_data);
			mutliplier_din_valid <= asym_pv_dout_valid;

			o_coefout_data <= resize(shift_right(addition, POLYVEC_SHIFT - POLY_SHIFT + 1), o_coefout_data'length);
		else
			o_bytein_ready <= asym_poly_din_ready;

			mutliplier_din_data  <= resize(unsigned(asym_poly_dout_data), mutliplier_din_data'length);
			mutliplier_din_valid <= asym_poly_dout_valid;

			o_coefout_data <= resize(shift_right(addition, 1), o_coefout_data'length);
		end if;
	end process mux_proc;

	asym_poly_dout_ready <= mutliplier_din_ready;
	asym_pv_dout_ready   <= mutliplier_din_ready;

	-- multiplier -> add -> shift -> out

	o_coefout_valid       <= mutliplier_dout_valid;
	mutliplier_dout_ready <= i_coefout_ready;

end architecture RTL;
