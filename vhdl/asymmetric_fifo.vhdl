------------------------------------------------------------------------------------------------
--
-- @module:    Asymmetric FIFO
--
-- @details:   Convert a valid/ready input interface of width IN_WIDTH bits to 
--                 the output valid/ready interface of OUT_WIDTH bits
--
-- @author:    Kamyar Mohajerani kamyar@ieee.org
-- @license:   MIT
--
-- @copyright: Copyright 2019 Kamyar Mohajerani
--
------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kyber_pkg.all;

entity asymmetric_fifo is
	generic(
		G_IN_WIDTH  : positive;
		G_OUT_WIDTH : positive
	);
	port(
		clk          : in  std_logic;
		rst          : in  std_logic;
		i_din_data   : in  std_logic_vector(G_IN_WIDTH - 1 downto 0);
		i_din_valid  : in  std_logic;
		o_din_ready  : out std_logic;
		o_dout_data  : out std_logic_vector(G_OUT_WIDTH - 1 downto 0);
		o_dout_valid : out std_logic;
		i_dout_ready : in  std_logic
	);
end entity asymmetric_fifo;

architecture LCM_IMPL of asymmetric_fifo is
	constant DEPTH     : positive := lcm(G_IN_WIDTH, G_OUT_WIDTH) / G_IN_WIDTH;
	constant NUM_OUTS  : positive := lcm(G_IN_WIDTH, G_OUT_WIDTH) / G_OUT_WIDTH;
	type T_fifo is array (0 to DEPTH - 1) of std_logic_vector(G_IN_WIDTH - 1 downto 0); -- DEPTH x G_IN_WIDTH-bit
	type T_state is (S_pump_in, S_pump_out);
	type T_out_choices is array (0 to NUM_OUTS - 1) of std_logic_vector(G_OUT_WIDTH - 1 downto 0);
	----------------------------------------------------( Registers )------------------------------------------------
	signal fifo_regs   : T_fifo;
	signal counter_reg : unsigned(log2ceilnz(maximum(DEPTH, NUM_OUTS)) - 1 downto 0);
	signal state       : T_state;
	----------------------------------------------------( Wires )----------------------------------------------------
	signal out_choice  : T_out_choices;
begin

	sync_proc : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state       <= S_pump_in;
				counter_reg <= (others => '0');
			else
				case state is
					when S_pump_in =>
						if i_din_valid and o_din_ready then
							for i in 0 to DEPTH - 2 loop
								fifo_regs(i) <= fifo_regs(i + 1);
							end loop;
							fifo_regs(DEPTH - 1) <= i_din_data;

							counter_reg <= counter_reg + 1;
							if counter_reg(log2ceilnz(DEPTH) - 1 downto 0) = DEPTH - 1 then
								counter_reg <= (others => '0');
								state       <= S_pump_out;
							end if;
						end if;
					when S_pump_out =>
						if o_dout_valid and i_dout_ready then
							counter_reg <= counter_reg + 1;
							if counter_reg(log2ceilnz(NUM_OUTS) - 1 downto 0) = NUM_OUTS - 1 then
								counter_reg <= (others => '0');
								state       <= S_pump_in;
							end if;
						end if;
				end case;
			end if;
		end if;
	end process sync_proc;

	gen_outchoice_wiring : for i in 0 to (DEPTH * G_IN_WIDTH) - 1 generate
		out_choice(i / G_OUT_WIDTH)(i mod G_OUT_WIDTH) <= fifo_regs(i / G_IN_WIDTH)(i mod G_IN_WIDTH);
	end generate;

	comb_proc : process(all) is
	begin
		o_din_ready  <= '0';
		o_dout_valid <= '0';
		o_dout_data  <= out_choice(0);

		case state is
			when S_pump_in =>
				o_din_ready <= '1';
			when S_pump_out =>
				o_dout_valid <= '1';
				o_dout_data  <= out_choice(to_integer(counter_reg));
		end case;

	end process comb_proc;

end architecture LCM_IMPL;

--architecture RTL of asymmetric_fifo is
--	----------------------------------------------------( Functions )------------------------------------------------
--	-- value for K
--	function calc_DEPTH return positive is
--	begin
--		if (G_OUT_WIDTH mod G_IN_WIDTH) < 2 then
--			return ceil_div(G_OUT_WIDTH, G_IN_WIDTH);
--		else
--			return ceil_div(G_OUT_WIDTH, G_IN_WIDTH) + 1; -- remainders can span both first and last rows
--		end if;
--	end function;
--
--	-- reduction if 0 <= param <= 2*modulus - 1
--	function red1(param : unsigned; modulus : positive)
--	return unsigned is
--		variable len : positive := log2ceilnz(modulus);
--	begin
--		if param >= modulus then
--			return resize(param - modulus, len);
--		else
--			return resize(param, len);
--		end if;
--	end function red1;
--	----------------------------------------------------( Constants )------------------------------------------------
--	constant DEPTH     : positive := calc_DEPTH;
--	constant R         : natural  := G_OUT_WIDTH mod G_IN_WIDTH;
--	constant D_U_M_M_Y : string   := INSTANTIATE("asymmetric_fifo",
--	                                             "G_IN_WIDTH=" & to_string(G_IN_WIDTH) & " G_OUT_WIDTH=" & to_string(G_OUT_WIDTH) & " R=" & to_string(R) & " DEPTH=" & to_string(DEPTH)
--	                                            );
--	----------------------------------------------------( Types )----------------------------------------------------
--	type T_fifo is array (0 to DEPTH - 1) of std_logic_vector(G_IN_WIDTH - 1 downto 0); -- (k) x G_IN_WIDTH-bit
--	----------------------------------------------------( Registers )------------------------------------------------
--	signal fifo_regs   : T_fifo;
--	signal residue_reg : unsigned(log2ceilnz(G_IN_WIDTH) - 1 downto 0); -- 0..G_IN_WIDTH-1
--	signal counter_reg : unsigned(log2ceilnz(DEPTH + 1) - 1 downto 0); -- 0->empty, 1 .. K
--	----------------------------------------------------( Wires )----------------------------------------------------
--	signal is_filled   : std_logic;
--
--begin
--
--	gen : if G_IN_WIDTH > G_OUT_WIDTH generate
--		process(clk, rst)
--		begin
--			report "not implemented" severity failure;
--		end process;
--	elsif G_IN_WIDTH < G_OUT_WIDTH generate
--		gen_filled : if R = 0 generate
--			is_filled <= '1' when counter_reg = DEPTH else '0';
--		else generate
--			is_filled <= '1' when counter_reg = DEPTH or (counter_reg = DEPTH - 1 and residue_reg <= (G_IN_WIDTH - R)) else '0';
--		end generate;
--
--		gen_output_wiring : if R = 0 generate
--			process(all)
--			begin
--				for i in 0 to G_OUT_WIDTH - 1 loop
--					o_dout_data(i) <= fifo_regs(i / G_IN_WIDTH)(i mod G_IN_WIDTH);
--				end loop;
--			end process;
--		else generate
--			process(all)
--				variable window : std_logic_vector(G_IN_WIDTH - 1 downto 0);
--				variable offset : natural;
--				variable level  : natural;
--			begin
--				-- G_OUT_WIDTH MUX of G_IN_WIDTH:1
--				for i in 0 to G_OUT_WIDTH - 1 loop
--					level          := i / G_IN_WIDTH;
--					offset         := i mod G_IN_WIDTH;
--					if counter_reg /= DEPTH then
--						window := fifo_regs(level + 1);
--					elsif offset = 0 then
--						window := fifo_regs(level);
--					else
--						window := fifo_regs(level + 1)(offset - 1 downto 0) & fifo_regs(level)(G_IN_WIDTH - 1 downto offset);
--					end if;
--					o_dout_data(i) <= window(to_integer(residue_reg));
--				end loop;
--			end process;
--
--		end generate;
--
--		reg_update_proc : process(clk) is
--		begin
--			if rising_edge(clk) then
--				if rst = '1' then
--					counter_reg <= (others => '0');
--					residue_reg <= (others => '0');
--				else
--					if i_din_valid and o_din_ready then
--						for i in 0 to DEPTH - 2 loop
--							fifo_regs(i) <= fifo_regs(i + 1);
--						end loop;
--						fifo_regs(DEPTH - 1) <= i_din_data;
--
--						counter_reg <= counter_reg + 1;
--					end if;
--
--					if o_dout_valid and i_dout_ready then -- implies is_filled = '1'
--						residue_reg <= red1(residue_reg + R, G_IN_WIDTH);
--						if i_din_valid and o_din_ready then -- in and out in the same cycle
--							counter_reg <= to_unsigned(1, counter_reg'length);
--						else
--							counter_reg <= to_unsigned(0, counter_reg'length);
--						end if;
--
--					end if;
--
--				end if;
--
--			end if;
--		end process reg_update_proc;
--
--		o_dout_valid <= is_filled;
--		o_din_ready  <= i_dout_ready or not is_filled;
--
--	else                                -- G_IN_WIDTH = G_OUT_WIDTH
--	generate
--		o_dout_data  <= i_din_data;
--		o_dout_valid <= i_din_valid;
--		o_din_ready  <= i_dout_ready;
--	end generate;
--
--end architecture RTL;
