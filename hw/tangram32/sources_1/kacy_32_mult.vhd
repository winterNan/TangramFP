library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity kacy_32_mult is
    generic(
        --re_width : integer := 48;
        width : integer := 24;
        cut : integer := 11
        --p: integer := 12
    );
    port(
--        Clk : in std_logic;
--        n_rst : in std_logic;
        u : in std_logic_vector(width-1 downto 0);
        v : in std_logic_vector(width-1 downto 0);
        mode : in std_logic_vector(1 downto 0);
        mantissa : out std_logic_vector(2*width-1 downto 0)
        -- dis : out std_logic_vector(cut+1 downto 0)
    );
end kacy_32_mult;

architecture kacy_mul_arch of kacy_32_mult is

    component DaddaMultiplier
        generic(n : integer := cut);
            port(
                enable : std_logic;
                a : in std_logic_vector(n-1 downto 0); -- 5
                b : in std_logic_vector(n-1 downto 0); -- 5
                is_signed : in std_logic;
                -- result : out std_logic_vector(2*n-1  downto 0)
                orow1 : out std_logic_vector(2*n-1 downto 0); -- 10
                orow2 : out std_logic_vector(2*n-1 downto 0)  -- 10
            );
    end component;

    component CSA4i
        generic(n : integer := 2*cut); -- 10
            port(
                w : in std_logic_vector (n-1 downto 0);
                x : in std_logic_vector (n-1 downto 0); -- 10
                y : in std_logic_vector (n-1 downto 0); -- 10
                z : in std_logic_vector (n-1 downto 0); -- 10
                cout : out std_logic;
                s : out std_logic_vector (n downto 0)
            );
    end component;

    component CSA3i
        generic(n : integer);
            port(
                x : in std_logic_vector (n-1 downto 0); -- 17
                y : in std_logic_vector (n-1 downto 0); -- 17
                z : in std_logic_vector (n-1 downto 0); -- 17
                cout : out std_logic;
                s : out std_logic_vector (n downto 0) -- 18
            );
    end component;

    constant FULL_COMPUTE : std_logic_vector(1 downto 0) := "00";
    constant      SKIP_BD : std_logic_vector(1 downto 0) := "01";
    constant       AC_ONLY: std_logic_vector(1 downto 0) := "10";
    constant    FULL_SKIP : std_logic_vector(1 downto 0) := "11";
    constant p : integer := width - cut-1;
    signal  x : std_logic; -- 1
    signal  y : std_logic; -- 1
    signal pu : std_logic_vector(width-1 downto 0); -- 10
    signal pv : std_logic_vector(width-1 downto 0); -- 10

    signal  a : std_logic_vector(p-1 downto 0); -- 5
    signal  b : std_logic_vector(cut-1 downto 0); -- 5
    signal  c : std_logic_vector(p-1 downto 0); -- 5
    signal  d : std_logic_vector(cut-1 downto 0); -- 5

    signal  Lac_a : std_logic_vector(p-1 downto 0); -- 12
    signal  Lac_c : std_logic_vector(p-1 downto 0); -- 0 & 11 
    signal  Lad_a : std_logic_vector(p-1 downto 0); -- 12
    signal  Lad_d : std_logic_vector(p-1 downto 0); -- 0 & 11 
    signal  Lbc_b : std_logic_vector(p-1 downto 0); -- 12
    signal  Lbc_c : std_logic_vector(p-1 downto 0); -- 0 & 11 
    signal  Lbd_b : std_logic_vector(cut-1 downto 0); -- 11
    signal  Lbd_d : std_logic_vector(cut-1 downto 0); -- 11

    signal bd : std_logic_vector(2*cut-1 downto 0); -- 10
    signal bd_row1 : std_logic_vector(2*cut-1 downto 0); -- 22
    signal bd_row2 : std_logic_vector(2*cut-1 downto 0); -- 22
    signal ad_row1 : std_logic_vector(2*p-1 downto 0); -- 24
    signal ad_row2 : std_logic_vector(2*p-1 downto 0); -- 24
    signal bc_row1 : std_logic_vector(2*p-1 downto 0); -- 24
    signal bc_row2 : std_logic_vector(2*p-1 downto 0); -- 24
    signal ac_row1 : std_logic_vector(2*p-1 downto 0); -- 24
    signal ac_row2 : std_logic_vector(2*p-1 downto 0); -- 24

    signal is_signed : std_logic := '0';

--    signal row0 : std_logic_vector(2*width-2 downto 0); -- 21
--    signal row1 : std_logic_vector(2*width-2 downto 0); -- 21
--    signal row2 : std_logic_vector(2*width-2 downto 0); -- 21
--    signal row3 : std_logic_vector(2*width-2 downto 0); -- 21
--    signal row4 : std_logic_vector(2*width-2 downto 0); -- 21
--    signal row5 : std_logic_vector(2*width-2 downto 0); -- 21

    -- signal res2 : std_logic_vector(2*width-1 downto 0); -- 22

    signal ac_e : std_logic;
    signal ad_e : std_logic;
    signal bc_e : std_logic;
    signal bd_e : std_logic;

    signal csa_bc_ad_c : std_logic; -- 1
    signal csa_bc_ad_s : std_logic_vector(2*p downto 0); -- 25

    signal csa_ac_puv_c : std_logic; -- 1
    signal csa_ac_puv_s : std_logic_vector(2*p downto 0); -- 25

    --signal cout : std_logic;
    signal res : std_logic_vector(2*width downto 0);

    signal final_csa_x : std_logic_vector(2*width-1 downto 0);
    signal final_csa_y : std_logic_vector(2*width-1 downto 0);
    signal final_csa_z : std_logic_vector(2*width-1 downto 0);

    signal dffman : std_logic_vector(2*width-1 downto 0);
    -- signal dffdis : std_logic_vector(cut+1 downto 0);

begin

    x  <= u(width-1); -- 1
    y  <= v(width-1); -- 1
    pu <= u(width-2 downto 0)&'0'; -- 23
    pv <= v(width-2 downto 0)&'0'; -- 23
    a  <= u(width-2 downto cut); -- [23:11]
    b  <= u(cut-1 downto   0); -- [10:0]
    c  <= v(width-2 downto cut); -- [23:11]
    d  <= v(cut-1 downto   0); -- [10:0]

    MUL_bd : DaddaMultiplier generic map (n => cut) port map (
        enable => bd_e,
        a => Lbd_b, b => Lbd_d, is_signed => is_signed, -- result => bd
        orow1 => bd_row1, orow2 => bd_row2
        );

    MUL_ad : DaddaMultiplier generic map (n => p) port map (
        enable => ad_e,
        a => Lad_a, b => Lad_d, is_signed => is_signed, -- result => ad
        orow1 => ad_row1, orow2 => ad_row2
        );

    MUL_bc : DaddaMultiplier generic map (n => p) port map (
        enable => bc_e,
        a => Lbc_b, b => Lbc_c, is_signed => is_signed, -- result => bc
        orow1 => bc_row1, orow2 => bc_row2
        );

    MUL_ac : DaddaMultiplier generic map (n => p) port map (
        enable => ac_e,
        a => Lac_a, b => Lac_c, is_signed => is_signed, -- result => ac
        orow1 => ac_row1, orow2 => ac_row2
        );

    latch_proc_ac: process(ac_e, a, c)
    begin
        if (ac_e = '1') then
            Lac_a <= a;
            Lac_c <= c;
        else 
            Lac_a <= (others => '0');
            Lac_c <= (others => '0');
        end if;
    end process;

    latch_proc_bc: process(bc_e, b, c)
    begin
        if (bc_e = '1') then
            --Lbc_b <= b;
            Lbc_b(p-2 downto 0) <= b;
            Lbc_b(p-1) <= '0';            
            Lbc_c <= c;
        else 
            Lbc_b <= (others => '0');
            Lbc_c <= (others => '0');    
        end if;
    end process;

    latch_proc_ad: process(ad_e, a, d)
    begin
        if (ad_e = '1') then
            Lad_a <= a;
            Lad_d(p-2 downto 0) <= d;
            Lad_d(p-1) <= '0';
        else 
            Lad_a <= (others => '0');
            Lad_d <= (others => '0');
        end if;
    end process;

    latch_proc_bd: process(bd_e, b, d)
    begin
        if (bd_e = '1') then
            Lbd_b <= b;
            Lbd_d <= d;
        else 
            Lbd_b <= (others => '0');
            Lbd_d <= (others => '0');
        end if;
    end process;

    if_proc: process (mode, u, v)
    begin
        if mode = FULL_COMPUTE then -- full compute
            ac_e <= '1';
            ad_e <= '1';
            bc_e <= '1';
            bd_e <= '1';
        elsif mode = SKIP_BD then -- skip bd
            ac_e <= '1';
            ad_e <= '1';
            bc_e <= '1';
            bd_e <= '0';
        elsif mode = AC_ONLY then -- ac only
            ac_e <= '1';
            ad_e <= '0';
            bc_e <= '0';
            bd_e <= '0';
        else -- full skip
            ac_e <= '0';
            ad_e <= '0';
            bc_e <= '0';
            bd_e <= '0';
        end if;
    end process;

    csa_bc_ad : CSA4i generic map (n => 2*p)
        port map(
        w => bc_row1,
        x => bc_row2,
        y => ad_row1,
        z => ad_row2,
        cout => csa_bc_ad_c,
        s => csa_bc_ad_s
        );

    csa_ac_ab_cd : CSA4i generic map (n => 2*p) 
        port map(
        w => ac_row1,
        x => ac_row2,
        y => pu,
        z => pv,
        cout => csa_ac_puv_c,
        s => csa_ac_puv_s
        );

    bd <= bd_row1 + bd_row2;

    csa_final : CSA3i 
        generic map (n => 2*width) 
        port map(
        x => final_csa_x,
        y => final_csa_y,
        z => final_csa_z,
        --cout => cout,
        s => res
        );

--    final_csa_x <= csa_ac_puv_c & csa_ac_puv_s & bd;--(2*cut-1 downto 2*cut-5); -- 1+25+22
--    final_csa_y <= std_logic_vector(TO_UNSIGNED(0, cut)) & csa_bc_ad_c & csa_bc_ad_s & std_logic_vector(TO_UNSIGNED(0, cut));--11+1+25+11
--    final_csa_z <= '0' & (x and y) & std_logic_vector(TO_UNSIGNED(0, 2*(p+cut))); --1<<46
result:    process(mode, bd,csa_ac_puv_s,csa_bc_ad_s,x,y,csa_ac_puv_c,csa_bc_ad_c)
    begin
        if (mode=FULL_COMPUTE) then--full
            final_csa_x <= csa_ac_puv_c & csa_ac_puv_s & bd;--(2*cut-1 downto 2*cut-5); -- 1+25+22
            final_csa_y <= std_logic_vector(TO_UNSIGNED(0, cut)) & csa_bc_ad_c & csa_bc_ad_s & std_logic_vector(TO_UNSIGNED(0, cut));--11+1+25+11
            final_csa_z <= '0' & (x and y) & std_logic_vector(TO_UNSIGNED(0, 2*(p+cut))); --1<<46
        
        elsif(mode=SKIP_BD)then--skip BD
            final_csa_x <= csa_ac_puv_c & csa_ac_puv_s & std_logic_vector(to_unsigned(0,22));
            final_csa_y <= std_logic_vector(TO_UNSIGNED(0, cut)) & csa_bc_ad_c & csa_bc_ad_s & std_logic_vector(TO_UNSIGNED(0, cut));
            final_csa_z <= '0' & (x and y) & std_logic_vector(TO_UNSIGNED(0, 2*(p+cut))); 
       
        elsif(mode = AC_ONLY)then -- AC only
            final_csa_x <= csa_ac_puv_c & csa_ac_puv_s & std_logic_vector(to_unsigned(0,22));
            final_csa_y <= (others => '0');--11+1+25+11
            final_csa_z <= '0' & (x and y) & std_logic_vector(TO_UNSIGNED(0, 2*(p+cut))); 
        else
            final_csa_x <= (others => '0');
            final_csa_y <= (others => '0');
            final_csa_z <= (others => '0');
       end if;
    end process;
    dffman <= res(2*width-1 downto 0);
    -- dffdis <= res(17) & res(5 downto 0);

--    process(Clk) -- output register
--    begin
--        if(falling_edge(Clk)) then -- originally rising_edge
--            if(n_rst = '0') then
--                mantissa <= (others => '0');
--                -- dis <= (others => '0');
--            else
--                mantissa <= dffman;
--                -- dis <= dffdis;
--            end if;
--        end if;
--    end process;
mantissa <= dffman;-----------------------output
    --- reduction phase with adder tree
    -- ac(2*cut-1 downto 0) <= ac_row1 + ac_row2;
    -- bc(2*cut-1 downto 0) <= bc_row1 + bc_row2;
    -- ad(2*cut-1 downto 0) <= ad_row1 + ad_row2;
    -- bd(2*cut-1 downto 0) <= bd_row1 + bd_row2;
    -- row0 <= '0' & ac & bd;
    -- row1 <= '0' & (2*width-3 downto cut*3 => '0') &
    --          ad & (cut-1 downto 0 => '0');
    -- row2 <= '0' & (2*width-3 downto cut*3 => '0') &
    --          bc & (cut-1 downto 0 => '0');
    -- row3 <= '0' & pu & (2*cut-1 downto 0 => '0');
    -- row4 <= '0' & pv & (2*cut-1 downto 0 => '0');
    -- row5 <= (x and y) & (2*width-3 downto 0 => '0');
    -- res2 <= '0' & ((row0 + row1) +
    --                (row2 + row3) +
    --                (row4 + row5));
    -- result <= res2(2*width-1 downto 2*cut+1); -- [21:11]

end kacy_mul_arch;
