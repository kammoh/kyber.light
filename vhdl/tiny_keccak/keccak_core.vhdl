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
----------------------------------------------------------------------------------------------------------------------------------
-- @description: FIPS 202 Compliant SHA3/Keccak-f[1600] + absorb/squeeze Core TOP 
-- @details:  FIPS 202
--
-- @interface: 
--    Data I/O: valid/ready 4-bit stream
-- 
-- @assumption: i_rate is rate // 64 therefore rate is assumed to be multiple of lane width, 
--           which is the case for all SHA-3 variants
--
-- @protocol:
--    Commands: {i_init, i_absorb, i_squeeze, (i_squeeze, i_init), (i_squeeze, i_absorb)}
--    1. Assert a "command" signal or signal combination
--    2. Keep asserted until 'o_done' is observed
--      2.1. During squeeze: 
--			2.1.a) If 'i_init' is also asserted, the core will do state-initialization after squeeze and then assert done
--          2.1.b) Else if 'i_absorb 'is also asserted, the core will assert 'o_done' after squeeze is completed. 
--                             Subsequent "squeeze" will return the same squeezed sequence, therefore only subsequent init + absorb is valid.
--          2.1.c) Otherwise in runs permutations round (prepare for next squeeze) and will then assert 'o_done'
--    3. In response to observing 'o_done', the caller must deassert all command signals.
--    4. Go to "1."
--
--    rationale: The parent module already keeps track of the sequence of high-level operations ("commands") which should be performed
--
----------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;

entity keccak_core is
	port(
		clk          : in  std_logic;
		rst          : in  std_logic;
		---- input
		i_init       : in  std_logic;
		i_absorb     : in  std_logic;
		i_squeeze    : in  std_logic;
		o_done       : out std_logic;
		i_din_data   : in  std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
		i_din_valid  : in  std_logic;
		o_din_ready  : out std_logic;
		i_rate       : in  unsigned(log2ceil(C_SLICE_WIDTH) - 1 downto 0);
		---- output
		o_dout_data  : out std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
		o_dout_valid : out std_logic;
		i_dout_ready : in  std_logic
	);
end entity keccak_core;

architecture RTL of keccak_core is
	---------------------------------------------------------------- Wires -----------------------------------------------------------------------
	signal round          : unsigned(log2ceil(C_NUM_ROUNDS + 1 - 1) - 1 downto 0);
	signal iota_bit       : std_logic;
	signal bypass_iochipi : std_logic;
	signal bypass_theta   : std_logic;
	signal do_vertical    : std_logic;
	signal hrotate        : std_logic;
	signal shift_en0      : std_logic;
	signal shift_en1      : std_logic;
	signal setzero_mem    : std_logic;
	signal do_xorin       : std_logic;
	signal k              : unsigned(log2ceil(C_LANE_WIDTH) - 1 downto 0);
	signal rho0_mod       : unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
	signal rho1_mod       : unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
	signal from_mem_dout  : T_word;
	signal to_mem_din     : T_word;
	signal mem_addr       : unsigned(log2ceil(C_NUM_MEM_WORDS) - 1 downto 0);
	signal mem_we         : std_logic;
	signal mem_re         : std_logic;
	signal rho_out        : std_logic;
	signal do_odd_lane    : std_logic;
	---------------------------------------------------------------- Constants -------------------------------------------------------------------

	---------------------------------------------------------------- Functions/Procedures --------------------------------------------------------

	---------------------------------------------------------------- Registers/FF ----------------------------------------------------------------

begin

	datapath : entity work.keccak_datapath
		port map(
			clk                  => clk,
			--		-- memory
			--		in_data_from_mem         : in  t_word;
			--		out_data_to_mem          : out t_word
			--
			in_do_xorin          => do_xorin,
			in_do_odd_lane       => do_odd_lane,
			in_do_setzero_mem    => setzero_mem,
			in_do_bypass_iochipi => bypass_iochipi,
			in_do_theta          => bypass_theta,
			in_do_shift_en0      => shift_en0,
			in_do_shift_en1      => shift_en1,
			in_do_hrotate        => hrotate,
			in_do_vertical       => do_vertical,
			in_do_rho_out        => rho_out,
			--
			in_rho0_mod          => rho0_mod,
			in_rho1_mod          => rho1_mod,
			--
			in_iota_bit          => iota_bit,
			--
			in_data_from_mem     => from_mem_dout,
			out_data_to_mem      => to_mem_din,
			--
			din                  => i_din_data,
			dout                 => o_dout_data
		);

	state_mem : entity work.ram_sp
		generic map(
			DEPTH  => (25 + 1) * 64 / 8,
			WORD_BITS => 8
		)
		port map(
			clk      => clk,
			i_ce       => mem_re,
			i_we       => mem_we,
			i_addr  => mem_addr,
			i_data  => to_mem_din,
			o_data => from_mem_dout
		);

	controller : entity work.keccak_controller
		port map(
			clk                 => clk,
			rst                 => rst,
			-- I/O control
			i_init              => i_init,
			i_absorb            => i_absorb,
			i_squeeze           => i_squeeze,
			o_done              => o_done,
			i_din_valid         => i_din_valid,
			o_din_ready         => o_din_ready,
			o_dout_valid        => o_dout_valid,
			i_dout_ready        => i_dout_ready,
			i_rate              => i_rate,
			-- to datapath
			o_do_bypass_iochipi => bypass_iochipi,
			o_do_theta          => bypass_theta,
			o_do_rho_out        => rho_out,
			o_do_setzero_mem    => setzero_mem,
			o_do_xorin          => do_xorin,
			o_do_odd_lane       => do_odd_lane,
			--
			o_do_shift_en0      => shift_en0,
			o_do_shift_en1      => shift_en1,
			o_do_hrotate        => hrotate,
			o_do_vertical       => do_vertical,
			-- to datapath Rho muxes
			o_rho0r             => rho0_mod,
			o_rho1r             => rho1_mod,
			-- to ROMs
			o_round             => round,
			o_k                 => k,
			-- to state memory
			o_mem_addr          => mem_addr,
			o_mem_we            => mem_we,
			o_mem_ce            => mem_re
		);

	iota_lut : entity work.iota_lut
		port map(
			round    => round,
			k        => k,
			iota_bit => iota_bit
		);

end architecture RTL;
