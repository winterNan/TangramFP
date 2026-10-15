-- Processing element of an output-stationary systolic array built around the FP16 MAC.
-- Operands flow left to right (a, with the start-of-dot-product flag clr) and top to bottom (w).
-- The running sum is kept as FP16: the FP32-format MAC output is truncated to FP16 and fed back.
-- tangram = 0: standard MAC (gating 0).  tangram = 1: TangramFP MAC with a registered mode (gating 4):
-- (tangram = 2: as 1 but without isolation latches; the operand registers hold the operand bits that the
--  selected mode does not use (the mantissas in Null mode), i.e. synchronous isolation.
--  tangram = 3: as 2 without holding, disabled partial products are only forced to zero.)
--   the mode of operation k is computed one cycle ahead, from the exponents of its operands and of
--   the running sum available at that time (which lags by one operation), and registered together
--   with the operands; the exponent arithmetic is therefore not in series with the MAC.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.all;

entity PE is
    generic (tangram : integer := 0; corr : integer := 0; thr1 : integer := 5; thr2 : integer := 12);
    port (clk, n_rst : in std_logic;
          a_in, w_in : in std_logic_vector(15 downto 0);
          clr_in : in std_logic;
          a_out, w_out : out std_logic_vector(15 downto 0);
          clr_out : out std_logic;
          acc : out std_logic_vector(15 downto 0));
end PE;

architecture rtl of PE is
    type gmap_t is array (0 to 3) of integer;
    constant G_MAC : gmap_t := (0, 4, 5, 5);
    component MAC
        generic (cut : integer := 5; offset : integer := 0; corr : integer := 0; gating : integer := 2);
        port (a, b, c : in std_logic_vector(15 downto 0);
              mode_in : in std_logic_vector(1 downto 0) := "00";
              clk, n_rst : in std_logic;
              sumout : out std_logic_vector(31 downto 0));
    end component;
    signal a_r, w_r : std_logic_vector(15 downto 0) := (others => '0');
    signal clr_r : std_logic := '0';
    signal a_m, w_m, c_m, acc16 : std_logic_vector(15 downto 0);
    signal clr_m : std_logic;
    signal mode_m : std_logic_vector(1 downto 0);
    signal sum32 : std_logic_vector(31 downto 0);
begin
    -- operand registers, forwarded to the neighbours
    process (clk) begin
        if rising_edge(clk) then
            if n_rst = '0' then a_r <= (others => '0'); w_r <= (others => '0'); clr_r <= '0';
            else a_r <= a_in; w_r <= w_in; clr_r <= clr_in; end if;
        end if;
    end process;
    a_out <= a_r; w_out <= w_r; clr_out <= clr_r;

    -- FP32-format sum -> FP16 (truncation; flush below the FP16 normal range, saturate above it)
    process (sum32)
        variable e : integer range 0 to 255;
    begin
        e := to_integer(unsigned(sum32(30 downto 23)));
        if e <= 112 then acc16 <= (others => '0');
        elsif e >= 143 then acc16 <= sum32(31) & "111101111111111";
        else acc16 <= sum32(31) & std_logic_vector(to_unsigned(e - 112, 5)) & sum32(22 downto 13);
        end if;
    end process;

    gen_std : if tangram = 0 generate
        a_m <= a_r; w_m <= w_r; clr_m <= clr_r; mode_m <= "00";
    end generate;

    gen_tfp : if tangram /= 0 generate
        signal a_q, w_q : std_logic_vector(15 downto 0) := (others => '0');
        signal clr_q : std_logic := '0';
        signal mode_q : std_logic_vector(1 downto 0) := "11";
    begin
        process (clk)
            variable ea, eb, ec, s : integer;
            variable m : std_logic_vector(1 downto 0);
        begin
            if rising_edge(clk) then
                ea := to_integer(unsigned(a_r(14 downto 10)));
                eb := to_integer(unsigned(w_r(14 downto 10)));
                if clr_r = '1' then ec := 0; else ec := to_integer(unsigned(acc16(14 downto 10))); end if;
                s := ec - (ea + eb - 15);
                if n_rst = '0' then
                    a_q <= (others => '0'); w_q <= (others => '0'); clr_q <= '0'; mode_q <= "11";
                else
                    clr_q <= clr_r;
                    if ea = 0 or eb = 0 then m := "11";               -- zero operand: Null
                    elsif ec = 0 or s <= 0 then m := "00";            -- Full
                    elsif s < thr1 then m := "01";                    -- Skip-BD
                    elsif s < thr2 then m := "10";                    -- AC
                    else m := "11";                                   -- Null
                    end if;
                    mode_q <= m;
                    if tangram = 2 and m = "11" then                 -- Null: hold the mantissas (the hidden-bit terms
                        a_q(15 downto 10) <= a_r(15 downto 10);       -- use the full mantissas in every other mode)
                        w_q(15 downto 10) <= w_r(15 downto 10);
                    else
                        a_q <= a_r; w_q <= w_r;
                    end if;
                end if;
            end if;
        end process;
        a_m <= a_q; w_m <= w_q; clr_m <= clr_q; mode_m <= mode_q;
    end generate;

    c_m <= (others => '0') when clr_m = '1' else acc16;

    mac_i : MAC
        generic map (corr => corr, gating => G_MAC(tangram))
        port map (a => a_m, b => w_m, c => c_m, mode_in => mode_m, clk => clk, n_rst => n_rst, sumout => sum32);

    acc <= acc16;
end rtl;
