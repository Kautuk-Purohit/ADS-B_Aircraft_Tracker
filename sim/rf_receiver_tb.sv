/* uart_rx -> iq_deinterleaver wired together, fed 20 real interleaved bytes
   from modes1.bin (around the known preamble), serialized bit-by-bit as if
   they arrived over an actual UART line. Confirms the receive chain
   reproduces exactly what Python's load_iq deinterleaving would produce on
   the same raw bytes -- proving nothing gets corrupted before it even
   reaches magnitude_calculator. */

module rx_chain_tb;

    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 3_000_000;
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    logic clk = 0;
    logic reset;
    logic rx = 1'b1;

    always #5 clk = ~clk;

    logic [7:0] rx_data;
    logic rx_valid;
    uart_rx #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_uart (
        .clk(clk), .reset(reset), .rx(rx),
        .rx_data(rx_data), .rx_valid(rx_valid)
    );

    logic [7:0] i_sample, q_sample;
    logic iq_valid;
    iq_deinterleaver u_deint (
        .clk(clk), .reset(reset),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .i_sample(i_sample), .q_sample(q_sample), .iq_valid(iq_valid)
    );

    task automatic send_byte(input logic [7:0] data);
        rx = 1'b0;
        repeat (CLKS_PER_BIT) @(posedge clk);
        for (int i = 0; i < 8; i++) begin
            rx = data[i];
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
        rx = 1'b1;
        repeat (CLKS_PER_BIT) @(posedge clk);
    endtask

    // 20 real interleaved bytes from modes1.bin at the known preamble location
    logic [7:0] raw_bytes [0:19];
    logic [7:0] expected_i [0:9];
    logic [7:0] expected_q [0:9];

    int pair_idx = 0;
    int errors = 0;

    initial begin
        raw_bytes[0]=90;  raw_bytes[1]=213; raw_bytes[2]=124; raw_bytes[3]=151;
        raw_bytes[4]=131; raw_bytes[5]=226; raw_bytes[6]=129; raw_bytes[7]=138;
        raw_bytes[8]=129; raw_bytes[9]=129; raw_bytes[10]=123; raw_bytes[11]=129;
        raw_bytes[12]=143; raw_bytes[13]=137; raw_bytes[14]=210; raw_bytes[15]=175;
        raw_bytes[16]=154; raw_bytes[17]=132; raw_bytes[18]=225; raw_bytes[19]=136;

        expected_i[0]=90;  expected_i[1]=124; expected_i[2]=131; expected_i[3]=129;
        expected_i[4]=129; expected_i[5]=123; expected_i[6]=143; expected_i[7]=210;
        expected_i[8]=154; expected_i[9]=225;

        expected_q[0]=213; expected_q[1]=151; expected_q[2]=226; expected_q[3]=138;
        expected_q[4]=129; expected_q[5]=129; expected_q[6]=137; expected_q[7]=175;
        expected_q[8]=132; expected_q[9]=136;
    end

    always @(posedge clk) begin
        if (iq_valid) begin
            if (i_sample === expected_i[pair_idx] && q_sample === expected_q[pair_idx])
                $display("PASS: pair %0d -> i=%0d q=%0d", pair_idx, i_sample, q_sample);
            else begin
                $display("FAIL: pair %0d -> got i=%0d q=%0d, expected i=%0d q=%0d",
                          pair_idx, i_sample, q_sample, expected_i[pair_idx], expected_q[pair_idx]);
                errors++;
            end
            pair_idx++;
        end
    end

    initial begin
        reset = 1;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        for (int b = 0; b < 20; b++) send_byte(raw_bytes[b]);

        repeat (CLKS_PER_BIT) @(posedge clk);

        if (pair_idx == 10 && errors == 0)
            $display("PASS: full receive chain (uart_rx -> iq_deinterleaver) reproduced all 10 real I/Q pairs correctly");
        else
            $display("FAIL: only matched %0d/10 pairs, %0d errors", pair_idx, errors);

        $finish;
    end

endmodule