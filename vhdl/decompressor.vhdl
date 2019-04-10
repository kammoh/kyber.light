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
	signal mutliplier_din_data   : unsigned(11 - 1 downto 0);
	signal mutliplier_din_valid  : std_logic;
	signal mutliplier_din_ready  : std_logic;
	signal mutliplier_dout_data  : unsigned(KYBER_COEF_BITS + 11 - 1 downto 0);
	signal mutliplier_dout_valid : std_logic;
	signal mutliplier_dout_ready : std_logic;
	signal a11_din_data          : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal a11_din_valid         : std_logic;
	signal a11_din_ready         : std_logic;
	signal a11_dout_data         : std_logic_vector(11 - 1 downto 0);
	signal a11_dout_valid        : std_logic;
	signal a11_dout_ready        : std_logic;
	signal a3_din_data           : std_logic_vector(T_byte_slv'length - 1 downto 0);
	signal a3_din_valid          : std_logic;
	signal a3_din_ready          : std_logic;
	signal a3_dout_data          : std_logic_vector(3 - 1 downto 0);
	signal a3_dout_valid         : std_logic;
	signal a3_dout_ready         : std_logic;
	signal addition              : unsigned(KYBER_COEF_BITS + 11 - 1 - 1 downto 0);

begin

	--	mutliplier_dout_data  <= mutliplier_din_data * KYBER_Q_US;
	--	mutliplier_dout_valid <= mutliplier_din_valid;
	--	mutliplier_din_ready  <= mutliplier_dout_ready;

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

	asym_fifo_8to11 : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_byte_slv'length,
			G_OUT_WIDTH => 11
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

	asym_fifo_8to3 : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_byte_slv'length,
			G_OUT_WIDTH => 3
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

	a3_din_data  <= i_bytein_data;
	a3_din_valid <= i_bytein_valid and not i_is_polyvec;

	a11_din_data  <= i_bytein_data;
	a11_din_valid <= i_bytein_valid and i_is_polyvec;

	addition <= resize(shift_right(mutliplier_dout_data, 2), addition'length) + (i_is_polyvec & "0000000" & not i_is_polyvec);

	mux_proc : process(                 --
	i_is_polyvec, a11_din_ready, a3_din_ready, addition, a11_dout_data, --
	a11_dout_valid, a3_dout_data, a3_dout_valid --
	) is
	begin
		if i_is_polyvec = '1' then
			o_bytein_ready <= a11_din_ready;

			mutliplier_din_data  <= unsigned(a11_dout_data);
			mutliplier_din_valid <= a11_dout_valid;

			o_coefout_data <= resize(shift_right(addition, 9), 13);
		else
			o_bytein_ready <= a3_din_ready;

			mutliplier_din_data  <= resize(unsigned(a3_dout_data), mutliplier_din_data'length);
			mutliplier_din_valid <= a3_dout_valid;

			o_coefout_data <= resize(shift_right(addition, 1), 13);
		end if;
	end process mux_proc;

	a3_dout_ready  <= mutliplier_din_ready;
	a11_dout_ready <= mutliplier_din_ready;

	-- multiplier -> add -> shift -> out

	o_coefout_valid       <= mutliplier_dout_valid;
	mutliplier_dout_ready <= i_coefout_ready;

end architecture RTL;
