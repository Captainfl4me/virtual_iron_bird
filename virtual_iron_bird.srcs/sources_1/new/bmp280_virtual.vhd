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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

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
    
    signal s_rst : std_logic := '0';
    
    signal s_state: State_type := Ended;
    signal s_control_state: Control_State_type := Read_Address;
    signal s_command: Command_type := Read_From_Bus;
    signal s_command_addr: std_logic_vector(7 downto 0) := (others => '0');
    signal s_has_read_command_addr: std_logic := '0';
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
               Ended    when s_state = Ending;
    s_rst <= '1' when s_state = Starting or s_state = Ending else '0';
    
    -- Packet receiver
    process (i_SCL, s_rst) is
        variable current_msg    : std_logic_vector(7 downto 0) := (others => '0');
        variable bit_counter    : integer := 0;
        variable previous_state : Control_State_type := Read_Address;
        variable skip_ack       : std_logic := '0';
        variable end_next_cmd   : std_logic := '0';
        variable current_sda    : std_logic := '0';
    begin
        if s_rst = '1' then
            -- Reset states
            if s_state = Starting then
                bit_counter := 0;
                previous_state := Read_Address;
                end_next_cmd := '0';
                s_command <= Read_From_Bus;
                s_control_state <= Read_Address;
            elsif s_state = Ending then
                s_has_read_command_addr <= '0';
                s_command_addr <= (others => '0');
                s_command_addr_first_set <= '1';
            end if;
        else
            skip_ack := '0';
            if rising_edge(i_SCL) and s_state = Started and end_next_cmd = '0' then
                if s_control_state /= Ack then
                    if s_command = Read_From_Bus or s_control_state = Read_Address then
                        current_msg(7 - bit_counter) := io_SDA;
                    end if;
                    bit_counter := bit_counter + 1;
                    previous_state := s_control_state;
                    if bit_counter = 8 then
                        s_control_state <= Ack;
                        if s_command = Read_From_Bus and s_control_state = Execute_command and s_has_read_command_addr = '0' then
                            s_has_read_command_addr <= '1';
                            s_command_addr <= current_msg;
                        end if;
                    end if;
                elsif s_command = Write_To_Bus then
                    assert io_SDA = '0'
                        report "SDA Master ACK should be low"
                        severity ERROR;
                    if io_SDA /= '0' then
                        end_next_cmd := '1';
                    end if;
                end if;
            end if;
            if falling_edge(i_SCL) and s_state = Started and end_next_cmd = '0' then
                if s_control_state = Ack then
                    if bit_counter = 8 then
                        bit_counter := 0;
                        if previous_state = Read_Address then
                            case current_msg(0) is
                                when '0' =>
                                    s_command <= Read_From_Bus;
                                when '1' =>
                                    s_command <= Write_To_Bus;
                                when others =>
                                    s_command <= Read_From_Bus;
                            end case;
                        end if;
                    else
                        skip_ack := '1';
                        case previous_state is
                            when Read_Address =>
                                s_control_state <= Execute_command;                          
                            when Execute_command =>
                                if s_command_addr_first_set = '1' then
                                    s_command_addr <= s_command_addr;
                                    s_command_addr_first_set <= '0';
                                else
                                    s_command_addr <= std_logic_vector(to_unsigned(to_integer(unsigned(s_command_addr)) + 1, 8));
                                end if;
                                s_control_state <= Execute_command;
                            when others =>
                                s_control_state <= previous_state;
                        end case;
                        if s_command = Write_To_Bus then
                            -------------------------------------------------
                            -- OUTCOMING REGISTER
                            -------------------------------------------------
                            case s_command_addr is
                                when x"D0" => -- ID Register
                                    current_msg := x"58";
                                when others => current_msg := (others => '0');
                            end case;
                            current_sda := current_msg(7 - bit_counter);
                        end if;
                    end if;
                elsif s_command = Write_To_Bus then
                    current_sda := current_msg(7 - bit_counter);
                end if;
            end if;
        end if;
        
        -- Set Ack
        if s_command = Read_From_Bus then
            if s_control_state = Ack and skip_ack = '0' then
                io_SDA <= '0';
            else
                io_SDA <= 'Z';
            end if;
        elsif s_command = Write_To_Bus then
            if s_control_state = Ack and skip_ack = '0' and previous_state /= Read_Address then
                io_SDA <= 'Z';
            else
                io_SDA <= current_sda;
            end if;
        end if;
    end process;

end Behavioral;
