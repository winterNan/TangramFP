----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/27/2024 03:29:04 PM
-- Design Name: 
-- Module Name: Kacy_mult_tb - Behavioral
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;



entity Kacy_mult_tb is
    generic(width : integer := 11; man_length : integer := 22);
end Kacy_mult_tb;

architecture Behavioral of Kacy_mult_tb is
    component kacy_mul is
        generic(
            width : integer := 11;
            cut : integer := 5
        );
        port(
            Clk : in std_logic;
            n_rst : in std_logic;
            u : in std_logic_vector(width-1 downto 0);
            v : in std_logic_vector(width-1 downto 0);
            mode : in std_logic_vector(1 downto 0);
            mantissa : out std_logic_vector(man_length-1 downto 0)
            -- dis : out std_logic_vector(cut+1 downto 0)
    );
    end component;
    signal clk : std_logic := '0'; 
    signal n_rst : std_logic;
    signal u, v : std_logic_vector(width-1 downto 0);
    signal mode : std_logic_vector(1 downto 0);
    signal mantissa : std_logic_vector(man_length-1 downto 0);
    begin
        uut : kacy_mul port map (clk => clk, 
                                 n_rst => n_rst, 
                                 u => u, v => v, 
                                 mode => mode, 
                                 mantissa => mantissa);
        clk <= not clk after 50 ns;
            
        tb: process
            begin
            wait for 100 ns;
                n_rst <= '1';
                u <=  "11111111111" ; -- std_logic_vector(to_unsigned(144, u'length));
                v <=  "11111111111"; -- std_logic_vector(to_unsigned(144, v'length));
                mode <= "00";
                wait;
            end process;


end Behavioral;
