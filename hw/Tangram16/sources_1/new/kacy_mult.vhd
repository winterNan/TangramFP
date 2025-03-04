library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

entity kacy_mul is
    generic(
        width : integer := 11;
        cut : integer := 5
    );
    port(
        u : in std_logic_vector(width-1 downto 0);
        v : in std_logic_vector(width-1 downto 0);
        mode : in std_logic_vector(1 downto 0);
        mantissa : out std_logic_vector(2*width-1 downto 0)
        
    );
end kacy_mul;

architecture kacy_mul_arch of kacy_mul is

    component DaddaMultiplier
        generic(n : integer := cut);
            port(
                enable : std_logic;
                a : in std_logic_vector(n-1 downto 0); -- 5
                b : in std_logic_vector(n-1 downto 0); -- 5
                is_signed : in std_logic;               
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

    component CSA2i
        generic(n : integer := 22; cut : integer range 0 to 16 := 5);
            port(
                x : in std_logic_vector (n-1 downto 0); -- 17
                y : in std_logic_vector (n-1-cut downto cut); -- 17
                z : in std_logic; -- 1
                s : out std_logic_vector (n downto 0) -- 18
            );
    end component;

    constant FULL_COMPUTE : std_logic_vector(1 downto 0) := "00";
    constant      SKIP_BD : std_logic_vector(1 downto 0) := "01";
    constant       AC_ONLY: std_logic_vector(1 downto 0) := "10";
    constant    FULL_SKIP : std_logic_vector(1 downto 0) := "11";

    signal  x : std_logic; -- 1
    signal  y : std_logic; -- 1
    signal pu : std_logic_vector(width-2 downto 0); -- 10
    signal pv : std_logic_vector(width-2 downto 0); -- 10

    signal  a : std_logic_vector(cut-1 downto 0); -- 5
    signal  b : std_logic_vector(cut-1 downto 0); -- 5
    signal  c : std_logic_vector(cut-1 downto 0); -- 5
    signal  d : std_logic_vector(cut-1 downto 0); -- 5

    signal  Lac_a : std_logic_vector(cut-1 downto 0); -- 5
    signal  Lac_c : std_logic_vector(cut-1 downto 0); -- 5
    signal  Lad_a : std_logic_vector(cut-1 downto 0); -- 5
    signal  Lad_d : std_logic_vector(cut-1 downto 0); -- 5
    signal  Lbc_b : std_logic_vector(cut-1 downto 0); -- 5
    signal  Lbc_c : std_logic_vector(cut-1 downto 0); -- 5
    signal  Lbd_b : std_logic_vector(cut-1 downto 0); -- 5
    signal  Lbd_d : std_logic_vector(cut-1 downto 0); -- 5

    signal bd : std_logic_vector(2*cut-1 downto 0); -- 10
    signal bd_row1 : std_logic_vector(2*cut-1 downto 0); -- 10
    signal bd_row2 : std_logic_vector(2*cut-1 downto 0); -- 10
    signal ad_row1 : std_logic_vector(2*cut-1 downto 0); -- 10
    signal ad_row2 : std_logic_vector(2*cut-1 downto 0); -- 10
    signal bc_row1 : std_logic_vector(2*cut-1 downto 0); -- 10
    signal bc_row2 : std_logic_vector(2*cut-1 downto 0); -- 10
    signal ac_row1 : std_logic_vector(2*cut-1 downto 0); -- 10
    signal ac_row2 : std_logic_vector(2*cut-1 downto 0); -- 10

    signal is_signed : std_logic := '0';

    signal row0 : std_logic_vector(2*width-2 downto 0); -- 21
    signal row1 : std_logic_vector(2*width-2 downto 0); -- 21
    signal row2 : std_logic_vector(2*width-2 downto 0); -- 21
    signal row3 : std_logic_vector(2*width-2 downto 0); -- 21
    signal row4 : std_logic_vector(2*width-2 downto 0); -- 21
    signal row5 : std_logic_vector(2*width-2 downto 0); -- 21


    signal ac_e : std_logic;
    signal ad_e : std_logic;
    signal bc_e : std_logic;
    signal bd_e : std_logic;

    signal csa_bc_ad_c : std_logic; -- 1
    signal csa_bc_ad_s : std_logic_vector(2*cut downto 0); -- 11

    signal csa_ac_puv_c : std_logic; -- 1
    signal csa_ac_puv_s : std_logic_vector(2*cut downto 0); -- 11

    signal cout : std_logic;
    signal res : std_logic_vector(2*width downto 0);

    signal final_csa_x : std_logic_vector(2*width-1 downto 0);
    signal final_csa_y : std_logic_vector(2*width-1-cut downto cut);
    signal final_csa_z : std_logic;



begin

    x <= u(width-1 ); -- 1
    y <= v(width-1); -- 1

    pu <= u(width-2 downto 0); -- 10
    pv <= v(width-2 downto 0); -- 10

    a <= u(2*cut-1 downto cut); -- [9:5]
    b <= u(  cut-1 downto   0); -- [4:0]
    c <= v(2*cut-1 downto cut); -- [9:5]
    d <= v(  cut-1 downto   0); -- [4:0]

    MUL_bd : DaddaMultiplier port map (
        enable => bd_e,
        a => Lbd_b, b => Lbd_d, is_signed => is_signed, 
        orow1 => bd_row1, orow2 => bd_row2
        );

    MUL_ad : DaddaMultiplier port map (
        enable => ad_e,
        a => Lad_a, b => Lad_d, is_signed => is_signed, 
        orow1 => ad_row1, orow2 => ad_row2
        );

    MUL_bc : DaddaMultiplier port map (
        enable => bc_e,
        a => Lbc_b, b => Lbc_c, is_signed => is_signed, 
        orow1 => bc_row1, orow2 => bc_row2
        );

    MUL_ac : DaddaMultiplier port map (
        enable => ac_e,
        a => Lac_a, b => Lac_c, is_signed => is_signed, 
        orow1 => ac_row1, orow2 => ac_row2
        );

    latch_proc_ac: process(ac_e, a, c)
    begin
        if (ac_e = '1') then
            Lac_a <= a;
            Lac_c <= c;
        end if;
    end process;

    latch_proc_bc: process(bc_e, b, c)
    begin
        if (bc_e = '1') then
            Lbc_b <= b;
            Lbc_c <= c;
        end if;
    end process;

    latch_proc_ad: process(ad_e, a, d)
    begin
        if (ad_e = '1') then
            Lad_a <= a;
            Lad_d <= d;
        end if;
    end process;

    latch_proc_bd: process(bd_e, b, d)
    begin
        if (bd_e = '1') then
            Lbd_b <= b;
            Lbd_d <= d;
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

    csa_bc_ad : CSA4i port map(
        w => bc_row1,
        x => bc_row2,
        y => ad_row1,
        z => ad_row2,
        cout => csa_bc_ad_c,
        s => csa_bc_ad_s
        );

    csa_ac_ab_cd : CSA4i port map(
        w => ac_row1,
        x => ac_row2,
        y => pu,
        z => pv,
        cout => csa_ac_puv_c,
        s => csa_ac_puv_s
        );

    bd <= bd_row1 + bd_row2 when bd_e = '1'else (others => '0');

    csa_final : CSA2i generic map (n => 22, cut => cut)
        port map(
        x => final_csa_x,
        y => final_csa_y,
        z => final_csa_z,
        s => res
        );

    final_csa_x <= csa_ac_puv_c & csa_ac_puv_s & bd; -- 1+11+10
    final_csa_y <=  csa_bc_ad_c & csa_bc_ad_s when bc_e = '1' and ad_e ='1' else (others=>'0');
    final_csa_z <=  (x and y);

    mantissa <= res(2*width-1 downto 0);


end kacy_mul_arch;
