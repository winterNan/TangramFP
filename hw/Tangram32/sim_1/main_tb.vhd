library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;


entity kacy_mul_tb is
end kacy_mul_tb;

architecture behavior of kacy_mul_tb is
    constant RE_WIDTH : integer := 48;
    constant WIDTH : integer := 24;
    constant CUT : integer := 11;

    component kacy_32_mult 
        generic(
            --re_width : integer := RE_WIDTH;
            width : integer := WIDTH;
            cut : integer := CUT
        );
        port(
            Clk : in std_logic;
            n_rst : in std_logic;
            u : in std_logic_vector(width-1 downto 0);
            v : in std_logic_vector(width-1 downto 0);
            mode : in std_logic_vector(1 downto 0);
            mantissa : out std_logic_vector(re_width-1 downto 0)
        );
    end component;

    signal clk : std_logic := '0';
    signal n_rst : std_logic ;--:= '0';
    signal u_m, v_m : std_logic_vector(WIDTH-2 downto 0);    
    signal u, v : std_logic_vector(WIDTH-1 downto 0);
    signal mode : std_logic_vector(1 downto 0):="11";
    signal mantissa : std_logic_vector(RE_WIDTH-1 downto 0);
    signal expected : std_logic_vector(re_width-1 downto 0);
    
    constant clk_period : time := 10 ns;

    procedure generate_random_vector(seed1, seed2: inout positive; 
                                  signal vec: out std_logic_vector) is
        variable r: real;
        variable int_val: integer;
    begin
        uniform(seed1, seed2, r);
        int_val := integer(r * 2.0 ** vec'length);
        vec <= std_logic_vector(to_unsigned(int_val, vec'length));
    end procedure;

begin
    uut: kacy_32_mult 
        generic map(
            --re_width => RE_WIDTH,
            width => WIDTH,
            cut => CUT
        )
        port map(
            Clk => clk,
            n_rst => n_rst,
            u => u,
            v => v,
            mode => mode,
            mantissa => mantissa
        );

    clk_process: process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;
    u <= '1'&u_m;
    v <= '1'&v_m;
    
    stim_proc: process
        variable seed1, seed2: positive := 1;
        variable line_out: line;
        file output_file: text open write_mode is "mul_results.txt";
    begin
        -- Reset
        n_rst <= '0';
        mode <= "00";
        wait for clk_period * 2;
        n_rst <= '1';
        
        -- Test multiple modes
        for m in 0 to 3 loop
            mode <= std_logic_vector(to_unsigned(m, 2));
            
            -- Run multiple test cases per mode
            for i in 1 to 100 loop
                generate_random_vector(seed1, seed2, u_m);
                generate_random_vector(seed1, seed2, v_m);
                wait for clk_period/2;
                expected <= std_logic_vector(resize(unsigned(u) * unsigned(v), RE_WIDTH));
                
                
                wait for clk_period/2;
                
                -- Log results
                if (expected = mantissa)then
                    write(line_out, string'("success "));
                    write(line_out, i);
                    writeline(output_file, line_out);
                else
                    write(line_out, string'("failure "));
                    write(line_out, i);
                    writeline(output_file, line_out);          
                end if;      
                write(line_out, string'("Test "));
                write(line_out, i);
                writeline(output_file, line_out);
                
                write(line_out, string'("Mode: "));
                write(line_out, to_integer(unsigned(mode)));
                writeline(output_file, line_out);
                
                write(line_out, string'("u: "));
                write(line_out, to_integer(unsigned(u)));
                writeline(output_file, line_out);
                
                write(line_out, string'("v: "));
                write(line_out, to_integer(unsigned(v)));
                writeline(output_file, line_out);
                
                write(line_out, string'("mantissa: "));
                write(line_out, to_integer(unsigned(mantissa)));
                writeline(output_file, line_out);
                writeline(output_file, line_out);
            end loop;
        end loop;
        
        wait;
    end process;
end behavior;