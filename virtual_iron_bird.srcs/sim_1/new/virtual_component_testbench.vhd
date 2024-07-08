----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.06.2024 21:30:31
-- Design Name: 
-- Module Name: virtual_component_testbench - Behavioral
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

entity virtual_component_testbench is
    Generic (
        HALF_CLK: time := 5ns
    );
--  Port ( );
end virtual_component_testbench;

architecture Behavioral of virtual_component_testbench is    
    component bmp280_virtual is
        Generic (
            I2C_ADRR: unsigned(6 downto 0) := to_unsigned(0, 7)
        );
        Port (
            i_SCL  : in std_logic;
            io_SDA : inout std_logic
        );
    end component bmp280_virtual;
    
    signal sda          : std_logic := 'Z';
    signal scl          : std_logic := '0';
    signal locked_clock : std_logic := '0';
begin
    bmp_inst: bmp280_virtual
    Generic map (
        I2C_ADRR => to_unsigned(16#76#, 7)
    )
    Port map (
        i_SCL  => scl,
        io_SDA => sda
    );
    scl <= not scl after HALF_CLK when locked_clock = '0' else '1';
    process is
        procedure write_data(data: std_logic_vector(7 downto 0)) is
        begin
            for k in 0 to 7 loop
                wait for HALF_CLK*0.5;
                sda <= data(7 - k);
                wait for HALF_CLK*1.5;
            end loop;
        end procedure;
    begin
        -- Initial start condition
        sda <= '1';
        wait for HALF_CLK*1.5;
        sda <= '0';
        -- Send Slave ADDR packet
        wait for HALF_CLK*0.5;
        write_data("11101100"); -- Send slave ADDR + Write bit
        sda <= 'Z';
        wait for HALF_CLK*1.5;
        assert sda = '0'
            report "Ack should be set to 0 by device"
            severity ERROR;
        -- Send Write followup packet
        wait for HALF_CLK*0.5;
        write_data("11010000"); -- ID Register (0xD0)
        sda <= 'Z';
        wait for HALF_CLK*1.5;
        assert sda = '0'
            report "Ack should be set to 0 by device"
            severity ERROR;
        -- Repeat start condition
        wait for HALF_CLK*0.5;
        sda <= '1';
        wait for HALF_CLK;
        locked_clock <= '1';
        wait for HALF_CLK;
        locked_clock <= '0';
        sda <= '0';
        
        -- Send Slave ADDR packet
        wait for HALF_CLK;
        write_data("11101101");
        sda <= 'Z';
        wait for HALF_CLK*1.5;
        assert sda = '0'
            report "Ack should be set to 0 by device"
            severity ERROR;
        wait for HALF_CLK*0.5;
        wait for HALF_CLK*2*8;
        sda <= '1'; -- Invalid ack to end connection
        wait for HALF_CLK*2*2;
        locked_clock <= '1';
        sda <= '0';
        wait for HALF_CLK*0.5;
        sda <= '1';        
        wait;
    end process;

end Behavioral;
