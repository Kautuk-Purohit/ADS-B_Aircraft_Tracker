/* 4th
Maps to Python's demod_ppm. Unlike the Python version (which has the whole
   112-bit window as one array slice), hardware receives one magnitude sample
   per clock cycle and must compare pairs of consecutive samples (first half
   vs second half of each 1us bit period) as they arrive.

   Ignores preamble_found while already decoding a message (IDLE/DECODE FSM),
   which is the hardware answer to the "clustered duplicate preamble" issue
   from the Python model -- a real message in progress can't be interrupted
   by an echo of its own preamble a few samples later.

   Exposes both a serial interface (bit_out/bit_valid, one pulse per decoded
   bit -- feeds crc_checker) and a parallel interface (msg_bits/msg_done --
   feeds message_parser once the full message is assembled).

   sample_valid: same reasoning as preamble_detector -- this FSM only reads
   magnitude/preamble_found and advances on a cycle where a real new sample
   arrived. Without this, a slow/bursty source (UART) would cause it to
   re-check preamble_found and re-count samples on empty cycles, corrupting
   both the preamble handoff and the bit timing. */

module ppm_decoder (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] magnitude,
    input  logic       preamble_found,
    input  logic        sample_valid,

    output logic       bit_out,
    output logic       bit_valid,
    output logic       msg_start,     // pulses the cycle decoding begins (crc_checker/message_parser reset cue)
    output logic       msg_done,      // pulses when the 112th bit completes
    output logic [111:0] msg_bits,
    output logic       busy
);

    typedef enum logic {IDLE, DECODE} state_t;
    state_t state;

    logic [7:0] prev_sample;
    logic [7:0] sample_count;   // 0..223
    logic [6:0] bit_count;      // 0..111

    assign busy = (state == DECODE);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            sample_count <= 8'd0;
            bit_count    <= 7'd0;
            prev_sample  <= 8'd0;
            msg_bits     <= 112'd0;
            bit_out      <= 1'b0;
            bit_valid    <= 1'b0;
            msg_start    <= 1'b0;
            msg_done     <= 1'b0;
        end else begin
            // default: pulses are low unless this cycle explicitly sets them
            bit_valid <= 1'b0;
            msg_start <= 1'b0;
            msg_done  <= 1'b0;

            if (sample_valid) begin
            case (state)
                IDLE: begin
                    if (preamble_found) begin
                        // The cycle preamble_found becomes visible here is the SAME cycle
                        // carrying the first real data sample (one module's registered/combinational
                        // output feeding another module's clocked input always costs exactly one
                        // cycle of latency) -- so this cycle's magnitude must be consumed as sample
                        // 0 right now, not dropped while waiting for "the next" cycle.
                        state        <= DECODE;
                        prev_sample  <= magnitude;
                        sample_count <= 8'd1;
                        bit_count    <= 7'd0;
                        msg_start    <= 1'b1;
                    end
                end

                DECODE: begin
                    if (sample_count[0] == 1'b0) begin
                        // first half of this bit's window -- just remember it
                        prev_sample  <= magnitude;
                        sample_count <= sample_count + 8'd1;
                    end else begin
                        // second half -- compare and produce a bit
                        logic decided_bit;
                        decided_bit = (prev_sample > magnitude) ? 1'b1 : 1'b0;

                        bit_out         <= decided_bit;
                        bit_valid       <= 1'b1;
                        msg_bits        <= {msg_bits[110:0], decided_bit};
                        sample_count    <= sample_count + 8'd1;

                        if (bit_count == 7'd111) begin
                            msg_done <= 1'b1;
                            state    <= IDLE;
                        end else begin
                            bit_count <= bit_count + 7'd1;
                        end
                    end
                end
            endcase
            end
        end
    end

endmodule