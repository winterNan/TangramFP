library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Mode selection of the TangramFP MAC, moved out of MAC.vhd unchanged so that its
-- cost shows up as a separate instance in the utilization and power reports.
entity mode_sel is
    generic (ex_width : integer := 8; thr1v : integer := 5; thr2v : integer := 10; gating : integer := 2);
    port (exp_ab, exp_cn : in unsigned(ex_width-1 downto 0);
          nan_input, a_zero, b_zero, n_rst : in std_logic;
          mode : out std_logic_vector(1 downto 0));
end mode_sel;

architecture rtl of mode_sel is
    constant thr1 : signed(ex_width-1 downto 0) := to_signed(thr1v, ex_width);
    constant thr2 : signed(ex_width-1 downto 0) := to_signed(thr2v, ex_width);
    signal diff : signed(ex_width downto 0);
    signal ex_cn_cmp, ex_ab_cmp : signed(ex_width downto 0);
begin
    gen_std : if gating = 0 generate
        mode <= "00";
    end generate;

    gen_sel : if gating /= 0 generate
        ex_ab_cmp <= signed(resize(exp_ab, ex_width+1));
        ex_cn_cmp <= signed(resize(exp_cn, ex_width+1));
        diff <= ex_cn_cmp - ex_ab_cmp;

        mode_selection : process (nan_input, a_zero, b_zero, diff, n_rst)
        begin
            if n_rst = '0' then
                mode <= "11";
            else
                if nan_input = '0' and a_zero = '0' and b_zero = '0' then
                    if (diff = 0 or diff < 0) then
                        mode <= "00";
                    elsif (diff > 0 and diff < thr1) then
                        mode <= "01";
                    elsif (diff >= thr1 and diff < thr2) then
                        mode <= "10";
                    else
                        mode <= "11";
                    end if;
                else
                    mode <= "11";                        -- zero or invalid operand: Null (no inferred latch)
                end if;
            end if;
        end process;
    end generate;
end rtl;
