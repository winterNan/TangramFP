----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/28/2024 09:10:28 PM
-- Design Name: 
-- Module Name: csa_4i_tb - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity csa_4i_tb is
generic(n : integer := 4);
end csa_4i_tb;

architecture Behavioral of csa_4i_tb is
component CSA4i is
    generic(n : integer := 4);
    Port ( x : in std_logic_vector (n-1 downto 0);
           y : in std_logic_vector (n-1 downto 0);
           z : in std_logic_vector (n-1 downto 0);
           w : in std_logic_vector (n-1 downto 0);
           cout : out std_logic;
           s : out std_logic_vector (n downto 0)
         );
end component;
signal x,y,z,w : std_logic_vector(n-1 downto 0);
signal sum : std_logic_vector(n downto 0);
signal carry : std_logic;
signal result : std_logic_vector(n+1 downto 0);
begin
x <= "1101";
y <= "0110";
z <= "1011";
w <= "0101";
add: CSA4i  port map (x => x, y => y,
                     z => z, w => w, s => sum, 
                     cout => carry);
tb: process
begin
        wait for 10 ns;
        wait;
end process;
        result <= carry & sum;

end Behavioral;
