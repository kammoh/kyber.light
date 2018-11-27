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
	
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;



entity keccak_buffer is
  
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;    
    din_buffer_in     : in  std_logic_vector(63 downto 0);
    din_buffer_in_valid: in std_logic;
    last_block: in std_logic;
    din_buffer_full : out std_logic;
    din_buffer_out    : out std_logic_vector(1023 downto 0);
    dout_buffer_in : in std_logic_vector(255 downto 0);
    dout_buffer_out: out std_logic_vector(63 downto 0);
    dout_buffer_out_valid: out std_logic;
    ready: in std_logic);

end keccak_buffer;

architecture rtl of keccak_buffer is

--components


  ----------------------------------------------------------------------------
  -- Internal signal declarations
  ----------------------------------------------------------------------------

 
 signal mode, buffer_full: std_logic; --mode=0 input mode/ mode=1 output mode
  signal count_in_words : unsigned(4 downto 0);


  signal buffer_data: std_logic_vector(1023 downto 0);
 
  
begin  -- Rtl


 
 
 -- buffer
 
  p_main : process (clk, rst_n)
 variable count_out_words:integer range 0 to 4;
    
  begin  -- process p_main
    if rst_n = '0' then                 -- asynchronous rst_n (active low)
      buffer_data <= (others => '0');
      count_in_words <= (others => '0');
      count_out_words :=0;
      buffer_full <='0';
      mode<='0';      
      dout_buffer_out_valid<='0';
      
    elsif clk'event and clk = '1' then  -- rising clk edge
	
	
	if(last_block ='1' and ready='1') then
		mode<='1';
	end if;

	--input mode
	if (mode='0') then
		if(buffer_full='1' and ready ='1')  then
			buffer_full<='0';
			count_in_words<= (others=>'0');
			
		else
			
			if (din_buffer_in_valid='1' and buffer_full='0') then
							--shift buffer
					for i in 0 to 14 loop
						buffer_data( 63+(i*64) downto 0+(i*64) )<=buffer_data( 127+(i*64) downto 64+(i*64) );			
					end loop;
					
					--insert new input
					buffer_data(1023 downto 960) <= din_buffer_in;
					if (count_in_words=15) then
						-- buffer full ready for being absorbed by the permutation
						buffer_full <= '1';
						count_in_words<= (others=>'0');
				
					else
				
						-- increment count_in_words
						count_in_words <= count_in_words + 1;				
					
					end if;		
			--	end if;
			end if;
		end if;

	else
		--output mode
		dout_buffer_out_valid<='1';
		if(count_out_words=0) then
			buffer_data(255 downto 0) <= dout_buffer_in;
			count_out_words:=count_out_words+1;
			dout_buffer_out_valid<='1';
		
			--for i in 0 to 2 loop
			--	buffer_data( 63+(i*64) downto 0+(i*64) )<=buffer_data( 127+(i*64) downto 64+(i*64) );
			--end loop;

		
		else
			if(count_out_words<4) then
				count_out_words:=count_out_words+1;
				dout_buffer_out_valid<='1';
			
				for i in 0 to 2 loop
					buffer_data( 63+(i*64) downto 0+(i*64) )<=buffer_data( 127+(i*64) downto 64+(i*64) );
			
				end loop;
			else
				dout_buffer_out_valid<='0';
				count_out_words:=0;
				mode<='0';					
			end if;
		end if;
							
		
	end if;
    end if;
  end process p_main;

din_buffer_out<=buffer_data;
dout_buffer_out<=buffer_data(63 downto 0);
din_buffer_full<=buffer_full;

end rtl;
