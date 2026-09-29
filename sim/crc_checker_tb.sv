/* Feeds crc_checker the same real, known-good 112-bit message decoded by
   ppm_decoder in ppm_pipeline_tb, bit-serially, and confirms crc_valid=1.
   Then reruns with one bit flipped and confirms crc_valid=0 -- proving the
   checker actually discriminates real corruption, not just echoing input. */

module crc_checker_tb;

    logic clk = 0;
    logic reset;
    logic bit_in, bit_valid, msg_start;
    logic crc_done, crc_valid;

    always #5 clk = ~clk;

    crc_checker dut (
        .clk(clk), .reset(reset),
        .bit_in(bit_in), .bit_valid(bit_valid), .msg_start(msg_start),
        .crc_done(crc_done), .crc_valid(crc_valid)
    );

    logic [111:0] good_bits = 112'b1000111101001101001000000010001110011001000100001001001110101100110010001000000000010100100101111110111101100110;

    task automatic run_message(input logic [111:0] msg, input string label, input logic expect_valid);
        reset = 1;
        bit_in = 0; bit_valid = 0; msg_start = 0;
        @(posedge clk); @(posedge clk);
        reset = 0;

        msg_start = 1;
        @(posedge clk);
        #1;                 // let this edge's reset settle before deasserting
        msg_start = 0;

        for (int i = 0; i < 112; i++) begin
            bit_in    = msg[111 - i];   // msg[111] is the first transmitted bit
            bit_valid = 1;
            @(posedge clk);
            #1;
            if (crc_done) begin
                if (crc_valid === expect_valid)
                    $display("PASS (%s): crc_valid=%b as expected", label, crc_valid);
                else
                    $display("FAIL (%s): crc_valid=%b, expected %b", label, crc_valid, expect_valid);
            end
        end
        bit_valid = 0;
    endtask

    initial begin
        run_message(good_bits, "real message, uncorrupted", 1'b1);

        // flip one data bit to prove the checker actually catches corruption
        run_message(good_bits ^ (112'b1 << 100), "same message, one bit flipped", 1'b0);

        $finish;
    end

endmodule