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
--! @file      sha3_noisegen.vhdl
--
--! @brief     SHA3 hash wrapper, generate noise polynomials
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

use work.ocram_sp;
use work.keccak_pkg.all;
use work.kyber_pkg.all;

entity sha3_noisegen is
	generic(
		G_MAX_IN_BYTES : positive := KYBER_SYMBYTES
	);
	port(
		clk          : in  std_logic;
		rst          : in  std_logic;
		-- Commands
		i_recv_msg   : in  std_logic;
		i_send_hash  : in  std_logic;
		-- Parameters
		i_nonce      : in  T_byte_us;
		--		i_msg_bytes : in unsigned(log2ceil(G_MAX_IN_BYTES) - 1 downto 0); -- 32
		--		i_delim           : in  T_byte_slv;
		-- Done
		o_done       : out std_logic;
		-- Data input
		i_din_data   : in  T_byte_slv;
		i_din_valid  : in  std_logic;
		o_din_ready  : out std_logic;
		-- Data output
		o_dout_data  : out T_byte_slv;
		o_dout_valid : out std_logic;
		i_dout_ready : in  std_logic
	);
end entity sha3_noisegen;

architecture RTL of sha3_noisegen is
	------------------------------------------------------=( Constants )=----------------------------------------------------------
	constant C_RATE_BITWIDTH   : positive   := log2ceilnz(C_SLICE_WIDTH);
	constant C_SHA3_256_RATE   : positive   := 136; -- SHA3-256
	constant C_SHA3_256_DELIM  : T_byte_slv := x"1F";
	constant C_SHA3_SENTINEL   : T_byte_slv := x"80";
	constant C_FULL_RATE       : positive   := C_SHA3_256_RATE / 8;
	constant C_CUT_RATE        : positive   := (KYBER_N - C_SHA3_256_RATE) / 8;
	constant C_FULL_RATE_US    : unsigned   := to_unsigned(C_FULL_RATE, C_RATE_BITWIDTH);
	constant C_CUT_RATE_US     : unsigned   := to_unsigned(C_CUT_RATE, C_RATE_BITWIDTH);
	------------------------------------------------------=( Types )=--------------------------------------------------------------
	type T_state is (
		s_init,
		s_recv_msg,
		s_keccak_init, s_keccak_init_done,
		s_keccak_absorb, s_keccak_absorb_done,
		s_keccak_squeeze_1, s_keccak_squeeze_1_done, s_keccak_squeeze_2,
		s_done
	);
	--
	------------------------------------------------------=( Registers/FFs )=-------------------------------------------------------
	signal state               : T_state;
	signal counter_reg         : unsigned(log2ceilnz(maximum(C_SHA3_256_RATE, G_MAX_IN_BYTES)) - 1 downto 0); -- 0..135
	signal cram_dout_valid_reg : std_logic;
	--
	------------------------------------------------------=( Wires )=---------------------------------------------------------------
	signal byte2hw_din_data    : T_byte_slv;
	signal byte2hw_din_valid   : std_logic;
	signal byte2hw_din_ready   : std_logic;
	signal byte2hw_dout_data   : T_halfword;
	signal byte2hw_dout_valid  : std_logic;
	signal byte2hw_dout_ready  : std_logic;
	signal hw2byte_din_data    : T_halfword;
	signal hw2byte_din_valid   : std_logic;
	signal hw2byte_din_ready   : std_logic;
	signal hw2byte_dout_data   : T_byte_slv;
	signal hw2byte_dout_valid  : std_logic;
	signal hw2byte_dout_ready  : std_logic;
	signal cram_ce             : std_logic;
	signal cram_we             : std_logic;
	signal cram_in_addr        : unsigned(log2ceilnz(G_MAX_IN_BYTES) - 1 downto 0);
	signal cram_in_data        : T_byte_slv;
	signal cram_out_data       : T_byte_slv;
	signal keccak_rate         : unsigned(C_RATE_BITWIDTH - 1 downto 0);
	signal keccak_init         : std_logic;
	signal keccak_absorb       : std_logic;
	signal keccak_squeeze      : std_logic;
	signal keccak_done         : std_logic;
	signal keccak_din_data     : std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
	signal keccak_din_valid    : std_logic;
	signal keccak_din_ready    : std_logic;
	signal keccak_dout_data    : std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
	signal keccak_dout_valid   : std_logic;
	signal keccak_dout_ready   : std_logic;

begin
	coins_ram : entity work.ocram_sp
		generic map(
			D_BITS => T_byte_slv'length,
			DEPTH  => G_MAX_IN_BYTES
		)
		port map(
			clk      => clk,
			ce       => cram_ce,
			we       => cram_we,
			in_addr  => cram_in_addr,
			in_data  => cram_in_data,
			out_data => cram_out_data
		);

	keccak_inst : entity work.keccak_core
		port map(
			clk          => clk,
			rst          => rst,
			i_init       => keccak_init,
			i_absorb     => keccak_absorb,
			i_squeeze    => keccak_squeeze,
			o_done       => keccak_done,
			i_din_data   => keccak_din_data,
			i_din_valid  => keccak_din_valid,
			o_din_ready  => keccak_din_ready,
			i_rate       => keccak_rate,
			o_dout_data  => keccak_dout_data,
			o_dout_valid => keccak_dout_valid,
			i_dout_ready => keccak_dout_ready
		);

	byte2hw : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_byte_slv'length,
			G_OUT_WIDTH => T_halfword'length
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => byte2hw_din_data,
			i_din_valid  => byte2hw_din_valid,
			o_din_ready  => byte2hw_din_ready,
			o_dout_data  => byte2hw_dout_data,
			o_dout_valid => byte2hw_dout_valid,
			i_dout_ready => byte2hw_dout_ready
		);

	hw2byte : entity work.asymmetric_fifo
		generic map(
			G_IN_WIDTH  => T_halfword'length,
			G_OUT_WIDTH => T_byte_slv'length
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => hw2byte_din_data,
			i_din_valid  => hw2byte_din_valid,
			o_din_ready  => hw2byte_din_ready,
			o_dout_data  => hw2byte_dout_data,
			o_dout_valid => hw2byte_dout_valid,
			i_dout_ready => hw2byte_dout_ready
		);
	-- din -> cram
	cram_in_data       <= i_din_data;
	-- cram -> byte2hw
	byte2hw_din_valid  <= cram_dout_valid_reg;
	-- byte2hw -> keccak
	keccak_din_data    <= byte2hw_dout_data;
	keccak_din_valid   <= byte2hw_dout_valid;
	byte2hw_dout_ready <= keccak_din_ready;
	-- keccak -> hw2byte
	hw2byte_din_data   <= keccak_dout_data;
	hw2byte_din_valid  <= keccak_dout_valid;
	keccak_dout_ready  <= hw2byte_din_ready;
	-- hw2byte -> dout
	o_dout_data        <= hw2byte_dout_data;
	o_dout_valid       <= hw2byte_dout_valid;
	hw2byte_dout_ready <= i_dout_ready;

	--check:
	-- byte2hw_din_ready 
	-- i_din_valid 

	sync_proc : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= s_init;
			else
				case state is
					when s_init =>
						counter_reg         <= (others => '0');
						cram_dout_valid_reg <= '0';
						if i_recv_msg = '1'  then
							state <= s_recv_msg;
						elsif i_send_hash = '1'  then
							state <= s_keccak_init;
						end if;
					when s_recv_msg =>
						if i_din_valid = '1'  then
							counter_reg <= counter_reg + 1;
							if counter_reg = KYBER_SYMBYTES - 1 then
								state <= s_done;
							end if;
						end if;
					when s_keccak_init =>
						if keccak_done = '1'  then
							state <= s_keccak_init_done;
						end if;
					when s_keccak_init_done =>
						state <= s_keccak_absorb;

					when s_keccak_absorb =>
						cram_dout_valid_reg <= '1';
						if byte2hw_din_ready = '1'  or cram_dout_valid_reg = '0' then -- "FIFO" to be consumed or "FIFO" is empty
							counter_reg <= counter_reg + 1;
						end if;
						if keccak_done = '1'  then
							state               <= s_keccak_absorb_done;
							cram_dout_valid_reg <= '0';
						end if;
					when s_keccak_absorb_done =>
						state <= s_keccak_squeeze_1;

					when s_keccak_squeeze_1 =>
						if keccak_done = '1'  then
							state <= s_keccak_squeeze_1_done;
						end if;
					when s_keccak_squeeze_1_done =>
						state <= s_keccak_squeeze_2;

					when s_keccak_squeeze_2 =>
						if keccak_done = '1'  then
							state <= s_done;
						end if;

					when s_done =>
						if (i_recv_msg or i_send_hash) = '0' then
							state <= s_init;
						end if;

				end case;
			end if;
		end if;
	end process sync_proc;

	comb_proc : process(state, byte2hw_din_ready, counter_reg, cram_dout_valid_reg, cram_out_data, i_din_valid, i_nonce) is
	begin
		cram_ce        <= '0';
		cram_we        <= '0';
		keccak_init    <= '0';
		keccak_absorb  <= '0';
		keccak_squeeze <= '0';
		o_din_ready    <= '0';
		o_done         <= '0';

		keccak_rate      <= C_FULL_RATE_US;
		byte2hw_din_data <= cram_out_data;
		cram_in_addr     <= (others => '0');

		if counter_reg <= KYBER_SYMBYTES then
			cram_in_addr <= resize(counter_reg, cram_in_addr'length);
		elsif counter_reg = KYBER_SYMBYTES + 1 then
			byte2hw_din_data <= std_logic_vector(i_nonce);
		elsif counter_reg = KYBER_SYMBYTES + 2 then
			byte2hw_din_data <= C_SHA3_256_DELIM;
		elsif counter_reg = C_SHA3_256_RATE then -- sentinel
			byte2hw_din_data <= C_SHA3_SENTINEL;
		else
			byte2hw_din_data <= (others => '0');
		end if;

		case state is

			when s_init =>
				keccak_init <= '1';

			when s_recv_msg =>
				keccak_init <= '1';
				o_din_ready <= '1';
				cram_ce     <= i_din_valid;
				cram_we     <= i_din_valid;

			when s_keccak_init =>
				keccak_init <= '1';
			when s_keccak_init_done =>
				null;

			when s_keccak_absorb =>
				if counter_reg < KYBER_SYMBYTES then
					cram_ce <= byte2hw_din_ready or not cram_dout_valid_reg;
				end if;
				keccak_absorb <= '1';
			when s_keccak_absorb_done =>
				null;

			when s_keccak_squeeze_1 =>
				keccak_squeeze <= '1';
			when s_keccak_squeeze_1_done =>
				null;

			when s_keccak_squeeze_2 =>
				keccak_squeeze <= '1';
				keccak_absorb  <= '1';  -- do nothing after absorb completes, we explicitly perform init next
				keccak_rate    <= C_CUT_RATE_US;

			when s_done =>
				o_done <= '1';

		end case;
	end process comb_proc;

end architecture RTL;
