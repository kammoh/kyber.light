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
	-----------------------------------------------------------=( Types (1) )=-----------------------------------------------------------------------
	-----------------------------------------------------------=( Functions )=-----------------------------------------------------------------------
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
	-- computer greatest common divisor of a , b
	function gcd(a, b : positive) return positive;
	--
	-- computer least common multiplier of a , b
	function lcm(a, b : positive) return positive;
	--
	------------------------------------------------------------=( Parameters )=---------------------------------------------------------------------	
	constant KYBER_K             : positive := 3; -- 2: Kyber512, 3: Kyber768 (recommended), 4: KYBER1024
	--
	------------------------------------------------------------=( Constants )=----------------------------------------------------------------------	
	constant KYBER_Q             : positive := 7681;
	constant KYBER_N             : positive := 256;
	constant KYBER_ETA           : positive := 7 - KYBER_K; -- 5: Kyber512, 4: Kyber768 (recommended), 3: KYBER1024
	constant KYBER_COEF_BITS     : positive := log2ceilnz(KYBER_Q); -- 13
	constant KYBER_Q_US          : unsigned := to_unsigned(KYBER_Q, KYBER_COEF_BITS);
	constant KYBER_SYMBYTES      : positive := 32;
	------------------------------------------------------------=( Types (2) )=-----------------------------------------------------------------------
	subtype T_coef_slv is std_logic_vector(KYBER_COEF_BITS - 1 downto 0);
	subtype T_coef_us is unsigned(KYBER_COEF_BITS - 1 downto 0);
	subtype T_byte_slv is std_logic_vector(7 downto 0);
	subtype T_byte_us is unsigned(7 downto 0);
	--
	--
	------------------------------------------------------------=( Synthesis )=-------------------------------------------------
	--
	constant MEM_TECH : string := "SAED_MC";
	
	--
	attribute DONT_TOUCH_NETWORK : boolean;
	--
	attribute DONT_TOUCH         : boolean;
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
			return half_adder(a(2), a(1)) + a(0);
		else
			return ("0" & popcount(a_copy(n - 1 downto h))) + popcount(a_copy(h - 1 downto 0));
		end if;
	end function;

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
