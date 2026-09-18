/* Second module in pipeline.
This code takes an input magnitude signal, compares it against a threshold, and then outputs a single bit.
If the signal is loud enough, then output 1, otherwise if it's too quiet then output a 0 */

module threshold_checker #(
    parameter int threshold
)(
    input logic [7:0] magnitude,
    output logic valid
);
    always_comb begin
        if (magnitude > threshold) begin
            valid = 1;
        end else begin
            valid = 0;
        end
    end   


endmodule