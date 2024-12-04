library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity falling_edge_detector is
port
(
	i_clk				:	in		std_logic;
	i_rst				:	in		std_logic;
	i_signal			:	in		std_logic;
	o_edge_down		:	out	std_logic
);
end falling_edge_detector;

architecture behavioral of falling_edge_detector is

	signal r_first : std_logic;
	signal r_second : std_logic;

begin
	process(i_clk, i_rst)														
 	begin																							
		if (i_rst = '1')  then
			r_first <= '0';																		
			r_second <= '0';
		elsif rising_edge (i_clk) then												
			r_first <= i_signal;
			r_second <= r_first;																																				
		end if;																					
	end process;																
   o_edge_down <= not(r_first) and r_second;							   
end behavioral;
