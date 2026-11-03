-- N x N output-stationary systolic array of PEs. Row i receives a(i) and clr(i) on the left,
-- column j receives w(j) at the top (the stimulus is skewed by the testbench). All running sums are
-- XOR-reduced into one 16-bit output so that no PE is optimized away; dbg exposes the sums in simulation.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.all;
library UNISIM;
use UNISIM.VComponents.all;

entity sarray is
    generic (N : integer := 4; tangram : integer := 0; corr : integer := 0; thr2 : integer := 12;
             use_bufg : integer := 0);   -- 1 in implementation: clock on the global network (no skew-induced hold violations)
    port (clk, n_rst : in std_logic;
          a : in std_logic_vector(16*N-1 downto 0);
          w : in std_logic_vector(16*N-1 downto 0);
          clr : in std_logic_vector(N-1 downto 0);
          xout : out std_logic_vector(15 downto 0);
          dbg : out std_logic_vector(16*N*N-1 downto 0));
end sarray;

architecture rtl of sarray is
    type bus_t is array (0 to N, 0 to N) of std_logic_vector(15 downto 0);
    type bit_t is array (0 to N, 0 to N) of std_logic;
    signal ah, wv, acc : bus_t;
    signal ch : bit_t;
    signal clk_g : std_logic;
begin
    g_bufg : if use_bufg = 1 generate
        bufg_i : BUFG port map (I => clk, O => clk_g);
    end generate;
    g_nobufg : if use_bufg /= 1 generate
        clk_g <= clk;
    end generate;

    g_in : for i in 0 to N-1 generate
        ah(i, 0) <= a(16*i+15 downto 16*i);
        ch(i, 0) <= clr(i);
        wv(0, i) <= w(16*i+15 downto 16*i);
    end generate;

    g_r : for i in 0 to N-1 generate
        g_c : for j in 0 to N-1 generate
            pe_i : entity work.PE
                generic map (tangram => tangram, corr => corr, thr2 => thr2)
                port map (clk => clk_g, n_rst => n_rst,
                          a_in => ah(i, j), w_in => wv(i, j), clr_in => ch(i, j),
                          a_out => ah(i, j+1), w_out => wv(i+1, j), clr_out => ch(i, j+1),
                          acc => acc(i, j));
            dbg(16*(i*N+j)+15 downto 16*(i*N+j)) <= acc(i, j);
        end generate;
    end generate;

    process (acc)
        variable x : std_logic_vector(15 downto 0);
    begin
        x := (others => '0');
        for i in 0 to N-1 loop
            for j in 0 to N-1 loop
                x := x xor acc(i, j);
            end loop;
        end loop;
        xout <= x;
    end process;
end rtl;
