module Top (
	input        i_clk,
	input        i_rst_n,
	input        i_start,
	output [3:0] o_random_out
);

// please check out the working example in lab1 README (or Top_exmaple.sv) first
localparam S_IDLE= 2'b00;
localparam S_GEN = 2'b01;
localparam S_HOLD= 2'b10;

localparam INIT_THRESHOLD = 32'd1000000;
localparam DELTA_THRESHOLD = 32'd500000;

// signals
logic [1:0] state, state_next;
logic [3:0] random_out, random_out_next;
logic [5:0] iter, iter_next;
logic [15:0] seed, seed_next;
logic [31:0] count, count_next;
logic [31:0] threshold, threshold_next;

assign o_random_out = random_out;

// FSM
always_comb begin
    case(state)
        S_IDLE: state_next = (i_start) ? S_GEN : S_IDLE;
        S_GEN : state_next = (iter < 'd20) ? S_GEN : S_HOLD;
        S_HOLD: state_next = (i_start) ? S_GEN : S_HOLD;
    endcase
end

// combinational
always_comb begin
    case(state)
        S_IDLE: begin
            iter_next = 2'd0;
            random_out_next = 4'd0;
            seed_next = seed + 16'd1;
            count_next = 10'd0;
            threshold_next = threshold;
            if (i_start) begin 
                count_next = 10'd0;
                random_out_next = seed[3:0];
                seed_next = {seed[0] ^ seed[2] ^ seed[3] ^ seed[5], seed[15:1]};
                threshold_next = INIT_THRESHOLD;
                iter_next = 4'd0;
            end
        end
        S_GEN: begin
            random_out_next = seed[3:0];
            if (i_start) begin // if start in the middle of generation, restart
                count_next = 10'd0;
                seed_next = {seed[0] ^ seed[2] ^ seed[3] ^ seed[5], seed[15:1]};
                threshold_next = INIT_THRESHOLD;
                iter_next = 4'd0;
            end
            else if (count < threshold) begin 
                count_next = count + 10'd1;
                seed_next = seed;
                threshold_next = threshold;
                iter_next = iter;            
            end
            else begin // change output every threshold cycles
                count_next = 10'd0;
                seed_next = {seed[0] ^ seed[2] ^ seed[3] ^ seed[5], seed[15:1]};
                threshold_next = (iter>'d10)? threshold + DELTA_THRESHOLD : threshold;
                iter_next = iter + 4'd1;
            end
        end
        S_HOLD: begin
            iter_next = 'd0;
            random_out_next = random_out;
            seed_next = seed;
            count_next = 10'd0;
            threshold_next = INIT_THRESHOLD;
            if (i_start) begin 
                count_next = 10'd0;
                random_out_next = seed[3:0];
                seed_next = {seed[0] ^ seed[2] ^ seed[3] ^ seed[5], seed[15:1]};
                threshold_next = INIT_THRESHOLD;
                iter_next = 4'd0;
            end
        end
    endcase
end

// sequential
always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state <= S_IDLE;
        iter <= 2'd0;
        random_out <= 4'd0;
        seed <= 16'hACE5; // initial seed
        count <= 10'd0;
        threshold <= INIT_THRESHOLD;
    end else begin
        state <= state_next;
        iter <= iter_next;
        random_out <= random_out_next;
        seed <= seed_next;
        count <= count_next;
        threshold <= threshold_next;
    end
end
endmodule
