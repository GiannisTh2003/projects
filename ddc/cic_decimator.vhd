library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cic_decimator is
    generic (
        IN_WIDTH  : integer := 16;
        ACC_WIDTH : integer := 28; -- 16 + 3*log2(16) = 28 bits
        OUT_WIDTH : integer := 16;
        DECIM_R   : integer := 16  -- Decimation factor R
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        din       : in  signed(IN_WIDTH-1 downto 0);
        dout      : out signed(OUT_WIDTH-1 downto 0);
        valid_out : out std_logic
    );
end entity;

architecture rtl of cic_decimator is
    signal int1, int2, int3 : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal comb1, comb2, comb3 : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal d1, d2, d3 : signed(ACC_WIDTH-1 downto 0) := (others => '0');
    signal count : integer range 0 to DECIM_R-1 := 0;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                int1 <= (others => '0'); int2 <= (others => '0'); int3 <= (others => '0');
                comb1 <= (others => '0'); comb2 <= (others => '0'); comb3 <= (others => '0');
                d1 <= (others => '0'); d2 <= (others => '0'); d3 <= (others => '0');
                count <= 0;
                valid_out <= '0';
            else
                -- 1. Integrator Section (Runs at full ADC clock rate fs)
                int1 <= int1 + resize(din, ACC_WIDTH);
                int2 <= int2 + int1;
                int3 <= int3 + int2;

                -- 2. Rate Decimator & Comb Section (Runs at fs / R)
                if count = DECIM_R - 1 then
                    count <= 0;
                    valid_out <= '1';

                    comb1 <= int3 - d1;
                    d1    <= int3;

                    comb2 <= comb1 - d2;
                    d2    <= comb1;

                    comb3 <= comb2 - d3;
                    d3    <= comb2;
                else
                    count <= count + 1;
                    valid_out <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Truncate MSBs to output width (Removes DC gain of (R*M)^N)
    dout <= comb3(ACC_WIDTH-1 downto ACC_WIDTH-OUT_WIDTH);
end architecture;
