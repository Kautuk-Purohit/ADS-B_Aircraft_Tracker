/* Testbenches for rf_transmitter.sv, matching the rf_receiver.sv /
   rx_chain_tb.sv pairing. Two independent top-level testbenches in this one
   file:

     uart_tx_tb          -- exercises uart_tx alone, looping its output
                             straight into a uart_rx and checking round trip
     message_tx_framer_tb -- exercises the full framer (which instantiates
                             uart_tx internally), checking all 14 frame
                             bytes against the expected wire encoding for a
                             real decoded message

   Icarus runs every module here that nothing else instantiates as its own
   root, so compiling this file with no top specified runs BOTH at once --
   and whichever one calls $finish first kills the whole simulation, cutting
   the other one off early (confirmed: uart_tx_tb finishes faster and was
   silently truncating message_tx_framer_tb's later checks). Select one top
   module at compile time instead, with -s:

       iverilog -g2012 -s uart_tx_tb -o tb.out rf_receiver.sv rf_transmitter.sv rf_transmitter_tb.sv
       iverilog -g2012 -s message_tx_framer_tb -o tb.out rf_receiver.sv rf_transmitter.sv rf_transmitter_tb.sv

   (rf_receiver.sv is needed too -- both testbenches here loop the
   transmitted byte(s) back into a real uart_rx to check them, and uart_rx
   lives in rf_receiver.sv.) */

module uart_tx_tb;

    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 3_000_000;

    logic clk = 0;
    logic reset;
    always #5 clk = ~clk;

    logic [7:0] data_in;
    logic send;
    logic tx_line, busy;
    uart_tx #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_tx (
        .clk(clk), .reset(reset),
        .data_in(data_in), .send(send), .tx(tx_line), .busy(busy)
    );

    logic [7:0] rx_data;
    logic rx_valid;
    uart_rx #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_rx (
        .clk(clk), .reset(reset), .rx(tx_line),
        .rx_data(rx_data), .rx_valid(rx_valid)
    );

    task automatic send_and_check(input logic [7:0] val);
        @(posedge clk);
        while (busy) @(posedge clk);   // wait until idle
        data_in = val;
        send    = 1'b1;
        @(posedge clk);
        #1;
        send = 1'b0;

        // wait for the loop-backed byte to arrive at uart_rx
        while (!rx_valid) @(posedge clk);
        #1;
        if (rx_data === val)
            $display("PASS: sent 0x%02h, received 0x%02h", val, rx_data);
        else
            $display("FAIL: sent 0x%02h, received 0x%02h", val, rx_data);
    endtask

    initial begin
        reset = 1; data_in = 0; send = 0;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        send_and_check(8'hAA);
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h4D);
        send_and_check(8'h93);

        $finish;
    end

endmodule


/* Feeds message_tx_framer the same real decoded fields every other
   testbench in this project checked (DF=17 CA=7 ICAO=4D2023 TC=19 ew=146
   ns=-357 speed=393), receives the transmitted frame through a real
   uart_rx, and checks every one of the 14 bytes against the expected wire
   encoding. */

module message_tx_framer_tb;

    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 3_000_000;

    logic clk = 0;
    logic reset;
    always #5 clk = ~clk;

    logic fields_valid;
    logic [4:0] df = 5'd17;
    logic [2:0] ca = 3'd7;
    logic [23:0] icao = 24'h4D2023;
    logic [4:0] tc = 5'd19;
    logic is_velocity = 1'b1;
    logic signed [10:0] ew_velocity = 11'sd146;
    logic signed [10:0] ns_velocity = -11'sd357;
    logic [10:0] ground_speed = 11'd393;

    logic tx_line;
    message_tx_framer #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .reset(reset),
        .fields_valid(fields_valid),
        .df(df), .ca(ca), .icao(icao), .tc(tc), .is_velocity(is_velocity),
        .ew_velocity(ew_velocity), .ns_velocity(ns_velocity), .ground_speed(ground_speed),
        .tx(tx_line)
    );

    logic [7:0] rx_data;
    logic rx_valid;
    uart_rx #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_rx (
        .clk(clk), .reset(reset), .rx(tx_line),
        .rx_data(rx_data), .rx_valid(rx_valid)
    );

    // 146 = 0x0092 -> sign-extended 16-bit: 0x0092
    // -357 = 0xFE9B (16-bit two's complement)
    // 393 = 0x0189
    logic [7:0] expected [0:13];
    initial begin
        expected[0]  = 8'hAA;
        expected[1]  = 8'd17;
        expected[2]  = 8'd7;
        expected[3]  = 8'h4D;
        expected[4]  = 8'h20;
        expected[5]  = 8'h23;
        expected[6]  = 8'd19;
        expected[7]  = 8'd1;
        expected[8]  = 8'h00;
        expected[9]  = 8'h92;
        expected[10] = 8'hFE;
        expected[11] = 8'h9B;
        expected[12] = 8'h01;
        expected[13] = 8'h89;
    end

    int idx = 0;
    int errors = 0;

    always @(posedge clk) begin
        if (rx_valid) begin
            if (rx_data === expected[idx])
                $display("PASS: byte %0d = 0x%02h", idx, rx_data);
            else begin
                $display("FAIL: byte %0d = 0x%02h, expected 0x%02h", idx, rx_data, expected[idx]);
                errors++;
            end
            idx++;
        end
    end

    initial begin
        reset = 1;
        fields_valid = 0;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        fields_valid = 1'b1;
        @(posedge clk);
        #1;
        fields_valid = 1'b0;

        // 14 bytes at 3Mbaud, plenty of cycles for margin
        repeat (6000) @(posedge clk);

        if (idx == 14 && errors == 0)
            $display("PASS: all 14 frame bytes matched the expected wire encoding");
        else
            $display("FAIL: received %0d/14 bytes, %0d errors", idx, errors);

        $finish;
    end

endmodule