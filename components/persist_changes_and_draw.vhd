library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity persist_changes_and_draw is
port
(
	i_clk			:	in		std_logic;
	i_rst			:	in		std_logic;
	i_start		:	in		std_logic;
	i_row			:	natural range 31 downto 0;
	i_column		:	natural range 31 downto 0;
	i_gram_q		:	in		std_logic;
	o_gram_data	:	out	std_logic;
	o_gram_addr	:	out	std_logic_vector(10 downto 0);
	o_gram_wren	:	out	std_logic;
	o_vram_data	:	out	std_logic_vector(1 downto 0);
	o_vram_addr	:	out	std_logic_vector(12 downto 0);
	o_vram_wren	:	out	std_logic;
	o_idle		:	out	std_logic
);
end persist_changes_and_draw;

architecture behavioural of persist_changes_and_draw is

	type mach_lpfr	is (IDLE, LOAD_ADDRESS, READ_RAM, SWITCH_TO_BANK0, WRITE_MEM, CLEAR_AND_SWITCH_TO_BANK1, CLEAR_MEM);
	
	signal t_mach			:	mach_lpfr := IDLE;
	signal r_column		:	natural range 31 downto 0 := 0;
	signal r_row			:	natural range 31 downto 0 := 0;
	signal r_data			:	std_logic := '0';
	signal w_address		:	natural range 1023 downto 0 := 0;
	signal w_vram_addr	:	natural range 4799 downto 0 := 0;
	signal w_gram_addr	:	natural range 2047 downto 0 := 0;
	signal r_bank			:	natural range 1 downto 0 := 0;

begin

	w_address <= r_column + 32*r_row;
	w_gram_addr <= w_address + 1024*r_bank;
	w_vram_addr <= 1544 + r_column + 80*r_row;
	
	o_gram_addr <= std_logic_vector(to_unsigned(w_gram_addr, 11));
	o_gram_data <= r_data;
	o_gram_wren <= '1' when t_mach = WRITE_MEM or t_mach = CLEAR_MEM else '0';
	
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
			r_bank <= 0;
		elsif(falling_edge(i_clk) and t_mach = LOAD_ADDRESS) then
			r_bank <= 1;
		elsif(falling_edge(i_clk) and t_mach = SWITCH_TO_BANK0) then
			r_bank <= 0;
		elsif(falling_edge(i_clk) and t_mach = CLEAR_AND_SWITCH_TO_BANK1) then
			r_bank <= 1;
		end if;
	end process;

	process(i_clk, t_mach)
	begin
		if(t_mach = IDLE) then
			r_data <= '0';
		elsif(falling_edge(i_clk) and t_mach = READ_RAM) then
			r_data <= i_gram_q;
		elsif(falling_edge(i_clk) and t_mach = CLEAR_AND_SWITCH_TO_BANK1) then
			r_data <= '0';
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
				t_mach <= READ_RAM;
			when READ_RAM =>
				t_mach <= SWITCH_TO_BANK0;
			when SWITCH_TO_BANK0 =>
				t_mach <= WRITE_MEM;
			when WRITE_MEM =>
				t_mach <= CLEAR_AND_SWITCH_TO_BANK1;
			when CLEAR_AND_SWITCH_TO_BANK1 =>
				t_mach <= CLEAR_MEM;
			when CLEAR_MEM =>
				t_mach <= IDLE;
			end case;
		end if;
	end process;

end behavioural;