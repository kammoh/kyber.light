-- The Keccak sponge function, designed by Guido Bertoni, Joan Daemen,
-- Micha�l Peeters and Gilles Van Assche. For more information, feedback or
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

entity keccak_copro is
	port(
		clk           : in  std_logic;
		rst_n         : in  std_logic;
		start         : in  std_logic;
		addr          : out addr_type;
		enR           : out std_logic;
		enW           : out std_logic;
		data_from_mem : in  std_logic_vector(63 downto 0);
		data_to_mem   : out std_logic_vector(63 downto 0);
		done          : out std_logic
	);

end keccak_copro;

architecture rtl of keccak_copro is

	-- components

	component pe
		port(clk                 : in  std_logic;
		     rst_n               : in  std_logic;
		     data_from_mem       : in  std_logic_vector(63 downto 0);
		     data_to_mem         : out std_logic_vector(63 downto 0);
		     command             : in  std_logic_vector(7 downto 0);
		     counter_plane_to_pe : in  integer range 0 to 4;
		     counter_sheet_to_pe : in  integer range 0 to 4;
		     nxt_round           : in std_logic;
		     init_round          : in std_logic
		    );

	end component;

	component fsm
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
			nxt_round           : out std_logic;
			init_round          : out std_logic
		);
	end component;

	-- signal declarations

	signal command                                  : std_logic_vector(7 downto 0);
	signal counter_plane_to_pe, counter_sheet_to_pe : integer range 0 to 4;
	signal nxt_round                                : std_logic;
	signal init_round                               : std_logic;

begin                                   -- Rtl

	-- port map

	pe_map : pe
		port map(
			clk                 => clk,
			rst_n               => rst_n,
			data_from_mem       => data_from_mem,
			data_to_mem         => data_to_mem,
			command             => command,
			counter_plane_to_pe => counter_plane_to_pe,
			counter_sheet_to_pe => counter_sheet_to_pe,
			nxt_round           => nxt_round,
			init_round          => init_round
		);

	fsm_map : fsm
		port map(
			clk                 => clk,
			rst_n               => rst_n,
			start               => start,
			addr                => addr,
			enR                 => enR,
			enW                 => enW,
			command_for_pe      => command,
			counter_plane_to_pe => counter_plane_to_pe,
			counter_sheet_to_pe => counter_sheet_to_pe,
			done                => done,
			nxt_round           => nxt_round,
			init_round          => init_round
		);

end rtl;
