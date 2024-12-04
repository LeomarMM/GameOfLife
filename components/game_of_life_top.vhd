library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity game_of_life_top is
port
(
	i_clk			:	in		std_logic;
	i_rst			:	in		std_logic;
	i_buttons	:	in		std_logic_vector(2 downto 0);
	o_hsync		:	out	std_logic;
	o_vsync		:	out	std_logic;
	o_red			:	out	std_logic;
	o_green		:	out	std_logic;
	o_blue		:	out	std_logic;
	o_leds		:	out	std_logic_vector(3 downto 0)
);
end game_of_life_top;

architecture behavioural of game_of_life_top is
	
	component vga_controller
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
	end component;
	
	component VGA_PLL
	port
	(
		areset		: in std_logic  := '0';
		inclk0		: in std_logic  := '0';
		c0				: out std_logic ;
		locked		: out std_logic 
	);
	end component;
	
	component CGL_ACB
	port
	(
		i_pixel			:	in		natural range 639 downto 0;
		i_scanline		:	in		natural range 479 downto 0;
		i_character		:	in		std_logic_vector(1 downto 0);
		o_vram_addr		:	out	std_logic_vector(12 downto 0);
		o_chr_rom_addr	:	out	std_logic_vector(7 downto 0)
	);
	end component;
	
	component glp_core
	port
	(
		i_clk				:	in		std_logic;
		i_rst				:	in		std_logic;
		i_v_blank		:	in		std_logic;
		i_gram_q			:	in		std_logic;
		i_grom_q			:	in		std_logic;
		i_buttons		:	in		std_logic_vector(2 downto 0);
		o_gram_data		:	out	std_logic;
		o_gram_addr		:	out	std_logic_vector(10 downto 0);
		o_gram_wren		:	out	std_logic;
		o_grom_addr		:	out	std_logic_vector(11 downto 0);
		o_vram_data		:	out	std_logic_vector(1 downto 0);
		o_vram_addr		:	out	std_logic_vector(12 downto 0);
		o_vram_wren		:	out	std_logic
	);
	end component;

	component debouncer
	generic
	(
		clk_freq			:	natural := 50_000_000;
		ms_delay			:	natural := 15
	);
	port
	(
		i_clk				:	in		std_logic;
		i_rst				:	in		std_logic;
		i_signal			:	in		std_logic;
		o_signal			:	out	std_logic
	);
	end component;

	component CHR_ROM
	port
	(
		address		: in std_logic_vector (7 downto 0);
		clock			: in std_logic  := '1';
		q				: out std_logic_vector (2 downto 0)
	);
	end component;
	
	component PATTERN_ROM
	port
	(
		address		: in std_logic_vector (11 downto 0);
		clock			: in std_logic  := '1';
		q				: out std_logic_vector (0 downto 0)
	);
	end component;
	
	component GAME_RAM
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (10 DOWNTO 0);
		clock			: IN STD_LOGIC  := '1';
		data			: IN STD_LOGIC_VECTOR (0 DOWNTO 0);
		wren			: IN STD_LOGIC ;
		q				: OUT STD_LOGIC_VECTOR (0 DOWNTO 0)
	);
	end component;
	
	component VRAM
	port
	(
		data			: in std_logic_vector (1 downto 0);
		rdaddress	: in std_logic_vector (12 downto 0);
		rdclock		: in std_logic ;
		wraddress	: in std_logic_vector (12 downto 0);
		wrclock		: in std_logic  := '1';
		wren			: in std_logic  := '0';
		q				: out std_logic_vector (1 downto 0)
	);
	end component;

	component FIFO
	PORT
	(
		data			: in std_logic_vector (0 downto 0);
		rdclk			: in std_logic;
		rdreq			: in std_logic;
		wrclk			: in std_logic;
		wrreq			: in std_logic;
		q				: out std_logic_vector (0 downto 0);
		rdempty		: out std_logic;
		wrfull		: out std_logic 
	);
	end component;

	signal w_pixelclk			:	std_logic;
	signal w_rst				:	std_logic;
	signal w_enable			:	std_logic;
	signal w_locked			:	std_logic;
	signal w_column			:	natural range 639 downto 0;
	signal w_row				:	natural range 479 downto 0;
	signal w_v_blank			:	std_logic;
	signal w_vram_read_addr	:	std_logic_vector (12 downto 0);
	signal w_chr_rom_addr	:	std_logic_vector (7 downto 0);
	signal w_chr_rom_q		:	std_logic_vector (2 downto 0);
	signal w_character		:	std_logic_vector (1 downto 0);
	signal w_prom_addr		:	std_logic_vector (11 downto 0);
	signal w_prom_q			:	std_logic_vector (0 downto 0);
	signal w_vram_data		:	std_logic_vector (1 downto 0);
	signal w_vram_wr_addr	:	std_logic_vector (12 downto 0);
	signal w_vram_wren		:	std_logic;
	signal w_gram_q			:	std_logic_vector (0 downto 0);
	signal w_gram_data		:	std_logic_vector (0 downto 0);
	signal w_gram_addr		:	std_logic_vector (10 downto 0);
	signal w_gram_wren		:	std_logic;
	signal w_fifo_rdreq		:	std_logic;
	signal w_fifo_wrreq		:	std_logic;
	signal w_fifo_q_vec		:	std_logic_vector (0 downto 0);
	signal w_fifo_q			:	std_logic;
	signal w_fifo_rdempty	:	std_logic;
	signal w_fifo_wrfull		:	std_logic;
	signal w_buttons			:	std_logic_vector(2 downto 0);
begin

	VGA : vga_controller
	port map 
	(
		i_pixelclk	=>	w_pixelclk,
		i_rst			=>	w_rst,
		o_hsync		=>	o_hsync,
		o_vsync		=>	o_vsync,
		o_enable		=>	w_enable,
		o_column		=>	w_column,
		o_row			=>	w_row,
		o_v_blank	=> w_v_blank
	);
	
	PLL : VGA_PLL
	port map
	(
		inclk0		=>	i_clk,
		areset		=> "not"(i_rst),
		locked		=>	w_locked,
		c0				=>	w_pixelclk
	);
	
	ACB : CGL_ACB
	port map
	(
		i_pixel			=> w_column,
		i_scanline		=> w_row,
		i_character		=> w_character,
		o_vram_addr		=> w_vram_read_addr,
		o_chr_rom_addr	=> w_chr_rom_addr
	);

	GLP : glp_core
	port map
	(
		i_clk				=> i_clk,
		i_rst				=> w_rst,
		i_v_blank		=> w_fifo_q,
		i_gram_q			=> w_gram_q(0),
		i_grom_q			=> w_prom_q(0),
		i_buttons		=> w_buttons,
		o_gram_data		=> w_gram_data(0),
		o_gram_addr		=> w_gram_addr,
		o_gram_wren		=> w_gram_wren,
		o_grom_addr		=> w_prom_addr,
		o_vram_data		=> w_vram_data,
		o_vram_addr		=> w_vram_wr_addr,
		o_vram_wren		=> w_vram_wren
	);

	CHR : CHR_ROM
	port map 
	(
		address	=> w_chr_rom_addr,
		clock		=> w_pixelclk,
		q			=> w_chr_rom_q
	);
	
	PRM : PATTERN_ROM
	port map 
	(
		address	=> w_prom_addr,
		clock		=> i_clk,
		q			=> w_prom_q
	);

	VRM : VRAM 
	port map 
	(
		data			=> w_vram_data,
		rdaddress	=> w_vram_read_addr,
		rdclock		=> "not"(w_pixelclk),
		wraddress	=> w_vram_wr_addr,
		wrclock		=> i_clk,
		wren			=> w_vram_wren,
		q				=> w_character
	);
	
	GRM : GAME_RAM 
	port map
	(
		address	=> w_gram_addr,
		clock		=> i_clk,
		data		=> w_gram_data,
		wren		=> w_gram_wren,
		q			=> w_gram_q
	);
	
	FIF : FIFO
	port map
	(
		data		=> (0 => w_v_blank),
		rdclk		=> i_clk,
		rdreq		=> w_fifo_rdreq,
		wrclk		=> "not"(w_pixelclk),
		wrreq		=> w_fifo_wrreq,
		q			=> w_fifo_q_vec,
		rdempty	=> w_fifo_rdempty,
		wrfull	=> w_fifo_wrfull
	);
	
	DEB0 : debouncer
	port map
	(
		i_clk		=> i_clk,
		i_rst		=> w_rst,
		i_signal	=> i_buttons(0),
		o_signal	=> w_buttons(0)
	);

	DEB1 : debouncer
	port map
	(
		i_clk		=> i_clk,
		i_rst		=> w_rst,
		i_signal	=> i_buttons(1),
		o_signal	=> w_buttons(1)
	);

	DEB2 : debouncer
	port map
	(
		i_clk		=> i_clk,
		i_rst		=> w_rst,
		i_signal	=> i_buttons(2),
		o_signal	=> w_buttons(2)
	);

	w_fifo_wrreq <= not w_fifo_wrfull;
	w_fifo_rdreq <= not w_fifo_rdempty;
	w_fifo_q <= w_fifo_q_vec(0);
	w_rst <= not i_rst and not w_locked;
	
	o_red <= w_chr_rom_q(2) when w_enable = '1' else '0';
	o_green <= w_chr_rom_q(1) when w_enable = '1' else '0';
	o_blue <= w_chr_rom_q(0) when w_enable = '1' else '0';
	
	o_leds(0) <= not w_rst;
	o_leds(1) <= w_buttons(0);
	o_leds(2) <= w_buttons(1);
	o_leds(3) <= w_buttons(2);

end behavioural;