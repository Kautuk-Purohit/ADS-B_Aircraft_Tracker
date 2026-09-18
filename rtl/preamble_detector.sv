/* Third module in pipeline. 
Referring to the golden model in python, this module is the "find_preambles" function */

module preamble_detector #(
    parameter int pattern [0:15] = '{1, 0, 1, 0, 0 , 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0};
) (
    input logic clk,
    input logic valid,
    input logic magnitude,

    output logic working_indicies
);

    
endmodule

