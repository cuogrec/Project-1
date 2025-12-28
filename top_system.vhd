library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_system is
    port(
        clk     : in  std_logic;  -- 100MHz
        rst     : in  std_logic;  -- active-high

        cs_dac  : out std_logic;
        sck_dac : out std_logic;
        dac_out : out std_logic
    );
end entity;

architecture rtl of top_system is
    signal fsclk       : std_logic;
    signal fsclk_d     : std_logic := '0';
    signal sample_tick : std_logic := '0';

    signal x_u12 : std_logic_vector(11 downto 0);
    signal y_u12 : std_logic_vector(11 downto 0);

    signal dac_busy  : std_logic;
    signal start_spi : std_logic := '0';
begin
    -- 1) fsclk generator (default 1MHz if HALF_PERIOD=50 and clk=100MHz)
    u_div : entity work.clk_div
        generic map(HALF_PERIOD => 50)
        port map(
            clk   => clk,
            rst   => rst,
            fsclk => fsclk
        );

    -- 2) sample_tick: rising-edge detect fsclk in clk domain (1 cycle pulse)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                fsclk_d     <= '0';
                sample_tick <= '0';
            else
                fsclk_d     <= fsclk;
                sample_tick <= (not fsclk_d) and fsclk;
            end if;
        end if;
    end process;

    -- 3) sine LUT: x[n]
    u_lut : entity work.sine_lut
        port map(
            fsclk  => fsclk,
            rst    => rst,
            data_o => x_u12
        );

    -- 4) FIR/Convolution LPF 7-tap: y[n] = x[n] * h[n]
    u_fir : entity work.fir_lpf7_conv
        port map(
            clk         => clk,
            rst         => rst,
            sample_tick => sample_tick,
            x_u12       => x_u12,
            y_u12       => y_u12
        );

    -- 5) Start SPI only when idle (avoid overlapping frames)
    process(clk)
    begin
        if rising_edge(clk) then
            if rst='1' then
                start_spi <= '0';
            else
                start_spi <= sample_tick and (not dac_busy);
            end if;
        end if;
    end process;

    -- 6) SPI DAC driver (MCP4921)
    u_dac : entity work.spi_dac_mcp4921
        port map(
            clk_100M => clk,
            rst      => rst,
            start_tx => start_spi,
            data_in  => y_u12,
            dac_cs_n => cs_dac,
            dac_sck  => sck_dac,
            dac_sdi  => dac_out,
            busy     => dac_busy
        );

end architecture;
