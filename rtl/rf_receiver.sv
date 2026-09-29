/* The reciever pipeline to take in data from the dongle over UART and turn it into I/Q samples for magnitude_calculator */
/* Transport pipeline: takes raw serial bytes from the PC (which is relaying
   the RTL-SDR dongle's captured I/Q bytes) and turns them into paired
   (i_sample, q_sample) values ready for magnitude_calculator, the first
   module of the actual decoding pipeline. Two stages, both in this file:

     rx pin (serial) --> uart_rx --> iq_deinterleaver --> i_sample/q_sample

   uart_rx: standard 8-N-1 UART receiver. Not part of the Python model --
   this is new hardware needed because the ADS-B pipeline now has to receive
   its samples from the PC instead of a testbench array. Oversamples at 16x
   baud rate and samples each bit at the middle of its window (avoids
   sampling right at an edge, where transitions are), the standard,
   jitter-tolerant way to build a UART receiver. */

module uart_rx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 3_000_000
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,          // serial line in (idles high)

    output logic [7:0] rx_data,
    output logic        rx_valid     // one-cycle pulse when rx_data is fresh
);

    localparam int CLKS_PER_BIT   = CLK_FREQ_HZ / BAUD_RATE;
    localparam int CLKS_PER_16TH  = CLKS_PER_BIT / 16;

    typedef enum logic [1:0] {IDLE, START_BIT, DATA_BITS, STOP_BIT} state_t;
    state_t state;

    logic [$clog2(CLKS_PER_16TH+1)-1:0] tick_count;
    logic [3:0] sample_count;   // 0..15, counts 16ths of a bit period
    logic [2:0] bit_index;      // 0..7, which data bit we're on
    logic [7:0] shift_reg;

    // two-stage synchronizer: rx comes from an async external pin
    logic rx_sync0, rx_sync1;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            tick_count   <= '0;
            sample_count <= 4'd0;
            bit_index    <= 3'd0;
            shift_reg    <= 8'd0;
            rx_data      <= 8'd0;
            rx_valid     <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (state)
                IDLE: begin
                    tick_count   <= '0;
                    sample_count <= 4'd0;
                    if (rx_sync1 == 1'b0) begin   // falling edge = start bit begins
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    // walk 16 sub-ticks into the start bit, then confirm rx is
                    // still low at its midpoint (rejects a glitch that isn't a real start bit)
                    if (tick_count == CLKS_PER_16TH - 1) begin
                        tick_count <= '0;
                        if (sample_count == 4'd7) begin
                            if (rx_sync1 == 1'b0) begin
                                sample_count <= 4'd0;
                                bit_index    <= 3'd0;
                                state        <= DATA_BITS;
                            end else begin
                                state <= IDLE;   // false start, back off
                            end
                        end else begin
                            sample_count <= sample_count + 4'd1;
                        end
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end

                DATA_BITS: begin
                    if (tick_count == CLKS_PER_16TH - 1) begin
                        tick_count <= '0;
                        if (sample_count == 4'd15) begin
                            sample_count       <= 4'd0;
                            shift_reg[bit_index] <= rx_sync1;   // LSB first, standard UART order
                            if (bit_index == 3'd7)
                                state <= STOP_BIT;
                            else
                                bit_index <= bit_index + 3'd1;
                        end else begin
                            sample_count <= sample_count + 4'd1;
                        end
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end

                STOP_BIT: begin
                    if (tick_count == CLKS_PER_16TH - 1) begin
                        tick_count <= '0;
                        if (sample_count == 4'd15) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                            state    <= IDLE;
                        end else begin
                            sample_count <= sample_count + 4'd1;
                        end
                    end else begin
                        tick_count <= tick_count + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
/* Maps to Python's load_iq deinterleaving (i = raw[0::2], q = raw[1::2]).
   uart_rx delivers one raw byte at a time with no notion of "which sample
   this belongs to" -- this module is the piece that turns a plain byte
   stream back into paired I/Q samples, alternating which byte it's holding
   for every rx_valid pulse.

   Passes bytes through unchanged (still raw unsigned, centered at 127.5,
   not yet centered at 0) -- magnitude_calculator already does that
   centering internally, so this module doesn't duplicate it. */

module iq_deinterleaver (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] rx_data,
    input  logic        rx_valid,

    output logic [7:0] i_sample,
    output logic [7:0] q_sample,
    output logic        iq_valid    // pulses once both bytes of a pair have arrived
);

    logic parity;   // 0 = next byte is I, 1 = next byte is Q
    logic [7:0] i_hold;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            parity   <= 1'b0;
            i_hold   <= 8'd0;
            i_sample <= 8'd0;
            q_sample <= 8'd0;
            iq_valid <= 1'b0;
        end else begin
            iq_valid <= 1'b0;

            if (rx_valid) begin
                if (parity == 1'b0) begin
                    i_hold <= rx_data;
                    parity <= 1'b1;
                end else begin
                    i_sample <= i_hold;
                    q_sample <= rx_data;
                    iq_valid <= 1'b1;
                    parity   <= 1'b0;
                end
            end
        end
    end

endmodule