library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nco_cordic_mixer is
    generic (
        WIDTH  : integer := 16;
        STAGES : integer := 14
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        adc_in  : in  signed(WIDTH-1 downto 0);
        fcw     : in  unsigned(WIDTH-1 downto 0); -- Frequency Control Word
        i_mixed : out signed(WIDTH-1 downto 0);
        q_mixed : out signed(WIDTH-1 downto 0)
    );
end entity;

architecture rtl of nco_cordic_mixer is
    type angle_lut_t is array (0 to 13) of signed(WIDTH-1 downto 0);
    -- Precomputed atan(2^-i) scaled to 16-bit phase (-pi to +pi = -32768 to 32767)
    constant ATAN_LUT : angle_lut_t := (
        to_signed(8192, WIDTH), to_signed(4836, WIDTH), to_signed(2555, WIDTH),
        to_signed(1297, WIDTH), to_signed(651,  WIDTH), to_signed(326,  WIDTH),
        to_signed(163,  WIDTH), to_signed(81,   WIDTH), to_signed(41,   WIDTH),
        to_signed(20,   WIDTH), to_signed(10,   WIDTH), to_signed(5,    WIDTH),
        to_signed(3,    WIDTH), to_signed(1,    WIDTH)
    );

    type pipe_t is array (0 to STAGES) of signed(WIDTH-1 downto 0);
    signal x, y, z : pipe_t := (others => (others => '0'));
    signal phase_acc : unsigned(WIDTH-1 downto 0) := (others => '0');
begin
    process(clk)
        variable msbs : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                phase_acc <= (others => '0');
            else
                -- 1. NCO Phase Accumulator
                phase_acc <= phase_acc + fcw;

                -- 2. Quadrant Mapping (Map full 360 deg into +/- 90 deg)
                msbs := std_logic_vector(phase_acc(WIDTH-1 downto WIDTH-2));
                case msbs is
                    when "01" => -- Quadrant 2: rotate by -90 deg
                        x(0) <= (others => '0');
                        y(0) <= adc_in;
                        z(0) <= signed(phase_acc) - to_signed(16384, WIDTH);
                    when "10" => -- Quadrant 3: rotate by +90 deg
                        x(0) <= (others => '0');
                        y(0) <= -adc_in;
                        z(0) <= signed(phase_acc) + to_signed(16384, WIDTH);
                    when others => -- Quadrants 1 & 4: already in range
                        x(0) <= adc_in;
                        y(0) <= (others => '0');
                        z(0) <= signed(phase_acc);
                end case;

                -- 3. Unrolled Pipelined CORDIC Shift-Add Loop
                for i in 0 to STAGES-1 loop
                    if z(i) < 0 then
                        x(i+1) <= x(i) + shift_right(y(i), i);
                        y(i+1) <= y(i) - shift_right(x(i), i);
                        z(i+1) <= z(i) + ATAN_LUT(i);
                    else
                        x(i+1) <= x(i) - shift_right(y(i), i);
                        y(i+1) <= y(i) + shift_right(x(i), i);
                        z(i+1) <= z(i) - ATAN_LUT(i);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    i_mixed <= x(STAGES);
    q_mixed <= y(STAGES);
end architecture;
