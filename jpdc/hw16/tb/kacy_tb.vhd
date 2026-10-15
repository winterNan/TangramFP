library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Self-checking test of kacy_mul against vectors produced by the emulator (tfp16.c).
entity kacy_tb is
    generic (corr : integer := 0; gating : integer := 2; vecfile : string := "vec.txt");
end kacy_tb;

architecture sim of kacy_tb is
    signal u, v : std_logic_vector(10 downto 0) := (others => '0');
    signal mode : std_logic_vector(1 downto 0) := "11";
    signal mantissa : std_logic_vector(21 downto 0);
begin
    dut : entity work.kacy_mul generic map (width => 11, cut => 5, corr => corr, gating => gating)
        port map (u => u, v => v, mode => mode, mantissa => mantissa);

    process
        file f : text open read_mode is vecfile;
        variable l : line;
        variable iu, iv, im, ie, n, bad : integer := 0;
    begin
        while not endfile(f) loop
            readline(f, l); read(l, iu); read(l, iv); read(l, im); read(l, ie);
            mode <= "11"; wait for 1 ns;      -- all enables low, then the new operands arrive with the mode
            u <= std_logic_vector(to_unsigned(iu, 11)); v <= std_logic_vector(to_unsigned(iv, 11));
            mode <= std_logic_vector(to_unsigned(im, 2)); wait for 9 ns;
            n := n + 1;
            if to_integer(unsigned(mantissa)) /= ie then
                bad := bad + 1;
                if bad < 6 then
                    report "MISMATCH u=" & integer'image(iu) & " v=" & integer'image(iv) & " mode=" & integer'image(im) &
                           " got=" & integer'image(to_integer(unsigned(mantissa))) & " exp=" & integer'image(ie);
                end if;
            end if;
        end loop;
        report "KACY_TB corr=" & integer'image(corr) & " vectors=" & integer'image(n) & " mismatches=" & integer'image(bad);
        wait;
    end process;
end sim;
