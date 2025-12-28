library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fir_lpf7_conv is
    port(
        clk         : in  std_logic;  -- 100MHz
        rst         : in  std_logic;  -- active-high
        sample_tick : in  std_logic;  -- 1-cycle pulse / sample
        x_u12       : in  std_logic_vector(11 downto 0); -- 0..4095
        y_u12       : out std_logic_vector(11 downto 0)  -- 0..4095
    );
end entity;

architecture rtl of fir_lpf7_conv is
    -- 7-tap delay line, centered signed: x_s = x_u12 - 2048 (range ~[-2048..2047])
    type xbuf_t is array(0 to 6) of signed(12 downto 0);
    signal xbuf : xbuf_t := (others => (others=>'0'));

    -- integer taps (no /16 here); we will SHIFT=4 after accumulate
    constant H0 : integer := 1;
    constant H1 : integer := 2;
    constant H2 : integer := 3;
    constant H3 : integer := 4;
    constant H4 : integer := 3;
    constant H5 : integer := 2;
    constant H6 : integer := 1;

    function clip_u12(v : integer) return unsigned is
        variable r : integer := v;
    begin
        if r < 0 then r := 0; end if;
        if r > 4095 then r := 4095; end if;
        return to_unsigned(r, 12);
    end function;

    function to_signed_centered(u12 : std_logic_vector(11 downto 0)) return signed is
        variable tmp : signed(12 downto 0);
    begin
        tmp := signed(resize(unsigned(u12), 13)) - to_signed(2048, 13);
        return tmp;
    end function;

    signal y_reg : unsigned(11 downto 0) := (others=>'0');
begin
    y_u12 <= std_logic_vector(y_reg);

    process(clk)
        variable acc   : integer;
        variable yint  : integer;
        variable x0,x1,x2,x3,x4,x5,x6 : integer;
    begin
        if rising_edge(clk) then
            if rst='1' then
                xbuf  <= (others => (others=>'0'));
                y_reg <= (others=>'0');
            else
                if sample_tick='1' then
                    -- shift delay line (newest at 0)
                    xbuf(6) <= xbuf(5);
                    xbuf(5) <= xbuf(4);
                    xbuf(4) <= xbuf(3);
                    xbuf(3) <= xbuf(2);
                    xbuf(2) <= xbuf(1);
                    xbuf(1) <= xbuf(0);
                    xbuf(0) <= to_signed_centered(x_u12);

                    -- compute convolution (integer MAC)
                    x0 := to_integer(xbuf(0));
                    x1 := to_integer(xbuf(1));
                    x2 := to_integer(xbuf(2));
                    x3 := to_integer(xbuf(3));
                    x4 := to_integer(xbuf(4));
                    x5 := to_integer(xbuf(5));
                    x6 := to_integer(xbuf(6));

                    acc := x0*H0 + x1*H1 + x2*H2 + x3*H3 + x4*H4 + x5*H5 + x6*H6;

                    -- scale by /16 (SHIFT=4) and offset back to unsigned
                    yint := (acc / 16) + 2048;  -- same as >>4 for positive/negative integer division in VHDL integer
                    y_reg <= clip_u12(yint);
                end if;
            end if;
        end if;
    end process;

end architecture;
