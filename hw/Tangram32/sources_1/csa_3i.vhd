library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CSA3i is
    generic(n : integer := 48);
    Port ( x : in  std_logic_vector (n-1 downto 0);
           y : in  std_logic_vector (n-1 downto 0);
           z : in  std_logic_vector (n-1 downto 0);
           cout : out std_logic;
           s : out std_logic_vector (n downto 0)
         );
end CSA3i;

--architecture csa_arch of CSA3i is
--attribute use_carry_chain : string;
--attribute use_carry_chain of csa_arch : architecture is "yes";
--attribute keep : string;
--component fulladder is
--    port (a : in std_logic;
--          b : in std_logic;
--          cin : in std_logic;
--          sum : out std_logic;
--          carry : out std_logic
--         );
--end component;
--signal c1,s1,c2 : unsigned (n-1 downto 0) := (others => '0');

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
--    for i in 0 to n-2 generate
--        fa : fulladder
--            port map(
--                a => s1(i+1),
--                b => c1(i),
--                cin => c2(i),
--                sum => s(i+1),
--                carry => c2(i+1)
--                );
--    end generate;
---- fa_inst20 : fulladder port map(s1(1),c1(0),c2(0),s(1),c2(1));
---- fa_inst21 : fulladder port map(s1(2),c1(1),c2(1),s(2),c2(2));
---- fa_inst22 : fulladder port map(s1(3),c1(2),c2(2),s(3),c2(3));

--third_stage : fulladder port map(a => '0', b => c1(n-1), cin => c2(n-1),sum => s(n),carry => cout);

--s(0) <= s1(0);
----    attribute keep of c1 : signal is "true";
----    attribute keep of man_ab_sub : signal is "true";
--end csa_arch;--////////////////////////////////////////////////////////
architecture csa_arch of CSA3i is
    -- Attribute to enable carry chain
    attribute use_carry_chain : string;
    attribute use_carry_chain of csa_arch : architecture is "yes";
    
    -- Signals for intermediate carry and sum
    signal c1 : std_logic_vector(n-1 downto 0);
    signal s1 : std_logic_vector(n-1 downto 0);
    signal c2 : std_logic_vector(n-1 downto 0); -- One extra bit for the final carry chain

begin

    -- First stage: Full adder for x + y + z
    first_stage: for i in 0 to n-1 generate
        s1(i) <= (x(i) xor y(i)) xor z(i); -- Sum
        c1(i) <= (x(i) and y(i)) or (z(i) and (y(i) xor x(i))); -- Carry
    end generate;

    -- Second stage: Propagate sum and carry
-- Second stage: Propagate sum and carry
        second_stage: for i in 0 to n-1 generate
            stage_logic: if i = 0 generate
                s(i) <= s1(i); -- Propagate first sum
                c2(i) <= '0';  -- Initial carry
            end generate stage_logic;
    
            stage_logic_other: if i > 0 generate
                s(i) <= s1(i) xor c1(i-1) xor c2(i-1); -- Sum with carry propagation
                c2(i) <= (s1(i) and c1(i-1)) or ( c2(i-1) and (s1(i) xor c1(i-1))); -- Carry
            end generate stage_logic_other;
        end generate second_stage;

    -- Final stage: Compute the last sum and carry out
    s(n) <= c1(n-1) xor c2(n-1);
    cout <= (c1(n-1) and c2(n-1)); -- Final carry out

end csa_arch;