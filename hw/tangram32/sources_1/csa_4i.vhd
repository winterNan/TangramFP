library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CSA4i is
    generic(n : integer := 5);
    Port ( x : in std_logic_vector (n-1 downto 0);
           y : in std_logic_vector (n-1 downto 0);
           z : in std_logic_vector (n-1 downto 0);
           w : in std_logic_vector (n-1 downto 0);
           cout : out std_logic;
           s : out std_logic_vector (n downto 0)
         );
end CSA4i;

--architecture csa_arch of CSA4i is

--component fulladder is
--    port (a : in std_logic;
--          b : in std_logic;
--          cin : in std_logic;
--          sum : out std_logic;
--          carry : out std_logic
--         );
--end component;

--signal c1,s1,c2 : unsigned (n-1 downto 0) := (others => '0');
--signal s2 : unsigned (n-2 downto 0) := (others => '0');
--signal c3 : unsigned (n-2 downto 0) := (others => '0');
--signal c_final : std_logic; 

--begin

--    first_stage:
--    for i in 0 to n-1 generate
--        fa : fulladder
--            port map(
--                a => x(i),
--                b => y(i),
--                cin => z(i),
--                sum => s1(i),
--                carry => c1(i));
--    end generate;

--    second_stage:
--    for i in 1 to n-1 generate
--        fa : fulladder
--            port map (
--                a => c1(i-1),
--                b => s1(i),
--                cin => w(i),
--                sum => s2(i-1),
--                carry => c2(i)
--            );
--    end generate;

--    fa_2_0 : fulladder 
--        port map(a =>'0',
--                b =>s1(0), 
--                cin => w(0),
--                sum => s(0),
--                carry => c2(0));

--    third_stage:
--    for i in 1 to n-2 generate
--        fa : fulladder
--            port map(
--                a => c2(i),
--                b => s2(i),
--                cin => c3(i-1),
--                sum => s(i+1),
--                carry => c3(i)
--                );
--    end generate;

--    fa_3_0 : fulladder 
--        port map(
--                a =>'0',
--                b => c2(0),
--                cin => s2(0), 
--                sum => s(1), 
--                carry => c3(0));
--    fa_3_n : fulladder 
--        port map(a =>c3(n-2), 
--                b =>c2(n-1), 
--                cin => c1(n-1), 
--                sum => s(n), 
--                carry => c_final);
--     cout <= c_final;
----     s(n+1) <= c_final;
--end csa_arch;--//////////////////////////////////////////////////////////////
architecture csa_arch of CSA4i is
    attribute use_carry_chain : string;
    attribute use_carry_chain of csa_arch : architecture is "yes";

    -- Full Adder component declaration
--    component fulladder is
--        port (
--            a     : in std_logic;
--            b     : in std_logic;
--            cin   : in std_logic;
--            sum   : out std_logic;
--            carry : out std_logic
--        );
--    end component;

    signal c1, c2 : std_logic_vector(n-1 downto 0):= (others => '0');
    signal s2, c3 : std_logic_vector(n-2 downto 0):= (others => '0');
    signal s1     : std_logic_vector(n-1 downto 0):= (others => '0');
    signal c_final    : std_logic:=  '0';

begin
    -- First stage: Add x, y, and z
    first_stage: for i in 0 to n-1 generate

        s1(i) <= x(i) xor y(i) xor z(i); -- Sum
        c1(i) <= (x(i) and y(i)) or (y(i) and z(i)) or (z(i) and x(i)); -- Carry
    end generate;

    -- Second stage: Add s1, c1, and w
    second_stage: for i in 0 to n-1 generate
        se1: if i = 0 generate
                s(i) <= s1(i) xor w(i); -- Sum
                c2(i) <= s1(i) and w(i); -- Carry
          end generate se1;
          
        se2: if i>0 generate
                s2(i-1) <= (s1(i) xor w(i)) xor c1(i-1); -- Sum
                c2(i) <= (s1(i) and w(i)) or (c1(i-1) and (s1(i) xor w(i))); -- Carry
    end generate se2;
    end generate;

    -- Third stage: Combine c2 and s2
    third_stage: for i in 1 to n-2 generate

            s(i+1) <= (s2(i) xor c2(i)) xor c3(i-1); -- Sum
            c3(i) <= (s2(i) and c2(i)) or (c3(i-1) and (c2(i) xor s2(i))); -- Carry
    end generate;

    -- Handle the boundary cases for third stage

s(1) <= c2(0) xor s2(0);
c3(0) <= c2(0) and s2(0);
s(n) <= c1(n-1) xor c2(n-1) xor c3(n-2);
c_final <= (c1(n-1) and c2(n-1)) or (c3(n-2) and (c1(n-1) xor c2(n-1))) ;

    cout <= c_final;

end csa_arch;