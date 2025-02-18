library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fulladder is
    port (a : in std_logic;
          b : in std_logic;
          cin : in std_logic;
          sum : out std_logic;
          carry : out std_logic
          );
end fulladder;

architecture fa of fulladder is

begin

    sum <= a xor b xor cin;
    carry <= (a and b) or (cin and (a xor b));

end;
