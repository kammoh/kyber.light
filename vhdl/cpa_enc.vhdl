library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


use work.ocram_sp;
use work.kyber_pkg.all;

entity cpa_enc is
	port(
		clk           : in  std_logic;
		rst           : in  std_logic;
		-- Data inputs
		i_start       : in  std_logic;
		o_done        : out std_logic;
		i_coins_data  : in  T_byte_slv;
		i_coins_valid : in  std_logic;
		o_coins_ready : out std_logic;
		--
		i_msg_data    : in  T_byte_slv;
		i_pkmsg_valid : in  std_logic;
		o_msg_ready   : out std_logic;
		--

		-- Data output
		o_ct_data     : out T_byte_slv;
		o_ct_valid    : out std_logic;
		i_ct_ready    : in  std_logic
	);
end entity cpa_enc;

architecture RTL of cpa_enc is
	----------------------------------------------------------------=( Constants )=------------------------------------------------------------------
	----------------------------------------------------------------=( Types )=----------------------------------------------------------------------
	type T_state is (S_init,
	                 S_recv_coins, S_recv_AT_PK,
	                 S_polynoise_s, S_polynoise_bv, S_polymac,
	                 S_send_b_v,
	                 S_done
	                );                  -- TODO overlap operations?
	--
	----------------------------------------------------------------=( Registers/FFs )=--------------------------------------------------------------
	signal state                  : T_state;
	signal nonce_reg              : T_byte_us;
	signal poly_rama_blk_cntr_reg : unsigned(log2ceilnz(KYBER_K + 1) - 1 downto 0);
	--
	----------------------------------------------------------------=( Wires )=----------------------------------------------------------------------

	signal polymac_recv_aa       : std_logic;
	signal polymac_recv_bb       : std_logic;
	signal polymac_recv_v        : std_logic;
	signal polymac_send_v        : std_logic;
	signal polymac_do_mac        : std_logic;
	signal polymac_done          : std_logic;
	signal polymac_subtract      : std_logic;
	signal polymac_rama_blk      : unsigned(log2ceilnz(KYBER_K + 1) - 1 downto 0);
	signal polymac_din_data      : T_coef_us;
	signal polymac_din_valid     : std_logic;
	signal polymac_din_ready     : std_logic;
	signal polymac_dout_data     : T_coef_us;
	signal polymac_dout_valid    : std_logic;
	signal polymac_dout_ready    : std_logic;
	signal cbd_din_data          : T_byte_Slv;
	signal cbd_coeffout_data     : T_coef_slv;
	signal noisegen_recv_msg     : std_logic;
	signal noisegen_send_hash    : std_logic;
	signal noisegen_done         : std_logic;
	signal noisegen_coinin_data  : T_byte_slv;
	signal noisegen_coinin_valid : std_logic;
	signal noisegen_coinin_ready : std_logic;
	signal noisegen_dout_data    : T_byte_slv;
	signal noisegen_dout_valid   : std_logic;
	signal noisegen_dout_ready   : std_logic;
	signal compressor_din_data   : T_coef_us;
	signal compressor_din_valid  : std_logic;
	signal compressor_din_ready  : std_logic;
	signal msgadd_polyin_valid   : std_logic;
	signal msgadd_polyin_ready   : std_logic;
	signal msgadd_msgin_valid    : std_logic;
	signal msgadd_msgin_ready    : std_logic;
	signal msgadd_polyout_data   : T_coef_us;
	signal msgadd_polyout_valid  : std_logic;
	signal msgadd_polyout_ready  : std_logic;
	signal ser_din_valid         : std_logic;
	signal ser_din_ready         : std_logic;
	signal ser_coefout_data      : T_Coef_slv;
	signal ser_coefout_valid     : std_logic;
	signal ser_coefout_ready     : std_logic;
	signal polymac_extdiv_divin    : unsigned(2 * log2ceil(KYBER_Q) - 1 downto 0);
	signal polymac_extdiv_divout : T_coef_us;
	signal polymac_extdiv_active : std_logic;

begin

	noisegen_coinin_data <= i_coins_data;
	cbd_din_data         <= noisegen_dout_data;
	polymac_rama_blk     <= poly_rama_blk_cntr_reg;

	serializer_inst : entity work.decompressor
		port map(
			clk             => clk,
			rst             => rst,
			i_din_data      => i_msg_data,
			i_din_valid     => ser_din_valid,
			o_din_ready     => ser_din_ready,
			o_coefout_data  => ser_coefout_data,
			o_coefout_valid => ser_coefout_valid,
			i_coefout_ready => ser_coefout_ready
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
			G_NUM_RAM_A_BLOCKS => KYBER_K + 1
		)
		port map(
			clk             => clk,
			rst             => rst,
			i_recv_aa       => polymac_recv_aa,
			i_recv_bb       => polymac_recv_bb,
			i_recv_v        => polymac_recv_v,
			i_send_v        => polymac_send_v,
			i_do_mac        => polymac_do_mac,
			o_done          => polymac_done,
			i_subtract      => polymac_subtract,
			i_rama_blk      => polymac_rama_blk,
			i_din_data      => polymac_din_data,
			i_din_valid     => polymac_din_valid,
			o_din_ready     => polymac_din_ready,
			o_dout_data     => polymac_dout_data,
			o_dout_valid    => polymac_dout_valid,
			i_dout_ready    => polymac_dout_ready,
			i_extdiv_divin  => polymac_extdiv_divin,
			o_extdiv_divout => polymac_extdiv_divout,
			o_extdit_active => polymac_extdiv_active
		);

	cbd_inst : entity work.cbd
		port map(
			i_din_data      => cbd_din_data,
			o_coeffout_data => cbd_coeffout_data
		);

	compressor_inst : entity work.compressor
		port map(
			clk          => clk,
			rst          => rst,
			i_din_data   => compressor_din_data,
			i_din_valid  => compressor_din_valid,
			o_din_ready  => compressor_din_ready,
			o_dout_data  => o_ct_data,
			o_dout_valid => o_ct_valid,
			i_dout_ready => i_ct_ready
		);

	msgadd_inst : entity work.msg_add
		port map(
			clk             => clk,
			rst             => rst,
			i_polyin_data   => polymac_dout_data,
			i_polyin_valid  => msgadd_polyin_valid,
			o_polyin_ready  => msgadd_polyin_ready,
			i_msgin_data    => i_msg_data,
			i_msgin_valid   => msgadd_msgin_valid,
			o_msgin_ready   => msgadd_msgin_ready,
			o_polyout_data  => msgadd_polyout_data,
			o_polyout_valid => msgadd_polyout_valid,
			i_polyout_ready => msgadd_polyout_ready
		);

	sync_proc : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= S_init;
			else
				case state is
					when S_init =>
						nonce_reg              <= (others => '0');
						poly_rama_blk_cntr_reg <= (others => '0');
						if i_start = '1'  then
							state <= S_recv_coins;
						end if;

					when S_recv_coins =>
						if noisegen_done = '1'  then
							state <= S_recv_AT_PK;
						end if;
					when S_recv_AT_PK =>
						if polymac_done = '1'  then
							poly_rama_blk_cntr_reg <= poly_rama_blk_cntr_reg + 1;
							if poly_rama_blk_cntr_reg = KYBER_K then
								state                  <= S_polynoise_s;
								poly_rama_blk_cntr_reg <= (others => '0');
							end if;
						end if;

					when S_polynoise_s =>
						if noisegen_done = '1'  then
							nonce_reg <= nonce_reg + 1;
						end if;
						if polymac_done = '1'  then
							state <= S_polynoise_bv;
						end if;

					when S_polynoise_bv =>
						if polymac_done = '1'  then
							nonce_reg              <= nonce_reg + 1;
							poly_rama_blk_cntr_reg <= poly_rama_blk_cntr_reg + 1;
							if poly_rama_blk_cntr_reg = KYBER_K then
								state                  <= S_polymac;
								poly_rama_blk_cntr_reg <= (others => '0');
							end if;
						end if;

					when S_polymac =>
						if polymac_done = '1'  then
							poly_rama_blk_cntr_reg <= poly_rama_blk_cntr_reg + 1;
							if poly_rama_blk_cntr_reg = KYBER_K then
								state                  <= S_send_b_v;
								poly_rama_blk_cntr_reg <= (others => '0');
							end if;
						end if;

					when S_send_b_v =>
						if polymac_done = '1'  then
							poly_rama_blk_cntr_reg <= poly_rama_blk_cntr_reg + 1;
							if poly_rama_blk_cntr_reg = KYBER_K then
								state                  <= S_done;
								poly_rama_blk_cntr_reg <= (others => '0');
							end if;
						end if;

					when S_done =>
						state <= S_init;

				end case;
			end if;
		end if;
	end process sync_proc;

	comb_proc : process(state, cbd_coeffout_data, compressor_din_ready, i_coins_valid, i_pkmsg_valid, msgadd_msgin_ready, msgadd_polyin_ready, msgadd_polyout_data, msgadd_polyout_valid, noisegen_coinin_ready, noisegen_done, noisegen_dout_valid, poly_rama_blk_cntr_reg, polymac_din_ready, polymac_done, polymac_dout_data, polymac_dout_valid, ser_coefout_data, ser_coefout_valid, ser_din_ready) is
	begin
		polymac_recv_aa       <= '0';
		polymac_recv_bb       <= '0';
		polymac_recv_v        <= '0';
		polymac_do_mac        <= '0';
		polymac_send_v        <= '0';
		polymac_subtract      <= '0';
		polymac_din_valid     <= '0';
		polymac_dout_ready    <= '0';
		noisegen_recv_msg     <= '0';
		noisegen_send_hash    <= '0';
		noisegen_coinin_valid <= '0';
		noisegen_dout_ready   <= '0';
		ser_din_valid         <= '0';
		ser_coefout_ready     <= '0';
		msgadd_polyin_valid   <= '0';
		msgadd_msgin_valid    <= '0';
		msgadd_polyout_ready  <= '0';
		o_msg_ready           <= '0';
		o_coins_ready         <= '0';
		o_done                <= '0';
		polymac_din_data      <= unsigned(cbd_coeffout_data);
		compressor_din_data   <= polymac_dout_data;
		compressor_din_valid  <= polymac_dout_valid;
		polymac_dout_ready    <= compressor_din_ready;

		case state is
			when S_init =>
				null;

			when S_recv_coins =>
				noisegen_recv_msg     <= not noisegen_done;
				o_coins_ready         <= noisegen_coinin_ready;
				noisegen_coinin_valid <= i_coins_valid;

			when S_recv_AT_PK =>
				polymac_recv_aa   <= not polymac_done;
				o_msg_ready       <= ser_din_ready;
				polymac_din_valid <= ser_coefout_valid;
				polymac_din_data  <= unsigned(ser_coefout_data);
				ser_coefout_ready <= polymac_din_ready;
				ser_din_valid     <= i_pkmsg_valid;

			when S_polynoise_s =>
				polymac_recv_bb     <= not polymac_done;
				noisegen_send_hash  <= not noisegen_done;
				polymac_din_valid   <= noisegen_dout_valid;
				noisegen_dout_ready <= polymac_din_ready;

			when S_polynoise_bv =>
				polymac_recv_v <= not polymac_done;

			when S_polymac =>
				polymac_do_mac <= not polymac_done;

			when S_send_b_v =>
				polymac_send_v <= not polymac_done;
				if poly_rama_blk_cntr_reg = KYBER_K then -- sending out 'v'
					compressor_din_data  <= msgadd_polyout_data;
					compressor_din_valid <= msgadd_polyout_valid;
					polymac_dout_ready   <= msgadd_polyin_ready;
					msgadd_msgin_valid   <= i_pkmsg_valid;
					msgadd_polyin_valid  <= polymac_dout_valid;
					o_msg_ready          <= msgadd_msgin_ready;
				else
				end if;

			when S_done =>
				o_done <= '1';

		end case;
	end process comb_proc;

end architecture RTL;
