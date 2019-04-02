--===================================================================================================================--
-----------------------------------------------------------------------------------------------------------------------
--                                  
--                                  
--                                    8"""""o   8"""""   8""""o    8"""""o 
--                                    8     "   8        8    8    8     " 
--                                    8e        8eeeee   8eeee8o   8o     
--                                    88        88       88    8   88   ee 
--                                    88    e   88       88    8   88    8 
--                                    68eeee9   888eee   88    8   888eee8 
--                                  
--                                  
--                                  Cryptographic Engineering Research Group
--                                          George Mason University
--                                       https://cryptography.gmu.edu/
--                                  
--                                  
-----------------------------------------------------------------------------------------------------------------------
--
--  unit name: divider
--              
--! @file      divider.vhdl
--
--! @brief     divide and remainder on KYBER_Q
--
--! @author    <Kamyar Mohajerani (kamyar@ieee.org)>
--
--! @company   Cryptographic Engineering Research Group, George Mason University
--
--! @project   KyberLight: Lightweight hardware implementation of CRYSTALS-KYBER PQC
--
--! @context   Post-Quantum Cryptography
--
--! @license   
--
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--  
--! @date      <02/01/2019>
--
--! @version   <v0.1>
--
--! @details     - modular reduction mod KYBER_Q = 7681 based on [1], also gives division which is used in compression
--!              - streaming pipeline design, WITH back pressure for retaining valid data
--!              -  "valid" flag travels down with data, stall if the out-going data is valid and the sink is not ready
--!              - shared between polyvec_mac and compressor, arbitrated at top module
--!              - smaller footprint than Barret reduction (TODO: numbers?)
--!              - using 3 adders (14, 18, add by 1), 3 subtraction (13, 13 by constant, 4), 1x13-bit <= comparator, 
--!                         and 2x13 2:1 muxes
--!
--
--
--! <b>Dependencies:</b>\n
--!   kyber_pkg
--!
--! <b>References:</b>\n
--!       [1] Moller and Granlund, "Improved Division by Invariant Integers," IEEE Transactions on Computers, 2011
--!
-- 
--!
--! <b>Modified by:</b>\n
--! Author: Kamyar Mohajerani
-----------------------------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! <date> KM: <log>\n
--! <extended description>
-----------------------------------------------------------------------------------------------------------------------
--! @todo <next thing to do> \n
--
-----------------------------------------------------------------------------------------------------------------------
--===================================================================================================================--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity divider is
	generic(
		G_IN_WIDTH : positive := 25     -- <= 26 bits, while i_u = <u1,u0> u0,u1 < 2^13 , u1 < KYBER_Q
	);
	port(
		clk               : in  std_logic;
		rst               : in  std_logic;
		--
		i_uin_data        : in  unsigned(G_IN_WIDTH - 1 downto 0);
		i_uin_valid       : in  std_logic;
		o_uin_ready       : out std_logic;
		--
		o_remout_data     : out T_coef_us;
		o_divout_data     : out T_coef_us;
		o_remdivout_valid : out std_logic;
		i_remdivout_ready : in  std_logic
	);
end entity divider;

architecture RTL of divider is
	signal u0, u1                         : T_coef_us;
	signal u1_times_v                     : unsigned(17 downto 0); -- u1 * v,  23 bits >= (G_IN_WIDTH -13) + 10
	signal q                              : unsigned(25 downto 0); -- q = u1 * v + u , G_IN_WIDTH
	signal q0, q1, q1_times_d             : T_coef_us;
	signal r0, r0_minus_d                 : T_coef_us;
	signal adjust                         : boolean;
	-- pipeline registers
	signal r0_reg, q0_reg, q1_reg, u0_reg : T_coef_us;
	signal divout_data, remout_reg        : T_coef_us;
	--
	-- reg 0: input, reg G_PIPELINE_LEVELS - 1: output
	signal valid_pipe                     : std_logic_vector(C_DIVIDER_PIPELINE_LEVELS - 1 downto 0);
	signal q_reg                          : unsigned(25 downto 0);
	-- wires
	signal stall                          : boolean;

begin
	-- i_u = <u1,u0>
	u0 <= i_uin_data(12 downto 0);
	u1 <= resize(i_uin_data(G_IN_WIDTH - 1 downto 13), 13);

	-- v (reciprocal of 7681) = 544 = 2^9 + 2^5 (10 bit)
	u1_times_v <= ((17 downto 13 => '0') & u1(12 downto 4) + u1(12 downto 0)) & u1(3 downto 0);
	-- q = u1 * v + u
	q          <= ((u1 & u0(12 downto 5)) + u1_times_v) & u0(4 downto 0);
	-- q = <q1, q0>
	q0         <= q_reg(12 downto 0);
	q1         <= q_reg(25 downto 13);

	-- d = KYBER_Q = 2^13 - 2^9 + 1 
	q1_times_d <= (q1(12 downto 9) - q1(3 downto 0)) & q1(8 downto 0);

	-- choice of remainder
	r0 <= u0_reg - q1_times_d;

	-- correction
	r0_minus_d <= r0_reg - KYBER_Q;
	adjust     <= (r0_minus_d <= q0_reg);

	pipe_reg_proc : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				valid_pipe <= (others => '0');
			else
				if not stall then
					valid_pipe <= shift_in_left(valid_pipe, i_uin_valid);
					r0_reg     <= r0;
					q0_reg     <= q0;
					q1_reg     <= q1;
					q_reg      <= q;
					u0_reg     <= u0;

					if adjust then
						remout_reg <= r0_minus_d;
						divout_data <= q1_reg + 1;
					else
						remout_reg <= r0_reg;
						divout_data <= q1_reg;
					end if;

				end if;
			end if;
		end if;
	end process pipe_reg_proc;

	-- out ports
	o_divout_data     <= divout_data;
	o_remout_data     <= remout_reg;
	o_remdivout_valid <= msb(valid_pipe);

	stall <= msb(valid_pipe) = '1' and i_remdivout_ready = '0';

	o_uin_ready <= '0' when stall else '1';

end architecture RTL;
