-- Complete FP16 MAC as used in an accelerator: input register(s), mode generation, and the MAC.
-- tangram = 0: standard MAC (one input register stage, all sub-multipliers enabled).
-- tangram = 3 / 4: mode computed inside the MAC from the operands of the same cycle, without / with
--                  isolation latches (one input register stage).
-- tangram = 1 / 2 / 5: registered mode. Stage 1 registers the operands, the mode is computed from their
--                  exponents and registered with them in stage 2, which feeds the MAC. 1: isolation latches,
--                  2: no isolation, 5: synchronous isolation (stage 2 keeps its mantissas in Null mode).
-- The Null threshold thr2 and the Skip-BD/AC threshold thr1 follow s = e_c - (e_a + e_b - 15).
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
    signal mm : std_logic_vector(1 downto 0);
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
        process (clk)
            variable ea, eb, ec, s : integer;
            variable m : std_logic_vector(1 downto 0);
        begin
            if rising_edge(clk) then
                ea := to_integer(unsigned(a1(14 downto 10)));
                eb := to_integer(unsigned(b1(14 downto 10)));
                ec := to_integer(unsigned(c1(14 downto 10)));
                s := ec - (ea + eb - 15);
                if ea = 0 or eb = 0 then m := "11";               -- zero (or flushed subnormal) operand: Null
                elsif ec = 0 or s <= 0 then m := "00";           -- Full
                elsif s < thr1 then m := "01";                   -- Skip-BD
                elsif s < thr2 then m := "10";                   -- AC
                else m := "11";                                  -- Null
                end if;
                if n_rst = '0' then
                    a2 <= (others => '0'); b2 <= (others => '0'); c2 <= (others => '0'); m2 <= "11";
                else
                    m2 <= m; c2 <= c1;
                    if tangram = 5 and m = "11" then             -- synchronous isolation: keep the mantissas
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
