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

entity controller is
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
end entity controller;

architecture RTL of controller is
	---------------------------------------------------------------- Types -----------------------------------------------------------------------
	type t_state is (
		init, init_state_mem, begin_round, absorb_read, absorb_write, squeeze_out, squeeze_out_fin, slice_read, slice_read_fin, slice_proc, slice_write,
		rho_read, rho_read_fin, rho_rotate, rho_write, done
	);
	---------------------------------------------------------------- Constants (1) ---------------------------------------------------------------
	constant LAST_LANE                              : positive := C_SLICE_WIDTH; -- 25
	--
	---------------------------------------------------------------- Registers/FF ----------------------------------------------------------------
	signal round_cntr                               : unsigned(log2ceil(C_NUM_ROUNDS + 1) - 1 downto 0);
	signal lane_cntr                                : unsigned(log2ceil(LAST_LANE) - 1 downto 0); -- 0 to 25, 5 bits, 1 is invalid, 2 -> line 1, etc
	signal hword_cntr                               : unsigned(3 downto 0);
	signal dout_valid_piped_reg                     : std_logic;
	-------- State 
	signal state                                    : t_state;
	-------- flags
	signal pre_last_flag                            : std_logic;
	--
	---------------------------------------------------------------- Wires -----------------------------------------------------------------------
	signal rho1_rho0                                : unsigned(11 downto 0);
	signal rho0, rho1                               : unsigned(5 downto 0);
	signal rho0q, rho1q                             : unsigned(3 downto 0);
	signal hword_cntr_lt_rho0q, hword_cntr_lt_rho1q : boolean;
	--
	---------------------------------------------------------------- Constants (2) ---------------------------------------------------------------
	constant LAST_HWORD                             : unsigned := to_unsigned(C_LANE_WIDTH / C_HALFWORD_WIDTH - 1, hword_cntr'length);
	constant FIRST_LANE                             : unsigned := to_unsigned(1, lane_cntr'length);
	constant THIRD_LANE                             : unsigned := to_unsigned(3, lane_cntr'length);
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
				state                <= init_state_mem;
				dout_valid_piped_reg <= '0';
			else
				case state is
					when init =>
						lane_cntr  <= FIRST_LANE;
						round_cntr <= (others => '0');

						if i_squeeze then -- i_squeeze should have priority over i_init for the protocol (2.1)
							state <= squeeze_out;
						elsif i_absorb then
							state <= absorb_read;
						elsif i_init then
							state <= init_state_mem;
						end if;

					when init_state_mem =>
						if hword_cntr = LAST_HWORD then
							hword_cntr <= (others => '0');
							if lane_cntr = LAST_LANE then
								state <= done;
							else
								lane_cntr <= lane_cntr + 2;
							end if;
						else
							hword_cntr <= hword_cntr + 1;
						end if;

					when absorb_read =>
						state         <= absorb_write;
						o_do_odd_lane <= lane_cntr(0); -- delayed

					when absorb_write =>
						if i_din_valid then
							state <= absorb_read;
							if hword_cntr = LAST_HWORD then
								if lane_cntr = i_rate then -- started from 1 => 1..i_rate
									state <= begin_round;
								else
									hword_cntr <= (others => '0');
									lane_cntr  <= lane_cntr + 1;
								end if;
							else
								hword_cntr <= hword_cntr + 1;
							end if;
						end if;

					when squeeze_out =>
						dout_valid_piped_reg <= '1';
						if i_dout_ready or not dout_valid_piped_reg then -- "FIFO" to be consumed or "FIFO" is empty
							o_do_odd_lane <= lane_cntr(0); -- delayed
							if hword_cntr = LAST_HWORD then
								if lane_cntr = i_rate then
									lane_cntr  <= FIRST_LANE;
									hword_cntr <= (others => '0');
									state      <= squeeze_out_fin;
								else
									hword_cntr <= (others => '0');
									lane_cntr  <= lane_cntr + 1;
								end if;
							else
								hword_cntr <= hword_cntr + 1;
							end if;
						end if;

					when squeeze_out_fin =>
						if i_dout_ready then
							dout_valid_piped_reg <= '0';
							round_cntr           <= (others => '0');
							if i_init then
								state <= init_state_mem;
							else
								state <= begin_round;
							end if;
						end if;

					----- round states
					when begin_round =>
						lane_cntr     <= FIRST_LANE;
						hword_cntr    <= LAST_HWORD;
						pre_last_flag <= '1';
						state         <= slice_read;

					when slice_read =>
						if lane_cntr = LAST_LANE then -- 4-slice block loaded
							state <= slice_read_fin;
						else
							lane_cntr <= lane_cntr + 2;
						end if;

					when slice_read_fin =>
						lane_cntr <= (others => '0');
						state     <= slice_proc;

					when slice_proc =>
						if lane_cntr = C_HALFWORD_WIDTH - 1 then -- all shifted out, start from 0
							lane_cntr <= FIRST_LANE;
							if pre_last_flag then
								pre_last_flag <= '0';
								-- skip write and restart from first slice
								hword_cntr    <= (others => '0');
								state         <= slice_read;
							else
								state <= slice_write;
							end if;
						else
							lane_cntr <= lane_cntr + 1;
						end if;

					when slice_write =>
						if lane_cntr = LAST_LANE then -- 4 slices written back to state memory
							lane_cntr <= FIRST_LANE;
							if hword_cntr = LAST_HWORD then
								hword_cntr <= (others => '0');
								if round_cntr = C_NUM_ROUNDS then
									round_cntr <= (others => '0');
									state      <= done;
								else
									lane_cntr <= THIRD_LANE; -- first lane: no Rho, start from second lane, odd lane number to land on 25
									state     <= rho_read;
								end if;
							else
								hword_cntr <= hword_cntr + 1;
								state      <= slice_read;
							end if;
						else
							lane_cntr <= lane_cntr + 2;
						end if;

					when rho_read =>
						if hword_cntr = LAST_HWORD then
							state <= rho_read_fin;
						else
							hword_cntr <= hword_cntr + 1;
						end if;

					when rho_read_fin =>
						hword_cntr <= (others => '0');
						state      <= rho_rotate;

					when rho_rotate =>
						if hword_cntr_lt_rho0q or hword_cntr_lt_rho1q then
							hword_cntr <= hword_cntr + 1;
						else
							hword_cntr <= (others => '0');
							state      <= rho_write;
						end if;

					when rho_write =>
						if hword_cntr = LAST_HWORD then
							if lane_cntr = LAST_LANE then
								-- restart slice processing 
								-- starts with Theta parity initialization of last halfword
								round_cntr <= round_cntr + 1;
								state      <= begin_round;
							else
								hword_cntr <= (others => '0');
								lane_cntr  <= lane_cntr + 2;
								state      <= rho_read;
							end if;
						else
							hword_cntr <= hword_cntr + 1;

						end if;

					when done =>
						if not (i_init or i_absorb or i_squeeze) then
							state <= init;
						end if;

				end case;

			end if;
		end if;
	end process fsm;

	control_proc : process(all) is
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
			when init =>
				null;

			when init_state_mem =>
				o_do_setzero_mem <= '1';
				o_mem_ce         <= '1';
				o_mem_we         <= '1';

			when absorb_read =>
				o_mem_ce <= '1';

			when absorb_write =>
				o_mem_ce    <= '1';
				o_mem_we    <= i_din_valid;
				o_din_ready <= '1';
				o_do_xorin  <= '1';

			when squeeze_out =>
				o_mem_ce <= i_dout_ready or not dout_valid_piped_reg;

			when squeeze_out_fin =>
				null;

			when begin_round =>
				null;

			when slice_read =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_ce       <= '1';

			when slice_read_fin =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_ce       <= '1';

			when slice_proc =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_do_vertical  <= '1';
				if round_cntr = 0 then
					o_do_bypass_iochipi <= '1';
				end if;
				if round_cntr /= C_NUM_ROUNDS then
					o_do_theta <= '1';
				end if;

			when slice_write =>
				o_mem_ce       <= '1';
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_we       <= '1';

			when rho_read =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_ce       <= '1';

			when rho_read_fin =>
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_mem_ce       <= '1';

			when rho_rotate =>
				if hword_cntr_lt_rho0q then
					o_do_shift_en0 <= '1';
				end if;
				if hword_cntr_lt_rho1q then
					o_do_shift_en1 <= '1';
				end if;
				o_do_hrotate <= '1';

			when rho_write =>
				o_do_hrotate   <= '1';  -- rotate modular
				o_do_shift_en0 <= '1';
				o_do_shift_en1 <= '1';
				o_do_rho_out   <= '1';
				o_mem_ce       <= '1';
				o_mem_we       <= '1';

			when done =>
				o_done <= '1';

		end case;
	end process control_proc;

	o_dout_valid <= dout_valid_piped_reg;

	o_mem_addr <= lane_cntr(lane_cntr'length - 1 downto 1) & hword_cntr;

	o_round <= round_cntr;

	-- index to Iota ROM during slice_proc, lane_cntr counts slice in slice block and has nothing to do with lanes
	o_k <= hword_cntr & lane_cntr(1 downto 0);

end architecture RTL;
