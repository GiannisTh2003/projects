library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

entity tb_ddc is
end entity tb_ddc;

architecture sim of tb_ddc is
    constant CLK_PERIOD : time := 10 ns; -- fs = 100 MHz
    constant FS         : real := 100.0e6;
    constant F_WANTED   : real := 10.5e6; -- 10 MHz carrier + 500 kHz baseband tone
    constant F_INTERF   : real := 35.0e6; -- 35 MHz out-of-band interferer

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal adc_in     : signed(15 downto 0) := (others => '0');
    -- FCW for 10 MHz NCO: (10e6 / 100e6) * 65536 = 6553.6 -> 6554
    signal fcw        : unsigned(15 downto 0) := to_unsigned(6554, 16);
    signal valid_out  : std_logic;
    signal I_baseband : signed(15 downto 0);
    signal Q_baseband : signed(15 downto 0);

    file out_file : text open write_mode is "ddc_output.csv";
begin

    -- 1. Clock Generation (100 MHz)
    clk <= not clk after CLK_PERIOD / 2;

    -- 2. Instantiate Unit Under Test (UUT)
    uut : entity work.ddc_top_module
        port map (
            clk        => clk,
            rst        => rst,
            adc_in     => adc_in,
            fcw        => fcw,
            valid_out  => valid_out,
            I_baseband => I_baseband,
            Q_baseband => Q_baseband
        );

    -- 3. Two-Tone Stimulus Generator
    stim_proc : process
        variable n          : integer := 0;
        variable t          : real;
        variable sig_wanted : real;
        variable sig_interf : real;
        variable combined   : real;
    begin
        rst <= '1';
        wait for CLK_PERIOD * 10;
        wait until rising_edge(clk);
        rst <= '0';

        -- Run for 16,384 ADC clocks (produces 1,024 decimated output samples)
        for i in 0 to 16383 loop
            t := real(n) / FS;
            sig_wanted := 0.45 * cos(2.0 * MATH_PI * F_WANTED * t);
            sig_interf := 0.45 * cos(2.0 * MATH_PI * F_INTERF * t);
            
            -- Scale to 14-bit amplitude (~8192) to avoid CORDIC 1.647x gain overflow
            combined := (sig_wanted + sig_interf) * 8192.0;
            adc_in   <= to_signed(integer(combined), 16);

            n := n + 1;
            wait until rising_edge(clk);
        end loop;

        report "Simulation Complete! Output saved to ddc_output.csv" severity note;
        std.env.stop; -- Stops simulator cleanly (VHDL-2008)
        wait;
    end process;

    -- 4. Log Valid Decimated I/Q Outputs to CSV
    log_proc : process(clk)
        variable row : line;
    begin
        if rising_edge(clk) then
            if rst = '0' and valid_out = '1' then
                write(row, integer'image(to_integer(I_baseband)));
                write(row, string'(","));
                write(row, integer'image(to_integer(Q_baseband)));
                writeline(out_file, row);
            end if;
        end if;
    end process;

end architecture sim;
