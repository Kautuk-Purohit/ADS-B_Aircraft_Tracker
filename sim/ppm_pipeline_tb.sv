/* Integration test: preamble_detector -> ppm_decoder, fed the SAME real
   captured samples used to validate preamble_detector alone. Confirms the
   full 112-bit message ppm_decoder assembles matches the Python golden
   model's already-verified decode of this exact real aircraft message
   (ICAO 4D2023, TC=19) bit for bit -- not just "some 112 bits". */

module ppm_pipeline_tb;

    logic clk = 0;
    logic reset;
    logic [7:0] magnitude;

    always #5 clk = ~clk;

    logic preamble_found;
    preamble_detector u_pre (
        .clk(clk), .reset(reset),
        .magnitude(magnitude),
        .preamble_found(preamble_found)
    );

    logic bit_out, bit_valid, msg_start, msg_done, busy;
    logic [111:0] msg_bits;
    ppm_decoder u_ppm (
        .clk(clk), .reset(reset),
        .magnitude(magnitude),
        .preamble_found(preamble_found),
        .bit_out(bit_out), .bit_valid(bit_valid),
        .msg_start(msg_start), .msg_done(msg_done),
        .msg_bits(msg_bits), .busy(busy)
    );

    logic [7:0] samples [0:249];
    initial begin
        samples[0]=1; samples[1]=1; samples[2]=2; samples[3]=2; samples[4]=1; samples[5]=93; samples[6]=24; samples[7]=99; samples[8]=11; samples[9]=2; samples[10]=5; samples[11]=18; samples[12]=95; samples[13]=27; samples[14]=98; samples[15]=9; samples[16]=2; samples[17]=5; samples[18]=2; samples[19]=8; samples[20]=16; samples[21]=104; samples[22]=5; samples[23]=18; samples[24]=102; samples[25]=27; samples[26]=98; samples[27]=22; samples[28]=123; samples[29]=114; samples[30]=27; samples[31]=99; samples[32]=32; samples[33]=93; samples[34]=26; samples[35]=101; samples[36]=7; samples[37]=10; samples[38]=126; samples[39]=117; samples[40]=1; samples[41]=19; samples[42]=103; samples[43]=18; samples[44]=124; samples[45]=113; samples[46]=22; samples[47]=104; samples[48]=10; samples[49]=8; samples[50]=125; samples[51]=119; samples[52]=1; samples[53]=19; samples[54]=105; samples[55]=18; samples[56]=121; samples[57]=122; samples[58]=2; samples[59]=20; samples[60]=100; samples[61]=27; samples[62]=92; samples[63]=30; samples[64]=95; samples[65]=31; samples[66]=94; samples[67]=31; samples[68]=93; samples[69]=29; samples[70]=96; samples[71]=21; samples[72]=119; samples[73]=120; samples[74]=1; samples[75]=19; samples[76]=99; samples[77]=26; samples[78]=96; samples[79]=22; samples[80]=124; samples[81]=112; samples[82]=26; samples[83]=96; samples[84]=29; samples[85]=102; samples[86]=7; samples[87]=15; samples[88]=103; samples[89]=19; samples[90]=123; samples[91]=115; samples[92]=23; samples[93]=104; samples[94]=9; samples[95]=15; samples[96]=101; samples[97]=19; samples[98]=119; samples[99]=122; samples[100]=2; samples[101]=18; samples[102]=99; samples[103]=26; samples[104]=96; samples[105]=20; samples[106]=122; samples[107]=122; samples[108]=2; samples[109]=19; samples[110]=97; samples[111]=26; samples[112]=92; samples[113]=31; samples[114]=99; samples[115]=22; samples[116]=119; samples[117]=120; samples[118]=3; samples[119]=18; samples[120]=101; samples[121]=18; samples[122]=119; samples[123]=124; samples[124]=3; samples[125]=17; samples[126]=103; samples[127]=19; samples[128]=121; samples[129]=115; samples[130]=23; samples[131]=95; samples[132]=27; samples[133]=98; samples[134]=10; samples[135]=7; samples[136]=124; samples[137]=119; samples[138]=6; samples[139]=12; samples[140]=127; samples[141]=110; samples[142]=20; samples[143]=104; samples[144]=8; samples[145]=13; samples[146]=102; samples[147]=18; samples[148]=121; samples[149]=113; samples[150]=22; samples[151]=104; samples[152]=9; samples[153]=15; samples[154]=103; samples[155]=19; samples[156]=117; samples[157]=123; samples[158]=2; samples[159]=17; samples[160]=98; samples[161]=27; samples[162]=96; samples[163]=22; samples[164]=119; samples[165]=120; samples[166]=3; samples[167]=19; samples[168]=99; samples[169]=25; samples[170]=92; samples[171]=31; samples[172]=93; samples[173]=29; samples[174]=94; samples[175]=29; samples[176]=94; samples[177]=29; samples[178]=91; samples[179]=30; samples[180]=94; samples[181]=30; samples[182]=94; samples[183]=30; samples[184]=98; samples[185]=20; samples[186]=118; samples[187]=123; samples[188]=5; samples[189]=8; samples[190]=124; samples[191]=118; samples[192]=2; samples[193]=16; samples[194]=103; samples[195]=19; samples[196]=118; samples[197]=122; samples[198]=4; samples[199]=15; samples[200]=103; samples[201]=17; samples[202]=115; samples[203]=124; samples[204]=8; samples[205]=10; samples[206]=127; samples[207]=112; samples[208]=23; samples[209]=97; samples[210]=30; samples[211]=91; samples[212]=30; samples[213]=92; samples[214]=30; samples[215]=93; samples[216]=26; samples[217]=99; samples[218]=11; samples[219]=7; samples[220]=125; samples[221]=113; samples[222]=23; samples[223]=95; samples[224]=29; samples[225]=92; samples[226]=27; samples[227]=100; samples[228]=12; samples[229]=5; samples[230]=125; samples[231]=114; samples[232]=20; samples[233]=102; samples[234]=11; samples[235]=11; samples[236]=101; samples[237]=19; samples[238]=118; samples[239]=115; samples[240]=19; samples[241]=102; samples[242]=12; samples[243]=9; samples[244]=100; samples[245]=13; samples[246]=4; samples[247]=4; samples[248]=1; samples[249]=3;
    end

    // Known-correct answer from the Python golden model for this exact real message
    logic [111:0] expected_bits;
    initial expected_bits = 112'b1000111101001101001000000010001110011001000100001001001110101100110010001000000000010100100101111110111101100110;

    logic [111:0] captured_bits;

    initial begin
        reset = 1;
        @(posedge clk); @(posedge clk);
        reset = 0;

        for (int k = 0; k < 250; k++) begin
            magnitude = samples[k];
            @(posedge clk);
            #1;
            if (preamble_found) $display("  [k=%0d] preamble_found=1", k);
            if (msg_start)      $display("  [k=%0d] msg_start=1 (magnitude this cycle=%0d)", k, magnitude);
            if (bit_valid)      $display("  [k=%0d] bit_valid=1 bit_out=%b msg_done=%b busy=%b", k, bit_out, msg_done, busy);
            if (msg_done)       captured_bits = msg_bits;   // a real consumer must latch on this exact cycle
        end

        if (captured_bits === expected_bits)
            $display("PASS: ppm_decoder's 112 bits exactly match the Python golden model");
        else begin
            $display("FAIL:");
            $display("  got:      %b", msg_bits);
            $display("  expected: %b", expected_bits);
        end

        $finish;
    end

endmodule