library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Drives one complete MAC (MACW) with a trace of (a, b, c) FP16 operands, one per clock cycle. Inputs change
-- and the output is sampled at the falling edge, half a period away from every capture edge.
entity macw_tb is
    generic (trace : string := "trace.txt"; outfile : string := "out.txt"; half_ns : integer := 10);
end macw_tb;

architecture sim of macw_tb is
    component MACW
        port (a, b, c : in std_logic_vector(15 downto 0);
              clk, n_rst : in std_logic;
              sumout : out std_logic_vector(31 downto 0));
    end component;
    signal a, b, c : std_logic_vector(15 downto 0) := (others => '0');
    signal clk : std_logic := '0';
    signal n_rst : std_logic := '0';
    signal sumout : std_logic_vector(31 downto 0);
    signal done : boolean := false;
begin
    dut : MACW port map (a => a, b => b, c => c, clk => clk, n_rst => n_rst, sumout => sumout);
    clk <= not clk after half_ns * 1 ns when not done else '0';

    process
        file f : text open read_mode is trace;
        file g : text open write_mode is outfile;
        variable l, lo : line;
        variable ia, ib, ic : integer;
    begin
        wait for 105 ns;                 -- global set/reset of the timing netlist
        wait until falling_edge(clk); n_rst <= '0';
        wait until falling_edge(clk); wait until falling_edge(clk); n_rst <= '1';
        while not endfile(f) loop
            readline(f, l); read(l, ia); read(l, ib); read(l, ic);
            wait until falling_edge(clk);
            write(lo, to_integer(unsigned(sumout(31 downto 16)))); write(lo, string'(" "));
            write(lo, to_integer(unsigned(sumout(15 downto 0)))); writeline(g, lo);
            a <= std_logic_vector(to_unsigned(ia, 16)); b <= std_logic_vector(to_unsigned(ib, 16));
            c <= std_logic_vector(to_unsigned(ic, 16));
        end loop;
        for k in 0 to 3 loop
            wait until falling_edge(clk);
            write(lo, to_integer(unsigned(sumout(31 downto 16)))); write(lo, string'(" "));
            write(lo, to_integer(unsigned(sumout(15 downto 0)))); writeline(g, lo);
        end loop;
        done <= true;
        wait;
    end process;
end sim;
