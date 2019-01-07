library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.kyber_pkg.all;

use ieee.numeric_std_unsigned.all;

entity barret_reduce is
	generic(
		G_MOD       : positive := KYBER_Q;
		G_IN_WIDTH  : positive := 27;
		G_OUT_WIDTH : positive := log2ceilnz(G_MOD) -- 13
	);
	port(
		a : in  std_logic_vector(G_IN_WIDTH - 1 downto 0);
		r : out std_logic_vector(G_OUT_WIDTH - 1 downto 0)
	);
end entity barret_reduce;

architecture rtl of barret_reduce is
	constant MOD_BITS : positive := log2ceilnz(G_MOD);
	constant CC       : positive := (2**G_IN_WIDTH) / KYBER_Q;
	--	constant C        : unsigned(G_IN_WIDTH - MOD_BITS downto 0) := to_unsigned((2**G_IN_WIDTH) / KYBER_Q, G_IN_WIDTH - MOD_BITS + 1);

	signal cm0_in   : std_logic_vector(G_IN_WIDTH - MOD_BITS downto 0);
	signal cm0_out  : std_logic_vector(G_IN_WIDTH - MOD_BITS + log2ceil(CC) downto 0);
	signal cm1_out  : std_logic_vector(2 * MOD_BITS + 1 downto 0);
	signal quotient : std_logic_vector(MOD_BITS + 1 downto 0);
	signal product  : unsigned(MOD_BITS + 1 downto 0);
	--	attribute mult_style : string;
	--	attribute mult_style of cm0_out : signal is "kcm"; --"{auto|block|pipe_block|kcm|csd|lut|pipe_lut}";
	--	attribute mult_style of cm1_out : signal is "csd";
	signal y0       : unsigned(MOD_BITS + 1 downto 0);
	signal y1       : unsigned(MOD_BITS + 2 downto 0);
	signal y2       : unsigned(MOD_BITS + 2 downto 0);
	signal y        : unsigned(G_OUT_WIDTH - 1 downto 0);
	function pair(a, b : integer) return unsigned is
	begin
		return to_unsigned(a, 32) & to_unsigned(b, 32);
	end function;

begin

	cm0_in <= a(G_IN_WIDTH - 1 downto MOD_BITS - 1);

	quotient <= resize(cm0_out(minimum(cm0_out'length - 1, G_IN_WIDTH + 2) downto G_IN_WIDTH - MOD_BITS + 1), quotient'length);

	generate_const_mults : if pair(G_IN_WIDTH, G_OUT_WIDTH) = pair(26, 13) generate
		cm0_8736_15 : entity work.ConstMult_8736_14
			port map(
				X => cm0_in,
				R => cm0_out
			);
		cm1_7681_14 : entity work.ConstMult_7681_15 -- KYBER_Q, 
			port map(
				X => quotient,
				R => cm1_out
			);
	elsif pair(G_IN_WIDTH, G_OUT_WIDTH) = pair(27, 31) generate
		cm0_17473_15 : entity work.ConstMult_17473_15
			port map(
				X => cm0_in,
				R => cm0_out
			);
		cm1_7681_15 : entity work.ConstMult_7681_15 -- KYBER_Q, 
			port map(
				X => quotient,
				R => cm1_out
			);
	else generate
		assert false Report "No optimized constant multipliers for parameters G_IN_WIDTH=" & to_string(G_IN_WIDTH) &
				   " G_OUT_WIDTH=" & to_string(G_OUT_WIDTH) &
					" Using unoptimized implementation" severity warning;
		cm0_out <= std_logic_vector(resize(unsigned(cm0_in) * CC, cm0_out'length));
		--				cm0_out <= std_logic_vector(resize( unsigned(cm0_in) * CC, cm0_out'length));
		cm1_out <= std_logic_vector(resize(unsigned(quotient) * KYBER_Q, cm1_out'length));

	end generate;

	product <= unsigned(cm1_out(MOD_BITS + 1 downto 0));

	y0 <= unsigned(a(MOD_BITS + 1 downto 0)) - product;

	generate_finalize : if G_OUT_WIDTH = MOD_BITS generate
		y1 <= ('0' & y0) - KYBER_Q;
		y2 <= ('0' & y0) - (2 * KYBER_Q);
		--	y1 <= ('0' & y0) - M;
		--	y2 <= ('0' & y0) - (M & '0');
		--
		y  <= y0(G_OUT_WIDTH - 1 downto 0) when ?? y1(y1'left)
			else y1(G_OUT_WIDTH - 1 downto 0) when ?? y2(y1'left)
			else y2(G_OUT_WIDTH - 1 downto 0);
		--
		r  <= std_logic_vector(y);
	else generate
		r <= std_logic_vector(y0(G_OUT_WIDTH - 1 downto 0));
	end generate generate_finalize;

end rtl;
