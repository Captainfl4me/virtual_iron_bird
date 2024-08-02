----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Nicolas THIERRY
-- 
-- Create Date: 05.06.2024 22:57:43
-- Design Name: 
-- Module Name: real_time_physical_simulation - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bmp280_virtual is
    Generic (
        I2C_ADRR: unsigned(6 downto 0) := to_unsigned(0, 7)
    );
    Port (
        i_SCL  : in std_logic;
        io_SDA : inout std_logic
    );
end bmp280_virtual;

architecture Behavioral of bmp280_virtual is
    type State_type is (Starting, Started, Ending, Ended);
    type Control_State_type is (Read_Address, Ack, Execute_command);
    type Command_type is (Read_From_Bus, Write_To_Bus);
    
    signal s_is_starting : std_logic := '0';
    signal s_is_ending   : std_logic := '0';
    
    signal s_rst   : std_logic := '0';
    signal s_is_me : std_logic := '0';
    
    signal s_bit_counter      : integer range 0 to 7 := 0;
    signal s_bit_counter_next : integer range 0 to 8 := 0;
    signal current_read_byte  : std_logic_vector(7 downto 0) := (others => '0');
    signal current_write_byte : std_logic_vector(7 downto 0) := (others => '0');

    signal s_state                 : State_type := Ended;
    signal s_is_ack                : std_logic := '0';
    signal s_is_last_ack_valid     : std_logic := '0';
    signal s_is_reading_addr       : std_logic := '1';
    signal s_is_writing_to_bus     : std_logic := '0';
    signal s_command_addr          : std_logic_vector(7 downto 0) := (others => '0');
    signal s_has_read_command_addr : std_logic := '0';
    signal s_command_addr_first_set: std_logic := '1';
begin
    -------------------------------------------
    -- STATE CONDITION DETECTION LOGIC
    -------------------------------------------
    -- Start condition detection
    process (io_SDA) is
    begin
        s_is_starting <= '0';
        if falling_edge(io_SDA) then
            if i_SCL = '1' then
                s_is_starting <= '1';
            end if;
        end if;    
    end process;
    -- Stop condition detection
    process (io_SDA) is
    begin
        s_is_ending <= '0';
        if rising_edge(io_SDA) then
            if i_SCL = '1' then
                s_is_ending <= '1';
            end if;
        end if;    
    end process;
    -- State logic
    s_state <= Starting when s_is_starting = '1' else
               Ending   when s_is_ending = '1' else
               Started  when s_state = Starting else
               Ended    when s_state = Ending else s_state;
    s_rst <= '1' when s_state = Starting or s_state = Ending else '0';
    
    -- Bit counter logic
    process (i_SCL, s_rst) is
    begin
        if s_rst = '1' then
            s_bit_counter <= 0;
        elsif falling_edge(i_SCL) then
            if s_is_ack = '0' then
                s_bit_counter <= s_bit_counter_next;
            end if;
        end if;
    end process;
    s_bit_counter_next <= s_bit_counter + 1 when s_bit_counter /= 7 and s_state = Started else 0;
    
    -- Acknowledge State
    process (i_SCL, s_rst) is
    begin
        if s_rst = '1' then
            s_is_ack <= '0';
        elsif falling_edge(i_SCL) then
            if s_bit_counter = 7 then
                s_is_ack <= '1';
            else
                s_is_ack <= '0';
            end if;
        end if;
    end process;
    -- Acknowledge Verify
    process (i_SCL, s_rst) is
    begin
        if s_rst = '1' then
            s_is_last_ack_valid <= '1';
        elsif rising_edge(i_SCL) then
            s_is_last_ack_valid <= s_is_last_ack_valid;
            if s_is_ack = '1' then
                if io_SDA = '0' then
                    s_is_last_ack_valid <= '1';
                else
                    s_is_last_ack_valid <= '0';
                end if;
            end if;
        end if;
    end process;
 
    -- First address reading
    process (s_is_ack, s_is_starting) is
    begin
        if s_is_starting = '1' then
            s_is_reading_addr <= '1';
        elsif falling_edge(s_is_ack) then
            s_is_reading_addr <= '0';
        end if;
    end process;
    
    -- Address check
    process (s_is_ack, s_is_starting) is
    begin
        if s_is_starting = '1' then
            s_is_me <= '1';
        elsif rising_edge(s_is_ack) then
            if s_is_reading_addr = '1' then
                if current_read_byte(7 downto 1) = std_logic_vector(I2C_ADRR) then
                    s_is_me <= '1';
                else
                    s_is_me <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Read R/W flag
    process (s_is_ack, s_is_starting) is
    begin
        if s_is_starting = '1' then
            s_is_writing_to_bus <= '0';
        elsif rising_edge(s_is_ack) and s_is_reading_addr = '1' then
            s_is_writing_to_bus <= current_read_byte(0);
        end if;
    end process;

    -------------------------------------------
    -- READ FROM BUS LOGIC
    -------------------------------------------
    process (i_SCL, s_rst) is
    begin
        if s_rst = '1' then
            current_read_byte <= (others => '0');
        elsif rising_edge(i_SCL) and s_is_ack = '0'  then
            current_read_byte(7 - s_bit_counter) <= io_SDA;
        end if;
    end process;
    
    -------------------------------------------
    -- WRITE TO BUS LOGIC
    -------------------------------------------
    current_write_byte <= x"58" when s_command_addr = x"D0" else (others => '0');
    
    -------------------------------------------
    -- HIGH LEVEL LOGIC LOGIC
    -------------------------------------------
    process (s_is_ack, s_is_ending) is
    begin
        if s_is_ending = '1' then
            s_has_read_command_addr <= '0';
            s_command_addr <= (others => '0');
        elsif rising_edge(s_is_ack) then
            s_has_read_command_addr <= s_has_read_command_addr;
            s_command_addr <= s_command_addr;
            if s_is_reading_addr = '0' then
                if s_has_read_command_addr = '0' then
                    s_has_read_command_addr <= '1';
                    s_command_addr <= current_read_byte;
                else
                    s_command_addr <= std_logic_vector(unsigned(s_command_addr) + 1);
                end if;
            end if;
        end if;
    end process;
    
    io_SDA <= 'Z' when s_is_last_ack_valid = '0' or s_is_ending = '1' or s_is_me = '0' else
              '0' when s_is_ack = '1' and s_is_writing_to_bus = '0' else
              '0' when s_is_ack = '1' and s_is_reading_addr = '1' else
              current_write_byte(7 - s_bit_counter) when s_is_writing_to_bus = '1' and s_is_ack = '0' else
              'Z';
end Behavioral;
