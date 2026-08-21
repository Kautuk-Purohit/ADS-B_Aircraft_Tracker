module threshold_binarizer_tb #(
    parameter threshold_check = 50
);

    logic [8:0] magnitude;
    logic valid;

    threshold_binarizer #(
        .threshold(50)
    ) dut (
        .magnitude(magnitude),
        .valid(valid)
    );

    initial begin
        magnitude = 100;
        #10;

        if (magnitude <= threshold_check && valid == 0)
            $display("Pass lower");
        else if (magnitude <= threshold_check && valid == 1)
            $display("Fail lower");
        else if (magnitude > threshold_check && valid == 0)
            $display("Fail upper");
        else if (magnitude > threshold_check && valid == 1)
            $display("Pass upper");

        magnitude = 50;
        #10;

        if (magnitude <= threshold_check && valid == 0)
            $display("Pass lower");
        else if (magnitude <= threshold_check && valid == 1)
            $display("Fail lower");
        else if (magnitude > threshold_check && valid == 0)
            $display("Fail upper");
        else if (magnitude > threshold_check && valid == 1)
            $display("Pass upper");

        magnitude = 20;
        #10;

        if (magnitude <= threshold_check && valid == 0)
            $display("Pass lower");
        else if (magnitude <= threshold_check && valid == 1)
            $display("Fail lower");
        else if (magnitude > threshold_check && valid == 0)
            $display("Fail upper");
        else if (magnitude > threshold_check && valid == 1)
            $display("Pass upper");

        $display("Test complete");
        $finish;
            
    end

endmodule