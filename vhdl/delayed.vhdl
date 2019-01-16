library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delayed is
	generic (
		CYCLES: natural	
	);
	port(
		clk : in std_logic;
		sig : in std_logic_vector;
		sig_delayed : out std_logic_vector
	);
end entity delayed;

architecture RTL of delayed is
	type t_pipe_stages is array (0 to CYCLES - 1) of std_logic_vector(sig'length - 1 downto 0);
	signal regs : t_pipe_stages;
	
begin
	process(clk)
	begin
		if rising_edge(clk) then
			regs(0) <= sig;
			for i in 1 to CYCLES - 1 loop
				regs(i) <= regs(i-1);
			end loop;
			
		end if;
	end process;
	
	sig_delayed <= regs(CYCLES - 1);
	
end architecture RTL;
