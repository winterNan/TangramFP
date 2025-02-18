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
  generic (precision : integer := 64; man_width : integer := 52);
  Port (a : in std_logic_vector(precision-1 downto 0);
        b : in std_logic_vector(precision-1 downto 0);
        result : out std_logic_vector(precision-1 downto 0));
end add_fp;

architecture Behavioral of add_fp is
attribute use_carry_chain : string;
attribute use_carry_chain of Behavioral : architecture is "yes";
attribute keep : string;


    constant add : std_logic:= '0' ;
    constant sub : std_logic:= '1' ;
    signal operation : std_logic := '0';
    signal exp_a,exp_b, exp_ab, exp_ab_r: unsigned(precision-man_width-2 downto 0):= (others => '0');
    signal man_a, man_b,man_b_aligned,man_a_aligned  : unsigned(man_width downto 0):= (others => '0');
    signal man_add_a, man_add_b, man_sub_a,man_sub_b : unsigned(man_width downto 0):= (others => '0');
    signal man_ab_add,man_ab_sub : unsigned(man_width+1 downto 0):= (others => '0');
    signal man_result : unsigned(man_width-1 downto 0):= (others => '0');
    signal cin, bin : unsigned(man_width downto 0):= (others => '0');
    signal shift : integer range 0 to 64;
    signal sign_a, sign_b, sign_ab: std_logic;
    signal temp_result : unsigned(man_width+1 downto 0):= (others =>'0');
    signal  shift_count : natural range 0 to 54 := 0;
    ------------lzc
    signal man_lZC_input : std_logic_vector (53 downto 0);
    signal shift_vec : std_logic_vector (5 downto 0);
    signal enable_lzc : std_logic;
    
    attribute keep of man_ab_add : signal is "true";
    attribute keep of man_ab_sub : signal is "true";
    attribute keep of Cin : signal is "true";
    attribute keep of man_add_a : signal is "true";
    attribute keep of man_add_b : signal is "true";
    attribute keep of bin : signal is "true";
    
    component fulladder is
        port (a : in std_logic;
              b : in std_logic;
              cin : in std_logic;
              sum : out std_logic;
              carry : out std_logic
             );
    end component;
    component fullsubtractor is
        port (a : in std_logic;
              b : in std_logic;
              bin : in std_logic;
              diff : out std_logic;
              bout : out std_logic
             );
    end component;
    component lzc_54
        port (
        mantissa   : in std_logic_vector(53 downto 0);
        enable      : in std_logic;
        shift_count: out std_logic_vector(5 downto 0)
    );
    end component;
    begin
    -- extract parts
    exp_a <= unsigned(a(precision-2 downto man_width));
    exp_b <= unsigned(b(precision-2 downto man_width));
    man_a <= '1' & unsigned(a(man_width-1 downto 0)) when exp_a > 0 else (others => '0');
    man_b <= '1' & unsigned(b(man_width-1 downto 0)) when exp_b > 0 else (others => '0');
    sign_a <= a(precision-1);
    sign_b <= b(precision-1);
    -- compute alignment shift amount and swap
    process (exp_a,exp_b,man_a,man_b,sign_a,sign_b)
        begin
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

    -- enable addition or subtraction
    process(operation,man_a_aligned,man_b_aligned)
        begin
        if (operation = add) then
            man_add_a <= man_a_aligned;
            man_add_b <= man_b_aligned;
            man_sub_a <= (others => '0');
            man_sub_b <= (others => '0');
        elsif (operation =sub) then
            man_sub_a <= man_a_aligned;
            man_sub_b <= man_b_aligned;
            man_add_a <= (others => '0');
            man_add_b <= (others => '0');
        else 
            man_add_a <= (others => '0');
            man_add_b <= (others => '0');
            man_sub_a <= (others => '0');
            man_sub_b <= (others => '0');
        end if;
    end process;    
    --add
    
    man_ab_add(man_width) <= man_add_a(man_width) xor man_add_b(man_width) xor cin(man_width);
    man_ab_add(man_width+1) <= (man_add_a(man_width) and man_add_b(man_width)) or (cin(man_width) and (man_add_a(man_width) xor man_add_b(man_width)));
    addition:
        for i in 0 to man_width-1 generate
            fa : fulladder
                port map(
                    a => man_add_a(i),
                    b => man_add_b(i),
                    cin => cin(i),
                    sum => man_ab_add(i),
                    carry => cin(i+1)
                    );
        end generate;
    -- subtract
    man_ab_sub(man_width) <= man_sub_a(man_width) xor man_sub_b(man_width) xor bin(man_width); 
    man_ab_sub(man_width+1) <= (not man_sub_a(man_width) and man_sub_b(man_width)) or (bin(man_width) and (not man_sub_a(man_width) xor man_sub_b(man_width)));
    subtraction:
        for i in 0 to man_width-1 generate
            sub : fullsubtractor
                port map(
                    a => man_sub_a(i),
                    b => man_sub_b(i),
                    bin => bin(i),
                    diff => man_ab_sub(i),
                    bout => bin(i+1)
                    );
        end generate;
   --determine leading zero in mantissa
   ----------------------------------------------     
--    process(operation, man_ab_sub)
--    begin
--    if (operation = sub and man_ab_sub = to_unsigned(0, man_ab_sub'length)) then
--        shift_count <= 0;
--    else
--        for i in 0 to man_width+1 loop
--            if man_ab_sub(man_width+1-i) = '1' then
--                  shift_count <= i;
--                  exit;
--            else 
--                shift_count <= 0;
--            end if;
--        end loop;
--    end if;
--    end process;

    LZC: lzc_54
        Port map (
            mantissa => man_lZC_input,
            enable => enable_lzc,
            shift_count => shift_vec
            );
            
lzc_zeros:    process (man_ab_sub, operation, shift_vec)
            begin
            if (operation = sub) then
                man_lZC_input <= std_logic_vector(man_ab_sub);
                shift_count <= to_integer(unsigned(shift_vec));
                enable_lzc <= '1';
            else 
                man_lZC_input <= (others => '0');
                shift_count <= 0;
                enable_lzc <= '0';
            end if;
        end process;
    -----------------------------------------------
    -- normalize result
    process(man_ab_add, man_ab_sub, operation,shift_count)
    begin
        temp_result <= (others => '0');
        if (operation = add) then
            if (man_ab_add(man_width+1) = '1') then
                temp_result <= man_ab_add + 1; -- rounding
            else
                temp_result <= man_ab_add;
            end if;
        elsif (operation = sub) then
            if (man_ab_sub = to_unsigned(0, man_ab_sub'length)) then
                temp_result <= (others => '0');
            else
--                for i in 0 to man_width+1 loop
--                    if man_ab_sub(man_width+1-i) = '1' then
--                        shift_count <= i;
--                        exit;
--                    end if;
--                end loop;
                -- Normalize the mantissa by left-shifting it
                temp_result <= shift_left(man_ab_sub, shift_count);
            end if;
        else
            temp_result <= (others => '0');
        end if;
    end process;
    
    process(temp_result, exp_ab,man_ab_add, man_ab_sub,operation,shift_count)
    begin
        man_result <= (others => '0');
        exp_ab_r <= (others => '0');
        if (operation = add) then
            if (man_ab_add(man_width+1) = '1') then
                man_result <= temp_result(man_width downto 1);
                exp_ab_r <= exp_ab + 1;
            else
                man_result <= temp_result(man_width-1 downto 0);
                exp_ab_r <= exp_ab;
            end if;
        elsif (operation = sub) then
            if (man_ab_sub = to_unsigned(0, man_ab_sub'length)) then
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
