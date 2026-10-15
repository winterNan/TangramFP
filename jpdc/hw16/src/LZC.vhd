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
----------------------------------------------------------------------------------

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
        mantissa : in std_logic_vector(24 downto 0);
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
--    type v_array is array (8 downto 0) of std_logic;
    type z_array is array (4 downto 0) of std_logic_vector(2 downto 0);
    signal first_level_v : std_logic_vector(8 downto 0);--v_array;
    signal first_level_z : z_array;
    
    signal first_valid_block : unsigned(2 downto 0);  -- Encoding of which block
    signal base_count : unsigned(5 downto 0);
    
begin
    -- First level: Generate 9 6-bit LZC blocks
    gen_first_level: for i in 0 to 4 generate
        -- Handle the last incomplete block
        last_block: if i = 4 generate

                first_level_z(4) <= "00"& not mantissa(24);
                first_level_v(4) <= not mantissa(24);
        end generate last_block;
        
        -- Regular blocks
        regular_block: if i < 4 generate
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
          if enable = '1' then

            if first_level_v(4) = '0' then
                first_valid_block <= unsigned(first_level_z(4));
                base_count <= to_unsigned(0,6);
            elsif first_level_v(3) = '0' then
                first_valid_block <= unsigned(first_level_z(3));
                base_count <= to_unsigned(1,6);
            elsif first_level_v(2) = '0' then
                first_valid_block <= unsigned(first_level_z(2));
                base_count <= to_unsigned(7,6);
            elsif first_level_v(1) = '0' then
                first_valid_block <= unsigned(first_level_z(1));
                base_count <= to_unsigned(13,6);
            elsif first_level_v(0) = '0' then
                first_valid_block <= unsigned(first_level_z(0));
                base_count <= to_unsigned(19,6);
            else 
                first_valid_block <= to_unsigned(0,3);
                base_count <= to_unsigned(0,6);
            end if;
           end if;
        end process;
    shift_count <= std_logic_vector(base_count + first_valid_block);
end rtl;
