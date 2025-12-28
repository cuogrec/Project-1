library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_dac_mcp4921 is
    port(
        clk_100M : in  std_logic;     -- 100 MHz
        rst      : in  std_logic;     -- active-high
        start_tx : in  std_logic;     -- 1-cycle pulse (when idle)
        data_in  : in  std_logic_vector(11 downto 0);

        dac_cs_n : out std_logic;
        dac_sck  : out std_logic;
        dac_sdi  : out std_logic;

        busy     : out std_logic
    );
end entity;

architecture rtl of spi_dac_mcp4921 is
    type state_t is (IDLE, LOAD, SHIFT, DONE);
    signal state : state_t := IDLE;

    signal shreg  : std_logic_vector(15 downto 0) := (others=>'0');
    signal bitcnt : unsigned(4 downto 0) := (others=>'0');
    signal sckdiv : unsigned(2 downto 0) := (others=>'0');

    signal cs_r  : std_logic := '1';
    signal sck_r : std_logic := '0';
    signal sdi_r : std_logic := '0';
begin
    dac_cs_n <= cs_r;
    dac_sck  <= sck_r;
    dac_sdi  <= sdi_r;

    busy <= '1' when (state = LOAD or state = SHIFT) else '0';

    process(clk_100M)
    begin
        if rising_edge(clk_100M) then
            if rst = '1' then
                state  <= IDLE;
                cs_r   <= '1';
                sck_r  <= '0';
                sdi_r  <= '0';
                bitcnt <= (others=>'0');
                sckdiv <= (others=>'0');
            else
                case state is
                    when IDLE =>
                        cs_r  <= '1';
                        sck_r <= '0';
                        if start_tx='1' then
                            shreg  <= "0011" & data_in;       -- control bits + 12-bit data
                            bitcnt <= to_unsigned(15,5);
                            cs_r   <= '0';
                            state  <= LOAD;
                        end if;

                    when LOAD =>
                        sckdiv <= (others=>'0');
                        state  <= SHIFT;

                    when SHIFT =>
                        sckdiv <= sckdiv + 1;
                        case sckdiv is
                            when "000" =>
                                sck_r <= '0';
                                sdi_r <= shreg(15);

                            when "010" =>
                                sck_r <= '1'; -- DAC samples on rising edge

                            when "100" =>
                                sck_r <= '0';
                                shreg <= shreg(14 downto 0) & '0';
                                if bitcnt = 0 then
                                    state <= DONE;
                                else
                                    bitcnt <= bitcnt - 1;
                                end if;
                                sckdiv <= (others=>'0');

                            when others =>
                                null;
                        end case;

                    when DONE =>
                        cs_r  <= '1';
                        sck_r <= '0';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture;
