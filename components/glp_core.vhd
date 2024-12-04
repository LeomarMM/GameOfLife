library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity glp_core is
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
end glp_core;

architecture behavioural of glp_core is

	type mach_main is (IDLE, START_COMPONENT, WAIT_COMPONENT, NEXT_CELL, CHECK_CONDITIONS, NEXT_COMPONENT);
	type glp_components is (LPFR, FCAAR, PCAD);
	type speed_settings is (one_gps, two_gps, six_gps, twelve_gps);

	component load_pattern_from_rom
	port
	(
		i_clk			:	in		std_logic;
		i_rst			:	in		std_logic;
		i_start		:	in		std_logic;
		i_row			:	natural range 31 downto 0;
		i_column		:	natural range 31 downto 0;
		i_select		:	natural range 3 downto 0;
		i_grom_q		:	in		std_logic;
		o_gram_data	:	out	std_logic;
		o_gram_addr	:	out	std_logic_vector(10 downto 0);
		o_gram_wren	:	out	std_logic;
		o_grom_addr	:	out	std_logic_vector(11 downto 0);
		o_vram_data	:	out	std_logic_vector(1 downto 0);
		o_vram_addr	:	out	std_logic_vector(12 downto 0);
		o_vram_wren	:	out	std_logic;
		o_idle		:	out	std_logic
	);
	end component;

	component fetch_cell_and_apply_rules
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
	end component;
	
	component persist_changes_and_draw
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
	end component;

	component rising_edge_detector
	port
	(
		i_clk				:	in		std_logic;
		i_rst				:	in		std_logic;	
		i_signal			:	in		std_logic;
		o_edge_up		:	out	std_logic
	);
	end component;
	
	component falling_edge_detector
	port
	(
		i_clk				:	in		std_logic;
		i_rst				:	in		std_logic;	
		i_signal			:	in		std_logic;
		o_edge_down		:	out	std_logic
	);
	end component;

	signal t_mach					:	mach_main := IDLE;
	signal t_current_component	:	glp_components := LPFR;
	signal t_spd, t_past_spd	:	speed_settings := one_gps;

	signal r_row					:	natural range 31 downto 0 := 0;
	signal r_column				:	natural range 31 downto 0 := 0;
	signal w_frame_delay			:	natural range 59 downto 0;
	signal w_past_frame_delay	:	natural range 59 downto 0;
	signal r_frame_counter		:	integer range 59 downto -1 := -1;
	signal r_select				:	natural range 3 downto 0 := 0;

	signal w_lpfr_start			:	std_logic;
	signal w_lpfr_gram_data		:	std_logic;
	signal w_lpfr_gram_addr		:	std_logic_vector(10 downto 0);
	signal w_lpfr_gram_wren		:	std_logic;
	signal w_lpfr_grom_addr		:	std_logic_vector(11 downto 0);
	signal w_lpfr_vram_data		:	std_logic_vector(1 downto 0);
	signal w_lpfr_vram_addr		:	std_logic_vector(12 downto 0);
	signal w_lpfr_vram_wren		:	std_logic;
	signal w_lpfr_idle			:	std_logic;

	signal w_fcaar_start			:	std_logic;
	signal w_fcaar_addr			:	std_logic_vector(10 downto 0);
	signal w_fcaar_data			:	std_logic;
	signal w_fcaar_wren			:	std_logic;
	signal w_fcaar_idle			:	std_logic;

	signal w_pcad_start			:	std_logic;
	signal w_pcad_gram_data		:	std_logic;
	signal w_pcad_gram_addr		:	std_logic_vector(10 downto 0);
	signal w_pcad_gram_wren		:	std_logic;
	signal w_pcad_vram_data		:	std_logic_vector(1 downto 0);
	signal w_pcad_vram_addr		:	std_logic_vector(12 downto 0);
	signal w_pcad_vram_wren		:	std_logic;
	signal w_pcad_idle			:	std_logic;
	
	signal w_idle_component		:	std_logic;
	signal w_v_blank_edge		:	std_logic;
	signal w_buttons				:	std_logic_vector(1 downto 0);
	signal w_frame_counter		:	std_logic_vector(6 downto 0);

begin
	
	w_lpfr_start <= '1' when t_mach = START_COMPONENT and t_current_component = LPFR else '0';
	w_fcaar_start <= '1' when t_mach = START_COMPONENT and t_current_component = FCAAR else '0';
	w_pcad_start <= '1' when t_mach = START_COMPONENT and t_current_component = PCAD else '0';
	w_frame_delay <= 59 when t_spd = one_gps else 29 when t_spd = two_gps else 9 when t_spd = six_gps else 5;
	w_past_frame_delay <= 59 when t_past_spd = one_gps else 29 when t_past_spd = two_gps else 9 when t_past_spd = six_gps else 4;
	w_frame_counter <= std_logic_vector(to_signed(r_frame_counter, 7));

	CLPFR	: load_pattern_from_rom
	port map
	(
		i_clk			=> i_clk,
		i_rst			=> i_rst,
		i_start		=> w_lpfr_start,
		i_row			=> r_row,
		i_column		=> r_column,
		i_grom_q		=> i_grom_q,
		i_select		=>	r_select,
		o_gram_data	=> w_lpfr_gram_data,
		o_gram_addr	=> w_lpfr_gram_addr,
		o_gram_wren	=> w_lpfr_gram_wren,
		o_grom_addr	=> w_lpfr_grom_addr,
		o_vram_data	=> w_lpfr_vram_data,
		o_vram_addr	=> w_lpfr_vram_addr,
		o_vram_wren	=> w_lpfr_vram_wren,
		o_idle		=>	w_lpfr_idle
	);
	
	CFCAAR : fetch_cell_and_apply_rules
	port map
	(
		i_clk			=> i_clk,
		i_rst			=> i_rst,
		i_start		=> w_fcaar_start,
		i_gram_q		=> i_gram_q,
		i_row			=> r_row,
		i_column		=> r_column,
		o_gram_addr	=> w_fcaar_addr,
		o_gram_data	=> w_fcaar_data,
		o_gram_wren	=> w_fcaar_wren,
		o_idle		=>	w_fcaar_idle
	);
	
	CPCAD : persist_changes_and_draw
	port map
	(
		i_clk			=> i_clk,
		i_rst			=> i_rst,
		i_start		=> w_pcad_start,
		i_row			=> r_row,
		i_column		=> r_column,
		i_gram_q		=>	i_gram_q,
		o_gram_data	=> w_pcad_gram_data,
		o_gram_addr	=> w_pcad_gram_addr,
		o_gram_wren	=> w_pcad_gram_wren,
		o_vram_data	=> w_pcad_vram_data,
		o_vram_addr	=> w_pcad_vram_addr,
		o_vram_wren	=> w_pcad_vram_wren,
		o_idle		=>	w_pcad_idle
	);
	
	RED : rising_edge_detector
	port map
	(
		i_clk			=> i_clk,
		i_rst			=> i_rst,
		i_signal		=> i_v_blank,
		o_edge_up	=> w_v_blank_edge
	);
	
	FED0 : falling_edge_detector
	port map
	(
		i_clk			=> i_clk,
		i_rst			=> i_rst,
		i_signal		=> i_buttons(0),
		o_edge_down	=> w_buttons(0)
	);
	
	FED1 : falling_edge_detector
	port map
	(
		i_clk			=> i_clk,
		i_rst			=> i_rst,
		i_signal		=> i_buttons(1),
		o_edge_down	=> w_buttons(1)
	);

	-- Cell position register
	process(i_clk, t_mach)
	begin
		if(t_mach = IDLE or t_mach = NEXT_COMPONENT) then
			r_row <= 0;
			r_column <= 0;
		elsif(falling_edge(i_clk) and t_mach = NEXT_CELL) then
			if(r_column < 31) then	
				r_column <= r_column + 1;
			else 
				r_column <= 0;
				if(r_row < 31) then
					r_row <= r_row + 1;
				else 
					r_row <= 0;
				end if;
			end if;
		end if;
	end process;
	
	-- Main state machine
	process(i_clk, i_rst, t_mach)
	begin
		if(i_rst = '1') then
			t_mach <= IDLE;
		elsif(rising_edge(i_clk)) then
			case t_mach is
			when IDLE =>
				t_mach <= START_COMPONENT;
			when START_COMPONENT =>
				t_mach <= WAIT_COMPONENT;
			when WAIT_COMPONENT =>
				if(w_idle_component = '1') then
					t_mach <= NEXT_CELL;
				else
					t_mach <= WAIT_COMPONENT;
				end if;
			when NEXT_CELL =>
				if(r_column = 0 and r_row = 0) then
					t_mach <= CHECK_CONDITIONS;
				else
					t_mach <= START_COMPONENT;
				end if;
			when CHECK_CONDITIONS =>
				if(t_current_component = FCAAR) then
					if(w_frame_counter(w_frame_counter'left) = '1') then
						t_mach <= NEXT_COMPONENT;
					else
						t_mach <= CHECK_CONDITIONS;
					end if;
				elsif(t_current_component = LPFR) then
					if(i_buttons(2) = '0') then
						t_mach <= NEXT_COMPONENT;
					else
						t_mach <= START_COMPONENT;
					end if;
				else
					t_mach <= NEXT_COMPONENT;
				end if;
			when NEXT_COMPONENT =>
				t_mach <= START_COMPONENT;
			end case;
		end if;
	end process;
	
	-- Component selector
	process(i_clk, t_mach, t_current_component)
	begin
		if(t_mach = IDLE) then
			t_current_component <= LPFR;
		elsif(falling_edge(i_clk) and t_mach = NEXT_COMPONENT) then
			case t_current_component is
				when LPFR =>
					t_current_component <= FCAAR;
				when FCAAR =>
					t_current_component <= PCAD;
				when PCAD =>
					t_current_component <= FCAAR;
			end case;
		end if;
	end process;
	
	-- Output selector
	process(t_current_component, w_lpfr_idle, w_lpfr_gram_data, w_lpfr_gram_addr,
	w_lpfr_gram_wren, w_lpfr_grom_addr, w_lpfr_vram_data, w_lpfr_vram_addr, w_lpfr_vram_wren,
	w_fcaar_idle, w_fcaar_data, w_fcaar_addr, w_fcaar_wren, w_pcad_idle, w_pcad_gram_data, w_pcad_gram_addr,
	w_pcad_gram_wren, w_pcad_vram_data, w_pcad_vram_addr, w_pcad_vram_wren)
	begin
		if(t_current_component = LPFR) then
			w_idle_component <= w_lpfr_idle;
			o_gram_data <= w_lpfr_gram_data;
			o_gram_addr <= w_lpfr_gram_addr;
			o_gram_wren <= w_lpfr_gram_wren;
			o_grom_addr <= w_lpfr_grom_addr;
			o_vram_data <= w_lpfr_vram_data;
			o_vram_addr <= w_lpfr_vram_addr;
			o_vram_wren <= w_lpfr_vram_wren;
		elsif(t_current_component = FCAAR) then
			w_idle_component <= w_fcaar_idle;
			o_gram_data <= w_fcaar_data;
			o_gram_addr <= w_fcaar_addr;
			o_gram_wren <= w_fcaar_wren;
			o_grom_addr <= (others => '0');
			o_vram_data <= "00";
			o_vram_addr <= (others => '0');
			o_vram_wren <= '0';
		else 
			w_idle_component <= w_pcad_idle;
			o_gram_data <= w_pcad_gram_data;
			o_gram_addr <= w_pcad_gram_addr;
			o_gram_wren <= w_pcad_gram_wren;
			o_grom_addr <= (others => '0');
			o_vram_data <= w_pcad_vram_data;
			o_vram_addr <= w_pcad_vram_addr;
			o_vram_wren <= w_pcad_vram_wren;
		end if;
	end process;

	-- Frame delay counter
	process(i_clk, t_mach, w_v_blank_edge, r_frame_counter, t_spd, t_past_spd, w_frame_counter, w_frame_delay, w_past_frame_delay)
		variable elapsed_frames			:	natural;
		variable frame_delay				:	natural;
		variable past_frame_delay		:	natural;
		variable current_frames_left	:	natural;
		variable frames_left_to_tick	:	integer;
		variable frames_left_logic		:	std_logic_vector(6 downto 0);
	begin
		if(t_mach = IDLE) then
			r_frame_counter <= -1;
		elsif(rising_edge(i_clk) and t_spd /= t_past_spd) then
			frame_delay := w_frame_delay;
			past_frame_delay := w_past_frame_delay;
			current_frames_left := r_frame_counter;
			elapsed_frames := past_frame_delay - current_frames_left;
			frames_left_to_tick := frame_delay - elapsed_frames;
			frames_left_logic := std_logic_vector(to_signed(frames_left_to_tick, 7));
			if(frames_left_logic(frames_left_logic'left) = '1') then
				r_frame_counter <= -1;
			else
				r_frame_counter <= frames_left_to_tick;
			end if;
		elsif(rising_edge(i_clk) and t_mach = NEXT_COMPONENT) then
			r_frame_counter <= w_frame_delay;
		elsif(rising_edge(i_clk) and w_v_blank_edge = '1' and w_frame_counter(w_frame_counter'left) = '0') then
			r_frame_counter <= r_frame_counter - 1;
		end if;
	end process;

	-- Pattern select register
	process(i_clk, i_rst, t_current_component, r_select)
	begin
		if(i_rst = '1') then
			r_select <= 0;
		elsif(rising_edge(i_clk) and t_current_component = LPFR) then
			if(w_buttons = "01") then
				if(r_select > 0) then
					r_select <= r_select - 1;
				else
					r_select <= 3;
				end if;
			elsif(w_buttons = "10") then
				if(r_select < 3) then
					r_select <= r_select + 1;
				else
					r_select <= 0;
				end if;
			end if;
		end if;
	end process;

	-- Speed selector
	process(i_clk, i_rst, t_current_component, t_spd)
	begin
		if(i_rst = '1') then
			t_spd <= one_gps;
			t_past_spd <= one_gps;
		elsif(rising_edge(i_clk) and (t_current_component = FCAAR or t_current_component = PCAD)) then
			t_past_spd <= t_spd;
			case t_spd is
			when one_gps =>
				if(w_buttons = "01") then
					t_spd <= twelve_gps;
				elsif(w_buttons = "10") then
					t_spd <= two_gps;
				else
					t_spd <= one_gps;
				end if;
			when two_gps =>
				if(w_buttons = "01") then
					t_spd <= one_gps;
				elsif(w_buttons = "10") then
					t_spd <= six_gps;
				else
					t_spd <= two_gps;
				end if;
			when six_gps =>
				if(w_buttons = "01") then
					t_spd <= two_gps;
				elsif(w_buttons = "10") then
					t_spd <= twelve_gps;
				else
					t_spd <= six_gps;
				end if;
			when twelve_gps =>
				if(w_buttons = "01") then
					t_spd <= six_gps;
				elsif(w_buttons = "10") then
					t_spd <= one_gps;
				else
					t_spd <= twelve_gps;
				end if;
			end case;
		end if;
	end process;

end behavioural;