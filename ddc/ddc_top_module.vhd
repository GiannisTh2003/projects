library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity ddc_top_module is
generic (
        ACC_WIDTH : integer := 28; -- 16 + 3*log2(16) = 28 bits
        OUT_WIDTH : integer := 16;
        DECIM_R   : integer := 16;
        WIDTH  : integer := 16;
        STAGES : integer := 14 
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        adc_in    : in  signed(WIDTH-1 downto 0);
        fcw       : in  unsigned(WIDTH-1 downto 0);  -- Frequency Control Word
        valid_out : out std_logic;
        I_baseband: out signed(WIDTH-1 downto 0);
        Q_baseband: out signed(WIDTH-1 downto 0)
    );
end ddc_top_module;

architecture Behavioral of ddc_top_module is
    component nco_cordic_mixer is
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
    end component;
    component cic_decimator is
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
    end component;
    signal i_mixed_plc: signed(WIDTH-1 downto 0);
    signal q_mixed_plc: signed(WIDTH-1 downto 0);
    signal i_valid_out_plc:std_logic;
    signal q_valid_out_plc: std_logic;
begin
    valid_out<= i_valid_out_plc and q_valid_out_plc;
    top_cordic: nco_cordic_mixer
        generic map (WIDTH=>WIDTH, STAGES=>STAGES)
        port map(clk=>clk, rst=>rst, adc_in=>adc_in, fcw=>fcw, i_mixed=>i_mixed_plc, q_mixed=>q_mixed_plc);
    
    i_cic: cic_decimator
        generic map (IN_WIDTH=>WIDTH, ACC_WIDTH=>ACC_WIDTH, OUT_WIDTH=>OUT_WIDTH, DECIM_R=>DECIM_R)
        port map(clk=>clk, rst=>rst, din=>i_mixed_plc, dout=>I_baseband,valid_out=>i_valid_out_plc);
    
    q_cic:cic_decimator
        generic map (IN_WIDTH=>WIDTH, ACC_WIDTH=>ACC_WIDTH, OUT_WIDTH=>OUT_WIDTH, DECIM_R=>DECIM_R)
        port map(clk=>clk, rst=>rst, din=>q_mixed_plc, dout=>Q_baseband,valid_out=>q_valid_out_plc);

end Behavioral;
