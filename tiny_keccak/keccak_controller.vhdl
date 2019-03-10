----------------------------------------------------------------------------------------------------------------------------------
-- @description: Keccak controller
--
-- @author:      Kamyar Mohajerani
-- @copyright:   (c) 2019 GMU CERG LAB
--
-- @details:
---   Algorithm order of execution is: Theta(slice), Rho, Pi(slice), Chi(slice), Iota(slice)
--- 
---   Round 0:
---      slice (only Theta)
---   Rounds 1-23:
---      slice
---      Rho
---   Round 24:
---      slice(only Pi+Chi+Iota)
---
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;

entity keccak_controller is
	port(
		clk                 : in  std_logic;
		rst                 : in  std_logic;
		-- from core top ports
		i_absorb            : in  std_logic;
		i_squeeze           : in  std_logic;
		i_init              : in  std_logic;
		i_din_valid         : in  std_logic;
		o_din_ready         : out std_logic;
		o_dout_valid        : out std_logic;
		i_dout_ready        : in  std_logic;
		o_done              : out std_logic;
		i_rate              : in  unsigned(log2ceil(C_SLICE_WIDTH) - 1 downto 0);
		-- to datapath
		o_do_bypass_iochipi : out std_logic;
		o_do_theta          : out std_logic;
		o_do_rho_out        : out std_logic;
		o_do_setzero_mem    : out std_logic;
		o_do_xorin          : out std_logic;
		o_do_odd_lane       : out std_logic;
		--
		o_do_shift_en0      : out std_logic;
		o_do_shift_en1      : out std_logic;
		o_do_hrotate        : out std_logic;
		o_do_vertical       : out std_logic;
		-- to datapath Rho muxes
		o_rho0r             : out unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		o_rho1r             : out unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		-- to ROMs
		o_round             : out unsigned(log2ceil(C_NUM_ROUNDS + 1) - 1 downto 0);
		o_k                 : out unsigned(log2ceil(C_LANE_WIDTH) - 1 downto 0);
		-- to state memory
		o_mem_addr          : out unsigned(log2ceil(C_NUM_MEM_WORDS) - 1 downto 0);
		o_mem_we            : out std_logic;
		o_mem_ce            : out std_logic
	);
end entity keccak_controller;

architecture RTL of keccak_controller is
	--------------------------------------------------------------------- Types -----------------------------------------------------------------------
	type T_state is (
		s_init,
		s_initialize_smem,
		s_begin_round,
		s_absorb_load, s_absorb_store,
		s_squeeze_out, s_squeeze_out_fin,
		s_slice_load, s_slice_load_fin, s_slice_process, s_slice_store,
		s_rho_load, s_rho_load_fin, s_rho_rotate, s_rho_store,
		s_done
	);
	--------------------------------------------------------------------- Constants -------------------------------------------------------------------
	constant LAST_LANE                              : positive := C_SLICE_WIDTH; -- 25
	constant C_LANECNTR_BITS                        : positive := log2ceil(LAST_LANE);
	constant C_HWORDCNTR_BITS                       : positive := 4;
	constant FIRST_LANE                             : unsigned := to_unsigned(1, C_LANECNTR_BITS);
	constant THIRD_LANE                             : unsigned := to_unsigned(3, C_LANECNTR_BITS);
	constant LAST_HWORD                             : unsigned := to_unsigned(C_LANE_WIDTH / C_HALFWORD_WIDTH - 1, C_HWORDCNTR_BITS);
	--
	--------------------------------------------------------------------- Registers/FF ----------------------------------------------------------------
	signal state                                    : T_state;
	signal pre_last_flag                            : std_logic;
	signal round_cntr                               : unsigned(log2ceil(C_NUM_ROUNDS + 1) - 1 downto 0);
	signal lane_cntr                                : unsigned(C_LANECNTR_BITS - 1 downto 0); -- 0 to 25, 5 bits, 1 is invalid, 2 -> line 1, etc
	signal hword_cntr                               : unsigned(C_HWORDCNTR_BITS - 1 downto 0);
	signal dout_valid_piped_reg                     : std_logic;
	--
	--------------------------------------------------------------------- Wires -----------------------------------------------------------------------
	signal rho1_rho0                                : unsigned(11 downto 0);
	signal rho0, rho1                               : unsigned(5 downto 0);
	signal rho0q, rho1q                             : unsigned(3 downto 0);
	signal hword_cntr_lt_rho0q, hword_cntr_lt_rho1q : boolean;

begin

	rho0                <= rho1_rho0(5 downto 0);
	rho1                <= rho1_rho0(11 downto 6);
	rho0q               <= rho0(5 downto 2);
	o_rho0r             <= rho0(1 downto 0);
	rho1q               <= rho1(5 downto 2);
	o_rho1r             <= rho1(1 downto 0);
	--
	hword_cntr_lt_rho0q <= hword_cntr < rho0q;
	hword_cntr_lt_rho1q <= hword_cntr < rho1q;

	rho_rom_inst : entity work.rho_rom
		port map(
			lane_cntr       => lane_cntr(lane_cntr'length - 1 downto 1),
			rho_shift_const => rho1_rho0
		);

	fsm : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state                <= s_init;
				dout_valid_piped_reg <= '0';
			else
				case state is
					when s_init =>
						lane_cntr  <= FIRST_LANE;
						round_cntr <= (others => '0');
						hword_cntr <= (others => '0');

						if i_squeeze = '1' then -- i_squeeze must have priority over i_absorb and i_init as a requirement of the protocol (i.e. 2.1.a and 2.1.b)
							state <= s_squeeze_out;
						elsif i_absorb = '1' then
							state <= s_absorb_load;
						elsif i_init = '1' then
							state <= s_initialize_smem;
						end if;

					when s_initialize_smem =>
						if hword_cntr = LAST_HWORD then
							hword_cntr <= (others => '0');
							if lane_cntr = LAST_LANE then
								state <= s_done;
							else
								lane_cntr <= lane_cntr + 2;
							end if;
						else
							hword_cntr <= hword_cntr + 1;
						end if;

					when s_absorb_load =>
						state         <= s_absorb_store;
						o_do_odd_lane <= lane_cntr(0); -- delayed

					when s_absorb_store =>
						if i_din_valid = '1' then
							state <= s_absorb_load;
							if hword_cntr = LAST_HWORD then
								if lane_cntr = i_rate then -- started from 1 => 1..i_rate
									state <= s_begin_round;
								else
									hword_cntr <= (others => '0');
									lane_cntr  <= lane_cntr + 1;
								end if;
							else
								hword_cntr <= hword_cntr + 1;
							end if;
						end if;

					when s_squeeze_out =>
						dout_valid_piped_reg <= '1';
						if i_dout_ready = '1' or dout_valid_piped_reg = '0' then -- "FIFO" to be consumed or "FIFO" is empty
							o_do_odd_lane <= lane_cntr(0); -- delayed
							if hword_cntr = LAST_HWORD then
								if lane_cntr = i_rate then
									lane_cntr  <= FIRST_LANE;
									hword_cntr <= (others => '0');
									state      <= s_squeeze_out_fin;
								else
									hword_cntr <= (others => '0');
									lane_cntr  <= lane_cntr + 1;
								end if;
							else
								hword_cntr <= hword_cntr + 1;
							end if;
						end if;

					when s_squeeze_out_fin =>
						if i_dout_ready = '1' then
							dout_valid_piped_reg <= '0';
							round_cntr           <= (others => '0');
							if i_init = '1' then
								state <= s_initialize_smem;
							elsif i_absorb = '1' then
								state <= s_done;
							else
								state <= s_begin_round;
							end if;
						end if;

					----- round states
					when s_begin_round =>
						lane_cntr     <= FIRST_LANE;
						hword_cntr    <= LAST_HWORD;
						pre_last_flag <= '1';
						state         <= s_slice_load;

					when s_slice_load =>
						if lane_cntr = LAST_LANE then -- 4-slice block loaded
							state <= s_slice_load_fin;
						else
							lane_cntr <= lane_cntr + 2;
						end if;

					when s_slice_load_fin =>
						lane_cntr <= (others => '0');
						state     <= s_slice_process;

					when s_slice_process =>
						if lane_cntr = C_HALFWORD_WIDTH - 1 then -- all shifted out, start from 0
							lane_cntr <= FIRST_LANE;
							if pre_last_flag = '1' then
								pre_last_flag <= '0';
								-- skip write and restart from first slice
								hword_cntr    <= (others => '0');
								state         <= s_slice_load;
							else
								state <= s_slice_store;
							end if;
						else
							lane_cntr <= lane_cntr + 1;
						end if;

					when s_slice_store =>
						if lane_cntr = LAST_LANE then -- 4 slices written back to state memory
							lane_cntr <= FIRST_LANE;
							if hword_cntr = LAST_HWORD then
								hword_cntr <= (others => '0');
								if round_cntr = C_NUM_ROUNDS then
									round_cntr <= (others => '0');
									state      <= s_done;
								else
									lane_cntr <= THIRD_LANE; -- first lane: no Rho, start from second lane, odd lane number to land on 25
									state     <= s_rho_load;
								end if;
							else
								hword_cntr <= hword_cntr + 1;
								state      <= s_slice_load;
							end if;
						else
							lane_cntr <= lane_cntr + 2;
						end if;

					when s_rho_load =>
						if hword_cntr = LAST_HWORD then
							state <= s_rho_load_fin;
						else
							hword_cntr <= hword_cntr + 1;
						end if;

					when s_rho_load_fin =>
						hword_cntr <= (others => '0');
						state      <= s_rho_rotate;

					when s_rho_rotate =>
						if hword_cntr_lt_rho0q or hword_cntr_lt_rho1q then
							hword_cntr <= hword_cntr + 1;
						else
							hword_cntr <= (others => '0');
							state      <= s_rho_store;
						end if;

					when s_rho_store =>
						if hword_cntr = LAST_HWORD then
							if lane_cntr = LAST_LANE then
								-- restart slice processing 
								-- starts with Theta parity initialization of last halfword
								round_cntr <= round_cntr + 1;
								state      <= s_begin_round;
							else
								hword_cntr <= (others => '0');
								lane_cntr  <= lane_cntr + 2;
								state      <= s_rho_load;
							end if;
						else
							hword_cntr <= hword_cntr + 1;

						end if;

					when s_done =>
						if (i_init or i_absorb or i_squeeze)  = '0' then
							state <= s_init;
						end if;

				end case;

			end if;
		end if;
	end process fsm;

	control_proc : process(state, dout_valid_piped_reg, hword_cntr_lt_rho0q, hword_cntr_lt_rho1q, i_din_valid, i_dout_ready, round_cntr) is
	begin
		o_din_ready         <= '0';
		-- to datapath
		o_do_vertical       <= '0';
		o_do_hrotate        <= '0';
		o_do_shift_en0      <= '0';
		o_do_shift_en1      <= '0';
		o_mem_we            <= '0';
		o_do_rho_out        <= '0';
		-- squeeze/absorb control
		o_do_xorin          <= '0';     -- TODO
		o_do_setzero_mem    <= '0';
		o_do_theta          <= '0';
		o_do_bypass_iochipi <= '0';
		-- clock enable
		o_mem_ce            <= '0';
		o_done              <= '0';

		case state is
			when s_init =>
				null;

			when s_initialize_smem =>
				o_do_setzero_mem <= '1';
				o_mem_ce         <= '1';
				o_mem_we         <= '1';

			when s_absorb_load =>
				o_mem_ce <= '1';

			when s_absorb_store =>
				o_mem_ce    <= '1';
				o_mem_we    <= i_din_valid;
				o_din_ready <= '1';
				o_do_xorin  <= '1';

			when s_squeeze_out =>
				o_mem_ce <= i_dout_ready or not dout_valid_piped_reg;

			when s_squeeze_out_fin =>
				null;

			when s_begin_round =>
				null;

			when s_slice_load =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_ce       <= '1';

			when s_slice_load_fin =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_ce       <= '1';

			when s_slice_process =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_do_vertical  <= '1';
				if round_cntr = 0 then
					o_do_bypass_iochipi <= '1';
				end if;
				if round_cntr /= C_NUM_ROUNDS then
					o_do_theta <= '1';
				end if;

			when s_slice_store =>
				o_mem_ce       <= '1';
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_we       <= '1';

			when s_rho_load =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_ce       <= '1';

			when s_rho_load_fin =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_ce       <= '1';

			when s_rho_rotate =>
				if hword_cntr_lt_rho0q then
					o_do_shift_en0 <= '1';
				end if;
				if hword_cntr_lt_rho1q then
					o_do_shift_en1 <= '1';
				end if;
				o_do_hrotate <= '1';

			when s_rho_store =>
				o_do_hrotate   <= '1';  -- rotate modular
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_do_rho_out   <= '1';
				o_mem_ce       <= '1';
				o_mem_we       <= '1';

			when s_done =>
				o_done <= '1';

		end case;
	end process control_proc;

	o_dout_valid <= dout_valid_piped_reg;

	o_mem_addr <= lane_cntr(lane_cntr'length - 1 downto 1) & hword_cntr;

	o_round <= round_cntr;

	-- index to Iota ROM during slice_proc, lane_cntr counts slice in slice block and has nothing to do with lanes
	o_k <= hword_cntr & lane_cntr(1 downto 0);

end architecture RTL;
