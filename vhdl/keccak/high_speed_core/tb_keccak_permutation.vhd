-- The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
-- Michaël Peeters and Gilles Van Assche. For more information, feedback or
-- questions, please refer to our website: http://keccak.noekeon.org/

-- Implementation by the designers,
-- hereby denoted as "the implementer".

-- To the extent possible under law, the implementer has waived all copyright
-- and related or neighboring rights to the source code in this file.
-- http://creativecommons.org/publicdomain/zero/1.0/

 library work;
	use work.keccak_globals.all;
library std;
	use std.textio.all;
	
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_misc.all;
	use ieee.std_logic_arith.all;
	use ieee.std_logic_textio.all;
	use ieee.std_logic_unsigned."+"; 


entity keccak_permutation_tb is
end keccak_permutation_tb;
	
architecture tb of keccak_permutation_tb is


-- components

component keccak_round
port (

    round_in     : in  k_state;
    round_constant_signal    : in std_logic_vector(63 downto 0);
    round_out    : out k_state);

end component;

component keccak_round_constants_gen
port (
    round_number: in unsigned(4 downto 0);
    round_constant_signal_out: out std_logic_vector(63 downto 0));
 end component;


  -- signal declarations

	signal clk : std_logic;
	signal rst_n : std_logic;

 
  signal round_in,round_out,zero_state : k_state;
  signal counter : unsigned(4 downto 0);
  signal zero_lane: k_lane;
  signal zero_plane: k_plane;
  signal round_constant_signal: std_logic_vector(63 downto 0);
  
 
 type st_type is (st0,st1,STOP);
 signal st : st_type;
 
 
begin  -- Rtl

-- port map

round_map : keccak_round port map(round_in,round_constant_signal,round_out);
round_constants_gen: keccak_round_constants_gen port map(counter,round_constant_signal);

-- constants signals assingement
zero_lane<= (others =>'0');

i000: for x in 0 to 4 generate
	zero_plane(x)<= zero_lane;
end generate;

i001: for y in 0 to 4 generate
	zero_state(y)<= zero_plane;
end generate;

rst_n <= '0', '1' after 19 ns;

--main process
-- generate round number, read input value, write output value

tbgen : process(clk)
				
	variable line_in : line;
	variable line_out : line;
	
	variable datain0 : std_logic_vector(15 downto 0);
	variable temp: std_logic_vector(63 downto 0);			
	variable temp2: std_logic_vector(63 downto 0);			
	
	
	file filein : text open read_mode is "../test_vectors/perm_in.txt";
	file fileout : text open write_mode is "../test_vectors/perm_out_high_speed_core_vhdl.txt";
				
		begin
			if(rst_n='0') then
				st <= st0;
				--round_in <= (others=>'0');
				counter <= (others => '0');
					
			elsif(clk'event and clk='1') then
					
					----------------------
					case st is
						when st0 =>
						--continue to read up to the end of file marker.
							readline(filein,line_in);
							if(line_in(1)='.') then
								FILE_CLOSE(filein);
								FILE_CLOSE(fileout);
								assert false report "Simulation completed" severity failure;
								st <= STOP;
							else
								-- Write the header on output file if needed
								
								
								--read the input, 25 lines and apply to keccak
								--round_in<=zero_state;
								for row in 0 to 4 loop
								for col in 0 to 4 loop
									
									hread(line_in,temp);
										for i in 0 to 63 loop
											round_in(row)(col)(i)<= temp(i);
										end loop;
									readline(filein,line_in);
									end loop;	
								end loop;
								---...
								
								-- apply the round numbers
								counter <= (others => '0');
								st <= st1;
							end if;
						when st1 =>
							-- increment the counter in order of computing the rounds
							if (counter<23) then
								round_in<=round_out;
								counter<=counter+1;
								-- uncomment the following lines
								-- if you want to write
								-- round outputs


								-- for row in 0 to 4 loop
								--	for col in 0 to 4 loop
								--		for i IN 0 to 63 LOOP
								--			temp(i) := round_out(row)(col)(i);
								--		end loop;
								--		hwrite(line_out,temp);
								--		writeline(fileout,line_out);
								--	end loop;
								--end loop;
								--write(fileout,string'("-"));
								--writeline(fileout,line_out);


							else
								st<=st0;
								for row in 0 to 4 loop
									for col in 0 to 4 loop
										for i IN 0 to 63 LOOP
											temp(i) := round_out(row)(col)(i);
										end loop;
										hwrite(line_out,temp);
										writeline(fileout,line_out);
									end loop;
								end loop;
								write(fileout,string'("-"));
								writeline(fileout,line_out);

							end if;
							
							--if finished write output and go back to st0
							
						when STOP =>
							null;
					end case;
				end if;
			end process;


-- clock generation


clkgen : process
	begin
		clk <= '1';
		loop
				wait for 10 ns;
				clk<=not clk;
		end loop;
	end process;

end tb;
