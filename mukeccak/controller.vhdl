library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.keccak_pkg.all;

entity controller is
	port(
		clk                       : in  std_logic;
		rst                       : in  std_logic;
		-- from core top ports
		do_absorb                 : in  std_logic; -- press lever!
		do_squeeze                : in  std_logic; -- press lever!
		din_valid                 : in  std_logic;
		din_ready                 : out std_logic;
		dout_valid                : out std_logic;
		dout_ready                : in  std_logic;
		-- to datapath
		out_do_bypass_iochipi     : out std_logic;
		out_do_theta       		  : out std_logic;
		out_do_rho_out            : out std_logic;
		out_do_lane0              : out std_logic;
		out_do_odd_hword          : out std_logic; -- when shifting in and lane0 = '1', choose the higher half word from memory, o/w lower
		out_do_setzero_to_mem_din : out std_logic;
		out_do_xorin              : out std_logic;
		out_do_data_hi            : out std_logic; -- select high halfword of lane0 or odd bits (higher - even - lane) of lane pairs to dout

		--
		out_do_shift_en0          : out std_logic;
		out_do_shift_en1          : out std_logic;
		out_do_hrotate            : out std_logic;
		out_do_vertical           : out std_logic;
		-- to datapath Rho muxes
		rho0r                     : out unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		rho1r                     : out unsigned(log2ceil(C_HALFWORD_WIDTH) - 1 downto 0);
		-- to ROMs
		round                     : out unsigned(log2ceil(C_NUM_ROUNDS + 1) - 1 downto 0);
		k                         : out unsigned(log2ceil(C_LANE_WIDTH) - 1 downto 0);
		-- to state memory
		mem_addr                  : out unsigned(log2ceil(C_NUM_MEM_WORDS) - 1 downto 0);
		mem_we                    : out std_logic;
		mem_ce                    : out std_logic
	);
end entity controller;

architecture RTL of controller is
	---------------------------------------------------------------- Constants -------------------------------------------------------------------
	--	constant NUM_SHIFT_INS  : positive := C_LANE_WIDTH / C_HALFWORD_WIDTH;
	--	constant NUM_SHIFT_OUTS : positive := C_SLICE_WIDTH - (C_SLICE_WIDTH / 2);
	---------------------------------------------------------------- Types -----------------------------------------------------------------------
	type t_state is (init, init_state_mem, slice_read, slice_proc, slice_write, rho_read, rho_rotate, rho_write
	);

	constant LAST_LANE : positive := 1 + (C_SLICE_WIDTH - 1) / 2 - 1; -- = 12

	---------------------------------------------------------------- Functions/Procedures --------------------------------------------------------

	---------------------------------------------------------------- Registers/FF ----------------------------------------------------------------
	--------- Counters ---------------------------------------------------------------------------------------------------------------------------
	signal round_cntr : unsigned(round'length - 1 downto 0);

	signal lane_cntr  : unsigned(log2ceil(LAST_LANE + 1) - 1 downto 0); -- 0 to 12
	signal hword_cntr : unsigned(log2ceil(C_LANE_WIDTH / C_HALFWORD_WIDTH + 1) - 1 downto 0);

	-------- State 
	signal state                                    : t_state;
	signal pre_last_flag                            : std_logic;
	-------- flags
	---------------------------------------------------------------- Wires -----------------------------------------------------------------------
	signal rho1_rho0                                : unsigned(11 downto 0);
	signal rho0, rho1                               : unsigned(5 downto 0);
	signal rho0q, rho1q                             : unsigned(3 downto 0);
	signal hword_cntr_lt_rho0q, hword_cntr_lt_rho1q : boolean;

	constant LAST_HWORD : unsigned := to_unsigned(C_LANE_WIDTH / C_HALFWORD_WIDTH - 1, hword_cntr'length);
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
			lane_cntr       => lane_cntr,
			rho_shift_const => rho1_rho0
		);

	fsm : process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state <= init;
			------
			else
				------- State Machine -------
				case state is
					when init =>
						lane_cntr  <= (others => '0');
						hword_cntr <= (others => '0');
						state      <= init_state_mem;

					when init_state_mem =>
						if hword_cntr = LAST_HWORD then
							if lane_cntr = LAST_LANE then
								lane_cntr     <= (others => '0');
								pre_last_flag <= '1';
								-- hword_cntr remains LAST_HWORD
								state         <= slice_read;
								round_cntr    <= (others => '0');
							else
								hword_cntr <= (others => '0');
								lane_cntr  <= lane_cntr + 1;
							end if;
						else
							hword_cntr <= hword_cntr + 1; -- uniformity for lane0 to save hardware and complexity
						end if;

					----- round states
					when slice_read =>
						if lane_cntr = LAST_LANE + 1 then -- 4 slices fully read
							lane_cntr <= (others => '0');
							state     <= slice_proc; -- process
						else
							lane_cntr <= lane_cntr + 1;
						end if;

					when slice_proc =>

						if lane_cntr = C_HALFWORD_WIDTH - 1 then -- all shifted out
							lane_cntr <= (others => '0');
							if pre_last_flag then
								pre_last_flag <= '0';
								-- skip write and restart from first slice
								hword_cntr    <= (others => '0');
								state         <= slice_read;
							else
								state     <= slice_write;
							end if;
						else
							lane_cntr <= lane_cntr + 1;
						end if;
					when slice_write =>
						if lane_cntr = LAST_LANE then -- 4 slices written back to state memory
							lane_cntr <= (others => '0');
							if hword_cntr = LAST_HWORD then
								hword_cntr <= (others => '0');

								if round_cntr = C_NUM_ROUNDS then -- round
									-- TODO all rounds complete
									round_cntr <= (others => '0');
									state      <= init_state_mem; -- FIXME
								else
									lane_cntr <= to_unsigned(1, lane_cntr'length); -- lane 0: no Rho, start from 1
									state     <= rho_read;
								end if;
							else
								hword_cntr <= hword_cntr + 1;
								state      <= slice_read;
							end if;
						else
							lane_cntr <= lane_cntr + 1;
						end if;

					when rho_read =>
						if hword_cntr = LAST_HWORD + 1 then
							hword_cntr <= (others => '0');
							state      <= rho_rotate;
						else
							hword_cntr <= hword_cntr + 1;
						end if;
					when rho_rotate =>
						if hword_cntr_lt_rho0q or hword_cntr_lt_rho1q then
							hword_cntr <= hword_cntr + 1;
						else
							hword_cntr <= (others => '0');
							state      <= rho_write;
						end if;
					when rho_write =>
						if hword_cntr = LAST_HWORD then
							hword_cntr <= (others => '0');
							if lane_cntr = LAST_LANE then
								round_cntr <= round_cntr + 1;
								lane_cntr  <= (others => '0');
								state      <= slice_read;
							else
								lane_cntr <= lane_cntr + 1;
								state     <= rho_read;
							end if;
						else
							hword_cntr <= hword_cntr + 1;

						end if;

				end case;

			end if;
		end if;
	end process fsm;

	mem_addr              <= resize(hword_cntr(hword_cntr'length - 1 downto 1), mem_addr'length) when lane_cntr = 0 else (lane_cntr - 1) & hword_cntr(3 downto 0) + C_LANE0_WORDS;
	out_do_lane0          <= '1' when lane_cntr = 0 else '0';
	out_do_bypass_iochipi <= '1' when round_cntr = 0 else '0';

	control_proc : process(all) is
	begin
		din_ready                 <= '0';
		dout_valid                <= '0';
		-- to datapath
		out_do_vertical           <= '0';
		out_do_hrotate            <= '0';
		out_do_shift_en0          <= '0';
		out_do_shift_en1          <= '0';
		mem_we                    <= '0';
		out_do_rho_out            <= '0';
		-- squeeze/absorb control
		out_do_xorin              <= '0'; -- TODO
		out_do_data_hi            <= '0'; -- TODO
		out_do_setzero_to_mem_din <= '0';
		out_do_theta  <=  '0';
		--
		out_do_odd_hword          <= hword_cntr(0);

		-- clock enable
		mem_ce <= '0';

		case state is
			when init =>
				null;
			when init_state_mem =>
				out_do_setzero_to_mem_din <= '1';
				mem_ce                    <= '1';
				mem_we                    <= '1';
			when slice_read =>
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				mem_ce           <= '1';
			when slice_proc =>
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				out_do_vertical  <= '1';
				if round_cntr /= C_NUM_ROUNDS then
					out_do_theta  <=  '1';
				end if;
				
			when slice_write =>
				mem_ce           <= '1';
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				mem_we           <= '1';
			when rho_read =>
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
				out_do_shift_en0 <= '1';
				out_do_shift_en1 <= '1';
				out_do_rho_out   <= '1';
				mem_ce           <= '1';
				mem_we           <= '1';
		end case;
		round <= round_cntr;
		k     <= hword_cntr(3 downto 0) & lane_cntr(1 downto 0); -- index to Iota ROM in slice_proc
	end process control_proc;

end architecture RTL;
