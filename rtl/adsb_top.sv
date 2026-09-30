/* Full synthesizable top level: raw serial bytes in (from the PC, over
   UART, via pc_sender.py) all the way to parsed aircraft fields sent back
   out (over UART, via message_tx_framer, read on the PC by pc_receiver.py).
   Same decode wiring proven in full_pipeline_gapped_tb.sv, with uart_rx +
   iq_deinterleaver + magnitude_calculator prepended as the real first
   stages, and message_tx_framer appended as the real last stage, instead
   of a testbench array and a $display.

   magnitude_calculator is pure combinational logic (no clock), so its
   output is already settled by the time iq_deinterleaver's iq_valid pulse
   reaches preamble_detector/ppm_decoder on that same cycle -- iq_valid is
   used directly as sample_valid, no extra staging needed.

   The parsed-field output ports (fields_valid, df, ca, ...) are kept as
   real top-level ports alongside tx, not just internal wires to the
   framer -- useful for wiring an LED or 7-segment display straight to them
   later without having to touch this file again. */

module adsb_top #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 3_000_000
)(
    input  logic clk,
    input  logic reset,
    input  logic rx,          // serial line from the PC (raw I/Q in)
    output logic tx,          // serial line to the PC (decoded fields out)

    output logic         fields_valid,
    output logic [4:0]   df,
    output logic [2:0]   ca,
    output logic [23:0]  icao,
    output logic [4:0]   tc,
    output logic          is_velocity,
    output logic signed [10:0] ew_velocity,
    output logic signed [10:0] ns_velocity,
    output logic [10:0]   ground_speed,
    output logic          crc_valid_out
);

    logic [7:0] rx_data;
    logic       rx_valid;
    uart_rx #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_uart (
        .clk(clk), .reset(reset), .rx(rx),
        .rx_data(rx_data), .rx_valid(rx_valid)
    );

    logic [7:0] i_sample, q_sample;
    logic       iq_valid;
    iq_deinterleaver u_deint (
        .clk(clk), .reset(reset),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .i_sample(i_sample), .q_sample(q_sample), .iq_valid(iq_valid)
    );

    logic [7:0] magnitude;
    magnitude_calculator u_mag (
        .i_val(i_sample), .q_val(q_sample),
        .magnitude(magnitude)
    );

    logic preamble_found;
    preamble_detector u_pre (
        .clk(clk), .reset(reset),
        .magnitude(magnitude),
        .sample_valid(iq_valid),
        .preamble_found(preamble_found)
    );

    logic bit_out, bit_valid, msg_start, msg_done, busy;
    logic [111:0] msg_bits;
    ppm_decoder u_ppm (
        .clk(clk), .reset(reset),
        .magnitude(magnitude), .preamble_found(preamble_found),
        .sample_valid(iq_valid),
        .bit_out(bit_out), .bit_valid(bit_valid),
        .msg_start(msg_start), .msg_done(msg_done),
        .msg_bits(msg_bits), .busy(busy)
    );

    logic crc_done, crc_valid;
    crc_checker u_crc (
        .clk(clk), .reset(reset),
        .bit_in(bit_out), .bit_valid(bit_valid), .msg_start(msg_start),
        .crc_done(crc_done), .crc_valid(crc_valid)
    );
    assign crc_valid_out = crc_valid;

    message_parser u_parse (
        .clk(clk), .reset(reset),
        .msg_bits(msg_bits), .msg_done(msg_done), .crc_valid(crc_valid),
        .fields_valid(fields_valid),
        .df(df), .ca(ca), .icao(icao), .tc(tc), .is_velocity(is_velocity),
        .ew_velocity(ew_velocity), .ns_velocity(ns_velocity), .ground_speed(ground_speed)
    );

    message_tx_framer #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_framer (
        .clk(clk), .reset(reset),
        .fields_valid(fields_valid),
        .df(df), .ca(ca), .icao(icao), .tc(tc), .is_velocity(is_velocity),
        .ew_velocity(ew_velocity), .ns_velocity(ns_velocity), .ground_speed(ground_speed),
        .tx(tx)
    );

endmodule