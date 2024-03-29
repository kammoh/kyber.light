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
--! @license   
--
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--  
--! @date      <02/01/2019>
--
--! @version   <v0.1>
--
--! @details   Instantiates all the components, connects, and schedules them
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
--! @todo  TODO   termination flushing should be really based on not_empty to work with future modifications 
--!                     right now optimized away and works with current number of stages
--!        TODO   add not_empty out port to all pipelines/FIFOs = or(valid bits FIFO, sub-modules not_empty)
--!
--!        TODO   overlapped (parallel) operation of keccak and polyvec_mac
-----------------------------------------------------------------------------------------------------------------------
--===================================================================================================================--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ram_sp;
use work.kyber_pkg.all;

entity cpa is
	generic(
		G_FOBOS : boolean := False
	);
	port(
		clk         : in  std_logic;
		rst         : in  std_logic;
		-- 
		i_command   : in  unsigned(C_CPA_CMD_BITS - 1 downto 0);
		o_done      : out std_logic;
		-- RDI: Random Data Input, encrupt's coins input
		i_rdi_data  : in  T_byte_slv;
		i_rdi_valid : in  std_logic;
		o_rdi_ready : out std_logic;
		-- PDI: Public Data Input, encrypt's public-key input and decrypt's ciphertext input
		i_pdi_data  : in  T_byte_slv;
		i_pdi_valid : in  std_logic;
		o_pdi_ready : out std_logic;
		-- SDI: Secret Data Input, encrypt's plaintext input and decrypt's secret-key input
		i_sdi_data  : in  T_byte_slv;
		i_sdi_valid : in  std_logic;
		o_sdi_ready : out std_logic;
		-- PDO: Public Data Output, encrypt's ciphertext output
		o_pdo_data  : out T_byte_slv;
		o_pdo_valid : out std_logic;
		i_pdo_ready : in  std_logic;
		-- message out, corresponds to SDO
		o_sdo_data  : out T_byte_slv;
		o_sdo_valid : out std_logic;
		i_sdo_ready : in  std_logic
	);
end entity cpa;

architecture RTL of cpa is

	---------------------------------------------=( Constants )=--------------------------------------------------------
	---------------------------------------------=( Types )=------------------------------------------------------------
	type T_state is (S_init,
	                 S_recv_coins, S_recv_AT_PK,
	                 S_polynoise_s, S_polynoise_bv, S_polymac,
	                 S_send_b, S_send_b_flush, S_send_v,
	                 S_recv_sk,
	                 S_recv_ct_bp,
	                 S_recv_ct_bp_fin,
	                 S_recv_ct_v,
	                 S_recv_ct_v_fin,
	                 S_polymac_neg,
	                 S_send_m,
	                 S_done
	                );
	--
	---------------------------------------------=( Registers/FFs )=----------------------------------------------------
	signal state                      : T_state;
	signal nonce_reg                  : T_byte_us;
	signal poly_rama_blk_cntr_reg     : unsigned(log2ceilnz(KYBER_K + 1) - 1 downto 0);
	signal ct_byte_cntr               : unsigned(log2ceilnz(KYBER_POLYVECCOMPRESSEDBYTES) - 1 downto 0);
	--
	---------------------------------------------=( Wires )=------------------------------------------------------------
	signal polymac_recv_aa            : std_logic;
	signal polymac_recv_bb            : std_logic;
	signal polymac_recv_v             : std_logic;
	signal polymac_send_v             : std_logic;
	signal polymac_do_mac             : std_logic;
	signal polymac_done               : std_logic;
	signal polymac_subtract           : std_logic;
	signal polymac_rama_blk           : unsigned(log2ceilnz(KYBER_K + 1) - 1 downto 0);
	signal polymac_din_data           : T_coef_us;
	signal polymac_din_valid          : std_logic;
	signal polymac_din_ready          : std_logic;
	signal polymac_dout_data          : T_coef_us;
	signal polymac_dout_valid         : std_logic;
	signal polymac_dout_ready         : std_logic;
	signal cbd_din_data               : T_byte_Slv;
	signal cbd_coeffout_data          : T_coef_slv;
	signal noisegen_recv_msg          : std_logic;
	signal noisegen_send_hash         : std_logic;
	signal noisegen_done              : std_logic;
	signal noisegen_coinin_data       : T_byte_slv;
	signal noisegen_coinin_valid      : std_logic;
	signal noisegen_coinin_ready      : std_logic;
	signal noisegen_dout_data         : T_byte_slv;
	signal noisegen_dout_valid        : std_logic;
	signal noisegen_dout_ready        : std_logic;
	signal compressor_din_data        : T_coef_us;
	signal compressor_din_valid       : std_logic;
	signal compressor_din_ready       : std_logic;
	signal msgadd_polyin_valid        : std_logic;
	signal msgadd_polyin_ready        : std_logic;
	signal msgadd_msgin_valid         : std_logic;
	signal msgadd_msgin_ready         : std_logic;
	signal msgadd_polyout_data        : T_coef_us;
	signal msgadd_polyout_valid       : std_logic;
	signal msgadd_polyout_ready       : std_logic;
	signal deserializer_din_data      : T_byte_slv;
	signal deserializer_din_valid     : std_logic;
	signal deserializer_din_ready     : std_logic;
	signal deserializer_coefout_data  : T_Coef_us;
	signal deserializer_coefout_valid : std_logic;
	signal deserializer_coefout_ready : std_logic;
	signal polymac_is_using_divider   : std_logic;
	signal polymac_remin_data         : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal polymac_remin_valid        : std_logic;
	signal remdivout_valid            : std_logic;
	signal compressor_is_polyvec      : std_logic;
	signal uin_data                   : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal uin_valid                  : std_logic;
	signal compressor_divin_data      : unsigned(2 * KYBER_COEF_BITS - 1 downto 0);
	signal compressor_divin_valid     : std_logic;
	signal uin_ready                  : std_logic;
	signal remdivout_ready            : std_logic;
	signal compressor_divout_valid    : std_logic;
	signal compressor_divout_ready    : std_logic;
	signal polymac_remin_ready        : std_logic;
	signal polymac_remout_data        : T_coef_us;
	signal polymac_remout_valid       : std_logic;
	signal polymac_remout_ready       : std_logic;
	signal compressor_divout_data     : T_coef_us;
	signal compressor_divin_ready     : std_logic;
	signal compressor_dout_valid      : std_logic;
	signal msgadd_msgin_data          : T_byte_slv;
	signal compressor_is_msg          : std_logic;
	signal compressor_dout_data       : T_byte_slv;
	signal compressor_dout_ready      : std_logic;
	signal decompress_is_polyvec      : std_logic;
	signal decompress_din_data        : T_byte_slv;
	signal decompress_din_valid       : std_logic;
	signal decompress_din_ready       : std_logic;
	signal decompress_coefout_data    : T_Coef_us;
	signal decompress_coefout_valid   : std_logic;
	signal decompress_coefout_ready   : std_logic;
	--
	signal DUMMY_NIST_ROUND           : positive := P_NIST_ROUND;

begin

	noisegen_coinin_data <= i_rdi_data;
	cbd_din_data         <= noisegen_dout_data;
	polymac_rama_blk     <= poly_rama_blk_cntr_reg;

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

	sha3_noisegen_inst : entity work.sha3_noisegen
		generic map(
			G_MAX_IN_BYTES => KYBER_SYMBYTES
		)
		port map(
			clk          => clk,
			rst          => rst,
			i_recv_msg   => noisegen_recv_msg,
			i_send_hash  => noisegen_send_hash,
			i_nonce      => nonce_reg,
			o_done       => noisegen_done,
			i_din_data   => noisegen_coinin_data,
			i_din_valid  => noisegen_coinin_valid,
			o_din_ready  => noisegen_coinin_ready,
			o_dout_data  => noisegen_dout_data,
			o_dout_valid => noisegen_dout_valid,
			i_dout_ready => noisegen_dout_ready
		);

	polyvec_mac_inst : entity work.polyvec_mac
		generic map(
			--			G_PIPELINE_LEVELS  => G_PIPELINE_LEVELS,
			G_NUM_RAM_A_BLOCKS => KYBER_K + 1,
			G_INTERNAL_DIVIDER => False
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
			--
			o_remin_data   => polymac_remin_data,
			o_remin_valid  => polymac_remin_valid,
			i_remin_ready  => polymac_remin_ready,
			i_remout_data  => polymac_remout_data,
			i_remout_valid => polymac_remout_valid,
			o_remout_ready => polymac_remout_ready,
			o_divider_busy => polymac_is_using_divider
		);

	cbd_inst : entity work.cbd
		port map(
			i_din_data      => cbd_din_data,
			o_coeffout_data => cbd_coeffout_data
		);

	compressor_inst : entity work.compressor
		generic map(
			G_ENCRYPT => True,
			G_DECRYPT => True
		)
		port map(
			clk             => clk,
			rst             => rst,
			i_is_msg        => compressor_is_msg,
			i_is_polyvec    => compressor_is_polyvec,
			i_coeffin_data  => compressor_din_data,
			i_coeffin_valid => compressor_din_valid,
			o_coeffin_ready => compressor_din_ready,
			o_byteout_data  => compressor_dout_data,
			o_byteout_valid => compressor_dout_valid,
			i_byteout_ready => compressor_dout_ready,
			o_divin_data    => compressor_divin_data,
			o_divin_valid   => compressor_divin_valid,
			i_divin_ready   => compressor_divin_ready,
			i_divout_data   => compressor_divout_data,
			i_divout_valid  => compressor_divout_valid,
			o_divout_ready  => compressor_divout_ready
		);

	msgadd_inst : entity work.msg_add
		port map(
			clk             => clk,
			rst             => rst,
			i_polyin_data   => polymac_dout_data,
			i_polyin_valid  => msgadd_polyin_valid,
			o_polyin_ready  => msgadd_polyin_ready,
			i_msgin_data    => msgadd_msgin_data,
			i_msgin_valid   => msgadd_msgin_valid,
			o_msgin_ready   => msgadd_msgin_ready,
			o_polyout_data  => msgadd_polyout_data,
			o_polyout_valid => msgadd_polyout_valid,
			i_polyout_ready => msgadd_polyout_ready
		);

	--- i_sdi -> msg_add.msgin
	msgadd_msgin_data <= i_sdi_data;

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

	decompress_din_data <= i_pdi_data;

	sync_proc : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				report "NIST_ROUND " & integer'image(DUMMY_NIST_ROUND);
				report "reset:  state => S_init";
				state <= S_init;
			else
				case state is
					when S_init =>
						nonce_reg              <= (others => '0');
						poly_rama_blk_cntr_reg <= (others => '0');

						-- FIXME TESTING

						case to_integer(i_command) is
							when CMD_RECV_PK =>
								report ">> [command] recv_pk";
								report "state => S_recv_pk";
								state <= S_recv_AT_PK;
							when CMD_START_ENC =>
								report ">> [command] start_enc";
								report "state => S_recv_coins";
								state <= S_recv_coins;
							when CMD_RECV_SK =>
								report ">> [command] recv_sk";
								report "state => S_recv_sk";
								state <= S_recv_sk;
							when CMD_START_DEC =>
								report ">> [command] start_dec";
								report "state => S_recv_ct_bp";
								ct_byte_cntr <= (others => '0');
								state        <= S_recv_ct_bp;
							when others =>
								null;
						end case;

					--						-- FIXME TESTING
					--						report "state => S_recv_sk";
					--						state        <= S_recv_sk;
					--						ct_byte_cntr <= (others => '0');

					when S_recv_coins =>
						if noisegen_done = '1' then
							report "state => S_polynoise_s";
							state <= S_polynoise_s;
						end if;

					when S_recv_AT_PK =>
						if polymac_done = '1' then
							poly_rama_blk_cntr_reg <= poly_rama_blk_cntr_reg + 1;
							if poly_rama_blk_cntr_reg = KYBER_K then
								report "<< [done] (recv_pk)";
								report "state => S_done";
								state                  <= S_done;
								poly_rama_blk_cntr_reg <= (others => '0');
							end if;
						end if;

					when S_polynoise_s =>
						if noisegen_done = '1' then
							nonce_reg <= nonce_reg + 1;
						end if;
						if polymac_done = '1' then
							report "state => S_polynoise_bv";
							state <= S_polynoise_bv;
						end if;

					when S_polynoise_bv =>
						if polymac_done = '1' then
							nonce_reg              <= nonce_reg + 1;
							poly_rama_blk_cntr_reg <= poly_rama_blk_cntr_reg + 1;
							if poly_rama_blk_cntr_reg = KYBER_K then
								report "state => S_polymac";
								state                  <= S_polymac;
								poly_rama_blk_cntr_reg <= (others => '0');
							end if;
						end if;

					when S_polymac =>
						if polymac_done = '1' then
							poly_rama_blk_cntr_reg <= poly_rama_blk_cntr_reg + 1;
							if poly_rama_blk_cntr_reg = KYBER_K then
								report "state => S_send_b";
								state                  <= S_send_b;
								poly_rama_blk_cntr_reg <= (others => '0');
							end if;
						end if;

					when S_send_b =>
						if polymac_done = '1' then
							poly_rama_blk_cntr_reg <= poly_rama_blk_cntr_reg + 1;
							if poly_rama_blk_cntr_reg = KYBER_K - 1 then
								report "state => S_send_b_flush";
								state <= S_send_b_flush;
							end if;
						end if;

					when S_send_b_flush =>
						if compressor_divout_valid = '0' and compressor_dout_valid = '0' then
							report "state => S_send_v";
							state <= S_send_v;
						end if;

					when S_send_v =>
						if polymac_done = '1' and compressor_dout_valid = '0' and remdivout_valid = '0' then
							report "<< [done] (start_enc)";
							report "state => S_done";
							state                  <= S_done;
							poly_rama_blk_cntr_reg <= (others => '0');
						end if;

					when S_recv_sk =>
						if polymac_done = '1' then
							report ">> [done] recv_sk";
							report "state => S_done";

							state <= S_done;

						end if;

					when S_recv_ct_bp =>
						if (decompress_din_ready and i_pdi_valid) = '1' then
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
						if (decompress_din_ready and i_pdi_valid) = '1' then
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
						if i_command = 0 then
							report "state => S_init";
							state <= S_init;
						end if;
						--						-- FIXME TESTING
						--						report "state => S_recv_ct_bp";
						--						state                  <= S_recv_ct_bp;
						--						nonce_reg              <= (others => '0');
						--						poly_rama_blk_cntr_reg <= (others => '0');

				end case;
			end if;
		end if;
	end process sync_proc;

	comb_proc : process(                --
	state, cbd_coeffout_data, compressor_din_ready, i_rdi_valid, --
	msgadd_polyin_ready, msgadd_polyout_data, msgadd_polyout_valid, noisegen_coinin_ready, --
	noisegen_done, noisegen_dout_valid, polymac_din_ready, polymac_done, --
	polymac_dout_data, polymac_dout_valid, deserializer_coefout_data, deserializer_coefout_valid, --
	compressor_divin_valid, compressor_divout_ready, polymac_remin_valid, polymac_remout_ready, remdivout_valid, --
	uin_ready, deserializer_din_ready, msgadd_msgin_ready, compressor_dout_valid, i_pdo_ready, --
	i_pdi_valid, compressor_divin_data, compressor_dout_data, decompress_coefout_data, decompress_coefout_valid, --
	decompress_din_ready, i_sdi_valid, i_pdi_data, i_sdo_ready, i_sdi_data, polymac_remin_data --
	) is
	begin
		polymac_recv_aa            <= '0';
		polymac_recv_bb            <= '0';
		polymac_recv_v             <= '0';
		polymac_do_mac             <= '0';
		polymac_send_v             <= '0';
		polymac_subtract           <= '0';
		polymac_din_valid          <= '0';
		polymac_dout_ready         <= '0';
		polymac_remout_valid       <= '0';
		polymac_remin_ready        <= '0';
		polymac_din_data           <= unsigned(cbd_coeffout_data);
		--
		noisegen_recv_msg          <= '0';
		noisegen_send_hash         <= '0';
		noisegen_coinin_valid      <= '0';
		noisegen_dout_ready        <= '0';
		--
		msgadd_polyin_valid        <= '0';
		msgadd_polyout_ready       <= '0';
		--
		compressor_din_data        <= (others => '0');
		compressor_din_valid       <= '0';
		compressor_divout_valid    <= '0';
		compressor_divin_ready     <= '0';
		compressor_is_polyvec      <= '0';
		compressor_is_msg          <= '0';
		--
		o_sdo_data                 <= compressor_dout_data;
		o_sdo_valid                <= '0';
		--
		msgadd_msgin_valid         <= '0';
		o_sdi_ready                <= '0';
		--
		o_pdo_valid                <= '0';
		o_pdo_data                 <= (others => '0');
		compressor_dout_ready      <= '0';
		--
		remdivout_ready            <= '0';
		uin_valid                  <= '0';
		uin_data                   <= polymac_remin_data;
		--
		deserializer_din_data      <= i_pdi_data;
		deserializer_din_valid     <= '0';
		deserializer_coefout_ready <= '0';
		--
		decompress_coefout_ready   <= '0';
		decompress_din_valid       <= '0';
		decompress_is_polyvec      <= '0';

		--
		o_rdi_ready <= '0';
		o_pdi_ready <= '0';
		o_sdi_ready <= '0';
		--
		o_done      <= '0';

		case state is
			when S_init =>
				null;

			when S_recv_coins =>
				noisegen_recv_msg     <= not noisegen_done;
				o_rdi_ready           <= noisegen_coinin_ready;
				noisegen_coinin_valid <= i_rdi_valid;

			when S_recv_AT_PK =>
				polymac_recv_aa            <= not polymac_done;
				--
				polymac_din_valid          <= deserializer_coefout_valid;
				polymac_din_data           <= deserializer_coefout_data;
				deserializer_coefout_ready <= polymac_din_ready;
				--
				-- i_pk -> deserializer
				deserializer_din_data      <= i_pdi_data;
				deserializer_din_valid     <= i_pdi_valid;
				o_pdi_ready                <= deserializer_din_ready;

			when S_polynoise_s =>
				polymac_recv_bb     <= not polymac_done;
				noisegen_send_hash  <= not noisegen_done;
				polymac_din_valid   <= noisegen_dout_valid;
				noisegen_dout_ready <= polymac_din_ready;

			when S_polynoise_bv =>
				polymac_recv_v      <= not polymac_done; -- auto-restart for b[0..3],v
				noisegen_send_hash  <= not noisegen_done;
				polymac_din_valid   <= noisegen_dout_valid;
				noisegen_dout_ready <= polymac_din_ready;

			when S_polymac =>
				uin_valid            <= polymac_remin_valid;
				polymac_do_mac       <= not polymac_done; -- auto-restart
				remdivout_ready      <= polymac_remout_ready;
				polymac_remin_ready  <= uin_ready;
				polymac_remout_valid <= remdivout_valid;

			when S_send_b =>
				-- ack when "done"
				polymac_send_v          <= not polymac_done; -- auto-restart
				--
				uin_valid               <= compressor_divin_valid;
				uin_data                <= compressor_divin_data;
				--
				compressor_divout_valid <= remdivout_valid;
				remdivout_ready         <= compressor_divout_ready;
				--
				compressor_divin_ready  <= uin_ready;
				-- sending out polyvec b directly from polymac
				compressor_is_polyvec   <= '1';
				--- polyvec.dout -> compressir.din
				compressor_din_data     <= polymac_dout_data;
				compressor_din_valid    <= polymac_dout_valid;
				polymac_dout_ready      <= compressor_din_ready;
				--
				o_pdo_valid             <= compressor_dout_valid;
				o_pdo_data              <= compressor_dout_data;
				compressor_dout_ready   <= i_pdo_ready;

			when S_send_b_flush =>
				compressor_divout_valid <= remdivout_valid;
				remdivout_ready         <= compressor_divout_ready;
				-- sending out polyvec b directly from polymac
				compressor_is_polyvec   <= '1';
				--
				o_pdo_valid             <= compressor_dout_valid;
				o_pdo_data              <= compressor_dout_data;
				compressor_dout_ready   <= i_pdo_ready;

			when S_send_v =>
				o_sdi_ready             <= msgadd_msgin_ready;
				msgadd_msgin_valid      <= i_sdi_valid;
				--
				-- ack when "done"
				polymac_send_v          <= '1'; -- no auto-restart
				--
				uin_valid               <= compressor_divin_valid;
				uin_data                <= compressor_divin_data;
				--
				compressor_divout_valid <= remdivout_valid;
				remdivout_ready         <= compressor_divout_ready;
				--
				compressor_divin_ready  <= uin_ready;
				-- sending out poly 'v' through msg_add
				--- polymac.dout -> msg_add.polyin
				polymac_dout_ready      <= msgadd_polyin_ready;
				msgadd_polyin_valid     <= polymac_dout_valid; -- valid only in this state
				--- msg_add.polyout -> compressor.din
				compressor_din_data     <= msgadd_polyout_data;
				compressor_din_valid    <= msgadd_polyout_valid;
				msgadd_polyout_ready    <= compressor_din_ready;
				--
				o_pdo_valid             <= compressor_dout_valid;
				o_pdo_data              <= compressor_dout_data;
				compressor_dout_ready   <= i_pdo_ready;

			when S_recv_sk =>
				o_sdi_ready                <= deserializer_din_ready;
				deserializer_coefout_ready <= polymac_din_ready;
				deserializer_din_valid     <= i_sdi_valid;
				-- RAM B
				polymac_recv_bb            <= not polymac_done;
				deserializer_din_data      <= i_sdi_data;
				polymac_din_data           <= deserializer_coefout_data;
				polymac_din_valid          <= deserializer_coefout_valid;

			when S_recv_ct_bp =>
				decompress_coefout_ready <= polymac_din_ready;
				decompress_din_valid     <= i_pdi_valid;
				decompress_is_polyvec    <= '1';
				--
				polymac_din_data         <= decompress_coefout_data;
				polymac_din_valid        <= decompress_coefout_valid;
				o_pdi_ready              <= decompress_din_ready;
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
				decompress_din_valid     <= i_pdi_valid;
				--
				polymac_din_data         <= decompress_coefout_data;
				polymac_din_valid        <= decompress_coefout_valid;
				o_pdi_ready              <= decompress_din_ready;

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
				polymac_do_mac       <= not polymac_done;
				polymac_subtract     <= '1';
				polymac_remout_valid <= remdivout_valid;
				--				
				uin_valid            <= polymac_remin_valid;
				polymac_do_mac       <= not polymac_done; -- auto-restart
				remdivout_ready      <= polymac_remout_ready;
				polymac_remin_ready  <= uin_ready;
				uin_data             <= polymac_remin_data;
				polymac_remout_valid <= remdivout_valid;

			when S_send_m =>
				o_sdo_valid             <= compressor_dout_valid;
				compressor_dout_ready   <= i_sdo_ready;
				--
				compressor_is_msg       <= '1';
				--
				compressor_din_data     <= polymac_dout_data;
				compressor_din_valid    <= polymac_dout_valid;
				polymac_dout_ready      <= compressor_din_ready;
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
