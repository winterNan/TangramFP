----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/09/2024 06:43:05 PM
-- Design Name: 
-- Module Name: fp_mult - Behavioral
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
--arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fp_mult is
generic (width : integer := 24; cut : integer := 11);
    Port ( 
           clk : in STD_LOGIC;
           n_rst : in STD_LOGIC;
           mantissa_a,mantissa_b : in STD_LOGIC_VECTOR (23 downto 0);
           exp_ab_in : in unsigned (10 downto 0);
           mode : in std_logic_vector (1 downto 0);
           dnt_mult : in std_logic;
           exp_ab: out unsigned (10 downto 0);
           mantissa_ab_norm: out STD_LOGIC_VECTOR (51 downto 0):=(others=>'0')

);
end fp_mult;

architecture Behavioral of fp_mult is
    component kacy_32_mult generic(width : integer ; cut : integer);
        port (
--                clk : in std_logic; n_rst : in std_logic;
                u : in std_logic_vector(width-1 downto 0);
                v : in std_logic_vector(width-1 downto 0);
                mode : in std_logic_vector(1 downto 0);
                mantissa : out std_logic_vector(2*width-1 downto 0)
            );
    end component;
--signal sign_a, sign_b, sign_ab : std_logic;
--signal exp_a, exp_b : std_logic_vector(7 downto 0);
--signal exp_ab : std_logic_vector(10 downto 0):=(others=>'0');
--signal mantissa_a, mantissa_b : std_logic_vector(23 downto 0);
signal mantissa_ab : std_logic_vector(47 downto 0);
--signal mantissa_ab_norm : std_logic_vector(51 downto 0);
attribute keep : string;
attribute keep of  mantissa_ab_norm : signal   is "true";
begin
kacy_mult : kacy_32_mult 
            generic map (
                 width => 24,
                 cut  => cut)
            port map (
--                  clk=>clk,
--                  n_rst=>n_rst,
                  u=>mantissa_a, v=>mantissa_b,
                  mode=>mode,
                  mantissa=>mantissa_ab);


    
    
--    result <= sign_ab&exp_ab & mantissa_ab_norm;
    
    --normalization of the result
    process(clk)--,n_rst,mantissa_ab
        begin
        if rising_edge(clk) then
            if (n_rst = '0' or dnt_mult = '1')then
                mantissa_ab_norm <= (others => '0');
                exp_ab <= (others=>'0');
           else
           
               if (mantissa_ab(47)= '1') then
                    mantissa_ab_norm <= mantissa_ab(46 downto 0) & "00000";
                    exp_ab <= exp_ab_in + to_unsigned(1,11);
               elsif mantissa_ab(46) = '1' then
                    mantissa_ab_norm <= mantissa_ab(45 downto 0) & "000000";
                    exp_ab <=  exp_ab_in;
--              elsif(mantissa_ab(47)= '0' and mantissa_ab(46)= '0')then
--                    exp_ab <= (others => '0');-- std_logic_vector(resize(unsigned(exp_a),11)+ resize(unsigned(exp_b),11) + to_unsigned(769,11));
--                    mantissa_ab_norm <= mantissa_ab & "0000";
              else 
                    exp_ab <= (others => '0');-- std_logic_vector(resize(unsigned(exp_a),11)+ resize(unsigned(exp_b),11) + to_unsigned(769,11));
                    mantissa_ab_norm <= (others => '0');    
              end if;
          end if; 
        end if;
        end process;

end Behavioral;
