/* First module in order of pipeline.
This is a combination of the load_iq and mag functions in the python model.
 */

module magnitude_calculator #(
    //parameters
) (
    input logic [7:0] i_val,
    input logic [7:0] q_val,

    output logic [7:0] magnitude
);

    logic signed [7:0] i_centered;
    assign i_centered = {~i_val[7], i_val[6:0]};

    logic signed [7:0] q_centered;
    assign q_centered = {~q_val[7], q_val[6:0]};

    //apply alpha-max plus beta-min algorithm to find magnitude
    logic [7:0] max;
    logic [7:0] min;

    logic [7:0] i_abs;
    logic [7:0] q_abs;

    assign i_abs = (i_centered[7] == 1) ? -1 * i_centered : i_centered;
    assign q_abs = (q_centered[7] == 1) ? -1 * q_centered : q_centered;

    always_comb begin
        if (i_abs <= q_abs) begin
            max = q_abs;
            min = i_abs;
        end else begin
            max = i_abs;
            min = q_abs;
        end
    end

    //For hardware optimized values, alpha = 1.0, beta = 0.25
    assign magnitude = max + (min >> 2);
    

endmodule

