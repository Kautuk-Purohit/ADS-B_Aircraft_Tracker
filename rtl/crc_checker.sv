/* 5th module in pipeline
Maps to Python's check_crc. Mode S CRC-24 is polynomial division: the
   112-bit message (88 data bits + 24-bit CRC field) is divisible by the
   generator polynomial exactly when the message is uncorrupted. Python does
   this on the whole array at once; hardware does it one bit at a time as
   ppm_decoder produces bit_out/bit_valid, using the standard bit-serial
   LFSR-with-feedback-XOR technique -- same idea as preamble_detector's
   selective-tap-sum, just applied to a shift-and-XOR divider instead.

   Generator: x^24+x^23+...+x^12+x^10+x^3+x+1 (0x1FFF409, 25 bits with the
   implicit leading 1). Only the low 24 bits are used here since the top bit
   of the register is what triggers the conditional XOR each cycle. */

module crc_checker (
    input  logic clk,
    input  logic reset,
    input  logic bit_in,        // = ppm_decoder.bit_out
    input  logic bit_valid,     // = ppm_decoder.bit_valid, one pulse per bit
    input  logic msg_start,     // resets the divider for a new message

    output logic crc_done,      // pulses the cycle the 112th bit is consumed
    output logic crc_valid      // valid alongside crc_done: 1 = CRC passed
);

    localparam logic [23:0] POLY = 24'hFFF409;

    logic [23:0] crc_reg;
    logic [6:0]  bit_count;   // 0..111

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            crc_reg   <= 24'd0;
            bit_count <= 7'd0;
            crc_done  <= 1'b0;
            crc_valid <= 1'b0;
        end else begin
            crc_done <= 1'b0;

            if (msg_start) begin
                crc_reg   <= 24'd0;
                bit_count <= 7'd0;
            end else if (bit_valid) begin
                logic feedback;
                feedback = crc_reg[23] ^ bit_in;
                crc_reg  <= {crc_reg[22:0], 1'b0} ^ (feedback ? POLY : 24'd0);

                if (bit_count == 7'd111) begin
                    crc_done  <= 1'b1;
                    // feedback/POLY above already folds in this last bit, so
                    // the pass/fail check is against the register's NEXT value
                    crc_valid <= ({crc_reg[22:0], 1'b0} ^ (feedback ? POLY : 24'd0)) == 24'd0;
                    bit_count <= 7'd0;
                end else begin
                    bit_count <= bit_count + 7'd1;
                end
            end
        end
    end

endmodule