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
generic (precision : integer := 32;exp_width: integer:= 8;man_width : integer := 23);
end mac_tb;

architecture Behavioral of mac_tb is

    procedure generate_random_vector(seed1, seed2: inout positive; 
                                   rout: out real) is
         variable r1, r2: real;
         variable exp: integer;
         constant max_exp: integer := 127;  -- Maximum exponent for float32
         begin
          -- Generate first random number for mantissa
          uniform(seed1, seed2, r1);
          r1 := (r1*2.0-1.0);  -- Range [-1,1]
          
          -- Generate second random number for exponent
          uniform(seed1, seed2, r2);
          exp := integer(r2 * (2.0 * real(max_exp))) - max_exp;  -- Range [-38,38]
          
          -- Combine to get final number
          rout := r1 * (2.0 ** exp);
    end procedure;
    
    signal clk : std_logic := '0';
    signal n_rst : std_logic := '0';
    signal a, b,c : std_logic_vector(precision-1 downto 0);
    signal result,ar_vec : std_logic_vector(precision-1 downto 0);
    
    -- Function to convert real to IEEE-754
    function real_to_float32(r : real) return std_logic_vector is
        variable exp : integer := 0;
        variable mantissa : real:= abs(r);
        variable sign : std_logic:='0';
        variable mantissa_bits : std_logic_vector(man_width-1 downto 0):= (others => '0');
        variable exponent_bits : std_logic_vector(exp_width-1 downto 0):= (others => '0');
        variable result : std_logic_vector(precision-1 downto 0):= (others => '0');
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
    function float32_to_real(f : std_logic_vector(precision-1 downto 0)) return real is
        variable sign : real;
        variable exp : natural;
        variable mantissa : real;
        constant bias: integer := 127;
    begin
        -- Add conversion logic here
            if f(precision-1) = '0' then
            sign := 1.0;
        else
            sign := -1.0;
        end if;
        exp := to_integer(unsigned(f(precision-2 downto man_width)))- bias;---bias +127;
        report "exp addded" & integer'image(exp);
--        report "exp addded" & to_string(f);

         mantissa := 1.0; -- The implicit 1 in IEEE exp_width-154 representation
           for i in man_width-1 downto 0 loop
               report "Loop iteration: " & integer'image(i) & " bit value: " & std_logic'image(f(i));           
               if (f(i) = '1' )then
                   mantissa := mantissa + 2.0 ** ( i - man_width);
                   report "mantissa addded";
               end if;
           end loop;
        return sign * mantissa * 2.0 **exp ;--+(2.0**(-29)))
    end function;
begin
    -- Clock generation
    clk <= not clk after 5 ns;
    
    -- DUT instantiation
    DUT: entity work.MAC
        generic map(precision => 32, 
                 precision64  => 64,
                 ex_width  => 8,
                 man_width => 23,
                 cut  => 11,
                 offset  => 0)
            Port map( a  => a,
                   b  => b,
                   c  => c,
                   clk  => clk , n_rst  => n_rst,
                   sum  => result);
        
    
    -- Test process
    process
        variable abr,ar,cr,br, ulp, expected : real;
        variable actual_result : real;
        variable difference : real;
        variable seed1, seed2: positive := 1;
        variable line_out: line;
        file output_file: text open write_mode is "MAC_results.txt";
        
    begin
        -- Reset
        n_rst <= '0';
        wait for 10 ns;
        n_rst <= '1';
        wait until rising_edge(clk);
        a <= real_to_float32(5.0e31);
        b <= real_to_float32(0.0);
        c <= real_to_float32(0.1);
        wait until rising_edge(clk);
        a <= real_to_float32(5.0e31);
        b <= real_to_float32(3.0);
        c <= real_to_float32(0.0);
--        for m in 0 to 3 loop                    
--                    -- Run multiple test cases per mode
--                    for i in 1 to 100 loop
--                        generate_random_vector(seed1, seed2, ar);
--                        generate_random_vector(seed1, seed2, br);
--                        generate_random_vector(seed1, seed2, cr);                        
--                        a <= real_to_float32(ar);
--                        b <= real_to_float32(br);
--                        c <= real_to_float32(cr);
                        
                        
                        
--                        wait until rising_edge(clk);
----                        wait until rising_edge(clk);
----                        wait until rising_edge(clk);
--                        ulp:=2.0**(to_integer(unsigned(ar_vec(precision-2 downto man_width)))-(man_width-3));
--                        expected := ar*br + cr;
--                        abr := float32_to_real(result);
--                        ar_vec <= real_to_float32(expected);
--                        -- Log results
--                        if (abs(expected - abr))<ulp then
--                            write(line_out, string'("success "));
--                            write(line_out, i);
--                            writeline(output_file, line_out);
--                        else
--                            write(line_out, string'("failure "));
--                            write(line_out, i);
--                            writeline(output_file, line_out);          
--                        end if;      
--                        write(line_out, string'("a:= " & real'image(ar)));
--                        writeline(output_file, line_out);
                                           
--                        write(line_out, string'("b:= " & real'image(br)));
--                        writeline(output_file, line_out);
                        
--                        write(line_out, string'("abr:= " &  real'image(abr)));
--                        writeline(output_file, line_out);    
                        
--                        write(line_out, string'("expected:= " &  real'image(expected)));
--                        writeline(output_file, line_out);                    
                        
--                        write(line_out, string'("a: "));
--                        write(line_out,to_bitvector (a));
--                        writeline(output_file, line_out);
                        
--                        write(line_out, string'("b: "));
--                        write(line_out, to_bitvector (b));
--                        writeline(output_file, line_out);
                        
--                        write(line_out, string'("actual  : "));
--                        write(line_out, to_bitvector (result));
--                        writeline(output_file, line_out);
                        
--                        write(line_out, string'("expected: "));
--                        write(line_out, to_bitvector (ar_vec));
--                        writeline(output_file, line_out);

--                    end loop;
--                end loop;
----        -- Test cases
--        ar := -1.0037234e30;
--        br:= -1.1359606e30;
--        a <= real_to_float32(-1.0037234e38);
--        b <= real_to_float32(-1.1359606e38);
--        expected := ar+br;
--        wait for 1 ns;
--        abr := float32_to_real(result);
--        write(line_out, string'("single values: "));
--        write(line_out, string'("a: " & real'image(ar) & "b: " & real'image(br) &  "abr: " & real'image(abr)  & "expected : "&  real'image(expected)));
--        writeline(output_file, line_out);

        wait for 10 ns;
--        assert unsigned(result(precision-2 downto man_width)) < 255 report "overflow" severity failure;
--        expected := 2.5 + 3.3;--exp_width-1.5;
--        --actual_result := float32_to_real(result(precision-1 downto 0));
--        difference := abs(expected - abr);
--        --assert error < 0.001 report "Test failed!" severity note;
--        assert difference < 0.001 report "Test failed! Error: " & real'image(difference) severity ERROR;
        -- Add more test cases
        
        wait;
    end process;
end Behavioral;
