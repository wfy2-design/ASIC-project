`timescale 1ns/1ps

module project_postsyn_tb;
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

    reaction_tester_top dut (
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

    initial begin
        $sdf_annotate("E:/ASIC/reaction_tester_top_timesim.sdf", dut);
    end

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

    task automatic wait_led_pattern(input logic [3:0] pat, input int max_cycles);
        int i;
        begin
            for (i = 0; i < max_cycles; i++) begin
                @(posedge clk);
                if (led[3:0] == pat) return;
            end
            $fatal(1, "Timeout waiting led[3:0]==%h, current=%h", pat, led[3:0]);
        end
    endtask

    initial begin
        int hs_low_seen, hs_high_seen, vs_low_seen, vs_high_seen;
        int vga_check_cycles;
        bit fast_vga;

        repeat (20) @(posedge clk);
        btnC = 1'b0;
        repeat (40) @(posedge clk);

        // 启动一次测试，等待进入反应窗口（LED低4位=1111）
        press_start();
        wait_led_pattern(4'hF, 7000);
        repeat (150) @(posedge clk);
        press_react();

        // 结果/均值流程触发
        repeat (500) @(posedge clk);
        press_start();
        repeat (200) @(posedge clk);
        press_start();

        // VGA timing/output check (fast mode avoids very long gate-level sims)
        fast_vga = !$test$plusargs("FULL_VGA");
        vga_check_cycles = fast_vga ? 200_000 : 1_800_000;
        if (fast_vga) $display("INFO: FAST_VGA mode enabled; skipping Vsync toggle requirement");

        hs_low_seen = 0; hs_high_seen = 0;
        vs_low_seen = 0; vs_high_seen = 0;
        repeat (vga_check_cycles) begin
            @(posedge clk);
            if (Hsync === 1'b0) hs_low_seen = 1;
            if (Hsync === 1'b1) hs_high_seen = 1;
            if (Vsync === 1'b0) vs_low_seen = 1;
            if (Vsync === 1'b1) vs_high_seen = 1;
            if (^vgaRed === 1'bx || ^vgaGreen === 1'bx || ^vgaBlue === 1'bx) begin
                $fatal(1, "VGA RGB contains X");
            end
        end

        if (!(hs_low_seen && hs_high_seen)) $fatal(1, "Hsync did not toggle");
        if (!fast_vga) begin
            if (!(vs_low_seen && vs_high_seen)) $fatal(1, "Vsync did not toggle");
        end

        $display("PASS: project_postsyn_tb completed successfully.");
        $finish;
    end
endmodule
