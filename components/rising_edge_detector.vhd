library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity rising_edge_detector is
port
(
	i_clk				:	in		std_logic;
	i_rst				:	in		std_logic;
	i_signal			:	in		std_logic;
	o_edge_up		:	out	std_logic
);
end rising_edge_detector;

architecture behavioral of rising_edge_detector is

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
   o_edge_up <= not(r_second) and r_first;							   
end behavioral;
