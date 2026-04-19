module  I2cInitializer(
    input  i_rst_n,
    input  i_clk,
    input  i_start,

    output o_finished,
    output o_sclk,      // I2C Clock
    inout  io_sdat,      // I2C Data
    output o_oen        // you are outputing (you are not outputing only when you are "ack"ing.)
);

// -----------------------------------------------------------------
// Paramaters
// -----------------------------------------------------------------

localparam CMD10  = 24'b 0011_0100_000_1111_0_0000_0000; // Reset
localparam CMD0  = 24'b 0011_0100_000_0100_0_0001_0101; // Analogue Audio Path Control
localparam CMD1  = 24'b 0011_0100_000_0101_0_0000_0000; // Digital Audio Path Control
localparam CMD2  = 24'b 0011_0100_000_0110_0_0000_0000; // Power Down Control 
localparam CMD3  = 24'b 0011_0100_000_0111_0_0100_0010; // Digital Audio Interface Format 
localparam CMD4  = 24'b 0011_0100_000_1000_0_0001_1001; // Sampling Control 
localparam CMD5  = 24'b 0011_0100_000_1001_0_0000_0001; // Active Control 

localparam CMD6  = 24'b 0011_0100_000_0000_0_1001_0111; // Left Line In
localparam CMD7  = 24'b 0011_0100_000_0001_0_1001_0111; // Right Line In 
localparam CMD8  = 24'b 0011_0100_000_0010_0_0111_1001; // Left Headphone Out
localparam CMD9 = 24'b 0011_0100_000_0011_0_0111_1001; // Right Headphone Out

localparam N_CMD = 4'd10;

typedef enum logic [2:0] {
    S_IDLE,
    S_START,
    S_SEND,
    S_ACK,
    S_STOP,
    S_DONE
} state_t;

// -----------------------------------------------------------------
// Reg and wires
// -----------------------------------------------------------------
state_t      state_r   , state_w;

logic [3:0]  cmd_idx_r , cmd_idx_w;  // Determine current sending command
logic [23:0] cmd_data;              
logic [1:0]  byte_idx_r, byte_idx_w; // 3 bytes in a command
logic [3:0]  bit_idx_r , bit_idx_w;  

logic        sclk_r    , sclk_w;
logic        sdat_r    , sdat_w;

// -----------------------------------------------------------------
// Continuous assignment
// -----------------------------------------------------------------
// Output ports 
assign o_sclk     = sclk_r;
assign o_oen      = (state_r == S_ACK) ? 1'b0 : 1'b1;
assign io_sdat     = o_oen ? sdat_r : 1'bz;
assign o_finished = (state_r == S_DONE);

// -----------------------------------------------------------------
// Finite State Machine
// -----------------------------------------------------------------
always_comb begin
    state_w = state_r;
    case (state_r)
        S_IDLE: begin
            if (i_start)        state_w = S_START;
        end
        S_START: begin
            if (sdat_r == 1'b0) state_w = S_SEND;
        end
        S_SEND: begin
            if ((sclk_r == 1'b1) && (bit_idx_r == 4'd8))   state_w = S_ACK;
        end
        S_ACK: begin
            if (sclk_r == 1'b1) begin
                if ((byte_idx_r == 2'd3) && (io_sdat == 0)) state_w = S_STOP;
                else                                       state_w = S_SEND;
            end
        end
        S_STOP: begin
            if ((sclk_r == 1'b1) && (sdat_r == 1'b1)) begin
                if (cmd_idx_r == N_CMD)                    state_w = S_DONE;
                else                                       state_w = S_START;
            end
        end
    endcase
end

// -----------------------------------------------------------------
// Combinational Logic
// -----------------------------------------------------------------

// SCL
always_comb begin
    // Default high
    sclk_w = 1'b1;
    case (state_r)
        // Invert every cycle when sending cammand
        S_SEND, S_ACK: sclk_w = ~sclk_r;
    endcase
end

// Command MUX
always_comb begin
    cmd_data = 24'd0;
    case (cmd_idx_r)
        4'd0 : cmd_data = CMD0;
        4'd1 : cmd_data = CMD1;
        4'd2 : cmd_data = CMD2;
        4'd3 : cmd_data = CMD3;
        4'd4 : cmd_data = CMD4;
        4'd5 : cmd_data = CMD5;
        4'd6 : cmd_data = CMD6;
        4'd7 : cmd_data = CMD7;
        4'd8 : cmd_data = CMD8;
        4'd9 : cmd_data = CMD9;
        4'd10: cmd_data = CMD10;
    endcase
end

// SDAT
always_comb begin
    // Default
    sdat_w     = sdat_r;
    cmd_idx_w  = cmd_idx_r;
    byte_idx_w = byte_idx_r;
    bit_idx_w  = bit_idx_r;

    case (state_r)
        S_START: begin
            // 2 cycles, first sdat high, second low
            sdat_w      = 1'b0;
            byte_idx_w  = 2'd0;
            bit_idx_w   = 4'd0;
        end 
        S_SEND: begin
            if (sclk_r == 1'b1) begin
                // Change SDA
                sdat_w     = cmd_data[23 - byte_idx_r * 8 - bit_idx_r];
                bit_idx_w  = bit_idx_r + 1;
            end
        end   
        S_ACK: begin 
            // Start with ACLK low
            if (sclk_r == 0) begin
                bit_idx_w     = 0;
                byte_idx_w    = byte_idx_r + 1;
            end
            else if ((sclk_r == 1) && io_sdat == 1'b0) begin
                // ACK received
                if (byte_idx_r == 2'd3) begin
                    sdat_w     = 0;
                end else begin
                    sdat_w     = cmd_data[23 - byte_idx_r * 8 - bit_idx_r];
                    bit_idx_w  = bit_idx_r + 1;
                end
            end else begin
                // No ACK
                sdat_w     = cmd_data[23 - byte_idx_r * 8 - bit_idx_r + 8];
                byte_idx_w = byte_idx_r - 1;
                bit_idx_w  = bit_idx_r + 1;
            end
        end          
        S_STOP: begin
            // Pull up SDAT and update cmd_idx
            if ((sclk_r == 1'b1) && (sdat_r == 1'b0)) begin
                sdat_w      = 1'b1;
                cmd_idx_w   = cmd_idx_r + 1;
            end
        end   
    endcase
end


// -----------------------------------------------------------------
// Sequential Logic
// -----------------------------------------------------------------
always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r        <= S_IDLE;
        cmd_idx_r      <= 4'd0;
        byte_idx_r     <= 2'd0;
        bit_idx_r      <= 4'd0;
        sclk_r         <= 1'b1; 
        sdat_r         <= 1'b1;

	end
	else begin
		state_r        <= state_w;
        cmd_idx_r      <= cmd_idx_w;
        byte_idx_r     <= byte_idx_w;
        bit_idx_r      <= bit_idx_w;
        sclk_r         <= sclk_w;
        sdat_r         <= sdat_w;
	end
end
    
endmodule