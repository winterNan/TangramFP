----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/12/2024 07:34:23 PM
-- Design Name: 
-- Module Name: add_fp - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use work.tools.all;
-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity add_fp is
  generic (precision : integer range 0 to 63:= 32; 
  man_width : integer range 0 to 31:= 23; exp_width: integer range 0 to 31:= 8);
  Port (exp_ain,exp_bin : in unsigned(exp_width-1 downto 0);
        man_ain, man_bin : in std_logic_vector(man_width downto 0);
        sign_a,sign_b : in std_logic;
        z_sum : std_logic;
        result : out std_logic_vector(precision-1 downto 0));
end add_fp;

architecture Behavioral of add_fp is



    constant add : std_logic:= '0' ;
    constant sub : std_logic:= '1' ;
    signal operation : std_logic := '0';
    signal exp_a,exp_b, exp_ab, exp_ab_r: unsigned(precision-man_width-2 downto 0):= (others => '0');
    signal man_a, man_b,man_b_aligned,man_a_aligned  : unsigned(man_width+1 downto 0):= (others => '0');
    signal man_ab : unsigned(man_width+1 downto 0):= (others => '0');
    signal man_result : unsigned(man_width-1 downto 0):= (others => '0');

    signal shift : integer range 0 to 64;
    signal sign_ab: std_logic;
    signal temp_result : unsigned(man_width+1 downto 0):= (others =>'0');
    signal  shift_count : natural range 0 to 54 := 0;
    ------------lzc

    signal shift_vec : std_logic_vector (5 downto 0);
    signal enable_lzc : std_logic;
    


    component lzc_54
        port (
        mantissa   : in std_logic_vector(24 downto 0);
        enable      : in std_logic;
        shift_count: out std_logic_vector(5 downto 0)
    );
    end component;
    begin
    -- extract parts
    exp_a <= exp_ain;
    exp_b <= exp_bin+1 when man_bin(man_width)='1' else exp_bin;
    man_a <= unsigned('0' & man_ain);
    man_b <= unsigned( man_bin & '0' ) when man_bin(man_width)='0' and man_bin(man_width-1)='1' else unsigned('0' & man_bin);

    -- compute alignment shift amount and swap
    process (exp_a,exp_b,man_a,man_b,sign_a,sign_b,z_sum)
        begin
        if z_sum = '0' then
            if (exp_a = exp_b) then
                if (man_a >= man_b)then
                    man_a_aligned <= man_a;
                    man_b_aligned <= man_b;  
                    exp_ab <= exp_a; 
                    sign_ab <= sign_a;           
                else
                    man_a_aligned <= man_b;
                    man_b_aligned <= man_a;  
                    exp_ab <= exp_b;
                    sign_ab <= sign_b;
                end if;  
            elsif (exp_a > exp_b) then
                man_b_aligned <= shift_right(man_b, to_integer(exp_a - exp_b));
                man_a_aligned <= man_a;
                exp_ab <= exp_a;
                sign_ab <= sign_a;
            else
                man_b_aligned <= shift_right(man_a, to_integer(exp_b - exp_a)); 
                man_a_aligned <= man_b;
                exp_ab <= exp_b;
                sign_ab <= sign_b;
            end if;
        else 
            sign_ab <= sign_b;  
            exp_ab <= exp_b;
         end if;
    end process;
            
    -- check addition or subtraction
    process(sign_a, sign_b)
        begin
        if (sign_a = sign_b) then
            operation <= add;
        else
            operation <= sub;
        end if;
    end process;
    
    -- perform  addition or subtraction
process(operation,man_a_aligned,man_b_aligned,z_sum,man_b)
            begin
          if z_sum = '1' then 
            man_ab <= man_b;
          else 
            if (operation = add) then
                man_ab <= man_a_aligned + man_b_aligned;
               
            else 
                man_ab <= man_a_aligned - man_b_aligned;
            end if;
          end if;
        end process;    
    
--   count the leading zeros in case of subtraction

    LZC: lzc_54
        Port map (
            mantissa => std_logic_vector(man_ab),
            enable => enable_lzc,
            shift_count => shift_vec
            );
            
lzc_zeros:    process (man_ab, operation, shift_vec)
            begin
            if (operation = sub or z_sum = '1') then
                
                enable_lzc <= '1';
            else 
                enable_lzc <= '0';
            end if;
        end process;
  
  process(shift_vec)
  begin
    shift_count <= to_integer(unsigned(shift_vec));
  end process;      
  
    -----------------------------------------------
    -- normalize result
    process( man_ab, operation,shift_count,z_sum)
    begin
        temp_result <= (others => '0');
        if (operation = add) then
            if (man_ab(man_width+1) = '1') then
                temp_result <= man_ab + 1; -- rounding
            else
                temp_result <= man_ab;
            end if;
        elsif (operation = sub or z_sum = '1') then
            if (man_ab = to_unsigned(0, man_ab'length)) then
                temp_result <= (others => '0');
            else
                temp_result <= shift_left(man_ab, shift_count);
            end if;
        else
            temp_result <= (others => '0');
        end if;
    end process;
    
    process(temp_result, exp_ab,man_ab,operation,shift_count)
    begin
        man_result <= (others => '0');
        exp_ab_r <= (others => '0');
        if (operation = add) then
            if (man_ab(man_width+1) = '1') then
                man_result <= temp_result(man_width downto 1);
                exp_ab_r <= exp_ab + 1;
            else
                man_result <= temp_result(man_width-1 downto 0);
                exp_ab_r <= exp_ab;
            end if;
        elsif (operation = sub) then
            if (man_ab = to_unsigned(0, man_ab'length)) then
                man_result <= (others => '0');
                exp_ab_r <= exp_ab; -- No adjustment needed
            else
                man_result <= temp_result(man_width downto 1); -- Assign normalized mantissa
                exp_ab_r <= exp_ab - (shift_count-1); -- Adjust exponent
            end if;
        else
            man_result <= (others => '0');
            exp_ab_r <= (others => '0');
        end if;
    end process;
        
    result <= std_logic_vector(sign_ab & exp_ab_r&man_result);
end Behavioral;
