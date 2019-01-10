library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;

entity controller is
	port(
		clk                   : in  std_logic;
		rst                   : in  std_logic;
		-- from core top ports
		absorb                : in  std_logic; -- press lever!
		squeeze               : in  std_logic; -- press lever!
		din_valid             : in  std_logic;
		din_ready             : out std_logic;
		dout_valid            : out std_logic;
		dout_ready            : in  std_logic;
		done                  : out std_logic;
		rate                  : in  unsigned(log2ceil(C_SLICE_WIDTH) - 1 downto 0);
		-- to datapath
		out_do_bypass_iochipi : out std_logic;
		out_do_theta          : out std_logic;
		out_do_rho_out        : out std_logic;
		out_do_setzero_mem    : out std_logic;
		out_do_xorin          : out std_logic;
		out_do_odd_lane       : out std_logic;
		--
		out_do_shift_en0      : out std_logic;
		out_do_shift_en1      : out std_logic;
		out_do_hrotate        : out std_logic;
		out_do_vertical       : out std_logic;
		-- to datapath Rho muxes
		rho0r                 : out unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		rho1r                 : out unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		-- to ROMs
		round                 : out unsigned(log2ceil(C_NUM_ROUNDS + 1) - 1 downto 0);
		k                     : out unsigned(log2ceil(C_LANE_WIDTH) - 1 downto 0);
		-- to state memory
		mem_addr              : out unsigned(log2ceil(C_NUM_MEM_WORDS) - 1 downto 0);
		mem_we                : out std_logic;
		mem_ce                : out std_logic
	);
end entity controller;

architecture RTL of controller is
	---------------------------------------------------------------- Constants -------------------------------------------------------------------
	--	constant NUM_SHIFT_INS  : positive := C_LANE_WIDTH / C_HALFWORD_WIDTH;
	--	constant NUM_SHIFT_OUTS : positive := C_SLICE_WIDTH - (C_SLICE_WIDTH / 2);
	---------------------------------------------------------------- Types -----------------------------------------------------------------------
	type t_state is (
		init_state_mem, absorb_read, absorb_write, squeeze_out, squeeze_out_fin, slice_read, slice_read_fin, slice_proc, slice_write,
		rho_read, rho_read_fin, rho_rotate, rho_write, absorb_done, squeeze_done
	);

	constant LAST_LANE : positive := C_SLICE_WIDTH; -- = 25

	---------------------------------------------------------------- Functions/Procedures --------------------------------------------------------

	---------------------------------------------------------------- Registers/FF ----------------------------------------------------------------
	--------- Counters ---------------------------------------------------------------------------------------------------------------------------
	signal round_cntr : unsigned(log2ceil(C_NUM_ROUNDS + 1) - 1 downto 0);

	signal lane_cntr  : unsigned(log2ceil(LAST_LANE) - 1 downto 0); -- 0 to 25, 5 bits, 1 is invalid, 2 -> line 1, etc
	signal hword_cntr : unsigned(3 downto 0);

	-------- State 
	signal state                                    : t_state;
	signal pre_last_flag                            : std_logic;
	signal squeeze_flag                             : std_logic;
	-------- flags
	---------------------------------------------------------------- Wires -----------------------------------------------------------------------
	signal rho1_rho0                                : unsigned(11 downto 0);
	signal rho0, rho1                               : unsigned(5 downto 0);
	signal rho0q, rho1q                             : unsigned(3 downto 0);
	signal hword_cntr_lt_rho0q, hword_cntr_lt_rho1q : boolean;

	constant LAST_HWORD : unsigned := to_unsigned(C_LANE_WIDTH / C_HALFWORD_WIDTH - 1, hword_cntr'length);
	constant FIRST_LANE : unsigned := to_unsigned(1, lane_cntr'length);
	constant THIRD_LANE : unsigned := to_unsigned(3, lane_cntr'length);
begin

	rho0  <= rho1_rho0(5 downto 0);
	rho1  <= rho1_rho0(11 downto 6);
	rho0q <= rho0(5 downto 2);
	rho0r <= rho0(1 downto 0);
	rho1q <= rho1(5 downto 2);
	rho1r <= rho1(1 downto 0);

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
				lane_cntr  <= FIRST_LANE;
				hword_cntr <= (others => '0');
				state      <= init_state_mem;
				dout_valid <= '0';
			else
				case state is
					when init_state_mem =>
						if hword_cntr = LAST_HWORD then
							hword_cntr <= (others => '0');
							if lane_cntr = LAST_LANE then
								lane_cntr    <= FIRST_LANE;
								round_cntr   <= (others => '0');
								state        <= absorb_read;
								squeeze_flag <= '0';
							else
								lane_cntr <= lane_cntr + 2;
							end if;
						else
							hword_cntr <= hword_cntr + 1;
						end if;

					when absorb_read =>
						state           <= absorb_write;
						out_do_odd_lane <= lane_cntr(0); -- delayed

					when absorb_write =>
						if din_valid then
							state <= absorb_read;
							if hword_cntr = LAST_HWORD then
								if lane_cntr = rate then
									lane_cntr     <= FIRST_LANE;
									pre_last_flag <= '1';
									-- hword_cntr remains LAST_HWORD
									state         <= slice_read;
								else
									hword_cntr <= (others => '0');
									lane_cntr  <= lane_cntr + 1;
								end if;
							else
								hword_cntr <= hword_cntr + 1;
							end if;
						end if;

					when squeeze_out =>
						dout_valid <= '1';
						if dout_ready or not dout_valid then -- "FIFO" to be consumed or "FIFO" is empty
							out_do_odd_lane <= lane_cntr(0); -- delayed
							if hword_cntr = LAST_HWORD then
								if lane_cntr = rate then
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
						if dout_ready then
							dout_valid <= '0';
							state      <= squeeze_done;
						end if;

					----- round states
					when slice_read =>
						if lane_cntr = LAST_LANE then -- 4 slices fully read
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
									if squeeze_flag then
										state <= squeeze_out;
									else
										state <= absorb_done;
									end if;
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
								round_cntr    <= round_cntr + 1;
								lane_cntr     <= FIRST_LANE;
								hword_cntr    <= LAST_HWORD;
								pre_last_flag <= '1';
								state         <= slice_read;
							else
								hword_cntr <= (others => '0');
								lane_cntr  <= lane_cntr + 2;
								state      <= rho_read;
							end if;
						else
							hword_cntr <= hword_cntr + 1;

						end if;

					when absorb_done =>
						if absorb then
							state <= absorb_read;
						elsif squeeze then
							squeeze_flag <= '1';
							state        <= squeeze_out;
						end if;

					when squeeze_done =>
						dout_valid <= '0';
						if absorb then
							state <= init_state_mem;
						elsif squeeze then
							state <= slice_read;
						end if;

				end case;

			end if;
		end if;
	end process fsm;

	control_proc : process(all) is
	begin
		din_ready             <= '0';
		-- to datapath
		out_do_vertical       <= '0';
		out_do_hrotate        <= '0';
		out_do_shift_en0      <= '0';
		out_do_shift_en1      <= '0';
		mem_we                <= '0';
		out_do_rho_out        <= '0';
		-- squeeze/absorb control
		out_do_xorin          <= '0';   -- TODO
		out_do_setzero_mem    <= '0';
		out_do_theta          <= '0';
		out_do_bypass_iochipi <= '0';
		-- clock enable
		mem_ce                <= '0';
		done                  <= '0';

		case state is
			when init_state_mem =>
				out_do_setzero_mem <= '1';
				mem_ce             <= '1';
				mem_we             <= '1';

			when absorb_read =>
				mem_ce <= '1';

			when absorb_write =>
				mem_ce       <= '1';
				mem_we       <= din_valid;
				din_ready    <= '1';
				out_do_xorin <= '1';

			when squeeze_out =>
				mem_ce <= dout_ready or not dout_valid;

			when squeeze_out_fin =>
				if dout_ready then
					done <= '1';
				end if;

			when slice_read =>
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				mem_ce           <= '1';

			when slice_read_fin =>
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				mem_ce           <= '1';

			when slice_proc =>
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				out_do_vertical  <= '1';
				if round_cntr = 0 then
					out_do_bypass_iochipi <= '1';
				end if;
				if round_cntr /= C_NUM_ROUNDS then
					out_do_theta <= '1';
				end if;

			when slice_write =>
				mem_ce           <= '1';
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				mem_we           <= '1';

				if lane_cntr = LAST_LANE and hword_cntr = LAST_HWORD and round_cntr = C_NUM_ROUNDS and not (?? squeeze_flag) then
					done <= '1';
				end if;

			when rho_read =>
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				mem_ce           <= '1';

			when rho_read_fin =>
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				mem_ce           <= '1';

			when rho_rotate =>
				if hword_cntr_lt_rho0q then
					out_do_shift_en0 <= '1';
				end if;
				if hword_cntr_lt_rho1q then
					out_do_shift_en1 <= '1';
				end if;
				out_do_hrotate <= '1';

			when rho_write =>
				out_do_hrotate   <= '1'; -- rotate modular
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				out_do_rho_out   <= '1';
				mem_ce           <= '1';
				mem_we           <= '1';

			when absorb_done =>
				done <= '1';

			when squeeze_done =>
				done <= '1';

		end case;
	end process control_proc;

	mem_addr <= lane_cntr(lane_cntr'length - 1 downto 1) & hword_cntr;

	round <= round_cntr;

	-- index to Iota ROM during slice_proc, lane_cntr counts slice in slice block and has nothing to do with lanes
	k <= hword_cntr & lane_cntr(1 downto 0);

end architecture RTL;
