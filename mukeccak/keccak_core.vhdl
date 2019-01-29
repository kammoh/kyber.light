library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_float_types.all;

library poc;
use poc.ocram.all;

use work.keccak_pkg.all;

-- Protocol : 
-- Absorb while dout_ready = '0' 
--    when possible, din_ready -> '1' and get bytes when din_valid
-- After dout_ready = '1':
-- Squeeze while din_valid = '1'

entity keccak_core is
	port(
		clk        : in  std_logic;
		rst        : in  std_logic;
		---- input
		squeeze    : in  std_logic;
		absorb     : in  std_logic;
		done       : out std_logic;
		din_data        : in  std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
		din_valid  : in  std_logic;
		din_ready  : out std_logic;
		rate       : in  unsigned(log2ceil(C_SLICE_WIDTH) - 1 downto 0);
		---- output
		dout_data       : out std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
		dout_valid : out std_logic;
		dout_ready : in  std_logic
	);
end entity keccak_core;

architecture RTL of keccak_core is
	signal round          : unsigned(log2ceil(C_NUM_ROUNDS + 1 - 1) - 1 downto 0);
	signal iota_bit       : std_logic;
	signal bypass_iochipi : std_logic;
	signal bypass_theta   : std_logic;
	signal do_vertical    : std_logic;
	signal hrotate        : std_logic;
	signal shift_en0      : std_logic;
	signal shift_en1      : std_logic;
	signal setzero_mem    : std_logic;
	signal do_xorin       : std_logic;
	signal k              : unsigned(log2ceil(C_LANE_WIDTH) - 1 downto 0);
	signal rho0_mod       : unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
	signal rho1_mod       : unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
	signal from_mem_dout  : t_word;
	signal to_mem_din     : t_word;
	signal mem_addr       : unsigned(log2ceil(C_NUM_MEM_WORDS) - 1 downto 0);
	signal mem_we         : std_logic;
	signal mem_re         : std_logic;
	signal rho_out        : std_logic;
	signal do_odd_lane    : std_logic;
	---------------------------------------------------------------- Constants -------------------------------------------------------------------

	---------------------------------------------------------------- Functions/Procedures --------------------------------------------------------

	---------------------------------------------------------------- Registers/FF ----------------------------------------------------------------
	---------------------------------------------------------------- Wires -----------------------------------------------------------------------

begin

	datapath : entity work.datapath
		port map(
			clk                  => clk,
			--		-- memory
			--		in_data_from_mem         : in  t_word;
			--		out_data_to_mem          : out t_word
			--
			in_do_xorin          => do_xorin,
			in_do_odd_lane       => do_odd_lane,
			in_do_setzero_mem    => setzero_mem,
			in_do_bypass_iochipi => bypass_iochipi,
			in_do_theta          => bypass_theta,
			in_do_shift_en0      => shift_en0,
			in_do_shift_en1      => shift_en1,
			in_do_hrotate        => hrotate,
			in_do_vertical       => do_vertical,
			in_do_rho_out        => rho_out,
			--
			in_rho0_mod          => rho0_mod,
			in_rho1_mod          => rho1_mod,
			--
			in_iota_bit          => iota_bit,
			--
			in_data_from_mem     => from_mem_dout,
			out_data_to_mem      => to_mem_din,
			--
			din                  => din_data,
			dout                 => dout_data
		);

	state_mem : entity poc.ocram_sp
		generic map(
			A_BITS => log2ceil((25 * 64) / 8),
			D_BITS => 8
		)
		port map(
			clk => clk,
			ce  => mem_re,
			we  => mem_we,
			in_addr   => mem_addr,
			in_data   => to_mem_din,
			out_data   => from_mem_dout
		);

	controller : entity work.controller
		port map(
			clk                   => clk,
			rst                   => rst,
			-- I/O control
			absorb                => absorb,
			squeeze               => squeeze,
			done                  => done,
			din_valid             => din_valid,
			din_ready             => din_ready,
			dout_valid            => dout_valid,
			dout_ready            => dout_ready,
			rate                  => rate,
			-- to datapath
			out_do_bypass_iochipi => bypass_iochipi,
			out_do_theta          => bypass_theta,
			out_do_rho_out        => rho_out,
			out_do_setzero_mem    => setzero_mem,
			out_do_xorin          => do_xorin,
			out_do_odd_lane       => do_odd_lane,
			--
			out_do_shift_en0      => shift_en0,
			out_do_shift_en1      => shift_en1,
			out_do_hrotate        => hrotate,
			out_do_vertical       => do_vertical,
			-- to datapath Rho muxes
			rho0r                 => rho0_mod,
			rho1r                 => rho1_mod,
			-- to ROMs
			round                 => round,
			k                     => k,
			-- to state memory
			mem_addr              => mem_addr,
			mem_we                => mem_we,
			mem_ce                => mem_re
		);

	iota_lut : entity work.iota_lut
		port map(
			round    => round,
			k        => k,
			iota_bit => iota_bit
		);

end architecture RTL;
