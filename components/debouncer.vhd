library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.MATH_REAL.all;
use IEEE.NUMERIC_STD.ALL;

entity debouncer is
generic
(
	clk_freq	:	natural;
	ms_delay	:	natural
);
port
(
	i_clk		:	in		std_logic;
	i_rst		:	in		std_logic;
	i_signal	:	in		std_logic;
	o_signal	:	out	std_logic
);
end debouncer;

architecture behavioural of debouncer is

	constant cycles_each_ms : natural := clk_freq/1000;
	constant total_cycles : natural := ms_delay*cycles_each_ms;
	constant bits : natural	:= integer(ceil(log2(real(total_cycles) - real(1)))) + 1;

	signal r_stage : std_logic_vector(1 downto 0) := "11";
	signal r_output : std_logic := '1';
	signal r_counter : integer range total_cycles-2 downto -1 := total_cycles-2;
	signal w_counter : std_logic_vector(bits-1 downto 0);
	signal w_negative : std_logic;
	signal w_stage_xor : std_logic;

begin
	
	w_negative <= w_counter(w_counter'left);
	w_stage_xor <= r_stage(1) xor r_stage(0);
	w_counter <= std_logic_vector(to_signed(r_counter, bits));
	o_signal <= r_output;
	
	process(i_clk, i_rst, w_stage_xor, w_negative)
	begin
		if(i_rst = '1' or w_stage_xor = '1') then
			r_counter <= total_cycles-2;
		elsif(rising_edge(i_clk) and w_negative = '0') then
			r_counter <= r_counter - 1;
		end if;
	end process;
	
	process(i_clk, i_rst)
	begin
		if(i_rst = '1') then
			r_stage <= "11";
		elsif(rising_edge(i_clk)) then
			r_stage(0) <= i_signal;
			r_stage(1) <= r_stage(0);
		end if;
	end process;
	
	process(i_clk, i_rst, w_negative)
	begin
		if(i_rst = '1') then
			r_output <= '1';
		elsif(rising_edge(i_clk) and w_negative = '1') then
			r_output <= r_stage(1);
		end if;
	end process;

end behavioural;