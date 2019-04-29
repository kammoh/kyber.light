--===================================================================================================================--
-----------------------------------------------------------------------------------------------------------------------
--                                  
--                                  
--                                    8"""""o   8"""""   8""""o    8"""""o 
--                                    8     "   8        8    8    8     " 
--                                    8e        8eeeee   8eeee8o   8o     
--                                    88        88       88    8   88   ee 
--                                    88    e   88       88    8   88    8 
--                                    68eeee9   888eee   88    8   888eee8 
--                                  
--                                  
--                                  Cryptographic Engineering Research Group
--                                          George Mason University
--                                       https://cryptography.gmu.edu/
--                                  
--                                  
-----------------------------------------------------------------------------------------------------------------------
--
--  unit name: full name (shortname / entity name)
--              
--! @file      .vhdl
--
--! @language  VHDL 93,02,08
--
--! @brief     <file content, behavior, purpose, special usage notes>
--
--! @author    <Kamyar Mohajerani (kamyar@ieee.org)>
--
--! @company   Cryptographic Engineering Research Group, George Mason University
--
--! @project   KyberLight: Lightweight hardware implementation of CRYSTALS-KYBER PQC
--
--! @context   Post-Quantum Cryptography
--
--! @license   
--
--! @copyright Copyright 2019 Kamyar Mohajerani. All rights reserved.
--  
--! @date      <02/01/2019>
--
--! @version   <v0.1>
--
--! @details   blah blah
--!
--
--
--! <b>Dependencies:</b>\n
--! <Entity Name,...>
--!
--! <b>References:</b>\n
--! <reference one> \n
--! <reference two>
--!
--! <b>Modified by:</b>\n
--! Author: Kamyar Mohajerani
-----------------------------------------------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! <date> KM: <log>\n
--! <extended description>
-----------------------------------------------------------------------------------------------------------------------
--! @todo <next thing to do> \n
--
-----------------------------------------------------------------------------------------------------------------------
--===================================================================================================================--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package kyber_pkg is
	--------------------------------------------=( Types (1) )=--------------------------------------------------------
	--------------------------------------------=( Functions )=--------------------------------------------------------
	---- IEEE proposed

	function MINIMUM(L, R : INTEGER) return INTEGER;
	function MAXIMUM(L, R : INTEGER) return INTEGER;

	function maximum(
		l, r : UNSIGNED)                -- inputs
	return UNSIGNED;

	function maximum(
		l, r : SIGNED)                  -- inputs
	return SIGNED;

	function minimum(
		l, r : UNSIGNED)                -- inputs
	return UNSIGNED;

	function minimum(
		l, r : SIGNED)                  -- inputs
	return SIGNED;

	function maximum(
		l : UNSIGNED; r : NATURAL)      -- inputs
	return UNSIGNED;

	function maximum(
		l : SIGNED; r : INTEGER)        -- inputs
	return SIGNED;

	function minimum(
		l : UNSIGNED; r : NATURAL)      -- inputs
	return UNSIGNED;

	function minimum(
		l : SIGNED; r : INTEGER)        -- inputs
	return SIGNED;

	function maximum(
		l : NATURAL; r : UNSIGNED)      -- inputs
	return UNSIGNED;

	function maximum(
		l : INTEGER; r : SIGNED)        -- inputs
	return SIGNED;

	function minimum(
		l : NATURAL; r : UNSIGNED)      -- inputs
	return UNSIGNED;

	function minimum(
		l : INTEGER; r : SIGNED)        -- inputs
	return SIGNED;
	------

	-- extends maximum for 3 integers
	function maximum(arg1 : integer; arg2 : integer; arg3 : integer) return integer;
	--
	-- counts number of 1s in 'a'
	function popcount(a : std_logic_vector) return unsigned;
	--
	-- Half adder
	function half_adder(a, b : std_logic) return unsigned;
	--
	-- ceiling(log2(arg))
	function log2ceil(arg : positive) return natural;
	--
	-- return log2; always rounded up; the return value is >= 1
	function log2ceilnz(arg : positive) return positive;
	--
	-- returns ceiling(numerator/denominator)
	function ceil_div(numerator : natural; denominator : positive) return natural;
	--
	-- Print parameters upon instantiation of a module; 
	-- to use: define a dummy (or actual) constant and initialize using this function
	function INSTANTIATE(name : string; msg : string) return string;
	--
	--! computes the Greatest Common Divisor of a , b
	function gcd(a, b : positive) return positive;
	--
	--! computes the Least Common Multiplier of a , b
	function lcm(a, b : positive) return positive;
	--
	--! Decoder with variable sized output (power of 2)
	function decode(Sel : unsigned) return std_logic_vector;
	--
	--! Decoder with variable sized output (user specified)
	function decode(Sel : unsigned; Size : positive) return std_logic_vector;
	--
	--! Decoder with variable sized output (power of 2)
	function decode(Sel : std_logic_vector) return std_logic_vector;
	--! Decoder with variable sized output (user specified) and enable
	function decode(en : std_logic; Sel : unsigned) return std_logic_vector;
	--! Decoder with variable sized output (user specified) and enable
	function decode(en : std_logic; Sel : std_logic_vector) return std_logic_vector;

	function shift_in_left(arg : std_logic_vector; bit : std_logic) return std_logic_vector;

	--! get the most-significant (highest indexed) bit 
	function msb(arg : std_logic_vector) return std_logic;
	--
	function msb(arg : unsigned) return std_logic;
	--
	function msb(arg : signed) return std_logic;
	--
	function KYBER_Q return positive;
	--
	function KYBER_ETA return positive;
	--
	function KYBER_POLYVECCOMPRESSEDBYTES return positive;
	--
	function KYBER_POLYCOMPRESSEDBYTES return positive;
	--
	--------------------------------------------=( Synthesis )=--------------------------------------------------------
	--
	type T_TECHNOLOGY is (XILINX, SAED32);
	attribute DONT_TOUCH_NETWORK : boolean;
	--
	attribute DONT_TOUCH         : boolean;
	--
	--------------------------------------------=( Parameters )=-------------------------------------------------------	
	constant NIST_ROUND          : positive := 2;
	constant KYBER_K             : positive := 3; -- 2: Kyber512, 3: Kyber768 (recommended), 4: KYBER1024

	--
	--------------------------------------------=( Synthesis Parameters )=---------------------------------------------
	constant TECHNOLOGY : T_TECHNOLOGY := XILINX; -- Synthesis technology

	--------------------------------------------=( Interface )=--------------------------------------------------------	
	constant C_CPA_CMD_BITS   : positive := 3;
	constant CMD_RECV_PK      : positive := 1;
	constant CMD_START_ENC    : positive := 2;
	constant CMD_RECV_SK      : positive := 3;
	constant CMD_RECV_SK_US   : unsigned := to_unsigned(CMD_RECV_SK, C_CPA_CMD_BITS);
	constant CMD_START_DEC    : positive := 4;
	constant CMD_START_DEC_US : unsigned := to_unsigned(CMD_START_DEC, C_CPA_CMD_BITS);
	--------------------------------------------=( Constants )=--------------------------------------------------------	
	constant KYBER_N          : positive := 256;

	--
	constant KYBER_COEF_BITS : positive := log2ceilnz(KYBER_Q);
	constant KYBER_Q_US      : unsigned := to_unsigned(KYBER_Q, KYBER_COEF_BITS);
	constant KYBER_Q_S       : signed   := to_signed(KYBER_Q, KYBER_COEF_BITS);
	constant KYBER_SYMBYTES  : positive := 32;

	constant C_DIVIDER_PIPELINE_LEVELS : natural := 3;

	function POLYVEC_SHIFT return positive;
	function POLY_SHIFT return positive;

	--------------------------------------------=( Types (2) )=--------------------------------------------------------
	subtype T_coef_slv is std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	subtype T_coef_us is unsigned(KYBER_COEF_BITS - 1 downto 0);
	subtype T_byte_slv is std_logic_vector(7 downto 0);
	subtype T_byte_us is unsigned(7 downto 0);
	--
end package kyber_pkg;

package body kyber_pkg is

	function KYBER_Q return positive is
	begin
		if NIST_ROUND = 1 then
			return 7681;
		else
			return 3329;
		end if;
	end function;

	function KYBER_ETA return positive is
	begin
		if NIST_ROUND = 1 then
			return 7 - KYBER_K;
		else
			return 2;
		end if;
	end function;

	function KYBER_POLYCOMPRESSEDBYTES return positive is
	begin
		if NIST_ROUND = 1 then
			return 96;
		else
			return 128;
		end if;
	end function;

	function KYBER_POLYVECCOMPRESSEDBYTES return positive is
	begin
		if NIST_ROUND = 1 then
			return KYBER_K * 352;
		else
			return KYBER_K * 320;
		end if;
	end function;

	function POLYVEC_SHIFT return positive is
	begin
		if KYBER_Q = 7681 then
			return 11;
		else
			return 10;
		end if;
	end function;

	function POLY_SHIFT return positive is
	begin
		if KYBER_Q = 7681 then
			return 3;
		else
			return 4;
		end if;
	end function;

	function half_adder(a, b : std_logic) return unsigned is
		variable ret : unsigned(1 downto 0);
	begin
		ret(0) := a xor b;
		ret(1) := a and b;
		return ret;
	end function;

	function popcount(a : std_logic_vector) return unsigned is
		variable n      : positive                         := a'length;
		variable h      : natural                          := n / 2;
		variable a_copy : std_logic_vector(n - 1 downto 0) := a; -- required for GHDL at least?
	begin
		if n = 2 then
			return half_adder(a_copy(1), a_copy(0));
		elsif n = 3 then
			return half_adder(a(2), a(1)) + ('0' & a(0));
		else
			return ("0" & popcount(a_copy(n - 1 downto h))) + popcount(a_copy(h - 1 downto 0));
		end if;
	end function;

	-------- IEEE 2008 (additions)
	--============================================================================
	-- Id: C.43

	constant NAU        : UNSIGNED(0 downto 1) := (others => '0');
	constant NAS        : SIGNED(0 downto 1)   := (others => '0');
	constant NO_WARNING : BOOLEAN              := false; -- default to emit warnings
	function MAX(left, right : INTEGER) return INTEGER is
	begin
		if left > right then
			return left;
		else
			return right;
		end if;
	end function MAX;

	function MINIMUM(L, R : INTEGER) return INTEGER is
	begin
		if L > R then
			return R;
		else
			return L;
		end if;
	end function MINIMUM;

	function MAXIMUM(L, R : INTEGER) return INTEGER is
	begin
		if L > R then
			return L;
		else
			return R;
		end if;
	end function MAXIMUM;

	function TO_STRING(VALUE : INTEGER) return STRING is
	begin
		return INTEGER'image(VALUE);
	end function TO_STRING;

	function MINIMUM(L, R : REAL) return REAL is
	begin
		if L > R then
			return R;
		else
			return L;
		end if;
	end function MINIMUM;

	function MAXIMUM(L, R : UNSIGNED) return UNSIGNED is
		constant SIZE : NATURAL := MAX(L'length, R'length);
		variable L01  : UNSIGNED(SIZE - 1 downto 0);
		variable R01  : UNSIGNED(SIZE - 1 downto 0);
	begin
		if ((L'length < 1) or (R'length < 1)) then
			return NAU;
		end if;
		L01 := TO_01(RESIZE(L, SIZE), 'X');
		if (L01(L01'left) = 'X') then
			return L01;
		end if;
		R01 := TO_01(RESIZE(R, SIZE), 'X');
		if (R01(R01'left) = 'X') then
			return R01;
		end if;
		if L01 < R01 then
			return R01;
		else
			return L01;
		end if;
	end function MAXIMUM;

	-- signed output
	function MAXIMUM(L, R : SIGNED) return SIGNED is
		constant SIZE : NATURAL := MAX(L'length, R'length);
		variable L01  : SIGNED(SIZE - 1 downto 0);
		variable R01  : SIGNED(SIZE - 1 downto 0);
	begin
		if ((L'length < 1) or (R'length < 1)) then
			return NAS;
		end if;
		L01 := TO_01(RESIZE(L, SIZE), 'X');
		if (L01(L01'left) = 'X') then
			return L01;
		end if;
		R01 := TO_01(RESIZE(R, SIZE), 'X');
		if (R01(R01'left) = 'X') then
			return R01;
		end if;
		if L01 < R01 then
			return R01;
		else
			return L01;
		end if;
	end function MAXIMUM;

	-- UNSIGNED output
	function MINIMUM(L, R : UNSIGNED) return UNSIGNED is
		constant SIZE : NATURAL := MAX(L'length, R'length);
		variable L01  : UNSIGNED(SIZE - 1 downto 0);
		variable R01  : UNSIGNED(SIZE - 1 downto 0);
	begin
		if ((L'length < 1) or (R'length < 1)) then
			return NAU;
		end if;
		L01 := TO_01(RESIZE(L, SIZE), 'X');
		if (L01(L01'left) = 'X') then
			return L01;
		end if;
		R01 := TO_01(RESIZE(R, SIZE), 'X');
		if (R01(R01'left) = 'X') then
			return R01;
		end if;
		if L01 < R01 then
			return L01;
		else
			return R01;
		end if;
	end function MINIMUM;

	-- signed output
	function MINIMUM(L, R : SIGNED) return SIGNED is
		constant SIZE : NATURAL := MAX(L'length, R'length);
		variable L01  : SIGNED(SIZE - 1 downto 0);
		variable R01  : SIGNED(SIZE - 1 downto 0);
	begin
		if ((L'length < 1) or (R'length < 1)) then
			return NAS;
		end if;
		L01 := TO_01(RESIZE(L, SIZE), 'X');
		if (L01(L01'left) = 'X') then
			return L01;
		end if;
		R01 := TO_01(RESIZE(R, SIZE), 'X');
		if (R01(R01'left) = 'X') then
			return R01;
		end if;
		if L01 < R01 then
			return L01;
		else
			return R01;
		end if;
	end function MINIMUM;

	-- Id: C.39
	function MINIMUM(L : NATURAL; R : UNSIGNED)
	return UNSIGNED is
	begin
		return MINIMUM(TO_UNSIGNED(L, R'length), R);
	end function MINIMUM;

	-- Id: C.40
	function MINIMUM(L : INTEGER; R : SIGNED)
	return SIGNED is
	begin
		return MINIMUM(TO_SIGNED(L, R'length), R);
	end function MINIMUM;

	-- Id: C.41
	function MINIMUM(L : UNSIGNED; R : NATURAL)
	return UNSIGNED is
	begin
		return MINIMUM(L, TO_UNSIGNED(R, L'length));
	end function MINIMUM;

	-- Id: C.42
	function MINIMUM(L : SIGNED; R : INTEGER)
	return SIGNED is
	begin
		return MINIMUM(L, TO_SIGNED(R, L'length));
	end function MINIMUM;

	-- Id: C.45
	function MAXIMUM(L : NATURAL; R : UNSIGNED)
	return UNSIGNED is
	begin
		return MAXIMUM(TO_UNSIGNED(L, R'length), R);
	end function MAXIMUM;

	-- Id: C.46
	function MAXIMUM(L : INTEGER; R : SIGNED)
	return SIGNED is
	begin
		return MAXIMUM(TO_SIGNED(L, R'length), R);
	end function MAXIMUM;

	-- Id: C.47
	function MAXIMUM(L : UNSIGNED; R : NATURAL)
	return UNSIGNED is
	begin
		return MAXIMUM(L, TO_UNSIGNED(R, L'length));
	end function MAXIMUM;

	-- Id: C.48
	function MAXIMUM(L : SIGNED; R : INTEGER)
	return SIGNED is
	begin
		return MAXIMUM(L, TO_SIGNED(R, L'length));
	end function MAXIMUM;

	function MAXIMUM(L, R : STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR is
	begin
		return STD_ULOGIC_VECTOR(MAXIMUM(UNSIGNED(L), UNSIGNED(R)));
	end function MAXIMUM;

	-- Id: C.45
	function MAXIMUM(L : NATURAL; R : STD_ULOGIC_VECTOR) return STD_ULOGIC_VECTOR is
	begin
		return STD_ULOGIC_VECTOR(MAXIMUM(L, UNSIGNED(R)));
	end function MAXIMUM;

	-- Id: C.47
	function MAXIMUM(L : STD_ULOGIC_VECTOR; R : NATURAL) return STD_ULOGIC_VECTOR is
	begin
		return STD_ULOGIC_VECTOR(MAXIMUM(UNSIGNED(L), R));
	end function MAXIMUM;

	----

	function maximum(arg1 : integer; arg2 : integer; arg3 : integer) return integer is
	begin
		return maximum(arg1, maximum(arg2, arg3));
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

	function ceil_div(numerator : natural; denominator : positive)
	return natural is

	begin
		return (numerator + denominator - 1) / denominator;
	end function ceil_div;

	function log2ceilnz(arg : positive) return positive is
	begin
		return maximum(1, log2ceil(arg));
	end function;

	function INSTANTIATE(name : string; msg : string) return string is
	begin
		report "instantiating " & name & " => "  & msg;
		return "instantiating " & name & " => " & msg;
	end function;

	function gcd(a, b : positive) return positive is
		variable x : positive := a;
		variable y : natural  := b;
		variable r : natural;
	begin
		while y /= 0 loop
			r := x mod y;
			x := y;
			y := r;
		end loop;
		return x;
	end function;

	function lcm(a, b : positive) return positive is
	begin
		return (a * b) / gcd(a, b);
	end function;

	--
	function decode(Sel : unsigned) return std_logic_vector is

		variable result : std_logic_vector(0 to (2 ** Sel'length) - 1);
	begin
		-- generate the one-hot vector from binary encoded Sel
		result                  := (others => '0');
		result(to_integer(Sel)) := '1';
		return result;
	end function;
	--
	function decode(en : std_logic; Sel : unsigned) return std_logic_vector is

		variable result : std_logic_vector(0 to (2 ** Sel'length) - 1);
	begin
		-- generate the one-hot vector from binary encoded Sel
		result                  := (others => '0');
		result(to_integer(Sel)) := en;
		return result;
	end function;
	--
	function decode(Sel : unsigned; Size : positive)
	return std_logic_vector is

		variable full_result : std_logic_vector(0 to (2 ** Sel'length) - 1);
	begin
		assert Size <= 2 ** Sel'length
		report "Decoder output size: " & integer'image(Size)
        & " is too big for the selection vector"
		severity failure;

		full_result := decode(Sel);
		return full_result(0 to Size - 1);
	end function;

	function decode(Sel : std_logic_vector) return std_logic_vector is
	begin
		return decode(unsigned(Sel));
	end function;
	--
	function decode(en : std_logic; Sel : std_logic_vector) return std_logic_vector is
	begin
		return decode(en, unsigned(Sel));
	end function;

	function shift_in_left(arg : std_logic_vector; bit : std_logic) return std_logic_vector is
	begin
		return arg(arg'length - 2 downto 0) & bit;
	end function;

	function msb(arg : std_logic_vector) return std_logic is
	begin
		return arg(arg'length - 1);
	end;

	function msb(arg : unsigned) return std_logic is
	begin
		return arg(arg'length - 1);
	end;

	function msb(arg : signed) return std_logic is
	begin
		return arg(arg'length - 1);
	end;

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
