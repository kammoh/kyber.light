library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;

entity datapath is
	port(
		clk                      : in  std_logic;
		-- from controller
		in_do_setzero_to_mem_din : in  std_logic;
		in_do_bypass_iochipi     : in  std_logic;
		in_do_theta              : in  std_logic;
		in_do_lane0              : in  std_logic;
		in_do_odd_hword          : in  std_logic; -- when shifting in/out lane0, choose the higher half word from memory, o/w lower
		in_do_shift_en0          : in  std_logic;
		in_do_shift_en1          : in  std_logic;
		in_do_hrotate            : in  std_logic;
		in_do_vertical           : in  std_logic;
		in_do_rho_out            : in  std_logic;
		do_xorin                 : in  std_logic;
		do_data_hi               : in  std_logic; -- select high halfword of lane0 or odd bits (higher - even - lane) of lane pairs to dout
		-- from Rho ROM through controller
		in_rho0_mod              : in  unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		in_rho1_mod              : in  unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		-- from Iota ROM
		in_iota_bit              : in  std_logic;
		-- memory
		in_data_from_mem         : in  t_word;
		out_data_to_mem          : out t_word;
		-- message/digest I/O
		din                      : out std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0);
		dout                     : out std_logic_vector(C_HALFWORD_WIDTH - 1 downto 0)
	);
end entity datapath;

architecture RTL of datapath is
	---------------------------------------------------------------- Constants -------------------------------------------------------------------

	---------------------------------------------------------------- Functions/Procedures --------------------------------------------------------

	---------------------------------------------------------------- Registers/FF ----------------------------------------------------------------
	---------------------------------------------------------------- Wires -----------------------------------------------------------------------
	signal hword_in_0, hword_in_1                                      : t_half_word;
	signal mem_dout_hi, mem_dout_lo                                    : t_half_word;
	signal hword_out_0, hword_out_1                                    : t_half_word;
	signal deinterleaved_0, deinterleaved_1                            : t_half_word;
	signal interleaved_dout                                            : t_word;
	signal slice_unit_in, slice_unit_out                               : t_slice;
	signal shift_reg_slice_vertical_in0, shift_reg_slice_vertical_out0 : std_logic_vector(12 downto 0); -- 13 bits
	signal shift_reg_slice_vertical_in1, shift_reg_slice_vertical_out1 : std_logic_vector(12 downto 0); -- 13 bits

begin

	shift_reg0 : entity work.shift_reg
		port map(
			clk                => clk,
			--
			in_do_shift_en     => in_do_shift_en0,
			in_do_hrotate      => in_do_hrotate,
			in_do_vertical     => in_do_vertical,
			in_do_rho_out      => in_do_rho_out,
			--
			hword_in           => hword_in_0,
			in_rho_mod         => in_rho0_mod,
			hword_out          => hword_out_0,
			slice_vertical_in  => shift_reg_slice_vertical_in0,
			slice_vertical_out => shift_reg_slice_vertical_out0
		);

	shift_reg1 : entity work.shift_reg
		port map(
			clk                => clk,
			--
			in_do_shift_en     => in_do_shift_en1,
			in_do_hrotate      => in_do_hrotate,
			in_do_vertical     => in_do_vertical,
			in_do_rho_out      => in_do_rho_out,
			--
			hword_in           => hword_in_1,
			in_rho_mod         => in_rho1_mod,
			hword_out          => hword_out_1,
			slice_vertical_in  => shift_reg_slice_vertical_in1,
			slice_vertical_out => shift_reg_slice_vertical_out1
		);

	slice_unit0 : entity work.slice_unit
		port map(
			clk             => clk,
			slice_in        => slice_unit_in,
			slice_out       => slice_unit_out,
			bypass_iochipi  => in_do_bypass_iochipi,
			do_theta        => in_do_theta,
			round_const_bit => in_iota_bit
		);

	process(all) is
	begin
		for k in 0 to C_HALFWORD_WIDTH - 1 loop
			-- NOTE: odd lanes are stored in even bits
			deinterleaved_0(k)          <= in_data_from_mem(2 * k);
			deinterleaved_1(k)          <= in_data_from_mem(2 * k + 1);
			--
			interleaved_dout(2 * k)     <= hword_out_0(k);
			interleaved_dout(2 * k + 1) <= hword_out_1(k);
			--
		end loop;
		-- NOTE: odd lanes are shifted in shift_reg0
		--
		if in_do_odd_hword then
			-- in odd_hword line0 is read into shift_reg1
			slice_unit_in(0)                <= shift_reg_slice_vertical_out1(0);
			shift_reg_slice_vertical_in1(0) <= slice_unit_out(0);
			-- loop-back shift_reg0::slice_in/slice_out(0)
			shift_reg_slice_vertical_in0(0) <= shift_reg_slice_vertical_out0(0);
		else
			slice_unit_in(0)                <= shift_reg_slice_vertical_out0(0);
			shift_reg_slice_vertical_in0(0) <= slice_unit_out(0);
			-- loop-back shift_reg1::slice_in/slice_out(0)
			shift_reg_slice_vertical_in1(0) <= shift_reg_slice_vertical_out1(0);
		end if;
		for k in 1 to 12 loop
			slice_unit_in(2 * k - 1)        <= shift_reg_slice_vertical_out0(k);
			slice_unit_in(2 * k)            <= shift_reg_slice_vertical_out1(k);
			shift_reg_slice_vertical_in0(k) <= slice_unit_out(2 * k - 1);
			shift_reg_slice_vertical_in1(k) <= slice_unit_out(2 * k);
		end loop;
	end process;

	mem_dout_lo <= in_data_from_mem(C_HALFWORD_WIDTH - 1 downto 0);
	mem_dout_hi <= in_data_from_mem(C_WORD_WIDTH - 1 downto C_HALFWORD_WIDTH);

	hword_in_0 <= mem_dout_lo when in_do_lane0 else deinterleaved_0;
	hword_in_1 <= mem_dout_hi when in_do_lane0 else deinterleaved_1;

	out_data_to_mem <= mem_dout_hi xor din when (do_xorin and do_data_hi)
		else mem_dout_lo xor din when do_xorin
		else (others => '0') when in_do_setzero_to_mem_din
		else hword_out_1 & hword_out_0 when in_do_lane0
		else interleaved_dout;

	dout <= in_data_from_mem(C_WORD_WIDTH - 1 downto C_HALFWORD_WIDTH) when do_data_hi else in_data_from_mem(C_HALFWORD_WIDTH - 1 downto 0);

end architecture RTL;
