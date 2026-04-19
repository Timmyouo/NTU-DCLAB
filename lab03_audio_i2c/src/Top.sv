module Top (
	input i_rst_n,
	input i_clk,

	input i_key_0,       // Start
	input i_key_1,       // Pause
	input i_key_2,       // Stop

	input [2:0] i_speed, // Decide speed mode by switches
	input       i_is_slow,
	input		i_slow_mode,
	
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N, 
	output        o_SRAM_OE_N, 
	output        o_SRAM_LB_N, 
	output        o_SRAM_UB_N, 
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,

	// SEVENDECODER (optional display)
	//output [5:0] o_time,
	output [5:0] o_speed,
	output [5:0] o_record_time,
	output [5:0] o_play_time,

	// LCD (optional display)
	// input        i_clk_800k,
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON,

	// LED
	output  [8:0] o_ledg,
	output [17:0] o_ledr
);

// design the FSM and states as you like
parameter S_IDLE       = 0;
parameter S_I2C        = 1;
parameter S_RECD       = 2;
parameter S_PLAY       = 3;
parameter S_PLAY_PAUSE = 4;


logic [2:0]  state_r, state_w;
logic        i2c_oen;
logic [19:0] addr_record, addr_play, stop_address;
logic [15:0] data_record, data_play, dac_data;


assign o_SRAM_ADDR = (state_r == S_RECD) ? addr_record : addr_play[19:0];
assign io_SRAM_DQ  = (state_r == S_RECD) ? data_record : 16'dz; // sram_dq as output
assign data_play   = (state_r != S_RECD) ? io_SRAM_DQ : 16'd0; // sram_dq as input

assign o_SRAM_WE_N = (state_r == S_RECD) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;

// Button assignment
logic  start, pause, stop;
assign start = i_key_0;
assign pause = i_key_1;
assign stop  = i_key_2;

// Time Display
assign o_record_time = (state_r == S_RECD) ? addr_record[19:15] : 5'd0;
assign o_play_time   = ((state_r == S_PLAY) || (state_r == S_PLAY_PAUSE)) ? addr_play[19:15]   : 5'd0;
//assign o_time = (state_r == S_RECD) ? addr_record[19:15] :
//					 ((state_r == S_PLAY) || (state_r == S_PLAY_PAUSE)) ? addr_play[19:15]   : 5'd0;
assign o_speed = {2'b0, dsp_speed};

// Player enable signal
logic  player_en;
assign player_en = ((state_r == S_PLAY) && (addr_play <= stop_address));

// Recorder stop address control
//logic recd_stop;
//assign recd_stop = (state_r == S_RECD) && stop;

// I2C signal
logic I2c_start_r, I2c_start_w;
logic I2c_finish;
logic I2c_start;
assign I2c_start = (state_r == S_I2C);

always_comb begin
	I2c_start_w = 0;
	if (state_r == S_IDLE) I2c_start_w = 1'b1;
end

// DSP speed and mode
logic [3:0] dsp_speed;
logic dsp_fast, dsp_slow0, dsp_slow1;

assign dsp_fast  = ~i_is_slow;
assign dsp_slow0 = (i_is_slow) && (i_slow_mode == 1'b0);
assign dsp_slow1 = (i_is_slow) && (i_slow_mode == 1'b1);

// Decode 3-bit i_speed by Gray Code
always_comb begin
	case (i_speed)
		3'b000: dsp_speed = 4'd1;
		3'b001: dsp_speed = 4'd2;
		3'b011: dsp_speed = 4'd3;
		3'b010: dsp_speed = 4'd4;
		3'b110: dsp_speed = 4'd5;
		3'b111: dsp_speed = 4'd6;
		3'b101: dsp_speed = 4'd7;
		3'b100: dsp_speed = 4'd8;
	endcase
end

// LED : help debugging
assign o_ledg[0] = (state_r == S_IDLE);
assign o_ledg[1] = (state_r == S_I2C);
assign o_ledg[2] = (state_r == S_RECD);
assign o_ledg[3] = (state_r == S_PLAY);
assign o_ledg[4] = (state_r == S_PLAY_PAUSE);

assign o_ledr[0] = (state_w == S_IDLE);
assign o_ledr[1] = (state_w == S_I2C);
assign o_ledr[2] = (state_w == S_RECD);
assign o_ledr[3] = i_rst_n;

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n   (i_rst_n),
	.i_clk     (i_clk_100k),
	.i_start   (I2c_start),
	.o_finished(I2c_finish),
	.o_sclk    (o_I2C_SCLK),
	.io_sdat    (io_I2C_SDAT),
	.o_oen     (i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n    (i_rst_n),
	.i_clk      (i_AUD_BCLK),
	.i_start    (start),
	.i_pause    (pause),
	.i_stop     (stop),
	.i_speed    (dsp_speed),
	.i_fast     (dsp_fast),
	.i_slow_0    (dsp_slow0),
	.i_slow_1    (dsp_slow1),
	.i_daclrck  (i_AUD_DACLRCK),
	.i_sram_data(data_play),
	.o_dac_data (dac_data),
	.o_sram_addr(addr_play)
);

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n     (i_rst_n),
	.i_bclk      (i_AUD_BCLK),
	.i_daclrck   (i_AUD_DACLRCK),
	.i_en        (player_en), // enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data  (dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM
AudRecorder recorder0(
	.i_rst_n  (i_rst_n), 
	.i_clk    (i_AUD_BCLK),
	.i_lrc    (i_AUD_ADCLRCK),
	.i_start  (start),
	.i_pause  (pause),
	.i_stop   (stop),
	.i_data   (i_AUD_ADCDAT),
	.i_state  (state_r),
	.o_address(addr_record),
	.o_data   (data_record),
	.o_stop_address(stop_address)
);

// FSM
always_comb begin
	state_w = state_r;
	case (state_r)
		S_IDLE: 		            		   state_w = S_I2C; 
		S_I2C: 		   if (I2c_finish)   state_w = S_RECD;
		S_RECD: 	   if (stop)            state_w = S_PLAY_PAUSE;
		S_PLAY: 	   if (pause || stop)   state_w = S_PLAY_PAUSE;
		S_PLAY_PAUSE:  if (start)			state_w = S_PLAY;
	endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r     <= S_IDLE;
		I2c_start_r <= 1'b0;
	end
	else begin
		state_r     <= state_w;
		I2c_start_r <= I2c_start_w;
	end
end

endmodule
