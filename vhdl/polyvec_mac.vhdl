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
--  unit name: Polynomial vector Multiply and Accumulate (polyvec_mac)
--              
--! @file      polyvec_mac.vhdl
--
--! @brief     Given two Polynomial vectors a, b and a polynomial r: computes r +/- a*b
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
use work.ocram_sp;

entity polyvec_mac is
	generic(
		G_PIPELINE_LEVELS          : positive := 7;
		G_PROVIDE_EXTERNAL_DIVIDER : boolean  := True;
		G_NUM_RAM_A_BLOCKS         : positive := KYBER_K + 1 -- {1, KYBER_K + 1}  1: for CPA-Decrypt-Only, KYBER_K + 1: for either CPA-Encrypt-only or Encrypt/Decrypt
	);
	port(
		clk             : in  std_logic;
		rst             : in  std_logic;
		--
		-- Command/Done interface
		i_recv_aa       : in  std_logic;
		i_recv_bb       : in  std_logic;
		i_recv_v        : in  std_logic;
		i_send_v        : in  std_logic;
		i_do_mac        : in  std_logic;
		o_done          : out std_logic;
		--
		-- Command Arguments
		i_subtract      : in  std_logic;
		i_rama_blk      : in  unsigned(log2ceilnz(G_NUM_RAM_A_BLOCKS) - 1 downto 0);
		--
		-- Data input
		i_din_data      : in  T_coef_us;
		i_din_valid     : in  std_logic;
		o_din_ready     : out std_logic;
		--
		-- Data output
		o_dout_data     : out T_coef_us;
		o_dout_valid    : out std_logic;
		i_dout_ready    : in  std_logic;
		-- External divide provider
		i_extdiv_divin  : in  unsigned(2 * log2ceil(KYBER_Q) - 1 downto 0);
		o_extdiv_divout : out T_coef_us;
		o_extdit_active : out std_logic
	);
end entity polyvec_mac;

architecture RTL of polyvec_mac is
	------------------------------------------------------=( Types )=--------------------------------------------------------------
	type T_state is (
		s_init,
		--
		s_receive_aa, s_receive_bb, s_receive_v,
		--
		s_mac_load_v,
		s_mac_piped, s_mac_flush,
		s_mac_store_v,
		--
		s_send_v, s_send_v_flush,
		--
		s_done
	);
	--
	------------------------------------------------------=( Constants )=-----------------------------------------------------------
	constant K_REG_SIZE          : positive := maximum(log2ceil(KYBER_K), log2ceil(G_PIPELINE_LEVELS));
	--
	------------------------------------------------------=( Registers/FFs )=-------------------------------------------------------
	signal state                 : T_state;
	signal v_idx_reg             : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal ai_idx_reg            : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal k_reg                 : unsigned(K_REG_SIZE - 1 downto 0);
	signal dout_valid_piped_reg  : std_logic;
	--
	------------------------------------------------------=( Wires )=---------------------------------------------------------------
	signal bi_idx                : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal v_idx_minus_ai_idx    : unsigned(log2ceil(KYBER_N) downto 0);
	signal nega                  : std_logic;
	signal en_v, ld_v            : std_logic;
	signal bi                    : T_coef_us;
	signal ai                    : T_coef_us;
	signal vin                   : T_coef_us;
	signal vout                  : T_coef_us;
	signal v_idx_plus_one        : unsigned(log2ceil(KYBER_N) downto 0);
	signal v_idx_eq_255          : std_logic;
	signal v_idx_reg_next        : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal ai_idx_plus_one       : unsigned(log2ceil(KYBER_N) downto 0);
	signal ai_idx_plus_one_carry : std_logic;
	signal ai_idx_reg_next       : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	--
	signal rama_ce               : std_logic;
	signal rama_we               : std_logic;
	signal rama_blk_addr         : unsigned(log2ceil(G_NUM_RAM_A_BLOCKS * KYBER_N) - 1 downto 0);
	signal rama_addr             : unsigned(log2ceil(G_NUM_RAM_A_BLOCKS * (KYBER_K + 1) * KYBER_N) - 1 downto 0);
	signal v_addr                : unsigned(log2ceil((KYBER_K + 1) * KYBER_N) - 1 downto 0);
	signal rama_din              : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal rama_dout             : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal ramb_ce               : std_logic;
	signal ramb_we               : std_logic;
	signal ramb_addr             : unsigned(log2ceil(KYBER_K * KYBER_N) - 1 downto 0);
	signal ramb_dout             : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal extdit_active         : std_logic;

begin
	gen_polymac_dp : if G_PROVIDE_EXTERNAL_DIVIDER generate
		ploymac_datapath : entity work.polymac_datapath
			generic map(
				G_PIPELINE_LEVELS => G_PIPELINE_LEVELS
			)
			port map(
				clk              => clk,
				i_nega           => nega,
				i_en_v           => en_v,
				i_ld_v           => ld_v,
				in_a             => ai,
				in_b             => bi,
				in_v             => vin,
				out_v            => vout,
				i_ext_div_select => extdit_active,
				i_ext_div        => i_extdiv_divin,
				o_ext_div        => o_extdiv_divout
			);
	end generate;
	gen_polymac_dp_not : if not G_PROVIDE_EXTERNAL_DIVIDER generate
		ploymac_datapath : entity work.polymac_datapath
			generic map(
				G_PIPELINE_LEVELS => G_PIPELINE_LEVELS
			)
			port map(
				clk              => clk,
				i_nega           => nega,
				i_en_v           => en_v,
				i_ld_v           => ld_v,
				in_a             => ai,
				in_b             => bi,
				in_v             => vin,
				out_v            => vout,
				i_ext_div_select => '0',
				i_ext_div        => (others => '0')
			);
	end generate;

	--===========================--
	--     RAM-A Block layout    --
	--===========================--

	------------------------------- 0
	--                           --
	--                           --
	--                           --
	--             A             --
	--                           --
	--                           --
	--                           --
	--                           --
	------------------------------- 3*256
	--                           --
	--             v             --
	--                           --
	------------------------------- 4*256

	--===========================--
	--   x G_NUM_RAM_A_BLOCKS    --
	--===========================--

	ram_A : entity work.ocram_sp
		generic map(
			DEPTH  => G_NUM_RAM_A_BLOCKS * (KYBER_K + 1) * KYBER_N,
			D_BITS => KYBER_COEF_BITS
		)
		port map(
			clk      => clk,
			ce       => rama_ce,
			we       => rama_we,
			in_addr  => rama_addr,
			in_data  => rama_din,
			out_data => rama_dout
		);

	generate_rama_addr : if G_NUM_RAM_A_BLOCKS = 1 generate
		rama_addr <= rama_blk_addr;
	end generate;
	generate_rama_addr_not : if G_NUM_RAM_A_BLOCKS /= 1 generate
		rama_addr <= i_rama_blk & rama_blk_addr;
	end generate;

	ram_B : entity work.ocram_sp
		generic map(
			DEPTH  => KYBER_K * KYBER_N,
			D_BITS => KYBER_COEF_BITS
		)
		port map(
			clk      => clk,
			ce       => ramb_ce,
			we       => ramb_we,
			in_addr  => ramb_addr,
			in_data  => std_logic_vector(i_din_data),
			out_data => ramb_dout
		);

	v_idx_plus_one        <= ("0" & v_idx_reg) + 1;
	v_idx_reg_next        <= v_idx_plus_one(v_idx_reg'length - 1 downto 0);
	v_idx_eq_255          <= v_idx_plus_one(v_idx_reg'length);
	--
	ai_idx_plus_one       <= ("0" & ai_idx_reg) + 1;
	ai_idx_reg_next       <= ai_idx_plus_one(ai_idx_reg'length - 1 downto 0);
	ai_idx_plus_one_carry <= ai_idx_plus_one(ai_idx_reg'length);

	regs_proc : process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state                <= s_init;
				dout_valid_piped_reg <= '0';
			else
				case state is
					when s_init =>
						v_idx_reg  <= (others => '0');
						k_reg      <= (others => '0');
						ai_idx_reg <= (others => '0');
						if i_recv_bb = '1' then
							state <= s_receive_bb;
						elsif i_recv_aa = '1' then
							state <= s_receive_aa;
						elsif i_recv_v = '1' then
							state <= s_receive_v;
						elsif i_do_mac = '1' then
							state <= s_mac_load_v;
						elsif i_send_v = '1' then
							state <= s_send_v;
						end if;
					when s_receive_bb =>
						if i_din_valid = '1' then
							v_idx_reg <= v_idx_reg_next;
							if v_idx_eq_255 = '1' then
								k_reg <= k_reg + 1;
								if k_reg = (KYBER_K - 1) then
									k_reg <= (others => '0');
									state <= s_done;
								end if;
							end if;
						end if;
					when s_receive_aa =>
						if i_din_valid = '1' then
							ai_idx_reg <= ai_idx_reg_next;
							if ai_idx_plus_one_carry = '1' then
								k_reg <= k_reg + 1;
								if k_reg = (KYBER_K - 1) then
									k_reg <= (others => '0');
									state <= s_done;
								end if;
							end if;
						end if;
					when s_receive_v =>
						if i_din_valid = '1' then
							v_idx_reg <= v_idx_reg_next;
							if v_idx_eq_255 = '1' then
								state <= s_done;
							end if;
						end if;
					when s_mac_load_v =>
						state <= s_mac_piped;
					when s_mac_piped =>
						ai_idx_reg <= ai_idx_reg_next;
						if ai_idx_plus_one_carry = '1' then
							k_reg <= k_reg + 1;
							if k_reg = (KYBER_K - 1) then
								k_reg <= (others => '0');
								state <= s_mac_flush;
							end if;
						end if;
					when s_mac_flush =>
						k_reg <= k_reg + 1;
						if k_reg = G_PIPELINE_LEVELS - 1 then
							k_reg <= (others => '0');
							state <= s_mac_store_v;
						end if;
					when s_mac_store_v =>
						v_idx_reg <= v_idx_reg_next;
						if v_idx_eq_255 = '1' then
							state <= s_done;
						else
							state <= s_mac_load_v;
						end if;
					when s_send_v =>
						dout_valid_piped_reg <= '1';
						if i_dout_ready = '1' or dout_valid_piped_reg = '0' then -- "FIFO" to be consumed or "FIFO" is empty
							v_idx_reg <= v_idx_reg_next;
							if v_idx_eq_255 = '1' then
								state <= s_send_v_flush;
							end if;
						end if;
					when s_send_v_flush =>
						if i_dout_ready = '1' then
							dout_valid_piped_reg <= '0';
							state                <= s_done;
						end if;
					when s_done =>
						if (i_recv_bb or i_recv_aa or i_recv_v or i_do_mac or i_send_v) = '0' then
							state <= s_init;
						end if;

				end case;

			end if;
		end if;
	end process regs_proc;

	bi_idx             <= v_idx_minus_ai_idx(v_idx_minus_ai_idx'length - 2 downto 0);
	nega               <= v_idx_minus_ai_idx(v_idx_minus_ai_idx'length - 1) xor i_subtract;
	--
	v_idx_minus_ai_idx <= ("0" & v_idx_reg) - ai_idx_reg;
	v_addr             <= (to_unsigned(KYBER_K, log2ceil(KYBER_K)) & v_idx_reg);
	--
	vin                <= unsigned(rama_dout);
	bi                 <= unsigned(ramb_dout);
	ai                 <= unsigned(rama_dout);
	-- MAC: a_idx, s_receive_a: b_idx_reg == 0  -> a_idx = r_idx_minus_b_idx = r_idx
	ramb_addr          <= k_reg(log2ceil(KYBER_K) - 1 downto 0) & bi_idx;

	comb_proc : process(state, ai_idx_reg, dout_valid_piped_reg, i_din_data, i_din_valid, i_dout_ready, k_reg, v_addr, vout) is
	begin
		----
		rama_blk_addr <= k_reg(log2ceil(KYBER_K) - 1 downto 0) & ai_idx_reg; -- default: b
		rama_din      <= std_logic_vector(i_din_data);
		-- control signals defaults
		o_done        <= '0';
		o_din_ready   <= '0';
		en_v          <= '0';
		ld_v          <= '0';
		rama_ce       <= '0';
		rama_we       <= '0';
		ramb_ce       <= '0';
		ramb_we       <= '0';
		extdit_active <= '0';

		case state is
			when s_init =>
				extdit_active <= '1';
			when s_receive_bb =>
				ramb_ce       <= i_din_valid;
				ramb_we       <= i_din_valid;
				o_din_ready   <= '1';
				extdit_active <= '1';
			when s_receive_aa =>
				rama_ce       <= i_din_valid;
				rama_we       <= i_din_valid;
				o_din_ready   <= '1';
				extdit_active <= '1';
			when s_receive_v =>
				rama_ce       <= i_din_valid;
				rama_we       <= i_din_valid;
				rama_blk_addr <= v_addr;
				o_din_ready   <= '1';
				extdit_active <= '1';
			when s_mac_load_v =>
				rama_ce       <= '1';
				rama_blk_addr <= v_addr;
				ld_v          <= '1';
				extdit_active <= '1';
			when s_mac_piped =>
				ramb_ce <= '1';
				rama_ce <= '1';
				en_v    <= '1';
			when s_mac_store_v =>
				rama_ce       <= '1';
				rama_we       <= '1';
				rama_blk_addr <= v_addr;
				rama_din      <= std_logic_vector(vout);
			when s_mac_flush =>
				null;
			when s_send_v =>
				rama_ce       <= i_dout_ready or not dout_valid_piped_reg;
				rama_blk_addr <= v_addr;
				extdit_active <= '1';
			when s_send_v_flush =>
				extdit_active <= '1';
			when s_done =>
				extdit_active <= '1';
				o_done        <= '1';
		end case;

	end process comb_proc;

	o_dout_valid    <= dout_valid_piped_reg;
	o_dout_data     <= unsigned(rama_dout);
	o_extdit_active <= extdit_active;
	-- 
end architecture RTL;
