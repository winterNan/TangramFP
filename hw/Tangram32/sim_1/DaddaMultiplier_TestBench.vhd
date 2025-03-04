library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity testbench is
generic(n : integer := 4);
end testbench;

architecture behavior of testbench is
	component DaddaMultiplier
		generic(n : integer := 4);
		port(
		    enable : in std_logic;
			a : in std_logic_vector(n - 1 downto 0);
			b : in std_logic_vector(n - 1 downto 0);
			is_signed : in std_logic;
			--result : out std_logic_vector(2 * n - 1 downto 0)
			 orow1 : out std_logic_vector(2 * n - 1 downto 0);
             orow2 : out std_logic_vector(2 * n - 1 downto 0)
		);
	end component;
    signal enable: std_logic;
	signal op1 : std_logic_vector(n-1 downto 0); --:= "11111";
	signal op2 : std_logic_vector(n-1 downto 0) ;--:= "11111";
	--signal result : std_logic_vector(9 downto 0);
	signal orow1 : std_logic_vector(2*n-1 downto 0);
	signal orow2 : std_logic_vector(2*n-1 downto 0);
	signal result : std_logic_vector(2*n-1 downto 0);

begin
	uut: DaddaMultiplier port map(enable => enable,
	                                a => op1, b => op2,
	                                 is_signed => '1',
	                                  orow1 => orow1,
	                                  orow2 => orow2 );

	tb : process
	begin
	    enable <= '1';
		op1 <= "1110";--"11101";
		op2 <= "1110";--"10111";
		result <= orow1 + orow2;
		wait for 100 ns;
		
		--op1 <= "11111";
		--op2 <= "11111";
		wait;
	end process;
end;
