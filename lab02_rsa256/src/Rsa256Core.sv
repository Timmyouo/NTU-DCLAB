module Rsa256Core (
    input          i_clk,
    input          i_rst,
    input          i_start,
    input  [255:0] i_a, // cipher text y
    input  [255:0] i_d, // private key
    input  [255:0] i_n,
    output [255:0] o_a_pow_d, // plain text x
    output         o_finished
);

// State definitions
localparam S_IDLE = 2'd0;
localparam S_PREP = 2'd1;
localparam S_MONT = 2'd2;
localparam S_DONE = 2'd3;

// Sub-state for MONT (to handle t² and m×t operations)
localparam MONT_T_SQ = 1'b1;  // Calculate t² × 2^-256
localparam MONT_M_T  = 1'b0;  // Calculate m × t × 2^-256

logic [1:0] state, state_next;
logic mont_sub_state, mont_sub_state_next;
logic [9:0] bit_counter, bit_counter_next; // 0 to 255
logic [255:0] m, m_next;       // Result accumulator
logic [255:0] t, t_next;       // Temporary value
logic [255:0] d_reg, d_reg_next; // Registered private key

// PREP module signals
logic [255:0] prep_result;
logic prep_ready;
logic prep_start;

// MONT module signals
logic [255:0] mont_a, mont_b;
logic [255:0] mont_result;
logic mont_ready;
logic mont_start;
logic sub_rst;

// Module instantiations
RsaPrep prep_inst (
    .i_clk(i_clk),
    .i_rst(sub_rst),
    .i_start(prep_start),
    .i_y(i_a),
    .i_n(i_n),
    .o_prep(prep_result),
    .o_prep_ready(prep_ready)
);

RsaMont mont_inst (
    .i_clk(i_clk),
    .i_rst(sub_rst),
    .i_start(mont_start),
    .i_a(mont_a),
    .i_b(mont_b),
    .i_n(i_n),
    .o_mont(mont_result),
    .o_mont_ready(mont_ready)
);

// Output assignments
assign o_a_pow_d = m;
assign o_finished = (state == S_DONE);
assign sub_rst = (state == S_DONE || i_rst) ? 1 : 0;

// FSM and control logic
always_comb begin
    // Default values
    state_next = state;
    mont_sub_state_next = mont_sub_state;
    bit_counter_next = bit_counter;
    m_next = m;
    t_next = t;
    d_reg_next = d_reg;
    
    prep_start = 1'b0;
    mont_start = 1'b0;
    mont_a = 256'd0;
    mont_b = 256'd0;

    case (state)
        S_IDLE: begin
            if (i_start) begin
                state_next = S_PREP;
                d_reg_next = i_d;
                m_next = 256'd1; // Initialize m to 1
                bit_counter_next = 10'd0; // Start from MSB
                mont_sub_state_next = MONT_M_T;
                prep_start = 1'b1;
            end
        end
        
        S_PREP: begin
            if (prep_ready) begin
                t_next = prep_result; // t = y × 2^256 (mod N)
                state_next = S_MONT;
                mont_start = 1'b1; // Start first t² operation
                mont_a = prep_result;
                mont_b = prep_result;
            end
        end
        
        S_MONT: begin
            case (mont_sub_state)
                MONT_M_T: begin
                    // Calculate m × t × 2^-256 (mod N)
                    if (d_reg[bit_counter]) begin
                        mont_a = t;
                        mont_b = m;
                        if (mont_ready) begin
                            m_next = mont_result;
                            mont_sub_state_next = MONT_T_SQ;
                            mont_start = 1'b1;
                        end
                    end
                    else begin
                        mont_a = t;
                        mont_b = t;
                        mont_sub_state_next = MONT_T_SQ;
                    end
                end

                MONT_T_SQ: begin
                    // Calculate t × t × 2^-256 (mod N)
                    mont_a = t;
                    mont_b = t;
                    if (mont_ready) begin
                        t_next = mont_result;
                        // Move to next bit
                        if (bit_counter == 255) begin
                            state_next = S_DONE;
                        end else begin
                            bit_counter_next = bit_counter + 1;
                            mont_sub_state_next = MONT_M_T;
                            mont_start = 1'b1;
                        end
                    end
                end
            endcase
        end
        
        S_DONE: begin
            // Stay in DONE until reset or new start
            // if (i_start) begin
            //     state_next = S_PREP;
            //     d_reg_next = i_d;
            //     m_next = 256'd1;
            //     bit_counter_next = 10'd0;
            //     mont_sub_state_next = MONT_M_T;
            //     prep_start = 1'b1;
            // end
            state_next = S_IDLE;
            mont_sub_state_next = 0;
            bit_counter_next = 0;
            m_next = 256'd1;
            t_next = 0;
            d_reg_next = 0;
        end
    endcase
end

// Sequential logic
always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        state <= S_IDLE;
        mont_sub_state <= MONT_M_T;
        bit_counter <= 10'd0;
        m <= 256'd0;
        t <= 256'd0;
        d_reg <= 256'd0;
    end else begin
        state <= state_next;
        mont_sub_state <= mont_sub_state_next;
        bit_counter <= bit_counter_next;
        m <= m_next;
        t <= t_next;
        d_reg <= d_reg_next;
    end
end

endmodule

module RsaPrep #(
    parameter WIDTH = 256
) (
	input i_clk,
	input i_rst,
    input i_start,
	input [WIDTH-1:0] i_y,
	input [WIDTH-1:0] i_n,
	output [WIDTH-1:0] o_prep,
	output o_prep_ready
);

localparam S_IDLE = 0;
localparam S_CALC = 1;
localparam S_DONE = 2;

logic [1:0] state, state_next;
logic [8:0] k, k_next;
logic [WIDTH+1:0] m, m_next;
logic [WIDTH+1:0] t, t_next;
logic [WIDTH+1:0] temp, temp1;
logic prep_ready, prep_ready_next;

assign o_prep = m[WIDTH-1:0];
assign o_prep_ready = prep_ready;

always_comb begin
	 state_next = state;
    case(state)
        S_IDLE: state_next = i_start ? S_CALC : S_IDLE;
        S_CALC: state_next = (k<WIDTH) ? S_CALC : S_DONE;
        S_DONE: state_next = S_IDLE;
    endcase
end

always_comb begin
	 k_next = k;
	 t_next = t;
	 m_next = m;
	 prep_ready_next = prep_ready;
	 temp1 = 0;
	 temp = 0;
    case(state)
        S_IDLE: begin
            k_next = 0;
            t_next = {1'b0, i_y};
            m_next = 0;
            prep_ready_next = 0;
        end
        S_CALC: begin
            k_next = k + 1;
            temp1 = t << 1;
            t_next = (temp1 >= {2'b0, i_n}) ? (temp1 - i_n) : temp1;
            temp = m + t;
            if (k == WIDTH) begin
                m_next = (temp >= {2'b0, i_n}) ? (temp - i_n) : temp;
            end else
                m_next = m;
            prep_ready_next = 0;
        end
        S_DONE: begin
            k_next = k;
            t_next = t;
            m_next = m;
            prep_ready_next = 1;
        end
    endcase
end
always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        state <= S_IDLE;
        t <= 0;
        k <= 0;
        m <= 0;
        prep_ready <= 0;
    end else begin
        state <= state_next;
        t <= t_next;
        k <= k_next;
        m <= m_next;
        prep_ready <= prep_ready_next;
    end
end
endmodule

module RsaMont #(
    parameter WIDTH = 256
) (
    input  logic              i_clk,
    input  logic              i_rst,
    input  logic              i_start,
    input  logic [WIDTH-1:0]  i_a,
    input  logic [WIDTH-1:0]  i_b,
    input  logic [WIDTH-1:0]  i_n,
    output logic [WIDTH-1:0]  o_mont,
    output logic              o_mont_ready
);

localparam S_IDLE = 0;
localparam S_CALC = 1;
localparam S_DONE = 2;

logic [1:0] state, state_next;
logic mont_ready, mont_ready_next;
logic [8:0] k, k_next;
logic [WIDTH+1:0] m;
logic [WIDTH+2:0] m_next, temp;

assign o_mont = m[WIDTH-1:0];
assign o_mont_ready = mont_ready;

always_comb begin
    state_next       = state;
    k_next           = k;
    m_next           = m;
    mont_ready_next  = 0;
    temp = 0;
    case (state)
        S_IDLE: begin
            if (i_start) begin
                state_next = S_CALC;
                k_next = 0;
                m_next = 0;
            end
        end

        S_CALC: begin
            // Step 1: conditional add of b
            if (i_a[k])
                temp = m + i_b;
            else
                temp = m;

            // Step 2: Montgomery conditional add of n and shift
            if (temp[0])
                m_next = (temp + i_n) >> 1;
            else
                m_next = temp >> 1;

            // Step 3: progress iteration
            if (k == WIDTH-1)
                state_next = S_DONE;
            else
                k_next = k + 1;
        end

        S_DONE: begin
            if (m >= i_n)
                m_next = m - i_n;
            else
                m_next = m;
            mont_ready_next = 1;
            state_next = S_IDLE;
        end
    endcase
end

always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
        state <= S_IDLE;
        k <= 0;
        m <= 0;
        mont_ready <= 0;
    end else begin
        state <= state_next;
        k <= k_next;
        m <= m_next;
        mont_ready <= mont_ready_next;
    end
end

endmodule