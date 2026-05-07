module beep_led_fx #(
    parameter int CLK_HZ = 100_000_000
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        tick_1ms,
    input  logic        entered_react,
    input  logic [2:0]  state,
    input  logic [12:0] wait_cnt_ms,
    input  logic        last_is_fail,
    output logic        buzzer,
    output logic [3:0]  led_fx
);
    localparam logic [2:0] S_WAIT_RANDOM = 3'd1;
    localparam logic [2:0] S_REACT       = 3'd2;
    localparam logic [2:0] S_SHOW_RESULT = 3'd3;
    localparam logic [2:0] S_SHOW_AVG    = 3'd4;

    logic [6:0] beep_ms_cnt;
    logic [15:0] tone_div_cnt;
    logic tone_clk;

    localparam int TONE_DIV = CLK_HZ / 4000;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tone_div_cnt <= '0;
            tone_clk     <= 1'b0;
        end else begin
            if (tone_div_cnt == TONE_DIV-1) begin
                tone_div_cnt <= '0;
                tone_clk     <= ~tone_clk;
            end else begin
                tone_div_cnt <= tone_div_cnt + 1'b1;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            beep_ms_cnt <= '0;
        end else begin
            if (entered_react) beep_ms_cnt <= 7'd80;
            else if (tick_1ms && beep_ms_cnt != 0) beep_ms_cnt <= beep_ms_cnt - 1'b1;
        end
    end

    assign buzzer = (beep_ms_cnt != 0) ? tone_clk : 1'b0;

    always_comb begin
        unique case (state)
            S_WAIT_RANDOM: led_fx = wait_cnt_ms[8] ? 4'b1010 : 4'b0101;
            S_REACT:       led_fx = 4'b1111;
            S_SHOW_RESULT: led_fx = last_is_fail ? 4'b1001 : 4'b0110;
            S_SHOW_AVG:    led_fx = 4'b0011;
            default:       led_fx = 4'b0000;
        endcase
    end
endmodule
