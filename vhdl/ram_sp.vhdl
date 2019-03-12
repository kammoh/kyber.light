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
--  unit name: full name (shortname / entity name)
--              
--! @file      sam_sp.vhdl
--
--! @brief     Single-port on-chip SRAM
--
--! @author    <Kamyar Mohajerani (kamyar@ieee.org)>
--
--! @company   Cryptographic Engineering Research Group, George Mason University
--
--! @project   KyberLight: Lightweight hardware implementation of CRYSTALS-KYBER PQC
--
--! @context   Post-Quantum Cryptography
--
--! @license   MIT
--
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--  
--! @date      <03/10/2019>
--
--! @version   <v0.1>
--
--! @details   Inferred as Block RAM by Vivado when TECHNOLOGY=XILINX,
--!                in SAED32 used SRAMxxx.vhdl for simulation and block libs in synthesis
--!
--
--
--! <b>Dependencies:</b>\n
--! <Entity Name,...>
--!
--! <b>References:</b>\n
--! <reference one> \n
--! <reference two>
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

entity ocram_sp is
	generic(
		WORD_BITS : positive;           -- number of data bits
		DEPTH     : positive            -- number of words in the array
	);
	port(
		clk      : in  std_logic;
		ce       : in  std_logic;       -- clock enable
		we       : in  std_logic;       -- write enable
		in_addr  : in  unsigned(log2ceilnz(DEPTH) - 1 downto 0); -- address
		in_data  : in  std_logic_vector(WORD_BITS - 1 downto 0); -- write data
		out_data : out std_logic_vector(WORD_BITS - 1 downto 0) -- read output
	);

	attribute DONT_TOUCH_NETWORK of clk, we, ce, in_addr, in_data : signal is True;
	attribute DONT_TOUCH of clk, we, ce, in_addr, in_data, out_data : signal is True;
end entity;

architecture rtl of ocram_sp is
	impure function get_saed_block_size return natural is
	begin
		if DEPTH >= SAED32_SRAM_WC_L then
			return SAED32_SRAM_WC_L;
		elsif DEPTH >= SAED32_SRAM_WC_M then
			return SAED32_SRAM_WC_M;
		else
			return SAED32_SRAM_WC_S;
		end if;
	end function;
	constant C_BLOCK_SIZE                              : positive := get_saed_block_size;
	constant C_NUM_BLOCKS                              : positive := ceil_div(DEPTH, C_BLOCK_SIZE);
	signal WEB_array, OEB_array, CSB_array, selb_array : std_logic_vector(0 to C_NUM_BLOCKS - 1);
	signal block_address                               : std_logic_vector(log2ceilnz(C_BLOCK_SIZE) - 1 downto 0);
begin

	gen_xilinx : if (TECHNOLOGY = XILINX) generate
		subtype word_t is std_logic_vector(WORD_BITS - 1 downto 0);
		type ram_t is array (0 to DEPTH - 1) of word_t;

		signal ram : ram_t;

	begin
		-- Xilinx Single-Port Block RAM No-Change Mode
		process(clk)
		begin
			if rising_edge(clk) then
				if ce = '1' then
					if we = '1' then
						ram(to_integer(unsigned(in_addr))) <= in_data;
					else
						out_data <= ram(to_integer(unsigned(in_addr)));
					end if;
				end if;
			end if;
		end process;
	end generate gen_xilinx;

	gen_saed32 : if (TECHNOLOGY = SAED32) generate
		-- TODO generate optimum covering using different block size
		-- TODO current implementation is only for special case used in KyberLight 1.x implementation
		-- SAED32 Memory Compiler Block RAM
		gen_saed32_banks : for i in 0 to C_NUM_BLOCKS - 1 generate
			assert WORD_BITS = 8 or WORD_BITS = 13 severity failure; -- NOTE: Add all available widths here!  
			--

			gen_8bit : if WORD_BITS = 8 generate

				gen_blk128 : if C_BLOCK_SIZE = 128 generate
					SRAM128x8sp_inst : entity work.SRAM128x8sp -- SAED32_SRAM_WC = 128
						port map(
							A   => block_address, -- input address
							O   => out_data, -- output data
							I   => in_data, -- input data
							WEB => WEB_array(i), -- write enable, active-low
							CSB => CSB_array(i), -- chip select, active-low
							OEB => OEB_array(i), -- output enable, active-low
							CE  => clk  -- clock
						);
				end generate gen_blk128;

				gen_blk32 : if C_BLOCK_SIZE = 32 generate
					SRAM32x8sp_inst : entity work.SRAM32x8sp -- WC = 32
						port map(
							A   => block_address, -- input address
							O   => out_data, -- output data
							I   => in_data, -- input data
							WEB => WEB_array(i), -- write enable, active-low
							CSB => CSB_array(i), -- chip select, active-low
							OEB => OEB_array(i), -- output enable, active-low
							CE  => clk  -- clock
						);
				end generate gen_blk32;

			end generate gen_8bit;

			gen_13bit : if WORD_BITS = 13 generate

				gen_blk128 : if C_BLOCK_SIZE = 128 generate
					SRAM128x13sp_inst : entity work.SRAM128x13sp -- WC = 128
						port map(
							A   => block_address,
							O   => out_data,
							I   => in_data,
							WEB => WEB_array(i),
							CSB => CSB_array(i),
							OEB => OEB_array(i),
							CE  => clk
						);
				end generate gen_blk128;

				gen_blk32 : if C_BLOCK_SIZE = 32 generate
					SRAM128x13sp_inst : entity work.SRAM32x13sp -- WC = 32
						port map(
							A   => block_address,
							O   => out_data,
							I   => in_data,
							WEB => WEB_array(i),
							CSB => CSB_array(i),
							OEB => OEB_array(i),
							CE  => clk
						);
				end generate gen_blk32;

			end generate gen_13bit;
			--
			-- Control signals
			CSB_array(i) <= not ce or selb_array(i);
			WEB_array(i) <= not we or selb_array(i);

			--
		end generate gen_saed32_banks;
		gen_ctrl : if DEPTH > C_BLOCK_SIZE generate
			--			assert False report "in_addr'length=" &  to_string(in_addr'length) &" log2ceilnz(C_BLOCK_SIZE)="& to_string(log2ceilnz(C_BLOCK_SIZE)) & " selb_array'length="& to_string(selb_array'length) severity error;
			selb_array <= not decode(in_addr(in_addr'length - 1 downto log2ceilnz(C_BLOCK_SIZE)), selb_array'length);
		end generate gen_ctrl;
		gen_ctrl_lt : if DEPTH <= C_BLOCK_SIZE generate
			selb_array(0) <= '0';
		end generate gen_ctrl_lt;

		-- 
		reg_oeb_proc : process(clk)
		begin
			if rising_edge(clk) then
				if ce = '1' then
					OEB_array <= selb_array;
				end if;
			end if;
		end process;

		--

		block_address <= std_logic_vector(in_addr(log2ceilnz(C_BLOCK_SIZE) - 1 downto 0));
		-- output Mux
	end generate gen_saed32;

end architecture;
