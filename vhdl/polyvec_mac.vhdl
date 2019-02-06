-- Polynomial vector Multiply and Accumulate

-- C

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.kyber_pkg.all;

library poc;
use poc.ocram_sp;

entity polyvec_mac is
	port(
		clk                : in  std_logic;
		rst                : in  std_logic;
		-- Control
		i_recv_a           : in  std_logic;
		i_recv_b           : in  std_logic;
		i_recv_r           : in  std_logic;
		i_send_r           : in  std_logic;
		i_do_mac           : in  std_logic;
		i_subtract         : in  std_logic;
		o_done             : out std_logic;
		-- Data
		i_din_data         : in  t_coef_us;
		i_din_valid        : in  std_logic;
		o_din_ready        : out std_logic;
		o_dout_data        : out t_coef_us;
		o_dout_valid       : out std_logic;
		i_dout_ready       : in  std_logic;
		-- External divide provider
		i_ext_div_a        : in  unsigned(2 * log2ceil(KYBER_Q) - 1 downto 0);
		o_ext_div_a_div_q  : out t_coef_us;
		o_ext_div_selected : out std_logic
	);
end entity polyvec_mac;

architecture RTL of polyvec_mac is
	------------------------------------------ Constants ----------------------------------------------
	------------------------------------------ Types --------------------------------------------------
	type t_state is (s_init,
	                 s_receive_a, s_receive_b, s_receive_r,
	                 s_mac_rd_r, s_mac_fill, s_mac_piped, s_mac_flush_1, s_mac_flush_2, s_mac_wr_r,
	                 s_send_r, s_send_r_flush,
	                 s_done
	                );
	------------------------------------------ Registers/FFs ------------------------------------------
	-- state
	signal state                : t_state;
	-- counters
	-- address counts
	signal r_idx_reg            : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal b_idx_reg            : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal k_reg                : unsigned(log2ceil(KYBER_K) - 1 downto 0);
	signal en_r_piped_reg       : std_logic;
	signal ld_r_piped_reg       : std_logic;
	signal dout_valid_piped_reg : std_logic;
	------------------------------------------ Wires --------------------------------------------------
	signal a_idx                : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal r_idx_minus_b_idx    : unsigned(log2ceil(KYBER_N) downto 0);
	signal nega                 : std_logic;
	signal en_r                 : std_logic;
	signal ld_r                 : std_logic;
	signal a                    : t_coef_us;
	signal b                    : t_coef_us;
	signal rin                  : t_coef_us;
	signal rout                 : t_coef_us;
	signal r_idx_plus_one       : unsigned(log2ceil(KYBER_N) downto 0);
	signal r_idx_plus_one_carry : std_logic;
	signal r_idx_reg_next       : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal b_idx_plus_one       : unsigned(log2ceil(KYBER_N) downto 0);
	signal b_idx_plus_one_carry : std_logic;
	signal b_idx_reg_next       : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	---------------------------------------- RAM signals ----------------------------------------------
	signal b_r_ram_ce           : std_logic;
	signal b_r_ram_we           : std_logic;
	signal b_r_ram_addr         : unsigned(log2ceil((KYBER_K + 1) * KYBER_N) - 1 downto 0);
	signal r_addr               : unsigned(log2ceil((KYBER_K + 1) * KYBER_N) - 1 downto 0);
	signal b_r_ram_in_data      : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal b_r_ram_out_data     : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal a_ram_ce             : std_logic;
	signal a_ram_we             : std_logic;
	signal a_ram_addr           : unsigned(log2ceil(KYBER_K * KYBER_N) - 1 downto 0);
	signal a_ram_out_data       : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);

begin

	ploymac_datapath : entity work.polymac_datapath
		port map(
			clk              => clk,
			nega             => nega,
			en_r             => en_r_piped_reg,
			ld_r             => ld_r_piped_reg,
			in_a             => a,
			in_b             => b,
			in_r             => rin,
			out_r            => rout,
			i_ext_div_select => o_ext_div_selected,
			i_ext_div        => i_ext_div_a,
			o_ext_div        => o_ext_div_a_div_q
		);

	----------------------------
	-- b_r_ram address layout --
	----------------------------
	--
	---------------------- 0
	--                  --
	--                  --
	--                  --
	--        b         --
	--                  --
	--                  --
	--                  -- 
	---------------------- 3*256
	--                  --
	--        r         --
	--                  --
	---------------------- 4*256

	b_r_ram : entity poc.ocram_sp
		generic map(
			DEPTH  => (KYBER_K + 1) * KYBER_N,
			D_BITS => KYBER_COEF_BITS
		)
		port map(
			clk      => clk,
			ce       => b_r_ram_ce,
			we       => b_r_ram_we,
			in_addr  => b_r_ram_addr,
			in_data  => b_r_ram_in_data,
			out_data => b_r_ram_out_data
		);

	a_ram : entity poc.ocram_sp
		generic map(
			DEPTH  => KYBER_K * KYBER_N,
			D_BITS => KYBER_COEF_BITS
		)
		port map(
			clk      => clk,
			ce       => a_ram_ce,
			we       => a_ram_we,
			in_addr  => a_ram_addr,
			in_data  => std_logic_vector(i_din_data),
			out_data => a_ram_out_data
		);

	r_idx_plus_one       <= ("0" & r_idx_reg) + 1;
	r_idx_reg_next       <= r_idx_plus_one(r_idx_reg'length - 1 downto 0);
	r_idx_plus_one_carry <= r_idx_plus_one(r_idx_reg'length);
	--
	b_idx_plus_one       <= ("0" & b_idx_reg) + 1;
	b_idx_reg_next       <= b_idx_plus_one(b_idx_reg'length - 1 downto 0);
	b_idx_plus_one_carry <= b_idx_plus_one(b_idx_reg'length);

	regs_proc : process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state                <= s_init;
				dout_valid_piped_reg <= '0';
			else
				en_r_piped_reg <= en_r;
				ld_r_piped_reg <= ld_r;
				case state is
					when s_init =>
						r_idx_reg <= (others => '0');
						k_reg     <= (others => '0');
						b_idx_reg <= (others => '0');
						if i_recv_a then
							state <= s_receive_a;
						elsif i_recv_b then
							state <= s_receive_b;
						elsif i_recv_r then
							state <= s_receive_r;
						elsif i_do_mac then
							state <= s_mac_rd_r;
						elsif i_send_r then
							state <= s_send_r;
						end if;
					when s_receive_a =>
						if i_din_valid then
							r_idx_reg <= r_idx_reg_next;
							if r_idx_plus_one_carry then
								k_reg <= k_reg + 1;
								if k_reg = (KYBER_K - 1) then
									k_reg <= (others => '0');
									state <= s_done;
								end if;
							end if;
						end if;
					when s_receive_b =>
						if i_din_valid then
							b_idx_reg <= b_idx_reg_next;
							if b_idx_plus_one_carry then
								k_reg <= k_reg + 1;
								if k_reg = (KYBER_K - 1) then
									k_reg <= (others => '0');
									state <= s_done;
								end if;
							end if;
						end if;
					when s_receive_r =>
						if i_din_valid then
							r_idx_reg <= r_idx_reg_next;
							if r_idx_plus_one_carry then
								state <= s_done;
							end if;
						end if;
					when s_mac_rd_r =>
						state <= s_mac_fill;
					when s_mac_fill =>
						b_idx_reg <= b_idx_reg_next;
						state     <= s_mac_piped;
					when s_mac_piped =>
						b_idx_reg <= b_idx_reg_next;
						if b_idx_plus_one_carry then
							k_reg <= k_reg + 1;
							if k_reg = (KYBER_K - 1) then
								k_reg <= (others => '0');
								state <= s_mac_flush_1;
							end if;
						end if;
					when s_mac_flush_1 =>
						state <= s_mac_flush_2;
					when s_mac_flush_2 =>
						state <= s_mac_wr_r;
					when s_mac_wr_r =>
						r_idx_reg <= r_idx_reg_next;
						if r_idx_plus_one_carry then
							state <= s_done;
						else
							state <= s_mac_rd_r;
						end if;
					when s_send_r =>
						dout_valid_piped_reg <= '1';
						if i_dout_ready or not dout_valid_piped_reg then -- "FIFO" to be consumed or "FIFO" is empty
							r_idx_reg <= r_idx_reg_next;
							if r_idx_plus_one_carry then
								state <= s_send_r_flush;
							end if;
						end if;
					when s_send_r_flush =>
						if i_dout_ready then
							dout_valid_piped_reg <= '0';
							state                <= s_done;
						end if;
					when s_done =>
						if not (i_recv_a or i_recv_b or i_recv_r or i_do_mac or i_send_r) then
							state <= s_init;
						end if;

				end case;

			end if;
		end if;
	end process regs_proc;

	a_idx             <= r_idx_minus_b_idx(r_idx_minus_b_idx'length - 2 downto 0);
	nega              <= r_idx_minus_b_idx(r_idx_minus_b_idx'length - 1) xor i_subtract;
	--
	r_idx_minus_b_idx <= ("0" & r_idx_reg) - b_idx_reg;
	r_addr            <= (to_unsigned(KYBER_K, k_reg'length) & r_idx_reg);
	--
	rin               <= unsigned(b_r_ram_out_data);
	a                 <= unsigned(a_ram_out_data);
	b                 <= unsigned(b_r_ram_out_data);
	-- MAC: a_idx, s_receive_a: b_idx_reg == 0  -> a_idx = r_idx_minus_b_idx = r_idx
	a_ram_addr        <= (k_reg & a_idx);

	comb_proc : process(all) is
	begin
		----
		b_r_ram_addr       <= (k_reg & b_idx_reg); -- default: b
		b_r_ram_in_data    <= std_logic_vector(i_din_data);
		-- control signals defaults
		o_done             <= '0';
		o_din_ready        <= '0';
		en_r               <= '0';
		ld_r               <= '0';
		b_r_ram_ce         <= '0';
		b_r_ram_we         <= '0';
		a_ram_ce           <= '0';
		a_ram_we           <= '0';
		o_ext_div_selected <= '0';

		case state is
			when s_init =>
				o_ext_div_selected <= '1';
			when s_receive_a =>
				a_ram_ce           <= i_din_valid;
				a_ram_we           <= i_din_valid;
				o_din_ready        <= '1';
				o_ext_div_selected <= '1';
			when s_receive_b =>
				b_r_ram_ce         <= i_din_valid;
				b_r_ram_we         <= i_din_valid;
				o_din_ready        <= '1';
				o_ext_div_selected <= '1';
			when s_receive_r =>
				b_r_ram_ce         <= i_din_valid;
				b_r_ram_we         <= i_din_valid;
				b_r_ram_addr       <= r_addr;
				o_din_ready        <= '1';
				o_ext_div_selected <= '1';
			when s_mac_rd_r =>
				b_r_ram_ce         <= '1';
				b_r_ram_addr       <= r_addr;
				en_r               <= '1';
				ld_r               <= '1';
				o_ext_div_selected <= '1';
			when s_mac_fill =>
				a_ram_ce   <= '1';
				b_r_ram_ce <= '1';
			when s_mac_piped =>
				a_ram_ce   <= '1';
				b_r_ram_ce <= '1';
				en_r       <= '1';
			when s_mac_flush_1 =>
				en_r <= '1';
			when s_mac_flush_2 =>
				null;
			when s_mac_wr_r =>
				b_r_ram_ce      <= '1';
				b_r_ram_we      <= '1';
				b_r_ram_addr    <= r_addr;
				b_r_ram_in_data <= std_logic_vector(rout);
			when s_send_r =>
				b_r_ram_ce         <= i_dout_ready or not dout_valid_piped_reg;
				b_r_ram_addr       <= r_addr;
				o_ext_div_selected <= '1';
			when s_send_r_flush =>
				o_ext_div_selected <= '1';
			when s_done =>
				o_ext_div_selected <= '1';
				o_done             <= '1';
		end case;

	end process comb_proc;

	o_dout_valid <= dout_valid_piped_reg;
	o_dout_data  <= unsigned(b_r_ram_out_data);
	-- 
end architecture RTL;
