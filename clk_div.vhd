library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clk_div is
    generic(HALF_PERIOD : integer := 50); -- f_out = f_in/(2*HALF_PERIOD)
    port(
        clk   : in  std_logic;  -- 100MHz
        rst   : in  std_logic;  -- active-high
        fsclk : out std_logic
    );
end entity;

architecture rtl of clk_div is
    signal cnt : unsigned(15 downto 0) := (others=>'0');
    signal reg : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                cnt <= (others=>'0');
                reg <= '0';
            else
                if cnt = to_unsigned(HALF_PERIOD-1, cnt'length) then
                    cnt <= (others=>'0');
                    reg <= not reg;
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;

    fsclk <= reg;
end architecture;
