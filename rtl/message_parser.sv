/* 6th and final module in pipeline

Maps to Python's parse_message. Unlike ppm_decoder/crc_checker (serial,
   one bit per cycle), this is combinational field extraction: once msg_done
   pulses, all 112 bits already sit in one register, so every field is just
   a fixed slice of it -- no bit-serial logic needed here, only sign-magnitude
   arithmetic for the velocity fields.

   msg_bits is built MSB-first (msg_bits[111] = first transmitted bit), the
   opposite order of Python's bits[0] = first transmitted bit, so every
   Python slice bits[a:b] maps to msg_bits[111-a -: (b-a)] here.

   TC==19 (Airborne Velocity, subtype 1/2 ground speed) is the only message
   type decoded into real fields; every other TC is left as "unhandled" since
   this project only carries velocity messages through to the end -- same
   honest scope Python's parse_message keeps (heading/atan2 not implemented,
   this hardware version doesn't attempt it either). */

module message_parser (
    input  logic         clk,
    input  logic         reset,
    input  logic [111:0] msg_bits,
    input  logic         msg_done,
    input  logic         crc_valid,   // only trust fields when the CRC passed

    output logic         fields_valid,   // pulses one cycle after msg_done
    output logic [4:0]   df,
    output logic [2:0]   ca,
    output logic [23:0]  icao,
    output logic [4:0]   tc,
    output logic         is_velocity,    // tc == 19
    output logic signed [10:0] ew_velocity,  // signed knots, hardware-approx
    output logic signed [10:0] ns_velocity,
    output logic [10:0]  ground_speed    // alpha/beta approx of sqrt(ew^2+ns^2)
);

    /* msg_bits and crc_valid are both registered OUTPUTS OF OTHER MODULES,
       updated on the very same clock edge that msg_done/crc_done pulse. Same
       cross-module rule as before: a value another module's flip-flop
       produces this edge isn't readable until the NEXT cycle. So this can't
       latch on msg_done itself (that would grab the stale, one-message-old
       msg_bits/crc_valid) -- it has to wait one extra cycle first. */
    logic msg_done_d;
    logic [111:0] latched_bits;
    logic         latched_crc_valid;
    logic         do_parse;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            msg_done_d        <= 1'b0;
            latched_bits      <= 112'd0;
            latched_crc_valid <= 1'b0;
            do_parse          <= 1'b0;
        end else begin
            msg_done_d <= msg_done;
            do_parse   <= msg_done_d;
            if (msg_done_d) begin
                latched_bits      <= msg_bits;
                latched_crc_valid <= crc_valid;
            end
        end
    end

    // direct field slices (Python bits[a:b] -> msg_bits[111-a -: b-a])
    wire [4:0]  w_df   = latched_bits[111 -: 5];    // bits[0:5]
    wire [2:0]  w_ca   = latched_bits[106 -: 3];    // bits[5:8]
    wire [23:0] w_icao = latched_bits[103 -: 24];   // bits[8:32]
    wire [4:0]  w_tc   = latched_bits[79 -: 5];     // bits[32:37]

    // TC=19 velocity subfields (only meaningful when w_tc == 19)
    wire        w_dew    = latched_bits[66];        // bits[45]
    wire [9:0]  w_ew_raw = latched_bits[65 -: 10];   // bits[46:56]
    wire        w_dns    = latched_bits[55];         // bits[56]
    wire [9:0]  w_ns_raw = latched_bits[54 -: 10];   // bits[57:67]

    // ADS-B convention: raw field value 0 = no data, 1 = velocity of 0,
    // so the real magnitude is (raw - 1); direction bit picks the sign.
    wire signed [10:0] w_ew_mag = $signed({1'b0, w_ew_raw}) - 11'sd1;
    wire signed [10:0] w_ns_mag = $signed({1'b0, w_ns_raw}) - 11'sd1;
    wire signed [10:0] w_ew     = w_dew ? -w_ew_mag : w_ew_mag;
    wire signed [10:0] w_ns     = w_dns ? -w_ns_mag : w_ns_mag;

    // same alpha=1, beta=0.25 hardware approximation used in magnitude_calculator,
    // reused here for sqrt(ew^2+ns^2) instead of sqrt(i^2+q^2) -- same reason:
    // no multiplier/sqrt needed, just abs + compare + shift.
    wire [10:0] w_ew_abs = w_ew[10] ? -w_ew : w_ew;
    wire [10:0] w_ns_abs = w_ns[10] ? -w_ns : w_ns;
    wire [10:0] w_max    = (w_ew_abs > w_ns_abs) ? w_ew_abs : w_ns_abs;
    wire [10:0] w_min    = (w_ew_abs > w_ns_abs) ? w_ns_abs : w_ew_abs;
    wire [10:0] w_speed  = w_max + (w_min >> 2);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            fields_valid <= 1'b0;
            df <= 5'd0; ca <= 3'd0; icao <= 24'd0; tc <= 5'd0;
            is_velocity <= 1'b0;
            ew_velocity <= 11'sd0; ns_velocity <= 11'sd0; ground_speed <= 11'd0;
        end else begin
            fields_valid <= do_parse && latched_crc_valid;
            if (do_parse) begin
                df  <= w_df;
                ca  <= w_ca;
                icao <= w_icao;
                tc  <= w_tc;
                is_velocity <= (w_tc == 5'd19);
                if (w_tc == 5'd19) begin
                    ew_velocity  <= w_ew;
                    ns_velocity  <= w_ns;
                    ground_speed <= w_speed;
                end
            end
        end
    end

endmodule