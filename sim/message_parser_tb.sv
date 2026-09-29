/* Feeds message_parser the same real, known-good 112-bit message (the exact
   msg_bits layout ppm_decoder would hand it) and checks every field against
   values independently computed from the Python golden model:
   DF=17, CA=7, ICAO=0x4D2023, TC=19, ew=146, ns=-357, ground_speed=393. */

module message_parser_tb;

    logic clk = 0;
    logic reset;
    logic [111:0] msg_bits;
    logic msg_done, crc_valid;

    logic fields_valid;
    logic [4:0] df;
    logic [2:0] ca;
    logic [23:0] icao;
    logic [4:0] tc;
    logic is_velocity;
    logic signed [10:0] ew_velocity, ns_velocity;
    logic [10:0] ground_speed;

    always #5 clk = ~clk;

    message_parser dut (
        .clk(clk), .reset(reset),
        .msg_bits(msg_bits), .msg_done(msg_done), .crc_valid(crc_valid),
        .fields_valid(fields_valid),
        .df(df), .ca(ca), .icao(icao), .tc(tc), .is_velocity(is_velocity),
        .ew_velocity(ew_velocity), .ns_velocity(ns_velocity), .ground_speed(ground_speed)
    );

    logic [111:0] good_bits = 112'b1000111101001101001000000010001110011001000100001001001110101100110010001000000000010100100101111110111101100110;

    initial begin
        reset = 1; msg_bits = 112'd0; msg_done = 0; crc_valid = 0;
        @(posedge clk); @(posedge clk);
        #1;
        reset = 0;

        msg_bits  = good_bits;
        crc_valid = 1;
        msg_done  = 1;
        @(posedge clk);
        #1;
        msg_done = 0;

        // fields_valid pulses two cycles after msg_done (one to safely cross
        // from another module's same-edge register, one more to compute) -- wait for it
        @(posedge clk);
        #1;
        @(posedge clk);
        #1;

        if (!fields_valid) $display("FAIL: fields_valid never asserted");
        else if (df !== 5'd17)              $display("FAIL: df=%0d expected 17", df);
        else if (ca !== 3'd7)               $display("FAIL: ca=%0d expected 7", ca);
        else if (icao !== 24'h4D2023)        $display("FAIL: icao=%h expected 4d2023", icao);
        else if (tc !== 5'd19)              $display("FAIL: tc=%0d expected 19", tc);
        else if (!is_velocity)              $display("FAIL: is_velocity should be 1");
        else if (ew_velocity !== 11'sd146)  $display("FAIL: ew=%0d expected 146", ew_velocity);
        else if (ns_velocity !== -11'sd357) $display("FAIL: ns=%0d expected -357", ns_velocity);
        else if (ground_speed !== 11'd393)  $display("FAIL: ground_speed=%0d expected 393", ground_speed);
        else $display("PASS: all fields match the Python golden model (DF=17 CA=7 ICAO=4D2023 TC=19 ew=146 ns=-357 speed=393)");

        $finish;
    end

endmodule