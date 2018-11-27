library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.kyber_pkg.all;

entity polyvec_mac is
	generic(
		COEF_W : positive := log2ceil(KYBER_Q) -- 13	
	);
	port(
		clk       : in  std_logic;
		rst       : in  std_logic;
		--
		-- polyvec a
		a_rd_addr    : out unsigned(log2ceil(KYBER_K * KYBER_N) - 1 downto 0);
		a_rd_data   : in  unsigned(COEF_W - 1 downto 0);
		-- polyvec b
		b_rd_addr    : out unsigned(log2ceil(KYBER_K * KYBER_N) - 1 downto 0);
		b_rd_data   : in  unsigned(COEF_W - 1 downto 0);
		b_ce      : out std_logic;
		-- poly c = a * b
		c_rd_addr : out unsigned(log2ceil(KYBER_N) - 1 downto 0);
		c_rd_data : out unsigned(COEF_W - 1 downto 0);
		c_wr_addr : out unsigned(log2ceil(KYBER_N) - 1 downto 0);
		c_wr_data : out unsigned(COEF_W - 1 downto 0);
		c_we      : out std_logic;
		c_ce      : out std_logic;
		--
		-- ctrl
		go        : in  std_logic;
		busy      : out std_logic
	);
end entity polyvec_mac;

architecture RTL of polyvec_mac is
	------------------------------------------ Constants ----------------------------------------------

	-- data-path constants
	constant N_minus_one : unsigned := to_unsigned(KYBER_N - 1, log2ceil(KYBER_N - 1) - 1);
	constant K_minus_one : unsigned := to_unsigned(KYBER_K - 1, log2ceil(KYBER_K - 1) - 1);
	------------------------------------------ Registers/FFs ------------------------------------------
	-- state
	signal busy_reg      : std_logic;
	-- counters
	-- address counts
	signal i_reg         : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal j_reg         : unsigned(log2ceil(KYBER_N) - 1 downto 0);
	signal k_reg         : unsigned(log2ceil(KYBER_K) - 1 downto 0);
	-- data-path registers
	signal product_reg   : unsigned(2 * COEF_W + 1 - 1 downto 0);
	signal ri_reg        : unsigned(COEF_W - 1 downto 0);

	------------------------------------------ Wires --------------------------------------------------
	signal mac     : std_logic_vector(2 * COEF_W + 1 - 1 downto 0); -- 2*w + 1 = 27
	signal red_mac : std_logic_vector(COEF_W - 1 downto 0);

begin

	regs_proc : process(clk, rst)
	begin
		-- synchronous reset (to be changed when target technology requires)
		if rising_edge(clk) then
			if rst = '1' then
				busy_reg <= '0';
			else                        -- not reset
				if busy_reg = '0' then
					if go = '1' then
						busy_reg <= '1';
						i_reg    <= (others => '0');
						j_reg    <= (others => '0');
						k_reg    <= (others => '0');
						ri_reg   <= (others => '0');
					end if;
				else                    -- busy
					if j_reg = N_minus_one then
						j_reg <= (others => '0');

						if k_reg = K_minus_one then
							k_reg <= (others => '0');
							if i_reg = N_minus_one then
								i_reg    <= (others => '0');
								busy_reg <= '0';
							else
								i_reg <= i_reg + 1;
							end if;
						else
							k_reg <= k_reg + 1;
						end if;

					else
						j_reg <= j_reg + 1;
					end if;

				end if;
			end if;
		end if;
	end process regs_proc;

	datapath_reg_proc : process(clk)
	begin
		if rising_edge(clk) then
			product_reg <= a_rd_data * b_rd_data;
			ri_reg      <= unsigned(red_mac);
		end if;
	end process datapath_reg_proc;

	mac <= std_logic_vector(product_reg + ri_reg);

	assert mac'length = 27 severity failure;
	reduce : entity work.barret_reduce
		generic map(
			G_IN_WIDTH => mac'length
		)
		port map(
			a => mac,
			r => red_mac
		);

end architecture RTL;
