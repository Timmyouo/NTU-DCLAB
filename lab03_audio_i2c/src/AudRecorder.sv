
module AudRecorder (
    input         i_rst_n,
    input         i_clk,

    input         i_lrc,
    input         i_start,
    input         i_pause,
    input         i_stop,
    input         i_data,
	input          [2:0]i_state,

    output [19:0] o_address,
    output [15:0] o_data,
	output [19:0] o_stop_address
);


// Parameters
localparam L_CHANNEL = 1'b0;
localparam R_CHANNEL = 1'b1;

typedef enum logic [1:0] {
    S_IDLE,
    S_RECORD,
    S_PAUSE
} state_t;


// Wire and reg
state_t      state_r       , state_w;
logic [15:0] data_r        , data_w;         // Store input data
logic [19:0] addr_counter_r, addr_counter_w; // SRAM address
logic [4:0]  bit_counter_r , bit_counter_w;  
logic [15:0] mem_data_r    , mem_data_w;
logic [19:0] stop_address_r, stop_address_w;


// Wire assignment
assign o_address  = addr_counter_r;
assign o_data     = mem_data_r;
assign o_stop_address = stop_address_r;

// FSM
always_comb begin
    state_w = state_r;
    case (state_r)
        S_IDLE: begin
            if      (i_start) state_w = S_RECORD;
        end 
        S_RECORD: begin
            if      (i_pause) state_w = S_PAUSE;
            else if (i_stop && i_state == 2)  state_w = S_IDLE;
        end 
        S_PAUSE: begin
            if      (i_start) state_w = S_RECORD;
            else if (i_stop && i_state == 2)  state_w = S_IDLE;           
        end 
    endcase
end

// Stop address
always_comb begin
	stop_address_w = stop_address_r;
	if (i_stop && i_state == 2) begin
		stop_address_w = addr_counter_r;
	end

end

always_comb begin
    // Default
    data_w         = data_r;
    bit_counter_w  = 0;
    addr_counter_w = addr_counter_r;
    mem_data_w     = mem_data_r;

    // While recording, store the input bits serialy, then write back.
    if (state_r == S_RECORD) begin
        if (i_lrc == R_CHANNEL) begin
            // Record the right channel
            if (bit_counter_r == 0) begin
                data_w = 16'd0; // Empty cycle
                bit_counter_w = bit_counter_r + 1;
            end 
            else if (bit_counter_r < 5'd17) begin
                // 16 bit input
                data_w = {data_r[14:0], i_data};
                bit_counter_w = bit_counter_r + 1;
            end
            else if (bit_counter_r == 5'd17) begin
                // Change SRAM address and data, only once in a lrck cycle
                addr_counter_w = addr_counter_r + 1;
                mem_data_w     = data_r;
                bit_counter_w  = bit_counter_r + 1;
            end
            else begin
                // Action completes , hold bit_counter value
                bit_counter_w = bit_counter_r;
            end
        end 
    end
    else if (state_r == S_PAUSE) begin
        // Hold the same SRAM address
        addr_counter_w = addr_counter_r;
    end
    else begin
        // Reset SRAM address at S_IDLE 
        addr_counter_w = 0;
    end
end


always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r        <= S_IDLE;
        data_r         <= 16'd0;
        addr_counter_r <= 20'd0;
        bit_counter_r  <= 5'd0;
        mem_data_r     <= 16'd0;
		  stop_address_r <= 16'd0;
	end
	else begin
		state_r        <= state_w;
        data_r         <= data_w;
        addr_counter_r <= addr_counter_w;
        bit_counter_r  <= bit_counter_w;
        mem_data_r     <= mem_data_w;	
		stop_address_r <= stop_address_w;
	end
end

endmodule


/*
module AudRecorder (
    input i_rst_n,
    input i_clk,
    input i_lrc, // mic only right channel, so only need to handle when i_lrc is high
    input i_start,
    input i_stop,
    input i_data, // i2s data
    output [19:0] o_address, // total 2^20 words by 16 bits can be saved
    output [15:0] o_data,
    output [19:0] o_stop_address
    //output o_done,
    //output [1:0] o_state // debug purpose
);
    // TODO: Record audio data from WM8731 and save it to SRAM
    localparam S_IDLE  = 0;
    localparam S_LEFT  = 1;
    localparam S_RIGHT = 2;
    localparam S_STOP  = 3;

    localparam STOP_ADDR = 20'hfffff;
    // localparam STOP_ADDR = 20'd15; // for testing, at most 11 words

    reg [1:0] state_r, state_w;
    reg [4:0] count_r, count_w; // counter for right channel data

    reg stop_r, stop_w;

    reg [19:0] address_r, address_w;
    reg [15:0] data_r, data_w;
    reg [19:0] stop_address_r, stop_address_w;

    // output assignment
    assign o_address = address_r;
    assign o_data = data_r;
    assign o_stop_address = stop_address_r;
    assign o_done = (state_r == S_STOP);
    assign o_state = state_r;

    // state machine
    always @(*) begin
        state_w = state_r;
        case(state_r)
            S_IDLE: if(i_start) state_w = S_LEFT;
            S_LEFT: begin
                if(stop_r)      state_w = S_STOP;
                else if(i_lrc)  state_w = S_RIGHT;
            end
            S_RIGHT: if(!i_lrc) state_w = S_LEFT;
        endcase
    end

    // counter logic
    always @(*) begin
        count_w = count_r;
        case(state_r)
            S_LEFT: count_w = 0;
            S_RIGHT: if(count_r < 16) count_w = count_r + 1;
        endcase
    end

    // stop logic
    always @(*) begin
        stop_w = stop_r;
        case(state_r)
            S_IDLE: stop_w = 0;
            S_LEFT:  if(i_stop) stop_w = 1;
            S_RIGHT: if(i_stop || (address_r == STOP_ADDR)) stop_w = 1;
            S_STOP: stop_w = 1;
        endcase
    end

    // address logic
    always @(*) begin
        address_w = address_r;
        case(state_r)
            S_IDLE: address_w = 0;
            S_RIGHT: if(!i_lrc) address_w = address_r + 1;
        endcase
    end

    // data logic
    always @(*) begin
        data_w = data_r;
        case(state_r)
            S_LEFT: data_w = 0;
            S_RIGHT: begin
                if(count_r < 16) data_w = {data_r[14:0], i_data};
            end
        endcase
    end

    // stop address logic
    always @(*) begin
        stop_address_w = stop_address_r;
        case(state_r)
            S_IDLE:  stop_address_w = 0;
            S_RIGHT: stop_address_w = address_r;
        endcase
    end

    // sequential logic
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state_r <= S_IDLE;
            count_r <= 0;
            stop_r <= 0;
            address_r <= 0;
            data_r <= 0;
            stop_address_r <= 0;
        end
        else begin
            state_r <= state_w;
            count_r <= count_w;
            stop_r <= stop_w;
            address_r <= address_w;
            data_r <= data_w;
            stop_address_r <= stop_address_w;
        end
    end
endmodule
*/