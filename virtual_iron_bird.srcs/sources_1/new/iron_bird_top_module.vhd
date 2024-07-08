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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity iron_bird_top_module is
    Port (
        i_SCL  : in std_logic;
        io_SDA : inout std_logic
    );
end iron_bird_top_module;

architecture Behavioral of iron_bird_top_module is
    component bmp280_virtual is
        Generic (
            I2C_ADRR: unsigned(6 downto 0) := to_unsigned(0, 7)
        );
        Port (
            i_SCL  : in std_logic;
            io_SDA : inout std_logic
        );
    end component bmp280_virtual;
begin
    bmp_inst: bmp280_virtual
    Generic map (
        I2C_ADRR => to_unsigned(16#76#, 7)
    )
    Port map (
        i_SCL  => i_SCL,
        io_SDA => io_SDA
    );
end Behavioral;
