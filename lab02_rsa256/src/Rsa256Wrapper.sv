module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

// Feel free to design your own FSM!
localparam S_GET_KEY = 0;
localparam S_GET_DATA = 1;
localparam S_WAIT_CALCULATE = 2;
localparam S_SEND_DATA = 3;

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
logic [1:0] state_r, state_w;
logic [6:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[255-:8];

Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),
    .i_d(d_r),
    .i_n(n_r),
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
);

task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask
task StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask

always_comb begin
    // Default
    n_w = n_r;
    d_w = d_r;
    enc_w = enc_r;
    dec_w = dec_r;
    bytes_counter_w = bytes_counter_r;
    rsa_start_w = 0;
    state_w = state_r;

    
    avm_read_w  = avm_read_r;
    avm_write_w = avm_write_r;
    avm_address_w = avm_address_r;

    // Finite State Machine
    case (state_r)
        S_GET_KEY: begin
            // Keep the read signal to be 1 while waiting for permission, do not rely on avm_waitrequest
            if (avm_read_r == 0) begin
                // Request to read the rrdy bit at the beginning
                StartRead(STATUS_BASE);
            end
            // Reading rrdy bit:
            else if (avm_read_r && avm_address_r == STATUS_BASE) begin
                if (!avm_waitrequest) begin
                    // The reg is ready to be read（waitrequest==0）
                    if (avm_readdata[RX_OK_BIT] == 1) begin
                        // Read RX_BASE ：Change the address to RX_BASE（while avm_read stays high）
                        avm_address_w = RX_BASE;
                        avm_read_w = 1;
                    end
                    else begin
                        // rrdy low, keep reaading  STATUS_BASE
                        avm_address_w = STATUS_BASE;
                        avm_read_w = 1;
                    end
                end
                else begin
                    // waitrequest = 1：keep the value of avm_read and avm_address until waitrequest drops
                    avm_read_w = 1;
                    avm_address_w = STATUS_BASE;
                end
            end
            // Reading RX_BASE:
            else if (avm_read_r && avm_address_r == RX_BASE) begin
                //  Wait for permission to read RX after rrdy checked
                if (!avm_waitrequest) begin
                    // Read the RX
                    if (bytes_counter_r >= 32) begin
                        // Actually not sure n and d which comes first?
                        // Read n value for the first 32 bytes
                        n_w = {n_r[247:0], avm_readdata[7:0]};
                    end
                    else begin
                        // Read d value for the rest 
                        d_w = {d_r[247:0], avm_readdata[7:0]};
                    end
                    // Check counter
                    if (bytes_counter_r == 0) begin
                        // Finish n and d reading, go to data reading
                        bytes_counter_w = 31;
                        state_w = S_GET_DATA;
                        avm_read_w = 0; 
                    end
                    else begin
                        // Go back to check STATUS_BASE 
                        bytes_counter_w = bytes_counter_r - 1;
                        avm_read_w = 1;
                        avm_address_w = STATUS_BASE;
                    end
                end
                else begin
                    // Not ready：keeps read/address
                    avm_read_w = 1;
                    avm_address_w = RX_BASE;
                end
            end
        end

        //  S_GET_DATA: to get enc data
        S_GET_DATA: begin
            // Start to read check bit
            if (avm_read_r == 0) begin
                StartRead(STATUS_BASE);
            end
            else if (avm_read_r && avm_address_r == STATUS_BASE) begin
                //  Wait for permission to read rrdy bit
                if (!avm_waitrequest) begin
                    // Read the rrdy bit
                    if (avm_readdata[RX_OK_BIT] == 1) begin
                        // Ready, send request to read RX data
                        avm_address_w = RX_BASE;
                        avm_read_w = 1;
                    end else begin
                        // Not ready yet , keep waiting for rrdy
                        avm_address_w = STATUS_BASE;
                        avm_read_w = 1;
                    end
                end else begin
                    // Keeo waiting for permission to read rrdy bit
                    avm_read_w = 1;
                    avm_address_w = STATUS_BASE;
                end
            end
            else if (avm_read_r && avm_address_r == RX_BASE) begin
                //  Wait for permission to read RX after rrdy checked
                if (!avm_waitrequest) begin
                    // Read the RX
                    enc_w = {enc_r[247:0], avm_readdata[7:0]}; // Send readdata into enc_r and shift right
                    if (bytes_counter_r == 0) begin
                        // Go to calculate after collecting all 32 bytes
                        bytes_counter_w = 31;
                        rsa_start_w = 1;
                        state_w = S_WAIT_CALCULATE;
                        avm_read_w = 0;
                    end else begin
                        // Go back to check STATUS_BASE
                        bytes_counter_w = bytes_counter_r - 1;
                        avm_read_w = 1; 
                        avm_address_w = STATUS_BASE;
                    end
                end
            end
        end

        S_WAIT_CALCULATE: begin
            if (rsa_finished) begin
                dec_w[255:8] = rsa_dec[247:0];
                state_w = S_SEND_DATA;
                bytes_counter_w = 30;
            end
        end

        // S_SEND_DATA: Maintain write = 1 until !waitrequest
        S_SEND_DATA: begin
            if (!avm_write_r && !avm_read_r) begin
                StartRead(STATUS_BASE);
            end
            else if (avm_read_r && avm_address_r == STATUS_BASE) begin
                if (!avm_waitrequest) begin
                    if (avm_readdata[TX_OK_BIT] == 1) begin
                        avm_read_w = 0;
                        StartWrite(TX_BASE);
                    end else begin
                        avm_address_w = STATUS_BASE;
                        avm_read_w = 1;
                    end
                end else begin
                    avm_read_w = 1;
                    avm_address_w = STATUS_BASE;
                end
            end
            else if (avm_write_r && avm_address_r == TX_BASE) begin
                if (!avm_waitrequest) begin
                    dec_w = {dec_r[247:0], 8'd0};
                    if (bytes_counter_r == 0) begin
                        state_w = S_GET_DATA;
                        bytes_counter_w = 31;
                        avm_write_w = 0;
                    end else begin
                        bytes_counter_w = bytes_counter_r - 1;
                        // Go back to check STATUS_BASE
                        avm_write_w = 0; // finish this write cycle
                        StartRead(STATUS_BASE);
                    end
                end else begin
                    avm_write_w = 1;
                    avm_address_w = TX_BASE;
                end
            end
        end
    endcase
end


always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_GET_KEY;
        bytes_counter_r <= 63;
        rsa_start_r <= 0;
    end else begin
        n_r <= n_w;
        d_r <= d_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        bytes_counter_r <= bytes_counter_w;
        rsa_start_r <= rsa_start_w;
    end
end

endmodule
