library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package kyber_pkg is
	-------------------------------------------------------------------------------------------------------------------
	----------------------------------------------- Types (1) ---------------------------------------------------------
	----------------------------------------------- Functions ---------------------------------------------------------
	function imax(arg1 : integer; arg2 : integer) return integer;
	function imax(arg1 : integer; arg2 : integer; arg3 : integer) return integer;
	function log2ceil(arg : positive) return natural;
	function log2ceilnz(arg : positive) return positive;
	-------------------------------------------------------------------------------------------------------------------
	----------------------------------------------- Constants ---------------------------------------------------------	
	constant KYBER_Q         : positive := 7681;
	constant KYBER_N         : positive := 256;
	constant KYBER_K         : positive := 3; -- 2: Kyber512, 3: Kyber768 (recommended), 4: KYBER1024
	constant KYBER_ETA       : positive := 4; -- 5: Kyber512, 4: Kyber768 (recommended), 3: KYBER1024
	constant KYBER_COEF_BITS : positive := log2ceilnz(KYBER_Q); -- 13
	----------------------------------------------- Types (2) ---------------------------------------------------------
	subtype t_coef_slv is std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	subtype t_coef_us is unsigned(KYBER_COEF_BITS - 1 downto 0);
	-------------------------------------------------------------------------------------------------------------------
	----------------------------------------- std_logic_1164_additions ------------------------------------------------
	---------------------------------------- only required for VHDL < 2008 --------------------------------------------
	--	function to_hstring(value : STD_ULOGIC_VECTOR) return STRING;
	--	function to_hstring(value : STD_LOGIC_VECTOR) return STRING;
	--	function to_string(value : STD_ULOGIC_VECTOR) return STRING;
	--	function to_string(value : STD_LOGIC_VECTOR) return STRING;
	--	function to_string(value : integer) return STRING;
	--	function to_string(value : time) return STRING;
	--	function to_hstring(value : bit_vector) return STRING;
end package kyber_pkg;

package body kyber_pkg is

	function imax(arg1 : integer; arg2 : integer) return integer is
	begin
		if arg1 > arg2 then
			return arg1;
		end if;
		return arg2;
	end function;

	function imax(arg1 : integer; arg2 : integer; arg3 : integer) return integer is
	begin
		return imax(arg1, imax(arg2, arg3));
	end function;

	-- return log2; always rounded up
	function log2ceil(arg : positive) return natural is
		variable tmp : positive;
		variable log : natural;
	begin
		if arg = 1 then
			return 0;
		end if;
		tmp := 1;
		log := 0;
		while arg > tmp loop
			tmp := tmp * 2;
			log := log + 1;
		end loop;
		return log;
	end function;

	-- return log2; always rounded up; the return value is >= 1
	function log2ceilnz(arg : positive) return positive is
	begin
		return imax(1, log2ceil(arg));
	end function;

	-------------------------------------------------------------------------------------------------------------------
	----------------------------------------- std_logic_1164_additions ------------------------------------------------
	---------------------------------------- only required for VHDL < 2008 --------------------------------------------

	--	constant NBSP : CHARACTER      := CHARACTER'val(160); -- space character
	--	constant NUS  : STRING(2 to 1) := (others => ' '); -- null STRING
	--
	--	type char_indexed_by_MVL9 is array (STD_ULOGIC) of CHARACTER;
	--	constant MVL9_to_char : char_indexed_by_MVL9 := "UX01ZWLH-";
	--
	--	function to_hstring(value : STD_ULOGIC_VECTOR) return STRING is
	--		constant ne     : INTEGER := (value'length + 3) / 4;
	--		variable pad    : STD_ULOGIC_VECTOR(0 to (ne * 4 - value'length) - 1);
	--		variable ivalue : STD_ULOGIC_VECTOR(0 to ne * 4 - 1);
	--		variable result : STRING(1 to ne);
	--		variable quad   : STD_ULOGIC_VECTOR(0 to 3);
	--	begin
	--		if value'length < 1 then
	--			return NUS;
	--		else
	--			if value(value'left) = 'Z' then
	--				pad := (others => 'Z');
	--			else
	--				pad := (others => '0');
	--			end if;
	--			ivalue := pad & value;
	--			for i in 0 to ne - 1 loop
	--				quad := To_X01Z(ivalue(4 * i to 4 * i + 3));
	--				case quad is
	--					when x"0"   => result(i + 1) := '0';
	--					when x"1"   => result(i + 1) := '1';
	--					when x"2"   => result(i + 1) := '2';
	--					when x"3"   => result(i + 1) := '3';
	--					when x"4"   => result(i + 1) := '4';
	--					when x"5"   => result(i + 1) := '5';
	--					when x"6"   => result(i + 1) := '6';
	--					when x"7"   => result(i + 1) := '7';
	--					when x"8"   => result(i + 1) := '8';
	--					when x"9"   => result(i + 1) := '9';
	--					when x"A"   => result(i + 1) := 'A';
	--					when x"B"   => result(i + 1) := 'B';
	--					when x"C"   => result(i + 1) := 'C';
	--					when x"D"   => result(i + 1) := 'D';
	--					when x"E"   => result(i + 1) := 'E';
	--					when x"F"   => result(i + 1) := 'F';
	--					when "ZZZZ" => result(i + 1) := 'Z';
	--					when others => result(i + 1) := 'X';
	--				end case;
	--			end loop;
	--			return result;
	--		end if;
	--	end function to_hstring;
	--
	--	function to_string(value : STD_ULOGIC_VECTOR) return STRING is
	--		alias ivalue    : STD_ULOGIC_VECTOR(1 to value'length) is value;
	--		variable result : STRING(1 to value'length);
	--	begin
	--		if value'length < 1 then
	--			return NUS;
	--		else
	--			for i in ivalue'range loop
	--				result(i) := MVL9_to_char(iValue(i));
	--			end loop;
	--			return result;
	--		end if;
	--	end function to_string;
	--
	--	function to_string(value : STD_LOGIC_VECTOR) return STRING is
	--	begin
	--		return to_string(to_stdulogicvector(value));
	--	end function to_string;
	--
	--	function to_string(value : integer) return STRING is
	--	begin
	--		return integer'image(value);
	--	end function to_string;
	--
	--	function to_string(value : time) return STRING is
	--	begin
	--		return time'image(value);
	--	end function to_string;
	--
	--	function to_hstring(value : STD_LOGIC_VECTOR) return STRING is
	--	begin
	--		return to_hstring(to_stdulogicvector(value));
	--	end function to_hstring;
	--
	--	function to_hstring(value : bit_vector) return STRING is
	--	begin
	--		return to_hstring(to_stdlogicvector(value));
	--	end function to_hstring;

end package body kyber_pkg;
