-- The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
-- Michaï¿½l Peeters and Gilles Van Assche. For more information, feedback or
-- questions, please refer to our website: http://keccak.noekeon.org/

-- Implementation by the designers,
-- hereby denoted as "the implementer".

-- To the extent possible under law, the implementer has waived all copyright
-- and related or neighboring rights to the source code in this file.
-- http://creativecommons.org/publicdomain/zero/1.0/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.numeric_std_unsigned.all;

use work.keccak_globals.all;

entity fsm is

	port(
		clk                 : in  std_logic;
		rst_n               : in  std_logic;
		start               : in  std_logic;
		addr                : out addr_type;
		enR                 : out std_logic;
		enW                 : out std_logic;
		
		command_for_pe      : out std_logic_vector(7 downto 0);
		counter_plane_to_pe : out integer range 0 to 4;
		counter_sheet_to_pe : out integer range 0 to 4;
		done                : out std_logic;
		nxt_round : out std_logic;
		init_round : out std_logic
	);

end fsm;

architecture rtl of fsm is

	--components

	----------------------------------------------------------------------------
	-- Internal signal declarations
	----------------------------------------------------------------------------

	type fsm_st_type is (INIT,
	                     theta0, theta1, theta2, theta3, theta4, theta5, theta6, theta10, theta11, theta12, theta12bis, theta13, theta13bis, theta14,
	                     chi0, chi0bis, chi1, chi2, chi3, chi4, chi5);
	signal fsm_st : fsm_st_type;

	signal mem_addr                     : addr_type;
	signal ctr_sheet_plus_50                     : addr_type;
	signal fp1                     : addr_type;
	signal fx                     : addr_type;
	signal command                      : std_logic_vector(7 downto 0);
	signal counter_sheet, counter_plane : mod_5_type;
	signal nr_round_internal            : integer range 0 to 23;
	signal ff : mod_5_type;
	
	

	function pi(count_lane : mod_5_type; count_sheet : mod_5_type)
	return addr_type is
		variable addr_pi : addr_type;
	begin
		--addr_pi:=((10*count_lane+16*count_sheet)mod 25)+25;
		case count_sheet is
			when 0 =>
				case count_lane is
					when 0 =>
						addr_pi := 0;
					when 1 =>
						addr_pi := 10;
					when 2 =>
						addr_pi := 20;
					when 3 =>
						addr_pi := 5;
					when 4 =>
						addr_pi := 15;
				end case;

			when 1 =>
				case count_lane is
					when 0 =>
						addr_pi := 16;
					when 1 =>
						addr_pi := 1;
					when 2 =>
						addr_pi := 11;
					when 3 =>
						addr_pi := 21;
					when 4 =>
						addr_pi := 6;
				end case;
			when 2 =>
				case count_lane is
					when 0 =>
						addr_pi := 7;
					when 1 =>
						addr_pi := 17;
					when 2 =>
						addr_pi := 2;
					when 3 =>
						addr_pi := 12;
					when 4 =>
						addr_pi := 22;
				end case;
			when 3 =>
				case count_lane is
					when 0 =>
						addr_pi := 23;
					when 1 =>
						addr_pi := 8;
					when 2 =>
						addr_pi := 18;
					when 3 =>
						addr_pi := 3;
					when 4 =>
						addr_pi := 13;
				end case;
			when 4 =>
				case count_lane is
					when 0 =>
						addr_pi := 14;
					when 1 =>
						addr_pi := 24;
					when 2 =>
						addr_pi := 9;
					when 3 =>
						addr_pi := 19;
					when 4 =>
						addr_pi := 4;
				end case;
		end case;
		return addr_pi + 25;
	end pi;

	-- functions for implementing the mod 5
	function f_mod5_m1(counter_sheet : mod_5_type)
	return mod_5_type is
		variable counter_sheet_mod5_m1 : mod_5_type;
	begin
		case counter_sheet is
			when 0 =>
				counter_sheet_mod5_m1 := 4;
			when 1 =>
				counter_sheet_mod5_m1 := 0;
			when 2 =>
				counter_sheet_mod5_m1 := 1;
			when 3 =>
				counter_sheet_mod5_m1 := 2;
			when 4 =>
				counter_sheet_mod5_m1 := 3;
		end case;
		return counter_sheet_mod5_m1;
	end f_mod5_m1;

	function f_mod5_p1(counter_sheet : mod_5_type)
	return mod_5_type is
		variable counter_sheet_mod5_p1 : mod_5_type;
	begin
		case counter_sheet is
			when 0 =>
				counter_sheet_mod5_p1 := 1;
			when 1 =>
				counter_sheet_mod5_p1 := 2;
			when 2 =>
				counter_sheet_mod5_p1 := 3;
			when 3 =>
				counter_sheet_mod5_p1 := 4;
			when 4 =>
				counter_sheet_mod5_p1 := 0;
		end case;
		return counter_sheet_mod5_p1;
	end f_mod5_p1;

	function f_mod5_p2(counter_sheet : mod_5_type)
	return mod_5_type is
		variable counter_sheet_mod5_p2 : mod_5_type;
	begin
		case counter_sheet is
			when 0 =>
				counter_sheet_mod5_p2 := 2;
			when 1 =>
				counter_sheet_mod5_p2 := 3;
			when 2 =>
				counter_sheet_mod5_p2 := 4;
			when 3 =>
				counter_sheet_mod5_p2 := 0;
			when 4 =>
				counter_sheet_mod5_p2 := 1;
		end case;
		return counter_sheet_mod5_p2;
	end f_mod5_p2;

	function f_mod5_p3(counter_sheet : mod_5_type)
	return mod_5_type is
		variable counter_sheet_mod5_p3 : mod_5_type;
	begin
		case counter_sheet is
			when 0 =>
				counter_sheet_mod5_p3 := 3;
			when 1 =>
				counter_sheet_mod5_p3 := 4;
			when 2 =>
				counter_sheet_mod5_p3 := 0;
			when 3 =>
				counter_sheet_mod5_p3 := 1;
			when 4 =>
				counter_sheet_mod5_p3 := 2;
		end case;
		return counter_sheet_mod5_p3;
	end f_mod5_p3;

begin                                   -- Rtl
	ff <= 25 + 5 * counter_plane + f_mod5_p3(counter_sheet);
	fx <= counter_sheet + 5 * counter_plane;
	fp1 <= f_mod5_p1(counter_sheet);
	-- finite state machine
    nxt_round <= '1' when  fsm_st = chi5 and counter_plane = 4 and counter_sheet = 4 else '0';
    init_round <= '1' when fsm_st = INIT else '0';
    
	p_main : process(clk, rst_n)
	begin                               -- process p_main
		if rst_n = '0' then             -- asynchronous rst_n (active low)

			fsm_st            <= INIT;
			nr_round_internal <= 0;
			mem_addr          <= 0;
			command           <= "00000000";
			done              <= '0';

		elsif rising_edge(clk) then -- rising clk edge
			case fsm_st is
				when INIT =>
					done    <= '0';
					command <= "00000000";
					enR     <= '0';
					enW     <= '0';
					if start = '1' then
						fsm_st            <= theta0;
						nr_round_internal <= 0;
						--fix this, it is just ofr debugging
						mem_addr          <= 0;
						enR               <= '1';
						enW               <= '0';
						counter_sheet     <= 0;
						counter_plane     <= 0;
						command           <= "00000001";
					end if;
				-- compute sum of sheet			
				when theta0 =>
					fsm_st        <= theta1;
					--mem_addr<=0;
					mem_addr      <= fx;
					counter_plane <= counter_plane + 1;
					command       <= "00000000";
					enR           <= '1';
					enW           <= '0';
				when theta1 =>

					mem_addr      <= fx;
					counter_plane <= counter_plane + 1;
					command       <= "00000001";
					fsm_st        <= theta2;
				when theta2 =>
					mem_addr      <= fx;
					counter_plane <= counter_plane + 1;
					command       <= "00000010";
					fsm_st        <= theta3;
				when theta3 =>
					mem_addr      <= fx;
					counter_plane <= counter_plane + 1;
					command       <= "00000010";
					fsm_st        <= theta4;
				when theta4 =>
					mem_addr <= fx;
					command  <= "00000010";
					fsm_st   <= theta5;
				when theta5 =>
					enR     <= '0';
					command <= "00000010";
					fsm_st  <= theta6;
				when theta6 =>
					enW           <= '1';
					enR           <= '0';
					mem_addr      <= ctr_sheet_plus_50;
					command       <= "00010000";
					counter_plane <= 0;
					if (counter_sheet = 4) then
						fsm_st        <= theta10;
						counter_sheet <= 0;
					else
						counter_sheet <= counter_sheet + 1;
						fsm_st        <= theta0;
					end if;
				-- compute the second part of theta and pi rho as well
				when theta10 =>
					enW <= '0';
					enR <= '1';
					if (counter_plane = 4) then
						mem_addr      <= ctr_sheet_plus_50;
						counter_sheet <= counter_sheet + 1;
					else
						--mem_addr<=50+((5+counter_sheet-1) mod 5);
						mem_addr <= 50 + f_mod5_m1(counter_sheet);
					end if;

					fsm_st  <= theta11;
					command <= "00000001";
				when theta11 =>
					enR      <= '1';
					--mem_addr<=50+((5+counter_sheet+1) mod 5);
					mem_addr <= 50 + fp1;
					fsm_st   <= theta12;
					command  <= "00001001";
				when theta12 =>
					enW           <= '0';
					enR           <= '1';
					mem_addr      <= counter_sheet;
					counter_plane <= 0;
					fsm_st        <= theta12bis;
					command       <= "00001001";
				when theta12bis =>
					--bubble for let sum of sheet enter in r2 and r3
					command <= "00001100";
					fsm_st  <= theta13;
				when theta13 =>
					--bubble before writing
					enW      <= '0';
					enR      <= '0';
					--mem_addr<=mem_addr+25;
					mem_addr <= pi(counter_sheet, counter_plane);
					command  <= "00000100";
					fsm_st   <= theta13bis;
				when theta13bis =>

					enW     <= '1';
					enR     <= '0';
					command <= "00100000";

					if counter_plane = 4 then
						if counter_sheet = 4 then
							fsm_st <= chi0;

						else
							fsm_st <= theta10;
						end if;
					else

						fsm_st <= theta14;

					end if;

				when theta14 =>
					enW           <= '0';
					enR           <= '1';
					mem_addr      <= counter_sheet + 5 * (counter_plane + 1);
					counter_plane <= counter_plane + 1;

					command <= "00000100";
					fsm_st  <= theta13;

				-- chi computation and iota when needed
				when chi0 =>
					enW           <= '0';
					enR           <= '1';
					counter_plane <= 0;
					counter_sheet <= 0;
					mem_addr      <= 25;
					fsm_st        <= chi1;
					command       <= "00000000";
				when chi0bis =>
					enW <= '0';
					enR <= '1';

					mem_addr <= 25 + 5 * counter_plane + counter_sheet;
					fsm_st   <= chi1;
					command  <= "00000000";
				when chi1 =>
					--mem_addr<=25+5*counter_plane+((counter_sheet+1)mod 5);
					mem_addr <= 25 + 5 * counter_plane + fp1;
					command  <= "00000001";
					fsm_st   <= chi2;
				when chi2 =>
					enR      <= '1';
					enW      <= '0';
					--mem_addr<=25+5*counter_plane+((counter_sheet+2)mod 5);
					mem_addr <= 25 + 5 * counter_plane + f_mod5_p2(counter_sheet);
					fsm_st   <= chi3;
					command  <= "00001001";
				when chi3 =>
					--bubble
					enR     <= '0';
					command <= "00001001";
					fsm_st  <= chi4;
				when chi4 =>
					enW      <= '1';
					mem_addr <= 5 * counter_plane + counter_sheet;
					if (counter_sheet = 0 and counter_plane = 0) then
						command <= "10000000";
					else
						command <= "01000000";
					end if;
					fsm_st   <= chi5;
				when chi5 =>
	
					command <= "00000000";
					if (counter_sheet = 4) then
						if (counter_plane = 4) then
							enR           <= '0';
							enW           <= '0';
							counter_sheet <= 0;
							counter_plane <= 0;
							if nr_round_internal = 23 then
								fsm_st <= INIT;
								done   <= '1';
							else
								nr_round_internal <= nr_round_internal + 1;
								fsm_st            <= theta0;
							end if;
						else
							enR           <= '1';
							enW           <= '0';
							counter_plane <= counter_plane + 1;
							counter_sheet <= 0;
							fsm_st        <= chi0bis;
							--mem_addr<=25+5*counter_plane+((counter_sheet+3)mod 5);
							mem_addr      <= ff;
						end if;
					else
						enR           <= '1';
						enW           <= '0';
						counter_sheet <= counter_sheet + 1;
						fsm_st        <= chi3;
						--mem_addr<=25+5*counter_plane+((counter_sheet+3)mod 5);
						mem_addr      <= ff;
					end if;

			end case;

		end if;
	end process p_main;
	command_for_pe <= command;
	addr           <= mem_addr;

	counter_plane_to_pe <= counter_plane;
	counter_sheet_to_pe <= counter_sheet;

end rtl;
