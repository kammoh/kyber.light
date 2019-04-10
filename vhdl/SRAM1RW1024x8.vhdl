library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SRAM1RW1024x8 is
	port(
		A   : in  std_logic_vector(9 downto 0);
		O   : out std_logic_vector(7 downto 0);
		I   : in  std_logic_vector(7 downto 0);
		WEB : in  std_logic;
		CSB : in  std_logic;
		OEB : in  std_logic;
		CE  : in  std_logic             -- clock
	);
end entity SRAM1RW1024x8;

architecture BEHAVIOURAL of SRAM1RW1024x8 is
	type T_MEM_ARRAY is array (0 to 1023) of std_logic_vector(7 downto 0);
	signal mem_array : T_MEM_ARRAY;
	signal RE, WE    : std_logic;
	signal data_out  : std_logic_vector(7 downto 0);
	signal addr      : natural;
begin
	RE <= (not CSB) and WEB;
	WE <= (not CSB) and (not WEB);
	
	addr <= to_integer(unsigned(A));

	sync_proc : process(CE) is
	begin
		if rising_edge(CE) then
			if RE = '1' then
				data_out <= mem_array(addr);
			end if;
			if WE = '1' then
				mem_array(addr) <= I;
			end if;
		end if;
	end process sync_proc;
	
	comb_proc : process(data_out, OEB) is
	begin
		if OEB = '0' then
			O <= data_out;
		else
			O <= (others => 'Z');
		end if;
	end process comb_proc;
	

end architecture BEHAVIOURAL;