library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.kyber_pkg.all;

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
	constant XXX : positive := G_OUT_WIDTH+8;
	constant CM0_IN_W  : positive := G_IN_WIDTH - G_OUT_WIDTH + 1;
	constant S_W       : positive := log2ceilnz(((2**XXX) / KYBER_Q)); -- mod KYBER_Q);
	constant CM0_OUT_W : positive := CM0_IN_W + S_W;

	signal cm0_in   : std_logic_vector(CM0_IN_W - 1 downto 0);
	signal cm0_out  : std_logic_vector(CM0_OUT_W - 1 downto 0);
	signal quotient : std_logic_vector(G_OUT_WIDTH - 1 downto 0);
	signal cm1_out  : std_logic_vector(quotient'length + G_OUT_WIDTH - 1 downto 0);
	signal qq       : unsigned(G_OUT_WIDTH + 1 downto 0);
	signal y0       : unsigned(G_OUT_WIDTH + 1 downto 0);
	signal y1       : unsigned(G_OUT_WIDTH + 1 downto 0);
	signal y2       : unsigned(G_OUT_WIDTH + 1 downto 0);
	signal y        : unsigned(G_OUT_WIDTH + 1 downto 0);
begin
	-- s = (2**in_width // KYBER_Q) % KYBER_Q ??? TODO FIXME
	-- quotient =  s * (a >> 12)
	-- r = a - quotient*KYBER_Q = a mod KYBER_Q

	cm0_in <= a(G_IN_WIDTH - 1 downto G_OUT_WIDTH - 1); -- a >> 12

	quotient <= cm0_out(G_OUT_WIDTH + S_W - 1 downto S_W);

	-- cm0: out0 <- in0 * n0,  n0 = 2**in_width // KYBER_Q,  width(in0) = G_IN_WIDTH  - G_OUT_WIDTH + 1,  width(out0) = G_IN_WIDTH - G_OUT_WIDTH + 1 + S_W
	-- cm1: out1 <- in1 * n1,  n1 = KYBER_Q,                 width(in1) = G_OUT_WIDTH - G_OUT_WIDTH + 1,  width(out1) = G_IN_WIDTH + 1
	gen_const_mults : if G_IN_WIDTH = 26 generate
		cm0_8736_15 : entity work.ConstMult_273_14  
			port map(
				X => cm0_in,
				R => cm0_out
			);
		cm1_7681_14 : entity work.ConstMult_7681_13 -- KYBER_Q, 
			port map(
				X => quotient,
				R => cm1_out
			);
	elsif G_IN_WIDTH = 27 generate
		cm0_17473_15 : entity work.ConstMult_273_15
			port map(
				X => cm0_in,
				R => cm0_out
			);
		cm1_7681_15 : entity work.ConstMult_7681_13 -- KYBER_Q, 
			port map(
				X => quotient,
				R => cm1_out
			);
	else generate
		assert false Report "Unknown value for generic G_IN_WIDTH: " & to_string(G_IN_WIDTH) severity failure;
	end generate;

	qq <= unsigned(cm1_out(G_OUT_WIDTH + 1 downto 0));

	--  x = a >> (k-1) 
	--	X <= unsigned(a(G_N-1 downto G_K-1));
	--
	--	----------- generate quotient = x * (2^26/KYBER_Q)
	--	-- t1 <-  x >> 4  + x
	--	t1       <= ("00000" & X(13 downto 4)) + ("0" & X);
	--	--  q = {((x >> 4)  + x) >> 4}  +  (x >> 1) = x * (2^26/KYBER_Q)
	--	quotient <= ("0000" & t1(14 downto 5)) + ("0" & X(13 downto 1));

	----------- generate product = 7681 * quotient
	--	-- KYBER_Q = 7681 = 2^13-2^9+1
	--	t2(14 downto 9) <= ("00" & quotient(12 downto 9)) - quotient(5 downto 0);
	--	t2(8 downto 0)  <= quotient(8 downto 0);
	--	-- product = 7681 * quotient
	--	product         <= ((t2(14 downto 13)) + quotient(1 downto 0)) & (t2(12 downto 0));

	----------- y = (a mod 2^{15} - (7681 * quotient)

	y0 <= unsigned(a(G_OUT_WIDTH + 1 downto 0)) - qq;

	y1 <= (y0) - KYBER_Q;
	y2 <= (y0) - (2 * KYBER_Q);

	y <= y0 when ?? y1(y1'left)
		else y1 when ?? y2(y1'left)
		else y2;

	r <= std_logic_vector(y(G_OUT_WIDTH - 1 downto 0));

end rtl;
