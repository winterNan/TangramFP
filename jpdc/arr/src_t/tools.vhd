library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tools is
	function clog2(n : natural) return natural;
	function flog2(n : natural) return natural;
	function max(a, b : integer) return integer;
	function min(a, b : integer) return integer;
	function stages(height : natural) return natural;
	function num_fa(dots, add, target : natural) return natural;
	function num_ha(dots, add, target : natural) return natural;
	function dots_left(dots, add, target : natural) return natural;
	function float_32_to_64 (f : std_logic_vector(31 downto 0))return std_logic_vector;
	function float_64_to_32 (f : std_logic_vector(63 downto 0)) return std_logic_vector;
end;

package body tools is

	function clog2 (n : natural) return natural is
		variable counter : natural;
		variable m : natural;
	begin
		m := n - 1;
		counter := 1;
		while (m > 1) loop
			m := m / 2;
			counter := counter + 1;
		end loop;
		return counter;
	end function;

	function flog2 (n : natural) return natural is
		variable counter : natural;
		variable m : natural;
	begin
		m := n;
		counter := 0;
		while (m > 1) loop
			m := m / 2;
			counter := counter + 1;
		end loop;
		return counter;
	end function;

	function max (a, b : integer) return integer is
	begin
		if (a > b) then
			return a;
		else
			return b;
		end if;
	end function;

	function min (a, b : integer) return integer is
	begin
		if (a < b) then
			return a;
		else
			return b;
		end if;
	end function;

	function num_fa(dots, add, target : natural) return natural is
	begin
		return min(dots / 3, max((dots + add - target) / 2, 0));
	end function;

	function num_ha(dots, add, target : natural) return natural is
		variable dots_left, target_left : natural;
	begin
		dots_left := dots - 2 * num_fa(dots, add, target);
		target_left := target - num_fa(dots, add, target);
		return min(dots_left / 2, max(dots_left + add - target, 0));
	end function;

	function stages(height : natural) return natural is
		variable h, count : natural;
	begin
		h := height;
		count := 0;
		while (h > 2) loop
			h := (h * 2 + 2) / 3;
			count := count + 1;
		end loop;
		return count;
	end function;

	function dots_left(dots, add, target : natural) return natural is
	begin
		return dots - 3 * num_fa(dots, add, target) - 2 * num_ha(dots, add, target);
	end function;
     --32 to 64 conversion
    function float_32_to_64 (f : std_logic_vector(31 downto 0))
           return std_logic_vector is
           variable exp_old : integer := to_integer(unsigned(f(30 downto 23)));
           variable exp : unsigned (10 downto 0) := (others=>'0');
           variable m : unsigned (22 downto 0):= unsigned(f(22 downto 0));
           variable shift_count : natural range 0 to 32 := 0;
           begin
               
   --            if (exp_old = 0)then
   --                for i in 22 downto 0 loop
   --                if m(i) = '1' then 
   --                    shift_count := 23-i;
   --                    exit;  -- Found first '1' in subnormal
   --                end if;
   --                end loop;
   --                exp := to_unsigned(1023 - shift_count,11);  -- Convert position to biased exponent
   --                m := shift_left(m, 23-shift_count); 
              if (exp_old > 0 and exp_old < 255 ) then
                   exp := to_unsigned((exp_old + 896), 11);
   --            elsif(exp = 0) then
   --            exp := (others => '0');
               elsif(exp_old > 254)then
                   exp := (others => '1');
               else
                   exp := (others => '0');
                   m:= (others => '0');
               end if;
           return f(31)& std_logic_vector(exp)&std_logic_vector(m) & std_logic_vector(to_unsigned(0,29));
       end function;
       
       function float_64_to_32 (f : std_logic_vector(63 downto 0))
       return std_logic_vector is
           variable v : integer := 16777215;
           variable exp :unsigned(10 downto 0) := unsigned(f(62 downto 52));
           variable mantissa : unsigned (24 downto 0) :=  '0'& unsigned(f(51 downto 28)) +1;
           begin
               if (to_integer(exp) < 873)then 
                   exp := (others=> '0');
                   mantissa := (others => '0');
               
               elsif (to_integer(exp) > 872 and to_integer(exp) < 897)then
                   report integer'image(to_integer(mantissa));
                   mantissa := mantissa + to_unsigned(16777215,25);
                   report integer'image(to_integer(mantissa));
                   mantissa := shift_right(mantissa, (897 - to_integer(exp))) +1;
                   report integer'image(to_integer(mantissa));
                   mantissa := shift_right(mantissa, 1);
                   report integer'image(to_integer(mantissa));
                   exp := (others=> '0');
               elsif (to_integer(exp) > 896)then
                   exp := exp - 896;
                   mantissa := shift_right(mantissa, 1);
               elsif (to_integer(exp) > 1150) then
                   exp := (others=> '1');
               else 
                   exp := (others=> '0');
                   mantissa := (others => '0');
               end if;
               
           return f(63)& std_logic_vector(exp(7 downto 0)) & std_logic_vector(mantissa(22 downto 0));
   end function;
end package body;
