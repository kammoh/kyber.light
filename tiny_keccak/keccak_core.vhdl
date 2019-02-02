----------------------------------------------------------------------------------------------------------------------------------
-- @description: FIPS 202 Compliant SHA3/Keccak-f[1600] + absorb/squeeze Core TOP 
-- @details:  FIPS 202
--
-- @interface: 
--    Data I/O: valid/ready 4-bit stream
-- 
-- @assumption: i_rate is rate // 64 therefore rate is assumed to be multiple of lane width, 
--           which is the case for all SHA-3 variants
--
-- @protocol:
--    "commands": i_init, i_absorb, i_squeeze
--    1. assert any of the "commands"
--    2. keep asserted until o_done is observed
--      2.1 during squeeze a) if i_init is also asserted then the core will do state-initialization after squeeze and then assert done
--                         b) otherwise in runs permutations round (prepare for next squeeze) and then assert done
--    3. after seeing done the user must deassert all command signals
--    4. start over from step 1
--
--    rationale: The parent module already keeps track of the sequence of high-level operations ("commands") which should be performed
--
----------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_float_types.all;

library poc;
use poc.ocram.all;

use work.keccak_pkg.all;

entity keccak_core is
	port(
		clk          : in  std_logic;
		rst          : in  std_logic;
		---- input
		i_init       : in  std_logic;
		i_absorb     : in  std_logic;
		i_squeeze    : in  std_logic;
		o_done       : out std_logic;
		i_din_data   : in  std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
		i_din_valid  : in  std_logic;
		o_din_ready  : out std_logic;
		i_rate       : in  unsigned(log2ceil(C_SLICE_WIDTH) - 1 downto 0);
		---- output
		o_dout_data  : out std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
		o_dout_valid : out std_logic;
		i_dout_ready : in  std_logic
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
			din                  => i_din_data,
			dout                 => o_dout_data
		);

	state_mem : entity poc.ocram_sp
		generic map(
			DEPTH  => (25 + 1) * 64 / 8,
			D_BITS => 8
		)
		port map(
			clk      => clk,
			ce       => mem_re,
			we       => mem_we,
			in_addr  => mem_addr,
			in_data  => to_mem_din,
			out_data => from_mem_dout
		);

	controller : entity work.controller
		port map(
			clk                 => clk,
			rst                 => rst,
			-- I/O control
			i_init              => i_init,
			i_absorb            => i_absorb,
			i_squeeze           => i_squeeze,
			o_done              => o_done,
			i_din_valid         => i_din_valid,
			o_din_ready         => o_din_ready,
			o_dout_valid        => o_dout_valid,
			i_dout_ready        => i_dout_ready,
			i_rate              => i_rate,
			-- to datapath
			o_do_bypass_iochipi => bypass_iochipi,
			o_do_theta          => bypass_theta,
			o_do_rho_out        => rho_out,
			o_do_setzero_mem    => setzero_mem,
			o_do_xorin          => do_xorin,
			o_do_odd_lane       => do_odd_lane,
			--
			o_do_shift_en0      => shift_en0,
			o_do_shift_en1      => shift_en1,
			o_do_hrotate        => hrotate,
			o_do_vertical       => do_vertical,
			-- to datapath Rho muxes
			o_rho0r             => rho0_mod,
			o_rho1r             => rho1_mod,
			-- to ROMs
			o_round             => round,
			o_k                 => k,
			-- to state memory
			o_mem_addr          => mem_addr,
			o_mem_we            => mem_we,
			o_mem_ce            => mem_re
		);

	iota_lut : entity work.iota_lut
		port map(
			round    => round,
			k        => k,
			iota_bit => iota_bit
		);

end architecture RTL;
