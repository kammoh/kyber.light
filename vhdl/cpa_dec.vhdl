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
--  unit name: Kyber CPA Decrypt only top
--              
--! @file      cpa_dec.vhdl
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
--! @details   Instantiates all the components, connects, and schedules them to perform CPA decrypt
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
		o_pt_data   : out T_byte_slv;
		o_pt_valid  : out std_logic;
		i_pt_ready  : in  std_logic
	);
end entity cpa_dec;

architecture RTL of cpa_dec is
	signal polymac_recv_aa            : std_logic;
	signal polymac_recv_bb            : std_logic;
	signal polymac_recv_v             : std_logic;
	signal polymac_send_v             : std_logic;
	signal polymac_do_mac             : std_logic;
	signal polymac_done               : std_logic;
	signal polymac_subtract           : std_logic;
	signal polymac_rama_blk           : unsigned(0 downto 0);
	signal polymac_din_data           : T_coef_us;
	signal polymac_din_valid          : std_logic;
	signal polymac_din_ready          : std_logic;
	signal polymac_dout_data          : T_coef_us;
	signal polymac_dout_valid         : std_logic;
	signal polymac_dout_ready         : std_logic;
	signal polymac_remin_data         : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal polymac_remin_valid        : std_logic;
	signal polymac_remin_ready        : std_logic;
	signal polymac_remout_data        : T_coef_us;
	signal polymac_remout_valid       : std_logic;
	signal polymac_remout_ready       : std_logic;
	signal polymac_divider_busy       : std_logic;
	signal uin_data                   : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal uin_valid                  : std_logic;
	signal uin_ready                  : std_logic;
	signal compressor_divout_data     : T_coef_us;
	signal remdivout_valid            : std_logic;
	signal remdivout_ready            : std_logic;
	signal compressor_is_msg          : std_logic;
	signal compressor_is_polyvec      : std_logic;
	signal compressor_din_data        : T_coef_us;
	signal compressor_din_valid       : std_logic;
	signal compressor_din_ready       : std_logic;
	signal compressor_dout_valid      : std_logic;
	signal compressor_divin_data      : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal compressor_divin_valid     : std_logic;
	signal compressor_divin_ready     : std_logic;
	signal compressor_divout_valid    : std_logic;
	signal compressor_divout_ready    : std_logic;
	signal deserializer_din_data      : T_byte_slv;
	signal deserializer_din_valid     : std_logic;
	signal deserializer_din_ready     : std_logic;
	signal deserializer_coefout_data  : T_Coef_us;
	signal deserializer_coefout_valid : std_logic;
	signal deserializer_coefout_ready : std_logic;
	signal decompress_is_polyvec      : std_logic;
	signal decompress_din_data        : T_byte_slv;
	signal decompress_din_valid       : std_logic;
	signal decompress_din_ready       : std_logic;
	signal decompress_coefout_data    : T_Coef_us;
	signal decompress_coefout_valid   : std_logic;
	signal decompress_coefout_ready   : std_logic;
	signal ct_byte_cntr               : unsigned(log2ceilnz(KYBER_POLYVECCOMPRESSEDBYTES) - 1 downto 0);

	type T_state is (
		S_init,
		S_recv_sk,
		S_recv_ct_bp,
		S_recv_ct_bp_fin,
		S_recv_ct_v,
		S_recv_ct_v_fin,
		S_polymac_neg,
		S_send_m,
		S_done
	);

	signal state                 : T_state;
	signal compressor_dout_ready : std_logic;

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

	deserializer_din_data <= i_sk_data;

	decompress_inst : entity work.decompressor
		port map(
			clk             => clk,
			rst             => rst,
			i_is_polyvec    => decompress_is_polyvec,
			i_bytein_data   => decompress_din_data,
			i_bytein_valid  => decompress_din_valid,
			o_bytein_ready  => decompress_din_ready,
			o_coefout_data  => decompress_coefout_data,
			o_coefout_valid => decompress_coefout_valid,
			i_coefout_ready => decompress_coefout_ready
		);

	decompress_din_data <= i_ct_data;

	polyvec_mac_inst : entity work.polyvec_mac
		generic map(
			G_NUM_RAM_A_BLOCKS     => 1,
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
			i_coeffin_data     => compressor_din_data,
			i_coeffin_valid    => compressor_din_valid,
			o_coeffin_ready    => compressor_din_ready,
			o_byteout_data    => o_pt_data,
			o_byteout_valid   => compressor_dout_valid,
			i_byteout_ready   => compressor_dout_ready,
			o_divin_data   => compressor_divin_data,
			o_divin_valid  => compressor_divin_valid,
			i_divin_ready  => compressor_divin_ready,
			i_divout_data  => compressor_divout_data,
			i_divout_valid => compressor_divout_valid,
			o_divout_ready => compressor_divout_ready
		);

	compressor_is_msg     <= '1';
	compressor_is_polyvec <= '0';       -- don't care
	--
	compressor_din_data   <= polymac_dout_data;
	compressor_din_valid  <= polymac_dout_valid;
	polymac_dout_ready    <= compressor_din_ready;

	--

	state_proc : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				report "reset:  state => S_init";
				state <= S_init;
			else
				case state is
					when S_init =>
						if i_recv_sk = '1' then
							report ">> [command] recv_sk";
							report "state => S_recv_sk";
							state <= S_recv_sk;
						elsif i_start_dec = '1' then
							report ">> [command] start_dec";
							report "state => S_recv_ct_bp";
							ct_byte_cntr <= (others => '0');
							state        <= S_recv_ct_bp;
						end if;

					when S_recv_sk =>
						if polymac_done = '1' then
							report ">> [done] recv_sk";
							report "state => S_done";
							state <= S_done;
						end if;

					when S_recv_ct_bp =>
						if (decompress_din_ready and i_ct_valid) = '1' then
							ct_byte_cntr <= ct_byte_cntr + 1;
							if ct_byte_cntr = KYBER_POLYVECCOMPRESSEDBYTES - 1 then
								report "state => S_recv_ct_bp_fin";
								ct_byte_cntr <= (others => '0');
								state        <= S_recv_ct_bp_fin;
							end if;
						end if;

					when S_recv_ct_bp_fin =>
						if polymac_done = '1' then
							report "state => S_recv_ct_v";
							state <= S_recv_ct_v;
						end if;

					when S_recv_ct_v =>
						if (decompress_din_ready and i_ct_valid) = '1' then
							ct_byte_cntr <= ct_byte_cntr + 1;
							if ct_byte_cntr = KYBER_POLYCOMPRESSEDBYTES - 1 then
								report "state => S_recv_ct_v_fin";
								state <= S_recv_ct_v_fin;
							end if;
						end if;

					when S_recv_ct_v_fin =>
						if polymac_done = '1' then
							report "state => S_polymac_neg";
							state <= S_polymac_neg;
						end if;

					when S_polymac_neg =>
						if polymac_done = '1' then
							report "state => S_send_m";
							state <= S_send_m;
						end if;

					when S_send_m =>
						if polymac_done = '1' and compressor_dout_valid = '0' and remdivout_valid = '0' then -- FIXME?
							report ">> [done] start_enc";
							report "state => S_done";
							state <= S_done;
						end if;

					when S_done =>
						-- wait for ack from master (caller)
						if (i_start_dec or i_recv_sk) = '0' then
							report "state => S_init";
							state <= S_init;
						end if;

				end case;
			end if;
		end if;
	end process state_proc;

	comb_proc : process(state, compressor_divin_data, compressor_divin_valid, compressor_divout_ready, --
	compressor_dout_valid, decompress_coefout_data, decompress_coefout_valid, decompress_din_ready, --
	deserializer_coefout_data, deserializer_coefout_valid, deserializer_din_ready, i_ct_valid, i_pt_ready, --
	i_sk_valid, polymac_din_ready, polymac_remin_data, polymac_remin_valid, polymac_remout_ready, --
	remdivout_valid, uin_ready, polymac_done) is
	begin
		---
		o_done                 <= '0';
		--
		o_sk_ready             <= '0';
		o_ct_ready             <= '0';
		--
		o_pt_valid             <= '0';
		--
		--
		compressor_dout_ready  <= '0';
		compressor_divin_ready <= '0';
		----
		polymac_recv_aa        <= '0';
		polymac_recv_bb        <= '0';
		polymac_recv_v         <= '0';
		polymac_send_v         <= '0';
		polymac_do_mac         <= '0';
		--
		polymac_din_data       <= (others => '0');
		polymac_din_valid      <= '0';

		deserializer_din_valid <= '0';

		deserializer_coefout_ready <= '0';
		decompress_coefout_ready   <= '0';

		decompress_din_valid  <= '0';
		decompress_is_polyvec <= '0';
		-- 
		polymac_remout_valid  <= remdivout_valid; -- always ??? 2

		polymac_remin_ready <= uin_ready; -- always ???
		remdivout_ready     <= polymac_remout_ready; -- default: ?? 3

		uin_data  <= polymac_remin_data;
		uin_valid <= polymac_remin_valid;

		-- for decrypt-only
		polymac_subtract <= '1';
		polymac_rama_blk <= (others => '0');

		case state is
			when S_init =>

			when S_recv_sk =>
				o_sk_ready                 <= deserializer_din_ready;
				deserializer_coefout_ready <= polymac_din_ready;
				deserializer_din_valid     <= i_sk_valid;
				-- RAM B
				polymac_recv_bb            <= not polymac_done;
				polymac_din_data           <= deserializer_coefout_data;
				polymac_din_valid          <= deserializer_coefout_valid;

			when S_recv_ct_bp =>
				decompress_coefout_ready <= polymac_din_ready;
				decompress_din_valid     <= i_ct_valid;
				decompress_is_polyvec    <= '1';
				--
				polymac_din_data         <= decompress_coefout_data;
				polymac_din_valid        <= decompress_coefout_valid;
				o_ct_ready               <= decompress_din_ready;
				-- RAM A
				polymac_recv_aa          <= '1';

			when S_recv_ct_bp_fin =>
				decompress_coefout_ready <= polymac_din_ready;
				decompress_is_polyvec    <= '1';
				--
				polymac_din_data         <= decompress_coefout_data;
				polymac_din_valid        <= decompress_coefout_valid;
				-- RAM A
				polymac_recv_aa          <= not polymac_done;

			when S_recv_ct_v =>
				decompress_coefout_ready <= polymac_din_ready;
				decompress_din_valid     <= i_ct_valid;
				--
				polymac_din_data         <= decompress_coefout_data;
				polymac_din_valid        <= decompress_coefout_valid;
				o_ct_ready               <= decompress_din_ready;

				-- RAM A:v
				polymac_recv_v <= '1';

			when S_recv_ct_v_fin =>
				decompress_coefout_ready <= polymac_din_ready;
				--
				polymac_din_data         <= decompress_coefout_data;
				polymac_din_valid        <= decompress_coefout_valid;
				-- RAM A:v
				polymac_recv_v           <= not polymac_done;

			when S_polymac_neg =>
				polymac_do_mac   <= not polymac_done;
				polymac_subtract <= '1';
				polymac_rama_blk <= (others => '0');

			when S_send_m =>
				o_pt_valid              <= compressor_dout_valid;
				compressor_dout_ready   <= i_pt_ready;
				--
				uin_data                <= compressor_divin_data;
				uin_valid               <= compressor_divin_valid;
				compressor_divin_ready  <= uin_ready;
				--
				compressor_divout_valid <= remdivout_valid;
				remdivout_ready         <= compressor_divout_ready;
				--
				polymac_send_v          <= '1';

			when S_done =>
				o_done <= '1';

		end case;

	end process comb_proc;

end architecture RTL;
