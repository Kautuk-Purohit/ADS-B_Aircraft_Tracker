/* Output pipeline: takes one parsed message_parser result and sends it back
   to the PC (for pc_receiver.py to read) as a 14-byte frame over serial.
   Two stages, both in this file:

     df/ca/icao/tc/... --> message_tx_framer --> uart_tx --> tx pin (serial)

   uart_tx: standard 8-N-1 UART transmitter, the mirror image of uart_rx in
   rf_receiver.sv. Sends bytes out instead of receiving them.

   message_tx_framer: packages one message_parser result into a fixed
   14-byte frame and shifts it out over an internally-instantiated uart_tx.
   fields_valid only ever pulses on a CRC-passed message (message_parser
   gates it that way), so every frame sent here already passed CRC -- no
   separate valid flag needed in the frame itself.

   Frame layout (14 bytes, MSB-first for multi-byte fields):
     byte 0:     sync marker, 0xAA -- lets the PC-side parser resync if it
                 ever starts mid-frame or misses a byte
     byte 1:     df        (0-31, fits in a byte as-is)
     byte 2:     ca        (0-7)
     byte 3-5:   icao      (24-bit, 3 bytes MSB-first)
     byte 6:     tc        (0-31)
     byte 7:     is_velocity (0 or 1)
     byte 8-9:   ew_velocity  (16-bit sign-extended from 11-bit signed, MSB-first)
     byte 10-11: ns_velocity  (16-bit sign-extended from 11-bit signed, MSB-first)
     byte 12-13: ground_speed (16-bit zero-extended from 11-bit unsigned, MSB-first)

   If a new fields_valid pulses while a frame is still being sent, it's
   simply missed -- at 3Mbaud a 14-byte frame takes under 50us to send,
   and real ADS-B messages are microseconds-to-milliseconds apart at
   minimum, so this only matters under a burst far denser than real traffic
   would produce, and dropping an occasional message under overload is a
   reasonable choice over corrupting a frame in progress. */

module uart_tx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 3_000_000
)(
    input  logic       clk,
    input  logic       reset,

    input  logic [7:0] data_in,
    input  logic       send,      // pulse for one cycle to transmit data_in; ignored while busy
    output logic       tx,        // serial line out (idles high)
    output logic       busy       // high while a byte is being shifted out
);

    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    typedef enum logic [1:0] {IDLE, START_BIT, DATA_BITS, STOP_BIT} state_t;
    state_t state;

    logic [$clog2(CLKS_PER_BIT+1)-1:0] tick_count;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;

    assign busy = (state != IDLE);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            tick_count <= '0;
            bit_index  <= 3'd0;
            shift_reg  <= 8'd0;
            tx         <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (send) begin
                        shift_reg  <= data_in;
                        tick_count <= '0;
                        state      <= START_BIT;
                    end
                end

                START_BIT: begin
                    tx <= 1'b0;
                    if (tick_count == CLKS_PER_BIT - 1) begin
                        tick_count <= '0;
                        bit_index  <= 3'd0;
                        state      <= DATA_BITS;
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end

                DATA_BITS: begin
                    tx <= shift_reg[bit_index];   // LSB first, standard UART order
                    if (tick_count == CLKS_PER_BIT - 1) begin
                        tick_count <= '0;
                        if (bit_index == 3'd7)
                            state <= STOP_BIT;
                        else
                            bit_index <= bit_index + 3'd1;
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end

                STOP_BIT: begin
                    tx <= 1'b1;
                    if (tick_count == CLKS_PER_BIT - 1) begin
                        tick_count <= '0;
                        state      <= IDLE;
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule

module message_tx_framer #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 3_000_000
)(
    input  logic clk,
    input  logic reset,

    input  logic         fields_valid,
    input  logic [4:0]   df,
    input  logic [2:0]   ca,
    input  logic [23:0]  icao,
    input  logic [4:0]   tc,
    input  logic          is_velocity,
    input  logic signed [10:0] ew_velocity,
    input  logic signed [10:0] ns_velocity,
    input  logic [10:0]   ground_speed,

    output logic tx    // serial line out to the PC
);

    logic [7:0] tx_data;
    logic       tx_send;
    logic       tx_busy;
    uart_tx #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_tx (
        .clk(clk), .reset(reset),
        .data_in(tx_data), .send(tx_send), .tx(tx), .busy(tx_busy)
    );

    logic [7:0] frame [0:13];
    logic [3:0] byte_idx;

    typedef enum logic [1:0] {IDLE, LOAD, WAIT_START, WAIT_DONE} state_t;
    state_t state;

    // sign/zero-extend the 11-bit fields out to 16 bits for the wire format
    logic signed [15:0] ew16, ns16;
    logic        [15:0] speed16;
    assign ew16    = {{5{ew_velocity[10]}}, ew_velocity};
    assign ns16    = {{5{ns_velocity[10]}}, ns_velocity};
    assign speed16 = {5'd0, ground_speed};

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= IDLE;
            byte_idx <= 4'd0;
            tx_send  <= 1'b0;
            for (int k = 0; k < 14; k++) frame[k] <= 8'd0;
        end else begin
            tx_send <= 1'b0;

            case (state)
                IDLE: begin
                    if (fields_valid) begin
                        frame[0]  <= 8'hAA;
                        frame[1]  <= {3'd0, df};
                        frame[2]  <= {5'd0, ca};
                        frame[3]  <= icao[23:16];
                        frame[4]  <= icao[15:8];
                        frame[5]  <= icao[7:0];
                        frame[6]  <= {3'd0, tc};
                        frame[7]  <= {7'd0, is_velocity};
                        frame[8]  <= ew16[15:8];
                        frame[9]  <= ew16[7:0];
                        frame[10] <= ns16[15:8];
                        frame[11] <= ns16[7:0];
                        frame[12] <= speed16[15:8];
                        frame[13] <= speed16[7:0];
                        byte_idx  <= 4'd0;
                        state     <= LOAD;
                    end
                end

                LOAD: begin
                    tx_data <= frame[byte_idx];
                    tx_send <= 1'b1;
                    state   <= WAIT_START;
                end

                WAIT_START: begin
                    // wait for uart_tx to actually latch the byte and go busy,
                    // so WAIT_DONE doesn't mistake "not yet started" for "already finished"
                    if (tx_busy) state <= WAIT_DONE;
                end

                WAIT_DONE: begin
                    if (!tx_busy) begin
                        if (byte_idx == 4'd13) begin
                            state <= IDLE;
                        end else begin
                            byte_idx <= byte_idx + 4'd1;
                            state    <= LOAD;
                        end
                    end
                end
            endcase
        end
    end

endmodule