library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity load_pattern_from_rom is
port
(
	i_clk			:	in		std_logic;
	i_rst			:	in		std_logic;
	i_start		:	in		std_logic;
	i_row			:	natural range 31 downto 0;
	i_column		:	natural range 31 downto 0;
	i_grom_q		:	in		std_logic;
	o_gram_data	:	out	std_logic;
	o_gram_addr	:	out	std_logic_vector(10 downto 0);
	o_gram_wren	:	out	std_logic;
	o_grom_addr	:	out	std_logic_vector(9 downto 0);
	o_vram_data	:	out	std_logic_vector(1 downto 0);
	o_vram_addr	:	out	std_logic_vector(12 downto 0);
	o_vram_wren	:	out	std_logic;
	o_idle		:	out	std_logic
);
end load_pattern_from_rom;

architecture behavioural of load_pattern_from_rom is

	type mach_lpfr	is (IDLE, LOAD_ADDRESS, READ_ROM, WRITE_MEM);
	
	signal t_mach			:	mach_lpfr := IDLE;
	signal r_column		:	natural range 31 downto 0 := 0;
	signal r_row			:	natural range 31 downto 0 := 0;
	signal r_data			:	std_logic := '0';
	signal w_address		:	natural range 1023 downto 0 := 0;
	signal w_vram_addr	:	natural range 4799 downto 0 := 0;

begin

	w_address <= r_column + 32*r_row;
	w_vram_addr <= 1544 + r_column + 80*r_row;
	
	o_grom_addr <= std_logic_vector(to_unsigned(w_address, 10));
	o_gram_addr <= std_logic_vector(to_unsigned(w_address, 11));
	o_gram_data <= r_data;
	o_gram_wren <= '1' when t_mach = WRITE_MEM else '0';
	
	o_vram_addr <= std_logic_vector(to_unsigned(w_vram_addr, 13));
	o_vram_data <= "11" when r_data = '1' else "10";
	o_vram_wren <= '1' when t_mach = WRITE_MEM else '0';
	
	o_idle <= '1' when t_mach = IDLE else '0';

	process(i_clk, t_mach)
	begin
		if(t_mach = IDLE) then
			r_row <= 0;
			r_column <= 0;
		elsif(falling_edge(i_clk) and t_mach = LOAD_ADDRESS) then
			r_row <= i_row;
			r_column <= i_column;
		end if;
	end process;

	process(i_clk, t_mach)
	begin
		if(t_mach = IDLE) then
			r_data <= '0';
		elsif(falling_edge(i_clk) and t_mach = READ_ROM) then
			r_data <= i_grom_q;
		end if;
	end process;

	process(i_clk, i_rst, t_mach)
	begin
		if(i_rst = '1') then
			t_mach <= IDLE;
		elsif(rising_edge(i_clk)) then
			case t_mach is
			when IDLE =>
				if(i_start = '1') then
					t_mach <= LOAD_ADDRESS;
				else
					t_mach <= IDLE;
				end if;
			when LOAD_ADDRESS =>
				t_mach <= READ_ROM;
			when READ_ROM =>
				t_mach <= WRITE_MEM;
			when WRITE_MEM =>
				t_mach <= IDLE;
			end case;
		end if;
	end process;

end behavioural;