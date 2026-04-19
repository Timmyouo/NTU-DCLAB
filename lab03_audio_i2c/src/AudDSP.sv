module AudDSP(
    input i_rst_n,
	input i_clk,
	input i_start,
	input i_pause,
	input i_stop,
	input [3:0] i_speed,
	input i_fast,
	input i_slow_0, 
	input i_slow_1,
	input i_daclrck,
	input signed [15:0] i_sram_data,
	output signed [15:0] o_dac_data,
	output [19:0] o_sram_addr
);

typedef enum logic [2:0] {S_IDLE, S_PAUSE, S_CALC, S_DONE, S_SEND} state_t;
typedef enum logic [1:0] {FAST, SLOW0, SLOW1,NORMAL} mode_t;
typedef enum logic [1:0] {S_X1, S_X2, S_DIFF} substate_t;
// state
state_t state, state_next;
mode_t mode;
substate_t substate, substate_next;

// regs
logic [19:0] addr, addr_next;
logic signed [15:0] result, result_next, x1, x1_next, x2, x2_next, temp;
logic [3:0] counter, counter_next;

// control signals
logic stop, done;

assign stop = (i_stop || addr_next == 20'hFFFFF);
assign mode = (i_fast) ? FAST :
              (i_slow_0) ? SLOW0 :
              (i_slow_1) ? SLOW1 : NORMAL;
assign o_sram_addr = addr;
assign o_dac_data = result;

always_comb begin
    state_next = state;
    case(state)
        S_IDLE: state_next = (i_start) ? S_CALC : S_IDLE;
        S_PAUSE: state_next = (i_start) ? S_CALC : 
                              (stop) ? S_IDLE : S_PAUSE;
        S_CALC: state_next = (done) ? S_DONE : 
                             (stop) ? S_IDLE : 
									  (i_pause) ? S_PAUSE : S_CALC;
        S_DONE: state_next = (i_daclrck) ? S_SEND : 
                             (stop) ? S_IDLE : 
									  (i_pause) ? S_PAUSE : S_DONE;
        S_SEND: begin
			   if (!i_daclrck) state_next = S_CALC ;
				else if (i_pause) state_next = S_PAUSE; 
				else if (stop)    state_next = S_IDLE;
				else state_next = S_SEND;
			end
    endcase
	 //if (stop) state_next = S_IDLE;
end

always_comb begin
    addr_next = addr;
    result_next = result;
    done = 0;
    counter_next = counter;
    substate_next = substate;
    x1_next = x1;
    x2_next = x2;
    temp = 0;
    case (state)
        S_IDLE: begin
            addr_next = 0;
            result_next = 0;
            substate_next = S_X1;
        end
        S_PAUSE: begin
            addr_next = addr;
            result_next = 0;
        end
        S_CALC: begin
            case(mode)
                FAST: begin
                    addr_next = addr + i_speed;
                    result_next = i_sram_data;
                    done = 1;
                end
                SLOW0: begin
                    addr_next = (counter < i_speed-1) ? addr : addr + 1;
                    result_next = i_sram_data;
                    done = 1;
                end
                SLOW1: begin
                    addr_next = addr;
                    x1_next = x1;
                    x2_next = x2;
                    substate_next = substate;
                    
                    case(substate)
                        S_X1: begin
                            addr_next = addr + 1;
                            x1_next = i_sram_data;
                            result_next = result;
                            substate_next = S_X2;
                        end
                        S_X2: begin
                            addr_next = addr - 1;
                            x2_next = i_sram_data;
                            substate_next = S_DIFF;
                        end
                        S_DIFF: begin
                            addr_next = (counter < i_speed-1) ? addr : addr + 1;
                            temp = $signed($signed(x2) - $signed(x1))/$signed({13'b0,i_speed});
                            result_next = $signed(result) + $signed(temp);
                            done = 1;
                            substate_next = S_X1;
                        end
                    endcase
                end
                NORMAL: begin
                    addr_next = addr + 1;
                    result_next = i_sram_data;
                    done = 1;
                end
            endcase
        end
        S_DONE: begin
            addr_next = addr;
            result_next = result;
        end
        S_SEND: begin
            addr_next = addr;
            result_next = result;
            counter_next = (!i_daclrck) ? ((counter < i_speed - 1) ? counter + 1 : 0) : counter;
        end
    endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if(!i_rst_n) begin
        state <= S_IDLE;
        addr <= 0;
        result <= 0;
        counter <= 0;
        substate <= S_X1;
        x1 <= 0;
        x2 <= 0;
    end else begin
        state <= state_next;
        addr <= addr_next;
        result <= result_next;
        counter <= counter_next;
        substate <= substate_next;
        x1 <= x1_next;
        x2 <= x2_next;
    end
end
endmodule