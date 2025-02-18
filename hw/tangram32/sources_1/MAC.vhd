----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/02/2024 04:02:04 PM
-- Design Name: 
-- Module Name: MAC - Behavioral
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
use work.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MAC is
    Port ( a : in  STD_LOGIC_VECTOR (31 downto 0);
           b : in  STD_LOGIC_VECTOR (31 downto 0);
           c : in STD_LOGIC_VECTOR (31 downto 0);
           clk, n_rst : in STD_LOGIC;
           sumout : out STD_LOGIC_VECTOR (63 downto 0));
end MAC;

architecture Behavioral of MAC is
    component fp_mult
    generic (width : integer := 24; cut : integer := 11);
        Port (
               clk : in STD_LOGIC;
               n_rst : in STD_LOGIC;
               mantissa_a,mantissa_b : in STD_LOGIC_VECTOR (23 downto 0);
               exp_ab_in : in unsigned (10 downto 0);
               mode : in std_logic_vector (1 downto 0);
               dnt_mult: in std_logic;
               exp_ab: out unsigned (10 downto 0);
               mantissa_ab_norm: out STD_LOGIC_VECTOR (51 downto 0)
                                        );
    end component;
    
    component add_fp is
      generic (precision : integer := 64; man_width : integer := 52);
      Port (exp_ain,exp_bin : in unsigned(10 downto 0);
              man_ain, man_bin : in std_logic_vector(52 downto 0);
              sign_a,sign_b : in std_logic;
              result : out std_logic_vector(precision-1 downto 0));
    end component;
    
    constant precision : integer range 0 to 128:=32; 
     constant precision64 : integer range 0 to 128:=64;
     constant ex_width: integer range 0 to 32:=8;
     constant man_width: integer range 0 to 32:= 23;
     constant cut : integer range 0 to 32 := 11;
     constant offset : integer range 0 to 32 := 0;
    constant FULL : std_logic_vector(1 downto 0) := "00";
    constant SKIP_BD : std_logic_vector(1 downto 0) := "01";
    constant AC_ONLY: std_logic_vector(1 downto 0) := "10";
    constant SKIP : std_logic_vector(1 downto 0) := "11";
    constant thr1 : signed(10 downto 0) := to_signed((cut + offset),11);
    constant thr2 : signed(10 downto 0) := to_signed(man_width,11);
    
    --input to multiplier
    --output from multiplier
    -- input to adder
    -- output from adder
    signal exp_an: unsigned(10 downto 0):= (others => '0');
    signal exp_bn: unsigned(10 downto 0):= (others => '0');
    signal exp_cn: unsigned(10 downto 0):= (others => '0');
    signal exp_cnd: unsigned(10 downto 0):= (others => '0');
    
    signal exp_ab: unsigned(10 downto 0):= (others => '0');
    signal exp_ab_out : unsigned(10 downto 0):= (others => '0');
    signal exp_a  : unsigned(10 downto 0):= (others => '0');
    signal exp_b  : unsigned(10 downto 0):= (others => '0');
    signal exp_c  : unsigned(10 downto 0):= (others => '0');
    signal diff : signed(10 downto 0) := (others =>'0');--integer  := -1;--signed(ex_width downto 0);
    signal mantissa_a, mantissa_b, mantissa_c: unsigned(22 downto 0);
    signal mantissa_a_norm,mantissa_b_norm : std_logic_vector (23 downto 0);
    signal mantissa_c_norm : std_logic_vector (52 downto 0) := (others => '0');
    signal mantissa_c_normd : std_logic_vector (52 downto 0) := (others => '0');
    
    signal mode : std_logic_vector(1 downto 0);
    signal ab : std_logic_vector(51 downto 0):= (others => '0');    
--    signal am,bm,cm : std_logic_vector(31 downto 0);
--    signal a_mult_in : std_logic_vector(31 downto 0) := (others => '0');    
    signal ab_result : std_logic_vector(63 downto 0) := (others => '0');    
    signal sum_64_out : std_logic_vector(63 downto 0);
        -- input to adder
    signal sum_64_in, ab_add_in : std_logic_vector(52 downto 0);   
    signal sign_ab , sign_c,sign_ab_add,sign_c_add,sign_ab_ad,sign_c_ad: std_logic:='0';
    signal exp_cn_addin,exp_ab_addin : unsigned(10 downto 0);
        -- output from adder
--    signal sumout : std_logic_vector(31 downto 0) := (others => '0');

    -- falgs
    signal a_zero,b_zero : std_logic;
    signal z_mult, z_mult_d,nan_input,nan_op,z_sum,z_sumd  : std_logic;
    signal dnt_mult : std_logic := '1';
--    --32 to 64 conversion
--        function float_32_to_64 (f : std_logic_vector(31 downto 0))
--        return std_logic_vector is
--        variable exp_old : integer := to_integer(unsigned(f(30 downto 23)));
--        variable exp : unsigned (10 downto 0) := (others=>'0');
--        variable m : unsigned (22 downto 0):= unsigned(f(22 downto 0));
--        variable shift_count : natural range 0 to 32 := 0;
--        begin
            
----            if (exp_old = 0)then
----                for i in 22 downto 0 loop
----                if m(i) = '1' then 
----                    shift_count := 23-i;
----                    exit;  -- Found first '1' in subnormal
----                end if;
----                end loop;
----                exp := to_unsigned(1023 - shift_count,11);  -- Convert position to biased exponent
----                m := shift_left(m, 23-shift_count); 
--           if (exp_old > 0 and exp_old < 255 ) then
--                exp := to_unsigned((exp_old + 896), 11);
----            elsif(exp = 0) then
----            exp := (others => '0');
--            elsif(exp_old > 254)then
--                exp := (others => '1');
--            else
--                exp := (others => '0');
--                m:= (others => '0');
--            end if;
--        return f(31)& std_logic_vector(exp)&std_logic_vector(m) & std_logic_vector(to_unsigned(0,29));
--    end function;
    
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
 

-----------------------------------------------------------------------------------------------------------------------------------
    --variable exp : std_logic_vector(10 downto 0):=
--             std_logic_vector(unsigned(f(precision-2 downto man_width))+896);
attribute keep : string;
attribute keep of  exp_a : signal   is "true";
attribute keep of  exp_c : signal   is "true";
attribute keep of  exp_b : signal   is "true";
attribute keep of  mantissa_c_norm : signal   is "true";
attribute keep of  mantissa_c : signal   is "true";
attribute keep of  mantissa_a : signal   is "true";
attribute keep of  mantissa_b : signal   is "true";
attribute keep of  mantissa_c_normd : signal   is "true";
attribute keep of sign_c_ad : signal is "true";
--attribute keep of diff : signal is "true";

begin


--input sanitizing
sanitize : process (a,b,c)
begin
 mantissa_a <=  unsigned(a(man_width-1 downto 0));
 mantissa_b <=  unsigned(b(man_width-1 downto 0));
 mantissa_c <=  unsigned(c(man_width-1 downto 0));

 exp_a <= resize(unsigned(a(precision-2 downto man_width)),11);       
 exp_b <= resize(unsigned(b(precision-2 downto man_width)),11);  
 exp_c <= resize(unsigned(c(precision-2 downto man_width)),11) + to_unsigned(896,11);    
end process;

--sign_ab <= a(31) xor b(31);
 subnormal_a : process (a,exp_a,mantissa_a)
    begin
    if (exp_a /= 0 and mantissa_a /= 0) then
        mantissa_a_norm <= '1' & std_logic_vector (mantissa_a);
        exp_an <= exp_a;
        a_zero <= '0';
    elsif (exp_a = 0 and mantissa_a /= 0) then    
        mantissa_a_norm <= (others => '0');
        exp_an <= to_unsigned(1, 11);
        a_zero <= '0';
    else
        mantissa_a_norm <= (others => '0');
        exp_an <= to_unsigned(0, 11);
        a_zero <= '1';
    end if;   
 end process;
 subnormal_b : process (b,exp_b,mantissa_b)
    begin
    if (exp_b /= 0 and mantissa_b /= 0) then
        mantissa_b_norm <= '1' & std_logic_vector(mantissa_b);
        exp_bn <= exp_b;
        b_zero <= '0';
    elsif (exp_b = 0 and mantissa_b /= 0) then
        mantissa_b_norm <= (others => '0');
        exp_bn <= to_unsigned(1, 11);
        b_zero <= '0';
    else 
        mantissa_b_norm <= (others => '0');
        exp_bn <= to_unsigned(0, 11);
        b_zero <= '1';
 
    end if;   
 end process;      
        
         
 zero_ab: process(a_zero, b_zero)
    begin
    if (a_zero = '1' or b_zero='1') then
        z_mult <= '1';
    else
        z_mult <= '0';
    end if;
end process;

 

 nan_operation: process(exp_ab,exp_a,exp_b,exp_c)
    begin
    if (exp_a > 254 or --to_unsigned(255,ex_width)
     exp_b > 255 or --to_unsigned(255,ex_width)
     exp_c > 1150 or exp_ab > 1150) then -- to_unsigned(255,ex_width)
       nan_input <= '1';
    else
       nan_input <= '0';
    end if;
end process;
do_not_multiply: process(nan_input, z_mult)
begin
    if (z_mult = '1' or nan_input = '1') then
        dnt_mult <= '1';
    else 
        dnt_mult <= '0';
    end if;
end process;
input_c : process (c,exp_c,mantissa_c,a(31),b(31),c(31))--c,exp_c,mantissa_c
    begin
             mantissa_c_normd <= (others => '0');
             sign_ab_ad <= a(31) xor b(31);
            if (exp_c > 896 and mantissa_c > 0 ) then
                    mantissa_c_normd <=  std_logic_vector('1' & mantissa_c &  to_unsigned(0,29));
                    exp_cnd <= exp_c;
                    sign_c_ad <= c(31);
                    z_sumd <= '0';
            elsif (exp_c = 896 and mantissa_c > 0) then
                    mantissa_c_normd <= (others => '0');
                    exp_cnd <= to_unsigned(1, 11);
                    sign_c_ad <= c(31);
                    z_sumd <= '0';
            else  
                    mantissa_c_normd <= (others => '0');
                    exp_cnd <= to_unsigned(0, 11);
                    sign_c_ad <= '0';
                    z_sumd <= '1';
        
            end if; 
            
--        end if;
--    end if;
    end process;
clock_delay : process (clk)--c,exp_c,mantissa_c
        begin
        if rising_edge(clk)then 
            if n_rst = '0' then
                mantissa_c_norm <= (others => '0');
                exp_cn <= to_unsigned(0, 11);
                z_sum <= '1';
                nan_op <= '0';
                z_mult_d <= '1';
                sign_c_add <= '0';
                sign_ab_add <= '0';
            else
                nan_op <= nan_input;
                z_mult_d <= z_mult;
                sign_c_add <= sign_c_ad;
                sign_ab_add <= sign_ab_ad;
               
                mantissa_c_norm <=  mantissa_c_normd;
                exp_cn <= exp_cnd;
                z_sum <= z_sumd; 
            end if;
        end if;
        end process;

 --multiplication 
 ab_exp : process(exp_an,exp_bn)   
 begin  
 exp_ab <= exp_an + exp_bn + to_unsigned(769,11) ;
--        when exp_an < to_unsigned(255,11) and exp_bn < to_unsigned(255,11)  else to_unsigned(0,11);
end process;
 difference : process(exp_cnd, exp_ab)
 begin
 diff <= signed(exp_cnd) - signed(exp_ab);
--        when to_integer(exp_c) > 0 or to_integer(exp_ab) > 0 else 0 ;
 end process;
 
 mode_selection : process(nan_input, z_mult,diff,n_rst)--exp_a,exp_b,exp_ab,nan_input,z_mult, am,bm,diff,n_rst
 begin
--    if clk'event and clk='1'then 
        if n_rst = '0' then

            mode <= "11";--SKIP;
        else
--            trigger <= not trigger;
            if nan_input = '0' and z_mult = '0' then
                if (diff = 0 or diff < 0) then
                    mode <= "00";--Full;
                elsif (diff > 0 and diff < thr1) then
                    mode <= "01";---SKIP_BD;
                elsif (diff >= thr1 and diff < thr2)then
                    mode <= "10";--AC_ONLY;
                elsif (diff >= thr2) then
                    mode <= "11";--SKIP;
                else
                    mode <= "11";--SKIP;
                end if;
           else
                mode <= "11";--SKIP;
      end if;
   end if;
--  end if;
  end process;
  ---multiply 
  fp_multiply : fp_mult 
      generic map (width  => man_width+1, cut => cut)
      Port map( 
             clk => clk,
             n_rst => n_rst,
             mantissa_a => mantissa_a_norm,
             mantissa_b => mantissa_b_norm,
             mode => mode,
             exp_ab_in => exp_ab,
             exp_ab => exp_ab_out,
             mantissa_ab_norm => ab,
             dnt_mult => dnt_mult
  
             );
        ab_result <= sign_ab & std_logic_vector(exp_ab_out) & ab;
 -- Addition
 fp_add : add_fp
 generic map (precision => 64, man_width => 52)
   Port map (
         exp_ain => exp_cn_addin,
         exp_bin => exp_ab_addin,
         man_ain => sum_64_in,
         man_bin=> ab_add_in,
         sign_a => sign_c,
         sign_b => sign_ab,
         result => sum_64_out);
                 
 adder_inputs :process (ab,exp_cn,sign_ab_add,mantissa_c_norm,exp_ab_out,sign_c_add,z_sum,nan_op,z_mult_d)--ab,c_to_adder,z_sum,nan_op,n_rst,z_mult_d
 begin
--        if n_rst = '0' then
--             ab_add_in <= (others => '0');
--             sum_64_in <= (others => '0');
             
--         else
             if nan_op = '0' and z_sum = '0'and z_mult_d = '0' then        
                ab_add_in <= '1' & ab;
                sum_64_in <= mantissa_c_norm ;
                exp_cn_addin <= exp_cn;
                exp_ab_addin <= exp_ab_out;
                sign_c <= sign_c_add;
                sign_ab <= sign_ab_add;
             else
                ab_add_in <= (others => '0');
                sum_64_in <= (others => '0') ;
                exp_cn_addin <= (others => '0');
                exp_ab_addin <= (others => '0');
                sign_c <= '0';
                sign_ab <= '0';
             end if; 
--        end if;      
end process;



--prepare output to 32 bit
scaledown: process(clk)--process (sum_64_out,nan_input,z_mult_d,z_sum,c,ab,nan_op)  --sum_64_out,nan_input,z_mult_d,z_sum,cm,ab,nan_op 
    begin
    if rising_edge(clk) then
       if (nan_op = '1')then
            sumout <= (others => '1');--nan_value;
       else
           if (z_mult = '0' and z_sum = '0') then
               sumout <= sum_64_out;--float_64_to_32(sum_64_out);
           elsif(z_mult = '1' and z_sum = '0') then
               sumout <= sign_c & std_logic_vector (exp_cn) & mantissa_c_norm(51 downto 0);--(51 downto 29);
           elsif( z_mult = '0' and z_sum = '1')then
                sumout <= sign_ab & std_logic_vector (exp_ab_out) & ab;--float_64_to_32(sign_ab & std_logic_vector (exp_ab_out) & ab);
           else
                sumout <= (others => '0');
           end if;
       end if;
     end if;
   end process; 
   
   -- out put
--   output: process(clk)
--   begin
--   if rising_edge(clk) then
--        if n_rst = '0' then
--            sum <= (others => '0');
--        else 
--            sum <= sumout;
--       end if;
--  end if;
-- end process;
            
end Behavioral;