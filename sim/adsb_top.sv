/* True top-level test: raw serial bytes go in over rx exactly as they would
   from the PC, and parsed aircraft fields come out the other end -- nothing
   short-circuited, no internal signal poked directly. Uses the same 250
   magnitude values every other testbench in this project already validated
   against the Python golden model and real CRC-passing data, re-encoded as
   (i_val, q_val) = (sample+128, 128) so magnitude_calculator's exact
   hardware formula (top-bit-invert centering, alpha/beta) recovers that
   same sample back out -- this proves the wiring end to end using the
   project's already-proven real data, without needing to re-locate the
   original file's raw byte offset for this specific test. */

module adsb_top_tb;

    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 3_000_000;
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    logic clk = 0;
    logic reset;
    logic rx = 1'b1;

    always #5 clk = ~clk;

    logic fields_valid;
    logic [4:0] df; logic [2:0] ca; logic [23:0] icao; logic [4:0] tc;
    logic is_velocity;
    logic signed [10:0] ew_velocity, ns_velocity;
    logic [10:0] ground_speed;
    logic crc_valid_out;
    logic tx_line;

    adsb_top #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .reset(reset), .rx(rx), .tx(tx_line),
        .fields_valid(fields_valid),
        .df(df), .ca(ca), .icao(icao), .tc(tc), .is_velocity(is_velocity),
        .ew_velocity(ew_velocity), .ns_velocity(ns_velocity), .ground_speed(ground_speed),
        .crc_valid_out(crc_valid_out)
    );

    // receive the frame adsb_top's own message_tx_framer sends out on tx,
    // exactly as pc_receiver.py would on the real PC side
    logic [7:0] frame_rx_data;
    logic frame_rx_valid;
    uart_rx #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_frame_rx (
        .clk(clk), .reset(reset), .rx(tx_line),
        .rx_data(frame_rx_data), .rx_valid(frame_rx_valid)
    );

    logic [7:0] expected_frame [0:13];
    initial begin
        expected_frame[0]  = 8'hAA;
        expected_frame[1]  = 8'd17;
        expected_frame[2]  = 8'd7;
        expected_frame[3]  = 8'h4D;
        expected_frame[4]  = 8'h20;
        expected_frame[5]  = 8'h23;
        expected_frame[6]  = 8'd19;
        expected_frame[7]  = 8'd1;
        expected_frame[8]  = 8'h00;
        expected_frame[9]  = 8'h92;
        expected_frame[10] = 8'hFE;
        expected_frame[11] = 8'h9B;
        expected_frame[12] = 8'h01;
        expected_frame[13] = 8'h89;
    end

    int frame_idx = 0;
    int frame_errors = 0;
    always @(posedge clk) begin
        if (frame_rx_valid) begin
            if (frame_rx_data !== expected_frame[frame_idx]) frame_errors++;
            frame_idx++;
        end
    end

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

    always @(posedge clk) begin
        if (fields_valid) begin
            $display("fields_valid: DF=%0d CA=%0d ICAO=%h TC=%0d ew=%0d ns=%0d speed=%0d crc_valid=%b",
                      df, ca, icao, tc, ew_velocity, ns_velocity, ground_speed, crc_valid_out);
            if (df==17 && ca==7 && icao==24'h4D2023 && tc==19 &&
                ew_velocity==146 && ns_velocity==-357 && ground_speed==393)
                $display("PASS: full system (serial bytes in -> parsed aircraft fields out) matches golden model");
            else
                $display("FAIL: fields don't match expected golden-model values");
        end
    end

    logic [7:0] raw_bytes [0:499];
    initial begin
raw_bytes[0]=129; raw_bytes[1]=128; raw_bytes[2]=129; raw_bytes[3]=128; raw_bytes[4]=130; raw_bytes[5]=128; raw_bytes[6]=130; raw_bytes[7]=128; raw_bytes[8]=129; raw_bytes[9]=128; raw_bytes[10]=221; raw_bytes[11]=128; raw_bytes[12]=152; raw_bytes[13]=128; raw_bytes[14]=227; raw_bytes[15]=128; raw_bytes[16]=139; raw_bytes[17]=128; raw_bytes[18]=130; raw_bytes[19]=128; raw_bytes[20]=133; raw_bytes[21]=128; raw_bytes[22]=146; raw_bytes[23]=128; raw_bytes[24]=223; raw_bytes[25]=128; raw_bytes[26]=155; raw_bytes[27]=128; raw_bytes[28]=226; raw_bytes[29]=128; raw_bytes[30]=137; raw_bytes[31]=128; raw_bytes[32]=130; raw_bytes[33]=128; raw_bytes[34]=133; raw_bytes[35]=128; raw_bytes[36]=130; raw_bytes[37]=128; raw_bytes[38]=136; raw_bytes[39]=128; raw_bytes[40]=144; raw_bytes[41]=128; raw_bytes[42]=232; raw_bytes[43]=128; raw_bytes[44]=133; raw_bytes[45]=128; raw_bytes[46]=146; raw_bytes[47]=128; raw_bytes[48]=230; raw_bytes[49]=128; raw_bytes[50]=155; raw_bytes[51]=128; raw_bytes[52]=226; raw_bytes[53]=128; raw_bytes[54]=150; raw_bytes[55]=128; raw_bytes[56]=251; raw_bytes[57]=128; raw_bytes[58]=242; raw_bytes[59]=128; raw_bytes[60]=155; raw_bytes[61]=128; raw_bytes[62]=227; raw_bytes[63]=128; raw_bytes[64]=160; raw_bytes[65]=128; raw_bytes[66]=221; raw_bytes[67]=128; raw_bytes[68]=154; raw_bytes[69]=128; raw_bytes[70]=229; raw_bytes[71]=128; raw_bytes[72]=135; raw_bytes[73]=128; raw_bytes[74]=138; raw_bytes[75]=128; raw_bytes[76]=254; raw_bytes[77]=128; raw_bytes[78]=245; raw_bytes[79]=128; raw_bytes[80]=129; raw_bytes[81]=128; raw_bytes[82]=147; raw_bytes[83]=128; raw_bytes[84]=231; raw_bytes[85]=128; raw_bytes[86]=146; raw_bytes[87]=128; raw_bytes[88]=252; raw_bytes[89]=128; raw_bytes[90]=241; raw_bytes[91]=128; raw_bytes[92]=150; raw_bytes[93]=128; raw_bytes[94]=232; raw_bytes[95]=128; raw_bytes[96]=138; raw_bytes[97]=128; raw_bytes[98]=136; raw_bytes[99]=128; raw_bytes[100]=253; raw_bytes[101]=128; raw_bytes[102]=247; raw_bytes[103]=128; raw_bytes[104]=129; raw_bytes[105]=128; raw_bytes[106]=147; raw_bytes[107]=128; raw_bytes[108]=233; raw_bytes[109]=128; raw_bytes[110]=146; raw_bytes[111]=128; raw_bytes[112]=249; raw_bytes[113]=128; raw_bytes[114]=250; raw_bytes[115]=128; raw_bytes[116]=130; raw_bytes[117]=128; raw_bytes[118]=148; raw_bytes[119]=128; raw_bytes[120]=228; raw_bytes[121]=128; raw_bytes[122]=155; raw_bytes[123]=128; raw_bytes[124]=220; raw_bytes[125]=128; raw_bytes[126]=158; raw_bytes[127]=128; raw_bytes[128]=223; raw_bytes[129]=128; raw_bytes[130]=159; raw_bytes[131]=128; raw_bytes[132]=222; raw_bytes[133]=128; raw_bytes[134]=159; raw_bytes[135]=128; raw_bytes[136]=221; raw_bytes[137]=128; raw_bytes[138]=157; raw_bytes[139]=128; raw_bytes[140]=224; raw_bytes[141]=128; raw_bytes[142]=149; raw_bytes[143]=128; raw_bytes[144]=247; raw_bytes[145]=128; raw_bytes[146]=248; raw_bytes[147]=128; raw_bytes[148]=129; raw_bytes[149]=128; raw_bytes[150]=147; raw_bytes[151]=128; raw_bytes[152]=227; raw_bytes[153]=128; raw_bytes[154]=154; raw_bytes[155]=128; raw_bytes[156]=224; raw_bytes[157]=128; raw_bytes[158]=150; raw_bytes[159]=128; raw_bytes[160]=252; raw_bytes[161]=128; raw_bytes[162]=240; raw_bytes[163]=128; raw_bytes[164]=154; raw_bytes[165]=128; raw_bytes[166]=224; raw_bytes[167]=128; raw_bytes[168]=157; raw_bytes[169]=128; raw_bytes[170]=230; raw_bytes[171]=128; raw_bytes[172]=135; raw_bytes[173]=128; raw_bytes[174]=143; raw_bytes[175]=128; raw_bytes[176]=231; raw_bytes[177]=128; raw_bytes[178]=147; raw_bytes[179]=128; raw_bytes[180]=251; raw_bytes[181]=128; raw_bytes[182]=243; raw_bytes[183]=128; raw_bytes[184]=151; raw_bytes[185]=128; raw_bytes[186]=232; raw_bytes[187]=128; raw_bytes[188]=137; raw_bytes[189]=128; raw_bytes[190]=143; raw_bytes[191]=128; raw_bytes[192]=229; raw_bytes[193]=128; raw_bytes[194]=147; raw_bytes[195]=128; raw_bytes[196]=247; raw_bytes[197]=128; raw_bytes[198]=250; raw_bytes[199]=128; raw_bytes[200]=130; raw_bytes[201]=128; raw_bytes[202]=146; raw_bytes[203]=128; raw_bytes[204]=227; raw_bytes[205]=128; raw_bytes[206]=154; raw_bytes[207]=128; raw_bytes[208]=224; raw_bytes[209]=128; raw_bytes[210]=148; raw_bytes[211]=128; raw_bytes[212]=250; raw_bytes[213]=128; raw_bytes[214]=250; raw_bytes[215]=128; raw_bytes[216]=130; raw_bytes[217]=128; raw_bytes[218]=147; raw_bytes[219]=128; raw_bytes[220]=225; raw_bytes[221]=128; raw_bytes[222]=154; raw_bytes[223]=128; raw_bytes[224]=220; raw_bytes[225]=128; raw_bytes[226]=159; raw_bytes[227]=128; raw_bytes[228]=227; raw_bytes[229]=128; raw_bytes[230]=150; raw_bytes[231]=128; raw_bytes[232]=247; raw_bytes[233]=128; raw_bytes[234]=248; raw_bytes[235]=128; raw_bytes[236]=131; raw_bytes[237]=128; raw_bytes[238]=146; raw_bytes[239]=128; raw_bytes[240]=229; raw_bytes[241]=128; raw_bytes[242]=146; raw_bytes[243]=128; raw_bytes[244]=247; raw_bytes[245]=128; raw_bytes[246]=252; raw_bytes[247]=128; raw_bytes[248]=131; raw_bytes[249]=128; raw_bytes[250]=145; raw_bytes[251]=128; raw_bytes[252]=231; raw_bytes[253]=128; raw_bytes[254]=147; raw_bytes[255]=128; raw_bytes[256]=249; raw_bytes[257]=128; raw_bytes[258]=243; raw_bytes[259]=128; raw_bytes[260]=151; raw_bytes[261]=128; raw_bytes[262]=223; raw_bytes[263]=128; raw_bytes[264]=155; raw_bytes[265]=128; raw_bytes[266]=226; raw_bytes[267]=128; raw_bytes[268]=138; raw_bytes[269]=128; raw_bytes[270]=135; raw_bytes[271]=128; raw_bytes[272]=252; raw_bytes[273]=128; raw_bytes[274]=247; raw_bytes[275]=128; raw_bytes[276]=134; raw_bytes[277]=128; raw_bytes[278]=140; raw_bytes[279]=128; raw_bytes[280]=255; raw_bytes[281]=128; raw_bytes[282]=238; raw_bytes[283]=128; raw_bytes[284]=148; raw_bytes[285]=128; raw_bytes[286]=232; raw_bytes[287]=128; raw_bytes[288]=136; raw_bytes[289]=128; raw_bytes[290]=141; raw_bytes[291]=128; raw_bytes[292]=230; raw_bytes[293]=128; raw_bytes[294]=146; raw_bytes[295]=128; raw_bytes[296]=249; raw_bytes[297]=128; raw_bytes[298]=241; raw_bytes[299]=128; raw_bytes[300]=150; raw_bytes[301]=128; raw_bytes[302]=232; raw_bytes[303]=128; raw_bytes[304]=137; raw_bytes[305]=128; raw_bytes[306]=143; raw_bytes[307]=128; raw_bytes[308]=231; raw_bytes[309]=128; raw_bytes[310]=147; raw_bytes[311]=128; raw_bytes[312]=245; raw_bytes[313]=128; raw_bytes[314]=251; raw_bytes[315]=128; raw_bytes[316]=130; raw_bytes[317]=128; raw_bytes[318]=145; raw_bytes[319]=128; raw_bytes[320]=226; raw_bytes[321]=128; raw_bytes[322]=155; raw_bytes[323]=128; raw_bytes[324]=224; raw_bytes[325]=128; raw_bytes[326]=150; raw_bytes[327]=128; raw_bytes[328]=247; raw_bytes[329]=128; raw_bytes[330]=248; raw_bytes[331]=128; raw_bytes[332]=131; raw_bytes[333]=128; raw_bytes[334]=147; raw_bytes[335]=128; raw_bytes[336]=227; raw_bytes[337]=128; raw_bytes[338]=153; raw_bytes[339]=128; raw_bytes[340]=220; raw_bytes[341]=128; raw_bytes[342]=159; raw_bytes[343]=128; raw_bytes[344]=221; raw_bytes[345]=128; raw_bytes[346]=157; raw_bytes[347]=128; raw_bytes[348]=222; raw_bytes[349]=128; raw_bytes[350]=157; raw_bytes[351]=128; raw_bytes[352]=222; raw_bytes[353]=128; raw_bytes[354]=157; raw_bytes[355]=128; raw_bytes[356]=219; raw_bytes[357]=128; raw_bytes[358]=158; raw_bytes[359]=128; raw_bytes[360]=222; raw_bytes[361]=128; raw_bytes[362]=158; raw_bytes[363]=128; raw_bytes[364]=222; raw_bytes[365]=128; raw_bytes[366]=158; raw_bytes[367]=128; raw_bytes[368]=226; raw_bytes[369]=128; raw_bytes[370]=148; raw_bytes[371]=128; raw_bytes[372]=246; raw_bytes[373]=128; raw_bytes[374]=251; raw_bytes[375]=128; raw_bytes[376]=133; raw_bytes[377]=128; raw_bytes[378]=136; raw_bytes[379]=128; raw_bytes[380]=252; raw_bytes[381]=128; raw_bytes[382]=246; raw_bytes[383]=128; raw_bytes[384]=130; raw_bytes[385]=128; raw_bytes[386]=144; raw_bytes[387]=128; raw_bytes[388]=231; raw_bytes[389]=128; raw_bytes[390]=147; raw_bytes[391]=128; raw_bytes[392]=246; raw_bytes[393]=128; raw_bytes[394]=250; raw_bytes[395]=128; raw_bytes[396]=132; raw_bytes[397]=128; raw_bytes[398]=143; raw_bytes[399]=128; raw_bytes[400]=231; raw_bytes[401]=128; raw_bytes[402]=145; raw_bytes[403]=128; raw_bytes[404]=243; raw_bytes[405]=128; raw_bytes[406]=252; raw_bytes[407]=128; raw_bytes[408]=136; raw_bytes[409]=128; raw_bytes[410]=138; raw_bytes[411]=128; raw_bytes[412]=255; raw_bytes[413]=128; raw_bytes[414]=240; raw_bytes[415]=128; raw_bytes[416]=151; raw_bytes[417]=128; raw_bytes[418]=225; raw_bytes[419]=128; raw_bytes[420]=158; raw_bytes[421]=128; raw_bytes[422]=219; raw_bytes[423]=128; raw_bytes[424]=158; raw_bytes[425]=128; raw_bytes[426]=220; raw_bytes[427]=128; raw_bytes[428]=158; raw_bytes[429]=128; raw_bytes[430]=221; raw_bytes[431]=128; raw_bytes[432]=154; raw_bytes[433]=128; raw_bytes[434]=227; raw_bytes[435]=128; raw_bytes[436]=139; raw_bytes[437]=128; raw_bytes[438]=135; raw_bytes[439]=128; raw_bytes[440]=253; raw_bytes[441]=128; raw_bytes[442]=241; raw_bytes[443]=128; raw_bytes[444]=151; raw_bytes[445]=128; raw_bytes[446]=223; raw_bytes[447]=128; raw_bytes[448]=157; raw_bytes[449]=128; raw_bytes[450]=220; raw_bytes[451]=128; raw_bytes[452]=155; raw_bytes[453]=128; raw_bytes[454]=228; raw_bytes[455]=128; raw_bytes[456]=140; raw_bytes[457]=128; raw_bytes[458]=133; raw_bytes[459]=128; raw_bytes[460]=253; raw_bytes[461]=128; raw_bytes[462]=242; raw_bytes[463]=128; raw_bytes[464]=148; raw_bytes[465]=128; raw_bytes[466]=230; raw_bytes[467]=128; raw_bytes[468]=139; raw_bytes[469]=128; raw_bytes[470]=139; raw_bytes[471]=128; raw_bytes[472]=229; raw_bytes[473]=128; raw_bytes[474]=147; raw_bytes[475]=128; raw_bytes[476]=246; raw_bytes[477]=128; raw_bytes[478]=243; raw_bytes[479]=128; raw_bytes[480]=147; raw_bytes[481]=128; raw_bytes[482]=230; raw_bytes[483]=128; raw_bytes[484]=140; raw_bytes[485]=128; raw_bytes[486]=137; raw_bytes[487]=128; raw_bytes[488]=228; raw_bytes[489]=128; raw_bytes[490]=141; raw_bytes[491]=128; raw_bytes[492]=132; raw_bytes[493]=128; raw_bytes[494]=132; raw_bytes[495]=128; raw_bytes[496]=129; raw_bytes[497]=128; raw_bytes[498]=131; raw_bytes[499]=128;
    end

    initial begin
        reset = 1;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        for (int b = 0; b < 500; b++) send_byte(raw_bytes[b]);

        repeat (20) @(posedge clk);

        // let the tx frame (14 bytes at 3Mbaud) finish sending too
        repeat (6000) @(posedge clk);

        if (frame_idx == 14 && frame_errors == 0)
            $display("PASS: full round trip (raw bytes in -> tx frame out) matched the expected wire encoding");
        else
            $display("FAIL: tx frame -- received %0d/14 bytes, %0d errors", frame_idx, frame_errors);

        $finish;
    end

endmodule