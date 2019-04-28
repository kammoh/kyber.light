library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity ConstMult_7681_11_24 is
	port(
		clk       : in  std_logic;
		rst       : in  std_logic;
		i_X_data  : in  unsigned(10 downto 0);
		i_X_valid : in  std_logic;
		o_X_ready : out std_logic;
		--
		o_R_data  : out unsigned(23 downto 0);
		o_R_valid : out std_logic;
		i_R_ready : in  std_logic
	);
end entity;

architecture arch of ConstMult_7681_11_24 is
	signal M1X                             : unsigned(11 downto 0);
	signal M511X_High_L                    : unsigned(11 downto 0);
	signal M511X_High_R                    : unsigned(11 downto 0);
	signal M511X, M511X_d1                 : unsigned(20 downto 0);
	signal P7681X_High_L, P7681X_High_L_d1 : unsigned(10 downto 0);
	signal P7681X_High_R, P7681X_High_R_d1 : unsigned(10 downto 0);
	signal P7681X                          : unsigned(23 downto 0);
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
					M511X_d1         <= M511X;
					P7681X_High_L_d1 <= P7681X_High_L;
					P7681X_High_R_d1 <= P7681X_High_R;
				end if;
			end if;
		end if;
	end process;
	
	
	M1X <= (11 downto 0 => '0') - i_X_data;

	-- M511X <-  M1X<<9  + X
	M511X_High_L       <= M1X(11 downto 0);
	M511X_High_R       <= (20 downto 11 => '0') & i_X_data(10 downto 9);
	M511X(20 downto 9) <= M511X_High_R + M511X_High_L; -- sum of higher bits
	M511X(8 downto 0)  <= i_X_data(8 downto 0); -- lower bits untouched

	-- P7681X <-  X<<13  + M511X
	P7681X_High_L        <= i_X_data(10 downto 0);
	P7681X_High_R        <= (23 downto 21 => M511X(20)) & M511X(20 downto 13);
	P7681X(23 downto 13) <= P7681X_High_R_d1 + P7681X_High_L_d1; -- sum of higher bits
	P7681X(12 downto 0)  <= M511X_d1(12 downto 0); -- lower bits untouched

	o_R_data <= P7681X(23 downto 0);
end architecture;

