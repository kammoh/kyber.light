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
		clk        : in  std_logic;
		rst        : in  std_logic;
		-- Control
		i_rec_a    : in  std_logic;
		i_rec_b    : in  std_logic;
		i_rec_r    : in  std_logic;
		i_snd_r    : in  std_logic;
		i_do_mac   : in  std_logic;
		i_subtract : in  std_logic;
		o_done     : out std_logic;
		-- Data
		i_d_data   : in  t_coef;
		i_d_valid  : in  std_logic;
		i_d_ready  : out std_logic;
		o_d_data   : out t_coef;
		o_d_valid  : out std_logic;
		o_d_ready  : in  std_logic
	);
end entity polyvec_mac;

architecture RTL of polyvec_mac is
	------------------------------------------ Constants ----------------------------------------------
	------------------------------------------ Types --------------------------------------------------
	type t_state is (s_init, s_receive_a, s_receive_b, s_receive_r, s_mac_rd_r, s_mac_piped, s_mac_flush_0,
	                 s_mac_wr_r, s_send_r, s_done
	                );
	-- data-path constants
	constant N_minus_one     : unsigned := to_unsigned(KYBER_N - 1, log2ceil(KYBER_N - 1) - 1);
	constant K_minus_one     : unsigned := to_unsigned(KYBER_K - 1, log2ceil(KYBER_K - 1) - 1);
	------------------------------------------ Registers/FFs ------------------------------------------
	-- state
	signal state             : t_state;
	-- counters
	-- address counts
	signal r_idx_reg         : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal b_idx_reg         : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal k_reg             : unsigned(log2ceil(KYBER_K) - 1 downto 0);
	signal en_r_piped_reg    : std_logic;
	signal ld_r_piped_reg    : std_logic;
	signal dout_valid_piped_reg    : std_logic;
	------------------------------------------ Wires --------------------------------------------------
	signal a_idx             : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal r_idx_minus_b_idx : unsigned(log2ceil(KYBER_N) downto 0);
	signal nega              : std_logic;
	signal en_r              : std_logic;
	signal ld_r              : std_logic;
	signal a                 : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal b                 : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal rin               : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal rout              : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	---------------------------------------- RAM signals ----------------------------------------------
	signal b_r_ram_ce        : std_logic;
	signal b_r_ram_we        : std_logic;
	signal b_r_ram_addr      : unsigned(log2ceil((KYBER_K + 1) * KYBER_N) - 1 downto 0);
	signal r_addr            : unsigned(log2ceil((KYBER_K + 1) * KYBER_N) - 1 downto 0);
	signal b_r_ram_in_data   : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal b_r_ram_out_data  : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal a_ram_ce          : std_logic;
	signal a_ram_we          : std_logic;
	signal a_ram_addr        : unsigned(log2ceil(KYBER_K * KYBER_N) - 1 downto 0);
	signal a_ram_in_data     : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal a_ram_out_data    : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);

begin

	ploymac_datapath : entity work.polymac_datapath
		port map(
			clk   => clk,
			nega  => nega,
			en_r  => en_r_piped_reg,
			ld_r  => ld_r_piped_reg,
			in_a  => a,
			in_b  => b,
			in_r  => rin,
			out_r => rout
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
			in_data  => a_ram_in_data,
			out_data => a_ram_out_data
		);

	regs_proc : process(clk)
	begin
		if rising_edge(clk) then
			en_r_piped_reg <= en_r;
			ld_r_piped_reg <= ld_r;
			if rst = '1' then
				state <= s_init;
			else
				case state is
					when s_init =>
						r_idx_reg <= (others => '0');
						k_reg     <= (others => '0');
						b_idx_reg <= (others => '0');
						if i_rec_a then
							state <= s_receive_a;
						elsif i_rec_b then
							state <= s_receive_b;
						elsif i_rec_r then
							state <= s_receive_r;
						elsif i_do_mac then
							state <= s_mac_rd_r;
						elsif i_snd_r then
							state <= s_send_r;
						end if;

					when s_receive_a =>
						if i_d_valid then

						end if;
					when s_receive_b =>
						null;
					when s_receive_r =>
						null;
					when s_mac_rd_r =>
						null;
					when s_mac_piped =>
						null;
					when s_mac_flush_0 =>
						null;
					when s_mac_wr_r =>
						null;
					when s_send_r =>
						null;
					when s_done =>
						null;
				end case;

			end if;
		end if;
	end process regs_proc;

	comb_proc : process(all) is
	begin
		-- memory address generation
		r_idx_minus_b_idx <= ("0" & r_idx_reg) - b_idx_reg;
		if r_idx_minus_b_idx(r_idx_minus_b_idx'length - 1) then -- r_idx < b_idx
			a_idx <= resize(r_idx_minus_b_idx + KYBER_N, a_idx'length);
			nega  <= not i_subtract;
		else
			a_idx <= resize(r_idx_minus_b_idx, a_idx'length);
			nega  <= i_subtract;
		end if;
		r_addr            <= ("11" & b_idx_reg);
		a_ram_addr        <= (k_reg & a_idx);
		b_r_ram_addr      <= (k_reg & b_idx_reg); -- default: b
		-- control signals defaults
		o_done            <= '0';
		i_d_ready         <= '0';
		o_d_valid         <= '0';
		nega              <= '0';
		en_r              <= '0';
		ld_r              <= '0';
		b_r_ram_ce        <= '0';
		b_r_ram_we        <= '0';
		a_ram_ce          <= '0';
		a_ram_we          <= '0';

		case state is
			when s_init =>
				null;

			when s_receive_a =>
				a_ram_ce <= '1';
				a_ram_we <= '1';

			when s_receive_b =>
				b_r_ram_ce <= '1';
				b_r_ram_we <= '1';

			when s_receive_r =>
				b_r_ram_ce   <= '1';
				b_r_ram_we   <= '1';
				b_r_ram_addr <= r_addr;

			when s_mac_rd_r =>
				b_r_ram_ce   <= '1';
				b_r_ram_addr <= r_addr;
				en_r         <= '1';
				ld_r         <= '1';

			when s_mac_piped =>
				a_ram_ce   <= '1';
				b_r_ram_ce <= '1';
				en_r       <= '1';

			when s_mac_flush_0 =>
				null;

			when s_mac_wr_r =>
				b_r_ram_ce   <= '1';
				b_r_ram_we   <= '1';
				b_r_ram_addr <= r_addr;

			when s_send_r =>
				b_r_ram_ce   <= '1';
				b_r_ram_addr <= r_addr;

			when s_done =>
				o_done <= '1';

		end case;

	end process comb_proc;

end architecture RTL;
