/* 3rd 
Maps to the correlation portion of Python's find_preambles.
   Slides a 16-sample window of raw magnitude values and sums only the
   4 tap positions where the ADS-B preamble pattern is 1 (positions 0,2,7,9) --
   multiplying by 0/1 and summing is the same as just adding the 1-positions,
   so no multiplier is needed, same trick used for bit-serial CRC taps.

   THRESHOLD is a fixed constant (not adaptive mean+5*std like the Python
   version) because hardware processes a live, never-ending stream and can't
   wait to see "the whole file" before deciding a threshold. 350 was derived
   from this project's real capture: it catches all 9 known real preambles
   (min correlation 363) while rejecting the vast majority of noise.

   sample_valid: the window only advances on cycles where a real new
   magnitude sample has actually arrived. When fed straight from an RF ADC
   this would just be tied high (a new sample every cycle); when fed from
   something slower and bursty like a UART receiver, most cycles carry no
   new data at all, and shifting the window on those cycles would smear
   stale samples across it. */

module preamble_detector #(
    parameter int THRESHOLD = 350
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] magnitude,
    input  logic        sample_valid,
    output logic       preamble_found
);

    logic [7:0] win [0:15];   // win[0] = oldest sample in window, win[15] = newest

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int k = 0; k < 16; k++) win[k] <= 8'd0;
        end else if (sample_valid) begin
            for (int k = 0; k < 15; k++) win[k] <= win[k+1];
            win[15] <= magnitude;
        end
    end

    logic [10:0] tap_sum;   // 4 samples max ~255 each -> needs 11 bits
    assign tap_sum = win[0] + win[2] + win[7] + win[9];

    assign preamble_found = (tap_sum > THRESHOLD);

endmodule