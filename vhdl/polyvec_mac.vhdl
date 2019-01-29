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
		clk  : in  std_logic;
		rst  : in  std_logic;
		--
		-- ctrl
		go   : in  std_logic;
		busy : out std_logic
	);
end entity polyvec_mac;

architecture RTL of polyvec_mac is
	------------------------------------------ Constants ----------------------------------------------
	------------------------------------------ Types --------------------------------------------------
	type t_state is (init, receive_u, receive_bp, receive_vv, mac_rd_r, mac_piped, mac_flush_0, mac_wr_r, send_vv);
	-- data-path constants
	constant N_minus_one     : unsigned := to_unsigned(KYBER_N - 1, log2ceil(KYBER_N - 1) - 1);
	constant K_minus_one     : unsigned := to_unsigned(KYBER_K - 1, log2ceil(KYBER_K - 1) - 1);
	------------------------------------------ Registers/FFs ------------------------------------------
	-- state
	signal state             : t_state;
	-- counters
	-- address counts
	signal i_reg             : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal j_reg             : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal k_reg             : unsigned(log2ceil(KYBER_K) - 1 downto 0);
	------------------------------------------ Wires --------------------------------------------------
	signal nega              : std_logic;
	signal r_en              : std_logic;
	signal r_load            : std_logic;
	signal a                 : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal b                 : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal rin               : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	signal rout              : std_logic_vector(log2ceil(KYBER_Q) - 1 downto 0);
	---------------------------------------- RAM signals ----------------------------------------------
	signal v_bp_ram_ce       : std_logic;
	signal v_bp_ram_we       : std_logic;
	signal v_bp_ram_addr     : unsigned(log2ceil((KYBER_K + 1) * KYBER_N) - 1 downto 0);
	signal v_bp_ram_in_data  : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal v_bp_ram_out_data : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal u_ram_ce          : std_logic;
	signal u_ram_we          : std_logic;
	signal u_ram_in_addr     : unsigned(log2ceil(KYBER_K * KYBER_N) - 1 downto 0);
	signal u_ram_in_data     : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	signal u_ram_out_data    : std_logic_vector(KYBER_COEF_BITS - 1 downto 0);

begin

	ploymac_dp_inst : entity work.polymac_dp
		port map(
			clk   => clk,
			nega  => nega,
			en_r  => r_en,
			ld_r  => r_load,
			in_a  => a,
			in_b  => b,
			in_r  => rin,
			out_r => rout
		);

	v_bp_ram : entity poc.ocram_sp
		generic map(
			DEPTH  => (KYBER_K + 1) * KYBER_N,
			D_BITS => KYBER_COEF_BITS
		)
		port map(
			clk      => clk,
			ce       => v_bp_ram_ce,
			we       => v_bp_ram_we,
			in_addr  => v_bp_ram_addr,
			in_data  => v_bp_ram_in_data,
			out_data => v_bp_ram_out_data
		);

	u_ram : entity poc.ocram_sp
		generic map(
			DEPTH  => KYBER_K * KYBER_N,
			D_BITS => KYBER_COEF_BITS
		)
		port map(
			clk      => clk,
			ce       => u_ram_ce,
			we       => u_ram_we,
			in_addr  => u_ram_in_addr,
			in_data  => u_ram_in_data,
			out_data => u_ram_out_data
		);

	regs_proc : process(clk)
	begin
		-- synchronous reset (to be changed when target technology requires)
		if rising_edge(clk) then
			if rst = '1' then
				state <= init;
			else
				case state is
					when init =>
						if go then
							i_reg <= (others => '0');
							j_reg <= (others => '0');
							k_reg <= (others => '0');
							state <= receive_u;
						end if;

					when receive_u =>
						null;
					when receive_bp =>
						null;
					when receive_vv =>
						null;
					when mac_rd_r =>
						null;
					when mac_piped =>
						null;
					when mac_flush_0 =>
						null;
					when mac_wr_r =>
						null;
					when send_vv =>
						null;
				end case;

			end if;
		end if;
	end process regs_proc;

end architecture RTL;
