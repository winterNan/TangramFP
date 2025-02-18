----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/20/2025 07:01:17 PM
-- Design Name: 
-- Module Name: LZC - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- [1]. Nebojša Z. Milenković and Vladimir V. Stanković and Miljana Lj. Milić, "MODULAR DESIGN OF FAST LEADING ZEROS COUNTING CIRCUIT", Journal of ELECTRICAL ENGINEERING, VOL. 66, NO. 6, 2015, 329-333
----------------------------------------------------------------------------------

--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;

---- Basic 4-bit Leading Zero Counter (LZC-4)
--entity lzc_4bit is
--    port (
--        x : in std_logic_vector(3 downto 0);
--        q : out std_logic_vector(1 downto 0);
--        a : out std_logic
--    );
--end lzc_4bit;

--architecture rtl of lzc_4bit is
--begin
--    -- Boolean expressions from the paper:
--    -- z1 = (!x3)(!x2)(!x1)x0 + (!x3)(!x2)(!x1)(!x0)
--    -- z0 = (!x3)(!x2)x1 + (!x3)x2
--    -- v = (!x3)(!x2)(!x1)(!x0)
    
--    q(0) <= ((not x(3)) and  x(2)) or (not x(3) and not x(1));
--    q(1) <= not (x(3) or x(2));
--    a <= not (x(3) or x(2) or x(1) or x(0));
--end rtl;

---- 4-bit Leading Zero Encoder (LZE-4)
--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;
--entity lze_4bit is
--    port (
--        a0, a1, a2, a3 : in std_logic;
--        q2 : out std_logic_vector(1 downto 0)
--    );
--end lze_4bit;

--architecture rtl of lze_4bit is
--begin
--    -- Boolean expressions from the paper:
--    -- q2 = a0.(a1 + a2.a3)
--    -- q3 = a0.a1.(a2 + a3)
    
--    q2(0) <= a0 and (not a1 or (a2 and not a3));
--    q2(1) <= a0 and a1 and (not a2 or not a3);
--end rtl;

---- Complete 16-bit Leading Zero Counter
--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;
--entity lzc_16bit is
--    port (
--        x : in std_logic_vector(15 downto 0);
--        z : out std_logic_vector(3 downto 0);
--        v : out std_logic
--    );
--end lzc_16bit;

--architecture rtl of lzc_16bit is
--    -- Component declarations
--    component lzc_4bit is
--        port (
--            x : in std_logic_vector(3 downto 0);
--            q : out std_logic_vector(1 downto 0);
--            a : out std_logic
--        );
--    end component;
    
--    component lze_4bit is
--        port (
--            a0, a1, a2, a3 : in std_logic;
--            q2 : out std_logic_vector(1 downto 0)
--        );
--    end component;
    
--    -- Internal signals
--    signal z0, z1, z2, z3 : std_logic_vector(1 downto 0);
--    signal v0, v1, v2, v3 : std_logic;
--    signal upper_bits : std_logic_vector(1 downto 0);
    
--begin
--    -- Instantiate four LZC-4 blocks
--    lzc0: lzc_4bit port map(
--        x => x(15 downto 12),
--        q => z0,
--        a => v0
--    );
    
--    lzc1: lzc_4bit port map(
--        x => x(11 downto 8),
--        q => z1,
--        a => v1
--    );
    
--    lzc2: lzc_4bit port map(
--        x => x(7 downto 4),
--        q => z2,
--        a => v2
--    );
    
--    lzc3: lzc_4bit port map(
--        x => x(3 downto 0),
--        q => z3,
--        a => v3
--    );
    
--    -- Instantiate LZE-4 for upper bits
--    lze: lze_4bit port map(
--        a0 => v0,
--        a1 => v1,
--        a2 => v2,
--        a3 => v3,
--        q2 => upper_bits
--    );
    
--    -- MUX for lower bits based on upper bits
--    process(upper_bits, z0, z1, z2, z3)
--    begin
--        case upper_bits is
--            when "00" => z(1 downto 0) <= z0;
--            when "01" => z(1 downto 0) <= z1;
--            when "10" => z(1 downto 0) <= z2;
--            when "11" => z(1 downto 0) <= z3;
--            when others => z(1 downto 0) <= "00";
--        end case;
--    end process;
    
--    -- Assign upper bits
--    z(3 downto 2) <= upper_bits;
    
--    -- Generate v output (all zeros)
--    v <= v0 and v1 and v2 and v3;
    
--end rtl;

---- 54-bit Leading Zero Counter
--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;
--entity LZC_54 is
--    port (
--        mantissa   : in std_logic_vector(53 downto 0);
--        enable      : in std_logic;  -- New enable port
--        shift_count: out std_logic_vector(5 downto 0)
----        shift_all  : out std_logic
--    );
--end LZC_54;

--architecture rtl of LZC_54 is
--    component lzc_16bit is
--        port (
--            x : in std_logic_vector(15 downto 0);
--            z : out std_logic_vector(3 downto 0);
--            v : out std_logic
--        );
--    end component;  
--    component lzc_4bit is
--        port (
--            x : in std_logic_vector(3 downto 0);
--            q : out std_logic_vector(1 downto 0);
--            a : out std_logic
--        );
--    end component;
--    signal z0, z1, z2 : std_logic_vector(3 downto 0);
--    signal z3 : std_logic_vector(1 downto 0);
--    signal v0, v1, v2, v3 : std_logic;
--    signal mantissa_gated_0 : std_logic_vector(15 downto 0);
--    signal mantissa_gated_1 : std_logic_vector(15 downto 0);
--    signal mantissa_gated_2 : std_logic_vector(15 downto 0);
--    signal mantissa_gated_3 : std_logic_vector(3 downto 0);
--begin
--    -- Gate input process
--    process(enable, mantissa)
--    begin
--        if enable = '1' then
--            mantissa_gated_0 <= mantissa(53 downto 38);
--            mantissa_gated_1 <= mantissa(37 downto 22);
--            mantissa_gated_2 <= mantissa(21 downto 6);
--            mantissa_gated_3 <= mantissa(5 downto 2);
--        else
--            mantissa_gated_0 <= (others => '0');
--            mantissa_gated_1 <= (others => '0');
--            mantissa_gated_2 <= (others => '0');
--            mantissa_gated_3 <= (others => '0');
--        end if;
--    end process;
--    -- Instantiate three LZC-16 blocks
--    lzc0: lzc_16bit port map(
--        x => mantissa_gated_0,
--        z => z0,
--        v => v0
--    );
    
--    lzc1: lzc_16bit port map(
--        x => mantissa_gated_1,
--        z => z1,
--        v => v1
--    );
    
--    lzc2: lzc_16bit port map(
--        x => mantissa_gated_2,
--        z => z2,
--        v => v2
--    );
    
--    -- Instantiate one LZC-4 block for the remaining bits
--    lzc3: lzc_4bit port map(
--        x => mantissa_gated_3,
--        q => z3,
--        a => v3
--    );

--    -- MUX for lower bits based on upper bits
--    process(v0, v1, v2, v3, z0, z1, z2,z3,mantissa,enable)
--    begin
--    if enable = '1' then
--        if v0 = '0' then
--            shift_count <= "00" & z0;
--        elsif v1 = '0' then
--            shift_count <= "01" & z1;
--        elsif v2 = '0' then
--            shift_count <= "10" & z2;
--        elsif v3 = '0' then
--            shift_count <= "11" & "00" & z3;
--        elsif mantissa(1) = '1' then
--            shift_count <= "110100";
--        elsif mantissa(0) = '1' then
--            shift_count <= "110101";
--        else
--            shift_count <= "110110";
--        end if;
--    else
--        shift_count <= (others => '0');
--    end if;
--    end process;
    
--    -- Generate shift_all output (all zeros)
----    shift_all <= v0 and v1 and v2 and v3 and not mantissa(1) and not mantissa(0);
--end rtl;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Basic 6-bit LZC to maximize single LUT usage
entity lzc_6bit is
    port (
        x : in std_logic_vector(5 downto 0);
        z : out std_logic_vector(2 downto 0);
        v : out std_logic
    );
end lzc_6bit;

architecture rtl of lzc_6bit is
    -- This will map to a single 6-LUT
begin
    process(x)
    begin
        if x(5) = '1' then
            z <= "000";
            v <= '0';
        elsif x(4) = '1' then
            z <= "001";
            v <= '0';
        elsif x(3) = '1' then
            z <= "010";
            v <= '0';
        elsif x(2) = '1' then
            z <= "011";
            v <= '0';
        elsif x(1) = '1' then
            z <= "100";
            v <= '0';
        elsif x(0) = '1' then
            z <= "101";
            v <= '0';
        else
            z <= "110";
            v <= '1';
        end if;
    end process;
end rtl;


-- Main 54-bit LZC optimized for Kintex-7
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity lzc_54 is
    port (
        mantissa : in std_logic_vector(53 downto 0);
        enable: in std_logic;
        shift_count : out std_logic_vector(5 downto 0)
    );
end lzc_54;

architecture rtl of lzc_54 is
    component lzc_6bit is
        port (
            x : in std_logic_vector(5 downto 0);
            z : out std_logic_vector(2 downto 0);
            v : out std_logic
        );
    end component;
    
    component priority_encoder_6 is
        port (
            v : in std_logic_vector(5 downto 0);
            z : out std_logic_vector(2 downto 0)
        );
    end component;
    
    -- Signals for the first level (9 groups of 6 bits)
    type v_array is array (8 downto 0) of std_logic;
    type z_array is array (8 downto 0) of std_logic_vector(2 downto 0);
    signal first_level_v : std_logic_vector(8 downto 0);--v_array;
    signal first_level_z : z_array;
    
    signal first_valid_block : unsigned(2 downto 0);  -- Encoding of which block
    signal base_count : unsigned(5 downto 0);
    
begin
    -- First level: Generate 9 6-bit LZC blocks
    gen_first_level: for i in 0 to 8 generate
        -- Handle the last incomplete block
        last_block: if i = 8 generate
            lzc_block: lzc_6bit
                port map (
                    x => mantissa(53 downto 48),
                    z => first_level_z(i),
                    v => first_level_v(i)
                );
        end generate last_block;
        
        -- Regular blocks
        regular_block: if i < 8 generate
            lzc_block: lzc_6bit
                port map (
                    x => mantissa((i*6 + 5) downto (i*6)),
                    z => first_level_z(i),
                    v => first_level_v(i)
                );
        end generate regular_block;
    end generate gen_first_level;
    

    process(first_level_v,first_level_z,enable)
        begin
            if enable = '0' then
                first_valid_block <= (others => '0');
                base_count <= (others => '0');
            elsif    first_level_v(8) = '0' then
                first_valid_block <= unsigned(first_level_z(8));
                base_count <= "000000";
--                shift_count <= std_logic_vector(resize(unsigned(first_level_z(8)),6));
            elsif first_level_v(7) = '0' then
                first_valid_block <= unsigned(first_level_z(7));
                base_count <= to_unsigned(6,6);
--                shift_count <= std_logic_vector(to_unsigned((to_integer(unsigned(first_level_z(7)))+ 6),6));
            elsif first_level_v(6) = '0' then
                first_valid_block <= unsigned(first_level_z(6));
                base_count <= to_unsigned(12,6);
--                shift_count <= std_logic_vector(to_unsigned((to_integer(unsigned(first_level_z(6)))+ 12),6));
            elsif first_level_v(5) = '0' then
                first_valid_block <= unsigned(first_level_z(5));
                base_count <= to_unsigned(18,6);
--                shift_count <= std_logic_vector(to_unsigned((to_integer(unsigned(first_level_z(5)))+ 18),6));
            elsif first_level_v(4) = '0' then
                first_valid_block <= unsigned(first_level_z(4));
                base_count <= to_unsigned(24,6);
--                shift_count <= std_logic_vector(to_unsigned((to_integer(unsigned(first_level_z(4)))+ 24),6));
            elsif first_level_v(3) = '0' then
                first_valid_block <= unsigned(first_level_z(3));
                base_count <= to_unsigned(30,6);
--                shift_count <= std_logic_vector(to_unsigned((to_integer(unsigned(first_level_z(3)))+ 30),6));
            elsif first_level_v(2) = '0' then
                first_valid_block <= unsigned(first_level_z(2));
                base_count <= to_unsigned(36,6);
--                shift_count <= std_logic_vector(to_unsigned((to_integer(unsigned(first_level_z(2)))+ 36),6));
            elsif first_level_v(1) = '0' then
                first_valid_block <= unsigned(first_level_z(1));
                base_count <= to_unsigned(42,6);
--                shift_count <= std_logic_vector(to_unsigned((to_integer(unsigned(first_level_z(1)))+ 42),6));
            elsif first_level_v(0) = '0' then
                first_valid_block <= unsigned(first_level_z(0));
                base_count <= to_unsigned(48,6);
            else 
                first_valid_block <= to_unsigned(6,3);
                base_count <= to_unsigned(48,6);
--                shift_count <= std_logic_vector(to_unsigned((to_integer(unsigned(first_level_z(0)))+ 48),6));
            end if;
        end process;
    shift_count <= std_logic_vector(base_count + first_valid_block);
end rtl;
