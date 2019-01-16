library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cbd4_controller is
	port(
		clk             : in  std_logic;
		rst             : in  std_logic;
		-- cbd I/O
		in_hword_valid  : in  std_logic;
		in_hword_ready  : out std_logic;
		-- out coefficient stream
		out_coeff_valid : out std_logic;
		out_coeff_ready : in  std_logic;
		-- to datapath
		en_a            : out std_logic;
		en_b            : out std_logic
	);
end entity cbd4_controller;

architecture RTL of cbd4_controller is
	type state_type is (init_read_a, read_b, valid_read_a);
	signal state : state_type;
begin

	process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= init_read_a;
			else
				case state is
					when init_read_a =>
						if in_hword_valid then
							state <= read_b;
						end if;

					when read_b =>
						if in_hword_valid then
							state <= valid_read_a;
						end if;

					when valid_read_a =>
						if out_coeff_ready then
							if in_hword_valid then
								state <= read_b;
							else
								state <= init_read_a;
							end if;
						end if;

				end case;
			end if;
		end if;
	end process;

	process(all) is
	begin
		in_hword_ready  <= '0';
		out_coeff_valid <= '0';
		en_a            <= '0';
		en_b            <= '0';

		case state is
			when init_read_a =>
				in_hword_ready <= '1';
				en_a           <= in_hword_valid;

			when read_b =>
				in_hword_ready <= '1';
				en_b           <= in_hword_valid;

			when valid_read_a =>
				in_hword_ready  <= out_coeff_ready;
				en_a            <= in_hword_valid and out_coeff_ready;
				out_coeff_valid <= '1';

		end case;

	end process;

end architecture RTL;
