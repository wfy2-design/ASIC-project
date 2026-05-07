`timescale 1ns/1ps

module project_tb;
    localparam int CLK_HZ = 1000;
    localparam int S_IDLE        = 0;
    localparam int S_WAIT_RANDOM = 1;
    localparam int S_REACT       = 2;
    localparam int S_SHOW_RESULT = 3;
    localparam int S_SHOW_AVG    = 4;

    logic clk = 1'b0;
    logic btnC = 1'b1;
    logic btnU = 1'b0;
    logic btnD = 1'b0;
    logic [6:0] seg;
    logic dp;
    logic [3:0] an;
    logic [15:0] led;
    logic buzzer_out;
    logic [3:0] vgaRed, vgaGreen, vgaBlue;
    logic Hsync, Vsync;

    reaction_tester_top #(
        .CLK_HZ(CLK_HZ),
        .KEY_ACTIVE_LOW(1'b0)
    ) dut (
        .clk(clk),
        .btnC(btnC),
        .btnU(btnU),
        .btnD(btnD),
        .buzzer_out(buzzer_out),
        .seg(seg),
        .dp(dp),
        .an(an),
        .led(led),
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue),
        .Hsync(Hsync),
        .Vsync(Vsync)
    );

    always #5 clk = ~clk;

    task automatic press_start;
        begin
            btnU = 1'b1;
            repeat (25) @(posedge clk);
            btnU = 1'b0;
            repeat (25) @(posedge clk);
        end
    endtask

    task automatic press_react;
        begin
            btnD = 1'b1;
            repeat (25) @(posedge clk);
            btnD = 1'b0;
            repeat (25) @(posedge clk);
        end
    endtask

    task automatic wait_state(input int st, input int max_cycles);
        int i;
        begin
            for (i = 0; i < max_cycles; i++) begin
                @(posedge clk);
                if (dut.state == st[2:0]) return;
            end
            $fatal(1, "Timeout waiting state=%0d, current=%0d", st, dut.state);
        end
    endtask

    initial begin
        int hist_before;
        int hs_low_seen, hs_high_seen, vs_low_seen, vs_high_seen;

        // reset
        repeat (20) @(posedge clk);
        btnC = 1'b0;
        wait_state(S_IDLE, 200);

        // Test-1: 正常反应（>=100ms 且 <=5000ms）
        press_start();
        wait_state(S_WAIT_RANDOM, 300);
        force dut.wait_target_ms = 13'd30;
        wait_state(S_REACT, 200);
        release dut.wait_target_ms;

        repeat (150) @(posedge clk);
        press_react();
        wait_state(S_SHOW_RESULT, 500);

        if (dut.last_is_fail !== 1'b0) $fatal(1, "Normal reaction should PASS");
        if (!(dut.last_result_ms >= 13'd100 && dut.last_result_ms <= 13'd5000))
            $fatal(1, "Normal reaction result out of range: %0d", dut.last_result_ms);
        if (dut.hist_valid_cnt !== 2'd1) $fatal(1, "hist_valid_cnt should be 1");

        press_start();
        wait_state(S_SHOW_AVG, 300);
        press_start();
        wait_state(S_WAIT_RANDOM, 300);

        // Test-2: 抢按 -> Fail，且不计入历史
        hist_before = dut.hist_valid_cnt;
        force dut.wait_target_ms = 13'd200;
        repeat (30) @(posedge clk);
        press_react();
        wait_state(S_SHOW_RESULT, 500);
        release dut.wait_target_ms;

        if (dut.last_is_fail !== 1'b1) $fatal(1, "Early press should FAIL");
        if (dut.hist_valid_cnt !== hist_before[1:0]) $fatal(1, "Fail result should not update history");

        press_start();
        wait_state(S_SHOW_AVG, 300);
        press_start();
        wait_state(S_WAIT_RANDOM, 300);

        // Test-3: 超时 -> Fail
        force dut.wait_target_ms = 13'd15;
        wait_state(S_REACT, 200);
        release dut.wait_target_ms;
        wait_state(S_SHOW_RESULT, 5600);

        if (dut.last_is_fail !== 1'b1) $fatal(1, "Timeout should FAIL");
        if (dut.last_result_ms < 13'd5000) $fatal(1, "Timeout result should be >=5000, got %0d", dut.last_result_ms);

        // VGA 基本正确性：同步信号有高低电平、颜色非 X
        hs_low_seen = 0; hs_high_seen = 0;
        vs_low_seen = 0; vs_high_seen = 0;
        repeat (1_700_000) begin
            @(posedge clk);
            if (Hsync === 1'b0) hs_low_seen = 1;
            if (Hsync === 1'b1) hs_high_seen = 1;
            if (Vsync === 1'b0) vs_low_seen = 1;
            if (Vsync === 1'b1) vs_high_seen = 1;
            if (^vgaRed === 1'bx || ^vgaGreen === 1'bx || ^vgaBlue === 1'bx) begin
                $fatal(1, "VGA color outputs contain X");
            end
        end

        if (!(hs_low_seen && hs_high_seen)) $fatal(1, "Hsync did not toggle");
        if (!(vs_low_seen && vs_high_seen)) $fatal(1, "Vsync did not toggle");

        $display("PASS: project_tb completed successfully.");
        $finish;
    end
endmodule
