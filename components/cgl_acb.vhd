library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cgl_acb is
port
(
	i_pixel			:	in		natural range 639 downto 0;
	i_scanline		:	in		natural range 479 downto 0;
	i_character		:	in		std_logic_vector(1 downto 0);
	o_vram_addr		:	out	std_logic_vector(12 downto 0);
	o_chr_rom_addr	:	out	std_logic_vector(7 downto 0)
);
end cgl_acb;

architecture behavioural of cgl_acb is

	signal w_pixel_div_8						:	natural range 79 downto 0;
	signal w_scanline_div_8					:	natural range 59 downto 0;
	signal w_next_pixel						:	natural range 79 downto 0;
	signal w_next_pixel_scanline			:	natural range 59 downto 0;
	signal w_vram_addr						:	natural range 4799 downto 0;
	signal w_character						:	natural range 3 downto 0;
	signal w_pixel_mod_8						:	natural range 7 downto 0;
	signal w_scanline_mod_8					:	natural range 7 downto 0;
	signal w_character_pixel				:	natural range 63 downto 0;
	signal w_chr_rom_addr					:	natural range 255 downto 0;

begin

	w_character <= to_integer(unsigned(i_character));

	w_pixel_div_8 <= i_pixel / 8;
	w_scanline_div_8 <= i_scanline / 8;
	
	w_next_pixel <= w_pixel_div_8;
	w_next_pixel_scanline <= w_scanline_div_8;
	w_vram_addr <= w_next_pixel + 80*w_next_pixel_scanline;
	
	o_vram_addr <= std_logic_vector(to_unsigned(w_vram_addr, 13));
	
	w_pixel_mod_8 <= i_pixel mod 8;
	w_scanline_mod_8 <= i_scanline mod 8;
	w_character_pixel <= w_pixel_mod_8 + 8*w_scanline_mod_8;
	w_chr_rom_addr <= w_character_pixel + 64*w_character;
	o_chr_rom_addr <= std_logic_vector(to_unsigned(w_chr_rom_addr, 8));
	
end behavioural;