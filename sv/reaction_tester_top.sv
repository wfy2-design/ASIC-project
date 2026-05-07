`timescale 1ns/1ps

module reaction_tester_top #(
    parameter int CLK_HZ         = 100_000_000,
    parameter bit KEY_ACTIVE_LOW = 1'b0,
    parameter bit SEG_ACTIVE_LOW = 1'b1,
    parameter bit AN_ACTIVE_LOW  = 1'b1
)(
    input  logic        clk,
    input  logic        btnC,
    input  logic        btnU,
    input  logic        btnD,
    output logic        buzzer_out,
    output logic [6:0]  seg,
    output logic        dp,
    output logic [3:0]  an,
    output logic [15:0] led,
    output logic [3:0]  vgaRed,
    output logic [3:0]  vgaGreen,
    output logic [3:0]  vgaBlue,
    output logic        Hsync,
    output logic        Vsync
);
    logic rst_n;
    logic key_start, key_react;
    logic start_level, react_level;
    logic start_d, react_d;
    logic start_pulse, react_pulse;
    logic tick_1ms;
    logic [$clog2(CLK_HZ/1000)-1:0] ms_div_cnt;

    logic [2:0]  state;
    logic [12:0] wait_target_ms, wait_cnt_ms, react_cnt_ms, last_result_ms;
    logic        last_is_fail;
    logic [1:0]  hist_valid_cnt;
    logic [13:0] avg_ms;
    logic        entered_react;

    logic [4:0] d3, d2, d1, d0;
    logic [3:0] led_fx;
    logic       buzzer;

    assign rst_n     = ~btnC;
    assign key_start = btnU;
    assign key_react = btnD;
    assign led       = {11'b0, buzzer, led_fx};
    assign buzzer_out = buzzer;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms_div_cnt <= '0;
            tick_1ms   <= 1'b0;
        end else begin
            if (ms_div_cnt == (CLK_HZ / 1000)-1) begin
                ms_div_cnt <= '0;
                tick_1ms   <= 1'b1;
            end else begin
                ms_div_cnt <= ms_div_cnt + 1'b1;
                tick_1ms   <= 1'b0;
            end
        end
    end

    debouncer #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(20),
        .ACTIVE_LOW(KEY_ACTIVE_LOW)
    ) u_db_start (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key_start),
        .key_pressed(start_level)
    );

    debouncer #(
        .CLK_HZ(CLK_HZ),
        .DEBOUNCE_MS(20),
        .ACTIVE_LOW(KEY_ACTIVE_LOW)
    ) u_db_react (
        .clk(clk),
        .rst_n(rst_n),
        .key_in(key_react),
        .key_pressed(react_level)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_d <= 1'b0;
            react_d <= 1'b0;
        end else begin
            start_d <= start_level;
            react_d <= react_level;
        end
    end

    assign start_pulse = start_level & ~start_d;
    assign react_pulse = react_level & ~react_d;

    reaction_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .tick_1ms(tick_1ms),
        .start_pulse(start_pulse),
        .react_pulse(react_pulse),
        .state(state),
        .wait_target_ms(wait_target_ms),
        .wait_cnt_ms(wait_cnt_ms),
        .react_cnt_ms(react_cnt_ms),
        .last_result_ms(last_result_ms),
        .last_is_fail(last_is_fail),
        .hist_valid_cnt(hist_valid_cnt),
        .avg_ms(avg_ms),
        .entered_react(entered_react)
    );

    display_7seg #(
        .CLK_HZ(CLK_HZ),
        .SEG_ACTIVE_LOW(SEG_ACTIVE_LOW),
        .AN_ACTIVE_LOW(AN_ACTIVE_LOW)
    ) u_display (
        .clk(clk),
        .rst_n(rst_n),
        .state(state),
        .last_result_ms(last_result_ms),
        .last_is_fail(last_is_fail),
        .hist_valid_cnt(hist_valid_cnt),
        .avg_ms(avg_ms),
        .seg(seg),
        .dp(dp),
        .an(an),
        .d3(d3),
        .d2(d2),
        .d1(d1),
        .d0(d0)
    );

    beep_led_fx #(
        .CLK_HZ(CLK_HZ)
    ) u_beep_led (
        .clk(clk),
        .rst_n(rst_n),
        .tick_1ms(tick_1ms),
        .entered_react(entered_react),
        .state(state),
        .wait_cnt_ms(wait_cnt_ms),
        .last_is_fail(last_is_fail),
        .buzzer(buzzer),
        .led_fx(led_fx)
    );

    vga_renderer u_vga (
        .clk(clk),
        .rst_n(rst_n),
        .state(state),
        .d3(d3),
        .d2(d2),
        .d1(d1),
        .d0(d0),
        .last_is_fail(last_is_fail),
        .hist_valid_cnt(hist_valid_cnt),
        .vgaRed(vgaRed),
        .vgaGreen(vgaGreen),
        .vgaBlue(vgaBlue),
        .Hsync(Hsync),
        .Vsync(Vsync)
    );
endmodule
