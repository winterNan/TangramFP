----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/18/2024 03:28:24 PM
-- Design Name: 
-- Module Name: mac_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;
use std.textio.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
  
entity mac_tb is
generic (precision : integer range 0 to 32 := 16; precision32 : integer range 0 to 64 := 32;
                    exp_width: integer:= 5;man_width : integer := 10;
                    exp_width32 : integer:= 8;man_width32 : integer := 23);
end mac_tb;

architecture Behavioral of mac_tb is

    function is_x(v: std_logic_vector) return boolean is
    begin
        for i in v'range loop
            if v(i) = 'X' or v(i) = 'U' then
                return true;
            end if;
        end loop;
        return false;
    end function;

    procedure generate_aligned_random_vectors(seed1, seed2: inout positive; 
              rout_a,rout_b,rout_c: out std_logic_vector(precision-1 downto 0)) is
        variable r1, r2, r3, rm1,rm2,rm3: real;
        variable exp_a, exp_b, exp_c: integer;
        variable man1,man2,man3: natural;
        variable s1,s2,s3 : std_logic;
        constant max_exp: integer := 15;  -- Maximum exponent for float16
        constant min_exp: integer := -14; -- Minimum exponent for normalized float16
        constant alignment_shifts: integer := 10;
    begin
        -- Generate random numbers for a and b
        uniform(seed1, seed2, r1);
        r1 := (r1 * 2.0 - 1.0);  -- Range [-1,1]
        uniform(seed1, seed2, r2);
        r2 := (r2 * 2.0 - 1.0);  -- Range [-1,1]
        
        -- Generate random number for c
        uniform(seed1, seed2, r3);
        r3 := (r3 * 2.0 - 1.0);  -- Range [-1,1]
        
        uniform(seed1, seed2, rm1);
        uniform(seed1, seed2, rm2);
        uniform(seed1, seed2, rm3);
        man1 := integer(rm1*1023.0);
        man2 := man1 + integer(rm2*2.0);
        man3 := man1 - integer(rm3*2.0)
        
        -- Generate exponents for a and b
        uniform(seed1, seed2, r1);
        exp_a := integer(r1 * ( real(max_exp)-real(min_exp))) + min_exp;  -- Range [-14,15]
        uniform(seed1, seed2, r2);
        exp_b := integer(r2 * ( real(max_exp)-real(min_exp))) + min_exp;  -- Range [-14,15]

        -- Ensure the product of a and b does not exceed the max/min values of fp-16
        if exp_a + exp_b + alignment_shifts > max_exp then
            if (exp_a>exp_b) then
                exp_a := max_exp - exp_b - alignment_shifts;
            else
                exp_b := max_exp - exp_a- alignment_shifts;
            end if;
        elsif exp_a + exp_b < min_exp then
            if exp_a < exp_b then
                exp_a := min_exp - exp_b;
            else 
                exp_b := min_exp - exp_a;
            end if;
        end if;

        -- Ensure the exponent of c is greater than the sum of exponents of a and b minus alignment shifts
        -- value of exp_c that results in a specific multiplication mode
        exp_c := exp_a + exp_b + alignment_shifts;
        if exp_c > max_exp then
            exp_c := max_exp;
        elsif exp_c < min_exp then
            exp_c := min_exp;
        end if;

        if rm1 > 0.5 then
            s1 := '0';
        else
            s1 := '1';
        end if;
        if rm2  > 0.5 then
            s2 := '0';
        else
            s2 := '1';
        end if;
        if rm3  > 0.5 then
            s3 := '0';
        else
            s3 := '1';
        end if;
            rout_a := s1 & std_logic_vector(to_unsigned(exp_a+max_exp, exp_width)) & std_logic_vector(to_unsigned(man1, man_width));
        
            rout_b := s2 & std_logic_vector(to_unsigned(exp_b+max_exp, exp_width)) & std_logic_vector(to_unsigned(man2, man_width));
        
            rout_c := s3 & std_logic_vector(to_unsigned(exp_c+max_exp, exp_width)) & std_logic_vector(to_unsigned(man3, man_width));
    end procedure;

    
    --function to convert fp_64 to fp 32
    function float_to_half (f : std_logic_vector(precision32-1 downto 0))
    return std_logic_vector is
        variable v : integer := 1023;
        variable exp :unsigned(7 downto 0) := unsigned(f(precision32-2 downto 23));
        variable mantissa : unsigned (11 downto 0) :=  '0'& unsigned(f(22 downto 12)) +1;
        begin
            if (to_integer(exp) < 102)then 
                exp := (others=> '0');
                mantissa := (others => '0');
            
            elsif (to_integer(exp) > 101 and to_integer(exp) < 113)then
                report integer'image(to_integer(mantissa));
                mantissa := mantissa + to_unsigned(v,10);
                report integer'image(to_integer(mantissa));
                mantissa := shift_right(mantissa, (125 - to_integer(exp))) +1;
                report integer'image(to_integer(mantissa));
                mantissa := shift_right(mantissa, 1);
                report integer'image(to_integer(mantissa));
                exp := (others=> '0');
            elsif (to_integer(exp) > 112)then
                exp := exp - 112;
                mantissa := shift_right(mantissa, 1);
            elsif (to_integer(exp) > 143) then
                exp := (others=> '1');
            else 
                exp := (others=> '0');
                mantissa := (others => '0');
            end if;
            
        return f(31)& std_logic_vector(exp(4 downto 0)) & std_logic_vector(mantissa(9 downto 0));
end function;
    -- Function to convert real to IEEE-754
    function real_to_float(r : real) return std_logic_vector is
        variable exp : integer := 0;
        variable mantissa : real:= abs(r);
        variable sign : std_logic:='0';
        variable mantissa_bits : std_logic_vector(man_width32-1 downto 0):= (others => '0');
        variable exponent_bits : std_logic_vector(exp_width32-1 downto 0):= (others => '0');
        variable result : std_logic_vector(precision32-1 downto 0):= (others => '0');
    begin
        -- Add conversion logic here
     if r=0.0 then
        return result;
     else
        if (r < 0.0)then
            sign := '1';
        else 
            sign := '0';
        end if;
        while mantissa >= 2.0 loop
            mantissa := mantissa / 2.0;
            exp := exp + 1;
        end loop;
        while mantissa < 1.0  loop
            mantissa := mantissa * 2.0;
            exp := exp - 1;
        end loop;

        -- Bias the exponent
        exp := exp + 127;

        -- Convert mantissa to binary
        mantissa_bits := std_logic_vector(to_unsigned(integer(mantissa * 2.0**23), 23));
        exponent_bits := std_logic_vector(to_unsigned(exp, 8));

        -- Combine to form FP32
        result := sign & exponent_bits & mantissa_bits;
        return result;
        end if;
    end function;
    -- Function to convert IEEE-exp_width-154 to real
        function float32_to_real(f : std_logic_vector(precision32-1 downto 0)) return real is
            variable sign : real;
            variable exp : natural;
            variable mantissa : real;
            constant bias: integer := 127;
        begin
            -- Add conversion logic here
                if f(precision32-1) = '0' then
                sign := 1.0;
            else
                sign := -1.0;
            end if;
            exp := to_integer(unsigned(f(precision32-2 downto man_width32)))- bias;
            report "exp addded" & integer'image(exp);
             mantissa := 1.0; -- The implicit 1 in IEEE exp_width-154 representation
               for i in man_width32-1 downto 0 loop
                   report "Loop iteration: " & integer'image(i) & " bit value: " & std_logic'image(f(i));           
                   if (f(i) = '1' )then
                       mantissa := mantissa + 2.0 ** ( i - man_width32);
                       report "mantissa addded";
                   end if;
               end loop;
            return sign * mantissa * 2.0 **exp ;--+(2.0**(-29)))
        end function;
    -- Function to convert IEEE-exp_width-154 to real
    function float_to_real(f : std_logic_vector(precision-1 downto 0)) return real is
        variable sign : real;
        variable exp : natural;
        variable mantissa : real;
        constant bias: integer := 15;
    begin
        -- Add conversion logic here
        if (f = "0000000000000000") then 
            return 0.0;
        end if;
            if f(precision-1) = '0' then
            sign := 1.0;
        else
            sign := -1.0;
        end if;
        exp := to_integer(unsigned(f(precision-2 downto man_width)))- bias;---bias +127;
        report "exp addded" & integer'image(exp);


         mantissa := 1.0; -- The implicit 1 in IEEE exp_width-154 representation
           for i in man_width-1 downto 0 loop
               report "Loop iteration: " & integer'image(i) & " bit value: " & std_logic'image(f(i));           
               if (f(i) = '1' )then
                   mantissa := mantissa + 2.0 ** ( i - man_width);
                   report "mantissa addded";
               end if;
           end loop;
        return sign * mantissa * 2.0 **exp ;
    end function;
    --exponent of the result for ulp calculation
     function exp_cal(r : real) return integer is
           variable exp : integer := 0;
           variable mantissa : real:= abs(r);
       begin
           -- Add conversion logic here
        if r=0.0 then
           return exp;
        else
           
           while mantissa >= 2.0 loop
               mantissa := mantissa / 2.0;
               exp := exp + 1;
           end loop;
           while mantissa < 1.0  loop
               mantissa := mantissa * 2.0;
               exp := exp - 1;
           end loop;
           return exp;
        end if;
       end function;
    signal clk : std_logic := '0';
        signal n_rst : std_logic := '0';
        signal a, b,c : std_logic_vector(precision-1 downto 0);
        signal result: std_logic_vector(precision32-1 downto 0);
        signal ar_vec : std_logic_vector(precision-1 downto 0);
         signal a_delayed1, b_delayed1, c_delayed1 : std_logic_vector(precision-1 downto 0);
         signal expected : real :=0.0;
         signal abr, ulp : real;
         signal a_delayed, b_delayed, c_delayed:real;
         signal exp: integer;
begin
    -- Clock generation
    clk <= not clk after 5 ns;
    
    -- DUT instantiation
    DUT: entity work.MAC
            Port map( a  => a,
                   b  => b,
                   c  => c,
                   clk  => clk , n_rst  => n_rst,
                   sumout  => result);
        
    
    -- Test process
    
    input : process(result,ar_vec)
        variable seed1, seed2: positive := 1;
        variable a1,b1,c1 : std_logic_vector(precision-1 downto 0):= (others=>'0');
    begin 
    
        if is_x(result) then
                   ar_vec <= (others => '0');
                   abr <= 0.0;  -- Initialize to zero if result contains X or U
               else
                   ar_vec <= float_to_half(result);
                   abr <= float32_to_real(result);
               end if;
   end process; 
  pipeline_track: process(clk)
       begin
           if rising_edge(clk) then
               if n_rst = '0' then
                   a_delayed <= 0.0;
                   b_delayed <= 0.0;
                   c_delayed <= 0.0;
                   expected <= 0.0;
               else
                   -- Store current inputs for next cycle comparison
                   a_delayed <= float_to_real(a);
                   b_delayed <= float_to_real(b);
                   c_delayed <= float_to_real(c);

                   -- Calculate expected result using delayed values
                   if not is_x(a) and not is_x(b) and not is_x(c) then
                       expected <= float_to_real(a) * float_to_real(b) + 
                                        float_to_real(c);
                   end if;
               end if;
           end if;
       end process;
    process
        
        variable a1,b1,c1 : std_logic_vector(precision-1 downto 0):= (others=>'0');
        variable actual_result : real;
        variable difference : real;
        
        variable seed1, seed2: positive := 1;
        variable line_out: line;
        file output_file: text open write_mode is "MAC_results_NULL.txt";
        
    begin
        a <= (others => '0');
        b <= (others => '0'); 
        c <= (others => '0');
        -- Reset
        n_rst <= '0';
        wait for 10 ns;
        n_rst <= '1';
        wait until rising_edge(clk);
        
        write(line_out, string'("MODE AC_ONLY  : "));
        writeline(output_file, line_out);

     -- Run multiple test cases per mode
        for i in 1 to 1000000 loop
            generate_aligned_random_vectors(seed1, seed2, a1,b1,c1);
            a <= a1;
             b <= b1; c <= c1;
            
            wait until rising_edge(clk);
            write(line_out, string'("clock at: " & time'image(now)));
            writeline(output_file, line_out);

            wait for 1 ns;
            write(line_out, string'("a:= " & real'image(a_delayed)));
            writeline(output_file, line_out);
                    
            write(line_out, string'("b:= " & real'image(b_delayed)));
            writeline(output_file, line_out);
            write(line_out, string'("c:= " & real'image(c_delayed)));
                        writeline(output_file, line_out);
             
          
            
            exp <= exp_cal(expected);
            ulp <= abs(expected - abr)/ 2.0**(exp_cal(expected) - 10);
             write(line_out, string'("ulp:= " &  real'image(abs(expected - abr)/ 2.0**(exp_cal(expected) - 10))));
             writeline(output_file, line_out);
           
            if (abs(expected - abr)/ 2.0**(exp_cal(expected) - 10)) < 1.0 then      -- Use fixed ULP for FP32
                            write(line_out, string'("ulp < 1 "));
                            write(line_out, i);
                            writeline(output_file, line_out);
                        else
                            write(line_out, string'("ulp > 1 "));
                            write(line_out, i);
                            writeline(output_file, line_out);          
                        end if;      
            write(line_out, string'("actual:= "));
            write(line_out, abr, digits => 20); 
            writeline(output_file, line_out);    
                                    
            write(line_out, string'("expected:= " ));
            write(line_out, expected, digits => 20); 
            writeline(output_file, line_out);                    

            write(line_out, string'("a: "));
            write(line_out,to_string (a));
            writeline(output_file, line_out);

            write(line_out, string'("b: "));
            write(line_out, to_string (b));
            writeline(output_file, line_out);

            write(line_out, string'("c: "));
            write(line_out, to_string (c));
            writeline(output_file, line_out);

            write(line_out, string'("actual FP32 : "));
            write(line_out, to_string (result));
            writeline(output_file, line_out);
            writeline(output_file, line_out);


        end loop;
--        
        wait until rising_edge(clk);
--        
        -- Add more test cases
        
        wait;
    end process;
end Behavioral;
