library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity ConstMult_3329_10_22 is
	port(
		clk       : in  std_logic;
		rst       : in  std_logic;
		i_X_data  : in  unsigned(9 downto 0);
		i_X_valid : in  std_logic;
		o_X_ready : out std_logic;
		--
		o_R_data  : out unsigned(21 downto 0);
		o_R_valid : out std_logic;
		i_R_ready : in  std_logic
	);
end entity;

architecture arch of ConstMult_3329_10_22 is
	signal P3X_High_L                      : unsigned(10 downto 0);
	signal P3X_High_R                      : unsigned(10 downto 0);
	signal P3X                             : unsigned(11 downto 0);
	signal P257X_High_L                    : unsigned(10 downto 0);
	signal P257X_High_R                    : unsigned(10 downto 0);
	signal P257X, P257X_d1                 : unsigned(18 downto 0);
	signal P3329X_High_L, P3329X_High_L_d1 : unsigned(11 downto 0);
	signal P3329X_High_R, P3329X_High_R_d1 : unsigned(11 downto 0);
	signal P3329X                          : unsigned(21 downto 0);
	signal valid_bit_reg                   : std_logic;
	signal stall                           : boolean;
begin

	stall <= valid_bit_reg = '1' and i_R_ready = '0';

	o_X_ready <= '0' when stall else '1';

	o_R_valid <= valid_bit_reg;

	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				valid_bit_reg <= '0';
			else
				if not stall then
					valid_bit_reg    <= i_X_valid;
					P257X_d1         <= P257X;
					P3329X_High_L_d1 <= P3329X_High_L;
					P3329X_High_R_d1 <= P3329X_High_R;
				end if;
			end if;
		end if;
	end process;

	-- P3X <-  X<<1  + X
	P3X_High_L       <= (11 downto 11 => '0') & i_X_data(9 downto 0);
	P3X_High_R       <= (11 downto 10 => '0') & i_X_data(9 downto 1);
	P3X(11 downto 1) <= P3X_High_R + P3X_High_L; -- sum of higher bits
	P3X(0 downto 0)  <= i_X_data(0 downto 0); -- lower bits untouched

	-- P257X <-  X<<8  + X
	P257X_High_L       <= (18 downto 18 => '0') & i_X_data(9 downto 0);
	P257X_High_R       <= (18 downto 10 => '0') & i_X_data(9 downto 8);
	P257X(18 downto 8) <= P257X_High_R + P257X_High_L; -- sum of higher bits
	P257X(7 downto 0)  <= i_X_data(7 downto 0); -- lower bits untouched

	-- P3329X <-  P3X<<10  + P257X
	P3329X_High_L        <= P3X(11 downto 0);
	P3329X_High_R        <= (21 downto 19 => '0') & P257X(18 downto 10);
	P3329X(21 downto 10) <= P3329X_High_R_d1 + P3329X_High_L_d1; -- sum of higher bits
	P3329X(9 downto 0)   <= P257X_d1(9 downto 0); -- lower bits untouched

	o_R_data <= P3329X(21 downto 0);
end architecture;

