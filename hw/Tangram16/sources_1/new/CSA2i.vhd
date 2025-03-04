----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/26/2025 06:26:21 PM
-- Design Name: 
-- Module Name: CSA2i - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CSA2i is
    generic(n : integer := 22;
    cut : integer range 0 to 16 := 5);
    Port ( x : in  std_logic_vector (n-1 downto 0);
           y : in  std_logic_vector (n-1-2*cut downto 0);
           z : in  std_logic;
           s : out std_logic_vector (n downto 0)
         );
end CSA2i;

architecture csa_arch of CSA2i is
signal c : std_logic_vector(n-cut-1 downto 0) := (others => '0');
begin
-- First stage: Full adder for x + y + z
    first: for i in cut to n-1-cut generate
        s(i) <= (x(i) xor y(i-5)) xor c(i-5); -- Sum
        c(i+1-5) <= (x(i) and y(i-5)) or (c(i-5) and (y(i-5) xor x(i))); -- Carry
    end generate first;
    second: for i in n-cut to n-3 generate
        s(i) <= x(i) xor c(i-5);
        c(i+1-5) <= x(i) and c(i-5);
    end generate;
    s(n-2) <= x(n-2) xor z xor c(n-2-5);
    c(n-1-5) <= (x(n-2) and z)or (c(n-2-5) and(x(n-2) xor z));
    s(n-1) <= x(n-1) xor c(n-1-5);
    s(n) <= x(n-1) and c(n-1-5);
    s(4 downto 0) <= x(4 downto 0);
end csa_arch;