-- Code your testbench here
library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_STD.all;
use work.all;
entity tb is 
end entity;

architecture btb of tb is 
signal a :  std_logic_vector(31 downto 0) := (others => '0');
signal y :  std_logic_vector(31 downto 0);
signal b:  std_logic_vector(63 downto 0);
signal x :  std_logic_vector(63 downto 0) := (others => '0');

begin 
uut:entity work.convert 
port map (a=>a, b=>b, x=> x, y=> y);
process
begin 
-- wait for 10 ns;
--     a <= '0' & std_logic_vector(to_unsigned(128,8)) & 					std_logic_vector(to_unsigned(3,23));
--     wait for 10 ns;
--     a <= '0' & std_logic_vector(to_unsigned(128,8)) & 					std_logic_vector(to_unsigned(1234,23));
--     wait for 10 ns;
--    x <= "0100000000001000000000000000000000000000000000000000000000000000";
    wait for 10 ns;
x <= "0011011101000000011000010100000011110011110111101101111111101101";
wait for 10 ns;
wait;
end process;
end btb;