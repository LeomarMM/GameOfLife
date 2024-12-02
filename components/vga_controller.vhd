library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity vga_controller is
port
(
	i_pixelclk	:	in		std_logic;
	i_rst			:	in		std_logic;
	o_hsync		:	out	std_logic;
	o_vsync		:	out	std_logic;
	o_enable		:	out	std_logic;
	o_column		:	out	natural range 639 downto 0;
	o_row			:	out	natural range 479 downto 0;
	o_v_blank	:	out	std_logic
);
end vga_controller;

architecture behavioural of vga_controller is

	constant s_columns		:	natural := 640;
	constant s_hfporch		:	natural := 16;
	constant s_hsynpulse		:	natural := 96;
	constant s_hbporch		:	natural := 48;
	
	constant s_rows			:	natural := 480;
	constant s_vfporch		:	natural := 10;
	constant s_vsynpulse		:	natural := 2;
	constant s_vbporch		:	natural := 33;
	
	signal r_column		:	natural range 799 downto 0 := s_columns;
	signal r_row			:	natural range 524 downto 0 := s_rows;
	signal w_enable		:	std_logic;
	signal w_hsync			:	std_logic;
	signal w_vsync			:	std_logic;
	signal w_v_blank		:	std_logic;

begin

	o_hsync <= w_hsync;
	o_vsync <= w_vsync;
	o_enable <= w_enable;
	o_column <= r_column when r_column < s_columns else 0;
	o_row <= r_row  when r_row < s_rows else 0;
	o_v_blank <= w_v_blank;

	w_enable <= '1' when r_column < s_columns and r_row < s_rows and r_column /= 0 else '0';
	w_hsync <= '0' when r_column > s_columns+s_hfporch and r_column <= s_columns+s_hfporch+s_hsynpulse else '1';
	w_vsync <= '0' when r_row > s_rows+s_vfporch and r_row <= s_rows+s_vfporch+s_vsynpulse else '1';
	w_v_blank <= '1' when (r_row > s_rows and r_row <= s_rows+s_vfporch+s_vsynpulse+s_vbporch) or r_row = 0 else '0';
	
	process(i_pixelclk, i_rst)
	begin
		if(i_rst = '1') then
			r_column <= s_columns;
			r_row <= s_rows;
		elsif(rising_edge(i_pixelclk)) then
			if(r_column < s_columns + s_hfporch + s_hsynpulse + s_hbporch - 1) then
				r_column <= r_column + 1;
			else
				r_column <= 0;
				if(r_row < s_rows + s_vfporch + s_vsynpulse + s_vbporch - 1) then
					r_row <= r_row + 1;
				else
					r_row <= 0;
				end if;
			end if;		
		end if;
	end process;
	
end behavioural;