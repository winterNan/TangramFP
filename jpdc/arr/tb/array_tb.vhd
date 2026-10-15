-- Drives the N x N array with a pre-skewed stimulus (one line per cycle: N a-values, N w-values, N clr bits,
-- FP16 bit patterns as integers) and writes the XOR output (and, with dump = 1, all running sums) every cycle.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity array_tb is
    generic (N : integer := 4; tangram : integer := 0; corr : integer := 0;
             trace : string := "stim.txt"; outfile : string := "out.txt"; dump : integer := 0;
             half_ns : integer := 10);
end array_tb;

architecture tb of array_tb is
    component sarray
        port (clk, n_rst : in std_logic;
              a, w : in std_logic_vector(16*N-1 downto 0);
              clr : in std_logic_vector(N-1 downto 0);
              xout : out std_logic_vector(15 downto 0);
              dbg : out std_logic_vector(16*N*N-1 downto 0));
    end component;
    signal clk : std_logic := '0';
    signal n_rst : std_logic := '0';
    signal a, w : std_logic_vector(16*N-1 downto 0) := (others => '0');
    signal clr : std_logic_vector(N-1 downto 0) := (others => '0');
    signal xout : std_logic_vector(15 downto 0);
    signal dbg : std_logic_vector(16*N*N-1 downto 0);
    signal done : boolean := false;
begin
    dut : sarray port map (clk => clk, n_rst => n_rst, a => a, w => w, clr => clr, xout => xout, dbg => dbg);
    clk <= not clk after half_ns * 1 ns when not done else '0';

    process
        file fi : text open read_mode is trace;
        file fo : text open write_mode is outfile;
        variable li, lo : line;
        variable v : integer;
    begin
        wait for 105 ns;                         -- global set/reset of the timing netlist
        wait until rising_edge(clk); wait for 5 ns;
        n_rst <= '0';
        wait until rising_edge(clk); wait for 5 ns;
        n_rst <= '1';
        while not endfile(fi) loop
            readline(fi, li);
            wait until falling_edge(clk);          -- sample, then apply the next inputs half a period from any capture edge
            write(lo, to_integer(unsigned(xout)));
            if dump = 1 then
                for k in 0 to N*N-1 loop write(lo, string'(" ")); write(lo, to_integer(unsigned(dbg(16*k+15 downto 16*k)))); end loop;
            end if;
            writeline(fo, lo);
            for i in 0 to N-1 loop read(li, v); a(16*i+15 downto 16*i) <= std_logic_vector(to_unsigned(v, 16)); end loop;
            for i in 0 to N-1 loop read(li, v); w(16*i+15 downto 16*i) <= std_logic_vector(to_unsigned(v, 16)); end loop;
            for i in 0 to N-1 loop read(li, v); if v = 1 then clr(i) <= '1'; else clr(i) <= '0'; end if; end loop;
        end loop;
        wait until falling_edge(clk); wait until falling_edge(clk);
        done <= true;
        wait;
    end process;
end tb;
