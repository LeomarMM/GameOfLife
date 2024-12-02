library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fetch_cell_and_apply_rules is
port
(
	i_clk			:	in		std_logic;
	i_rst			:	in		std_logic;
	i_start		:	in		std_logic;
	i_gram_q		:	in		std_logic;
	i_row			:	in		natural range 31 downto 0;
	i_column		:	in		natural range 31 downto 0;
	o_gram_addr	:	out	std_logic_vector(10 downto 0);
	o_gram_data	:	out	std_logic;
	o_gram_wren	:	out	std_logic;
	o_idle		:	out	std_logic
);
end fetch_cell_and_apply_rules;

architecture behavioural of fetch_cell_and_apply_rules is

	function min(a, b: integer) return integer is begin if(a < b) then return a; else return b; end if; end function;
	function max(a, b: integer) return integer is begin if(a > b) then return a; else return b; end if; end function;
	
	type mach_fcaar IS (IDLE, LOAD_POSITION, READ_MEMORY, ACQUIRE_STATE, COUNT_LIVING, NEXT_CELL, APPLY_RULES, WRITE_MEM);
	
	signal t_mach					:	mach_fcaar := IDLE;
	signal w_current_cell_is_target_cell	:	std_logic;
	signal r_row					:	natural range 31 downto 0 := 0;
	signal r_column				:	natural range 31 downto 0 := 0;
	signal r_row_current			:	natural range 31 downto 0 := 0;
	signal r_column_current		:	natural range 31 downto 0 := 0;
	signal r_column_min			:	natural range 31 downto 0 := 0;
	signal r_row_max				:	natural range 31 downto 0 := 0;
	signal r_column_max			:	natural range 31 downto 0 := 0;
	signal w_row_minus_one		:	integer range 30 downto -1;
	signal w_column_minus_one	:	integer range 30 downto -1;
	signal w_row_plus_one		:	natural range 32 downto 1;
	signal w_column_plus_one	:	natural range 32 downto 1;
	signal w_addr					:	natural range 1023 downto 0;
	signal w_gram_addr			:	natural range 2047 downto 0;
	signal r_state_buffer		:	std_logic_vector(1 downto 0) := "00";
	signal r_alive					:	std_logic := '0';
	signal r_living_cells		:	natural range 8 downto 0 := 0;
	signal r_bank					:	natural range 1 downto 0 := 0;

begin
	
	w_current_cell_is_target_cell <= '1' when ((r_row = r_row_current) and (r_column = r_column_current)) else '0';
	w_row_minus_one <= i_row - 1;
	w_column_minus_one <= i_column - 1;
	w_row_plus_one <= i_row + 1;
	w_column_plus_one <= i_column + 1;

	w_addr <= r_column + 32*r_row;
	w_gram_addr	<= r_bank*1024+w_addr;
	
	o_gram_addr <= std_logic_vector(to_unsigned(w_gram_addr, 11));
	o_gram_data <= r_alive;
	o_gram_wren <= '1' when t_mach = WRITE_MEM else '0';
	o_idle <= '1' when t_mach = IDLE else '0';

	process(i_clk, t_mach)
		variable v_row_min				:	natural range 31 downto 0;
		variable v_column_min			:	natural range 31 downto 0;
		variable v_row_max				:	natural range 31 downto 0;
		variable v_column_max			:	natural range 31 downto 0;
	begin
		if(t_mach = IDLE) then
			r_row <= 0;
			r_column <= 0;
			r_row_current <= 0;
			r_column_current <= 0;
			r_column_min <= 0;
			r_row_max <= 0;
			r_column_max <= 0;
		elsif(falling_edge(i_clk) and t_mach = LOAD_POSITION) then
			v_row_min := max(0, w_row_minus_one);
			v_column_min := max(0, w_column_minus_one);
			v_row_max := min(31, w_row_plus_one);
			v_column_max := min(31, w_column_plus_one);
			r_row_current <= i_row;
			r_column_current <= i_column;
			r_row <= v_row_min;
			r_column <= v_column_min;
			r_column_min <= v_column_min;
			r_row_max <= v_row_max;
			r_column_max <= v_column_max;
		elsif(falling_edge(i_clk) and t_mach = NEXT_CELL) then
			if(r_column < r_column_max) then	
				r_column <= r_column + 1;
			else 
				r_column <= r_column_min;
				if(r_row < r_row_max) then
					r_row <= r_row + 1;
				else 
					r_row <= 0;
					r_column <= 0;
				end if;
			end if;
		elsif(falling_edge(i_clk) and t_mach = APPLY_RULES) then
			r_row <= r_row_current;
			r_column <= r_column_current;
		end if;
	end process;

	process(i_clk, t_mach)
	begin
		if(t_mach = IDLE) then
			r_state_buffer <= "00";
		elsif(falling_edge(i_clk) and t_mach = ACQUIRE_STATE) then
			if(w_current_cell_is_target_cell = '1') then
				r_state_buffer(1) <= i_gram_q;
			else
				r_state_buffer(0) <= i_gram_q;
			end if;
		end if;
	end process;

	process(i_clk, t_mach)
	begin
		if(t_mach = IDLE) then
			r_living_cells <= 0;
		elsif(falling_edge(i_clk) and t_mach = COUNT_LIVING) then
			if(w_current_cell_is_target_cell = '0' and r_state_buffer(0) = '1') then
				r_living_cells <= r_living_cells + 1;
			end if;
		end if;
	end process;
	
	process(i_clk, t_mach)
	begin
		if(t_mach = IDLE) then
			r_bank <= 0;
		elsif(falling_edge(i_clk) and t_mach = LOAD_POSITION) then
			r_bank <= 0;
		elsif(falling_edge(i_clk) and t_mach = APPLY_RULES) then
			r_bank <= 1;
		end if;
	end process;
	
	process(i_clk, t_mach)
	begin
		if(t_mach = IDLE) then
			r_alive <= '0';
		elsif(falling_edge(i_clk) and t_mach = APPLY_RULES) then
			if(r_living_cells < 2 or r_living_cells > 3) then
				r_alive <= '0';
			elsif(r_living_cells = 3) then
				r_alive <= '1';
			else
				r_alive <= r_state_buffer(1);
			end if;
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
					t_mach <= LOAD_POSITION;
				else
					t_mach <= IDLE;
				end if;
			when LOAD_POSITION =>
				t_mach <= READ_MEMORY;
			when READ_MEMORY =>
				t_mach <= ACQUIRE_STATE;
			when ACQUIRE_STATE =>
				t_mach <= COUNT_LIVING;
			when COUNT_LIVING =>
				t_mach <= NEXT_CELL;
			when NEXT_CELL =>
				if(r_row = 0 and r_column = 0) then
					t_mach <= APPLY_RULES;
				else
					t_mach <= READ_MEMORY;
				end if;
			when APPLY_RULES =>
				t_mach <= WRITE_MEM;
			when WRITE_MEM =>
				t_mach <= IDLE;
			end case;
		end if;
	end process;

end behavioural;