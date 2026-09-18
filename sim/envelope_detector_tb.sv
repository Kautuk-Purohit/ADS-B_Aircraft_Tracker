/* Testbench for envelope_detector.sv */

module envelope_detector_tb #(
    //parameters
) (
    //I/O's
);
    logic [7:0] i_val;
    logic [7:0] q_val;
    logic [7:0] magnitude;
    logic [7:0] expected;

    envelope_detector #(
        //no parameters
    ) dut (
        .i_val(i_val),
        .q_val(q_val),
        .magnitude(magnitude)
    );

    initial begin
        //Case 1: both near-zero
        i_val = 8'd127;
        q_val = 8'd127;
        #10;

        expected = 8'd1; //this value is worked out by hand
        if (magnitude != expected)
            $display("Fail: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        else
            $display("Pass: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        

        //case 2: exact zero
        i_val = 8'd128;
        q_val = 8'd128;
        #10;

        expected = 8'd0;
        if (magnitude != expected)
            $display("Fail: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        else
            $display("Pass: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        

        //case 3: Maximum I, zero Q
        i_val = 8'd255;
        q_val = 8'd128;
        #10;

        expected = 8'd127;
        if (magnitude != expected)
            $display("Fail: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        else
            $display("Pass: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        

        //case 4: Min (or maximum negative) I, zero Q
        i_val = 8'd0;
        q_val = 8'd128;
        #10;

        expected = 8'd128;
        if (magnitude != expected)
            $display("Fail: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        else
            $display("Pass: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        

        //case 5: I larger, but both positive
        i_val = 8'd200;
        q_val = 8'd140;
        #10;

        expected = 8'd75;
        if (magnitude != expected)
            $display("Fail: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        else
            $display("Pass: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        

        //case 6: Both negative, but Q even more negative
        i_val = 8'd100;
        q_val = 8'd10;
        #10;

        expected = 8'd125;
        if (magnitude != expected)
            $display("Fail: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        else
            $display("Pass: i = %0d, q = %0d. Expected = %0d, Tested = %0d", i_val, q_val, expected, magnitude);
        
        $display("Test Complete");
        $finish;

    end



endmodule
