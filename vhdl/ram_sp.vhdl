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
--! @license   AGPL-3.0-or-later
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

	--	attribute DONT_TOUCH_NETWORK of clk, we, ce, in_addr, in_data : signal is True;
	--	attribute DONT_TOUCH of clk, we, ce, in_addr, in_data, out_data : signal is True;
end entity;

architecture rtl of ocram_sp is
	--
	-- very simple for this project
	function C_BLOCK_SIZE return natural is
	begin
		return 2**log2ceilnz(maximum(minimum(DEPTH, 1024), 64)); -- No SRAM1RW32x8 !!! :/
	end function;
	--
	constant C_BLOCK_WORD_BITS                         : positive := 8;
	constant C_ROWS                                    : positive := ceil_div(DEPTH, C_BLOCK_SIZE);
	constant C_COLS                                    : positive := ceil_div(WORD_BITS, C_BLOCK_WORD_BITS);
	signal WEB_array, OEB_array, CSB_array, selb_array : std_logic_vector(0 to C_ROWS - 1);
	signal addr_array                                  : std_logic_vector(log2ceilnz(C_BLOCK_SIZE) - 1 downto 0);
	type T_dataio_array is array (0 to (C_ROWS * C_COLS) - 1) of std_logic_vector(C_BLOCK_WORD_BITS - 1 downto 0);
	signal din_array                                   : T_dataio_array;
	signal dout_array                                  : T_dataio_array;
	---

	component SRAM1RW1024x8
		port(
			A   : in  std_logic_vector(9 downto 0);
			O   : out std_logic_vector(7 downto 0);
			I   : in  std_logic_vector(7 downto 0);
			WEB : in  std_logic;
			CSB : in  std_logic;
			OEB : in  std_logic;
			CE  : in  std_logic
		);
	end component SRAM1RW1024x8;

	component SRAM1RW256x8
		port(
			A   : in  std_logic_vector(7 downto 0);
			O   : out std_logic_vector(7 downto 0);
			I   : in  std_logic_vector(7 downto 0);
			WEB : in  std_logic;
			CSB : in  std_logic;
			OEB : in  std_logic;
			CE  : in  std_logic
		);
	end component SRAM1RW256x8;

	component SRAM1RW64x8
		port(
			A   : in  std_logic_vector(5 downto 0);
			O   : out std_logic_vector(7 downto 0);
			I   : in  std_logic_vector(7 downto 0);
			WEB : in  std_logic;
			CSB : in  std_logic;
			OEB : in  std_logic;
			CE  : in  std_logic
		);
	end component SRAM1RW64x8;

begin

	gen_xilinx : if (P_TECHNOLOGY = XILINX) generate
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

	gen_saed32 : if (P_TECHNOLOGY = SAED32) generate
		-- TODO generate optimum covering using different block size
		-- TODO current implementation is only for special case used in KyberLight 1.x implementation
		-- SAED32 Memory Compiler Block RAM
		
		addr_array <= std_logic_vector(resize(in_addr(minimum(in_addr'length, log2ceilnz(C_BLOCK_SIZE)) - 1 downto 0), addr_array'length));
		
		gen_sram_banks : for i in 0 to C_ROWS - 1 generate
			--
			gen_8bit : for j in 0 to C_COLS - 1 generate
				--
				din_array(i * C_COLS + j) <= std_logic_vector(resize(unsigned(in_data(minimum(WORD_BITS, (j + 1) * C_BLOCK_WORD_BITS) - 1 downto j * C_BLOCK_WORD_BITS)), C_BLOCK_WORD_BITS));

				out_data(minimum(WORD_BITS, (j + 1) * C_BLOCK_WORD_BITS) - 1 downto j * C_BLOCK_WORD_BITS) <= dout_array(i * C_COLS + j)(minimum(WORD_BITS, (j + 1) * C_BLOCK_WORD_BITS) - (j * C_BLOCK_WORD_BITS) - 1 downto 0);

								--
				gen_blk1024 : if C_BLOCK_SIZE = 1024 generate
					SRAM1RW1024x8_inst : SRAM1RW1024x8
						port map(
							A   => addr_array, -- input address
							O   => dout_array(i * C_COLS + j),
							I   => din_array(i * C_COLS + j),
							WEB => WEB_array(i), -- write enable, active-low
							CSB => CSB_array(i), -- chip select, active-low
							OEB => OEB_array(i), -- output enable, active-low
							CE  => clk  -- clock
						);
				end generate gen_blk1024;

				gen_blk256 : if C_BLOCK_SIZE = 256 generate
					SRAM1RW256x8_inst : SRAM1RW256x8
						port map(
							A   => addr_array, -- input address
							O   => dout_array(i * C_COLS + j), -- output data
							I   => din_array(i * C_COLS + j),
							WEB => WEB_array(i), -- write enable, active-low
							CSB => CSB_array(i), -- chip select, active-low
							OEB => OEB_array(i), -- output enable, active-low
							CE  => clk  -- clock
						);
				end generate gen_blk256;

				gen_blk32 : if C_BLOCK_SIZE = 64 generate
					SRAM1RW64x8_inst : SRAM1RW64x8
						port map(
							A   => addr_array, -- input address
							O   => dout_array(i * C_COLS + j), -- output data
							I   => din_array(i * C_COLS + j),
							WEB => WEB_array(i), -- write enable, active-low
							CSB => CSB_array(i), -- chip select, active-low
							OEB => OEB_array(i), -- output enable, active-low
							CE  => clk  -- clock
						);
				end generate gen_blk32;

			end generate gen_8bit;

			--
			-- Control signals
			CSB_array(i) <= not ce or selb_array(i);
			WEB_array(i) <= not we or selb_array(i);

			--
		end generate gen_sram_banks;
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
	end generate gen_saed32;

end architecture;
