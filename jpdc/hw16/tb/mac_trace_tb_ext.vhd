library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Drives one MAC with a trace of (a, b, c, mode): the mode arrives together with the operands.
-- The result is written to a file so that variants can be compared; switching
-- activity is collected by the simulator (SAIF) for report_power.
entity mac_trace_tb_ext is
    generic (trace : string := "trace.txt"; outfile : string := "out.txt"; half_period : time := 10 ns);
end mac_trace_tb_ext;

architecture sim of mac_trace_tb_ext is
    component MAC
        port (a, b, c : in std_logic_vector(15 downto 0);
              mode_in : in std_logic_vector(1 downto 0);
              clk, n_rst : in std_logic;
              sumout : out std_logic_vector(31 downto 0));
    end component;
    signal a, b, c : std_logic_vector(15 downto 0) := (others => '0');
    signal mode_in : std_logic_vector(1 downto 0) := "11";
    signal clk : std_logic := '0';
    signal n_rst : std_logic := '0';
    signal sumout : std_logic_vector(31 downto 0);
    signal done : boolean := false;
begin
    dut : MAC port map (a => a, b => b, c => c, mode_in => mode_in, clk => clk, n_rst => n_rst, sumout => sumout);
    clk <= not clk after half_period when not done else '0';

    process
        file f : text open read_mode is trace;
        file g : text open write_mode is outfile;
        variable l, lo : line;
        variable ia, ib, ic, im : integer;
    begin
        wait for 105 ns;                 -- global set/reset of the timing netlist
        wait until rising_edge(clk); wait for 1 ns;
        n_rst <= '1';
        while not endfile(f) loop
            readline(f, l); read(l, ia); read(l, ib); read(l, ic); read(l, im);
            a <= std_logic_vector(to_unsigned(ia, 16)); b <= std_logic_vector(to_unsigned(ib, 16));
            c <= std_logic_vector(to_unsigned(ic, 16)); mode_in <= std_logic_vector(to_unsigned(im, 2));
            wait until rising_edge(clk); wait for 1 ns;
            write(lo, to_integer(unsigned(sumout(31 downto 16)))); write(lo, string'(" "));
            write(lo, to_integer(unsigned(sumout(15 downto 0)))); writeline(g, lo);
        end loop;
        done <= true;
        wait;
    end process;
end sim;
