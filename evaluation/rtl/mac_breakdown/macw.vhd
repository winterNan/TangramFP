-- Complete FP16 MAC as used in an accelerator: input register(s), mode generation, and the MAC.
-- tangram = 0: standard MAC (one input register stage, all sub-multipliers enabled).
-- tangram = 3 / 4: mode computed inside the MAC from the operands of the same cycle, without / with
--                  isolation latches (one input register stage).
-- tangram = 1 / 2 / 5: registered mode. Stage 1 registers the operands, the mode is computed from their
--                  exponents and registered with them in stage 2, which feeds the MAC. 1: isolation latches,
--                  2: no isolation, 5: synchronous isolation (stage 2 keeps its mantissas in Null mode).
-- The Null threshold thr2 and the Skip-BD/AC threshold thr1 follow s = e_c - (e_a + e_b - 15).
-- Mode generation of design vi as its own entity (hierarchy kept) for the controller-cost breakdown.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity mode_gen is
    generic (thr1 : integer := 5; thr2 : integer := 12);
    port (ea, eb, ec : in std_logic_vector(4 downto 0); m : out std_logic_vector(1 downto 0));
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of mode_gen : entity is "yes";
end mode_gen;
architecture rtl of mode_gen is
begin
    process (ea, eb, ec)
        variable a, b, c, s : integer;
    begin
        a := to_integer(unsigned(ea)); b := to_integer(unsigned(eb)); c := to_integer(unsigned(ec));
        s := c - (a + b - 15);
        if a = 0 or b = 0 then m <= "11";
        elsif c = 0 or s <= 0 then m <= "00";
        elsif s < thr1 then m <= "01";
        elsif s < thr2 then m <= "10";
        else m <= "11";
        end if;
    end process;
end rtl;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.all;

entity MACW is
    generic (tangram : integer := 0; corr : integer := 0; thr1 : integer := 5; thr2 : integer := 12);
    port (a, b, c : in std_logic_vector(15 downto 0);
          clk, n_rst : in std_logic;
          sumout : out std_logic_vector(31 downto 0));
end MACW;

architecture rtl of MACW is
    type gmap_t is array (0 to 5) of integer;
    constant G_MAC : gmap_t := (0, 4, 5, 1, 2, 5);
    signal a1, b1, c1, a2, b2, c2 : std_logic_vector(15 downto 0) := (others => '0');
    signal m2 : std_logic_vector(1 downto 0) := "11";
    signal am, bm, cm : std_logic_vector(15 downto 0);
    signal mm, m1 : std_logic_vector(1 downto 0);
begin
    process (clk) begin
        if rising_edge(clk) then
            if n_rst = '0' then a1 <= (others => '0'); b1 <= (others => '0'); c1 <= (others => '0');
            else a1 <= a; b1 <= b; c1 <= c; end if;
        end if;
    end process;

    g_one : if tangram = 0 or tangram = 3 or tangram = 4 generate
        am <= a1; bm <= b1; cm <= c1; mm <= "00";
    end generate;

    g_two : if tangram = 1 or tangram = 2 or tangram = 5 generate
        mg : entity work.mode_gen generic map (thr1 => thr1, thr2 => thr2)
            port map (ea => a1(14 downto 10), eb => b1(14 downto 10), ec => c1(14 downto 10), m => m1);
        process (clk)
        begin
            if rising_edge(clk) then
                if n_rst = '0' then
                    a2 <= (others => '0'); b2 <= (others => '0'); c2 <= (others => '0'); m2 <= "11";
                else
                    m2 <= m1; c2 <= c1;
                    if tangram = 5 and m1 = "11" then             -- synchronous isolation: keep the mantissas
                        a2(15 downto 10) <= a1(15 downto 10); b2(15 downto 10) <= b1(15 downto 10);
                    else
                        a2 <= a1; b2 <= b1;
                    end if;
                end if;
            end if;
        end process;
        am <= a2; bm <= b2; cm <= c2; mm <= m2;
    end generate;

    mac_i : entity work.MAC
        generic map (corr => corr, gating => G_MAC(tangram), thr2 => thr2)
        port map (a => am, b => bm, c => cm, mode_in => mm, clk => clk, n_rst => n_rst, sumout => sumout);
end rtl;
