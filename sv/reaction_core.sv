module reaction_core(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        tick_1ms,
    input  logic        start_pulse,
    input  logic        react_pulse,
    output logic [2:0]  state,
    output logic [12:0] wait_target_ms,
    output logic [12:0] wait_cnt_ms,
    output logic [12:0] react_cnt_ms,
    output logic [12:0] last_result_ms,
    output logic        last_is_fail,
    output logic [1:0]  hist_valid_cnt,
    output logic [13:0] avg_ms,
    output logic        entered_react
);
    localparam logic [2:0] S_IDLE        = 3'd0;
    localparam logic [2:0] S_WAIT_RANDOM = 3'd1;
    localparam logic [2:0] S_REACT       = 3'd2;
    localparam logic [2:0] S_SHOW_RESULT = 3'd3;
    localparam logic [2:0] S_SHOW_AVG    = 3'd4;

    logic [2:0] state_n;
    logic [12:0] hist0, hist1, hist2;
    logic [15:0] lfsr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) lfsr <= 16'h1ACE;
        else lfsr <= {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
    end

    function automatic logic [12:0] random_delay_ms(input logic [15:0] rnd);
        logic [12:0] m;
        begin
            m = rnd % 13'd4501;
            random_delay_ms = 13'd500 + m;
        end
    endfunction

    always_comb begin
        unique case (hist_valid_cnt)
            2'd0: avg_ms = 14'd0;
            2'd1: avg_ms = hist0;
            2'd2: avg_ms = (hist0 + hist1) / 2;
            default: avg_ms = (hist0 + hist1 + hist2) / 3;
        endcase
    end

    always_comb begin
        state_n = state;
        unique case (state)
            S_IDLE: begin
                if (start_pulse) state_n = S_WAIT_RANDOM;
            end
            S_WAIT_RANDOM: begin
                if (react_pulse) state_n = S_SHOW_RESULT;
                else if (tick_1ms && (wait_cnt_ms >= wait_target_ms)) state_n = S_REACT;
            end
            S_REACT: begin
                if (react_pulse) state_n = S_SHOW_RESULT;
                else if (tick_1ms && react_cnt_ms >= 13'd5000) state_n = S_SHOW_RESULT;
            end
            S_SHOW_RESULT: begin
                if (start_pulse) state_n = S_SHOW_AVG;
            end
            S_SHOW_AVG: begin
                if (start_pulse) state_n = S_WAIT_RANDOM;
            end
            default: state_n = S_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            wait_target_ms <= 13'd500;
            wait_cnt_ms    <= '0;
            react_cnt_ms   <= '0;
            last_result_ms <= 13'd0;
            last_is_fail   <= 1'b0;
            hist0          <= '0;
            hist1          <= '0;
            hist2          <= '0;
            hist_valid_cnt <= 2'd0;
            entered_react  <= 1'b0;
        end else begin
            entered_react <= 1'b0;
            state <= state_n;

            if (state == S_WAIT_RANDOM && tick_1ms) begin
                if (wait_cnt_ms < 13'd8191) wait_cnt_ms <= wait_cnt_ms + 1'b1;
            end
            if (state == S_REACT && tick_1ms) begin
                if (react_cnt_ms < 13'd8191) react_cnt_ms <= react_cnt_ms + 1'b1;
            end

            if (state != state_n) begin
                unique case (state_n)
                    S_WAIT_RANDOM: begin
                        wait_target_ms <= random_delay_ms(lfsr);
                        wait_cnt_ms    <= 13'd0;
                        react_cnt_ms   <= 13'd0;
                        last_is_fail   <= 1'b0;
                    end
                    S_REACT: begin
                        react_cnt_ms  <= 13'd0;
                        entered_react <= 1'b1;
                    end
                    S_SHOW_RESULT: begin
                        if (state == S_WAIT_RANDOM) begin
                            last_is_fail   <= 1'b1;
                            last_result_ms <= 13'd0;
                        end else if (state == S_REACT) begin
                            if (!react_pulse) begin
                                last_is_fail   <= 1'b1;
                                last_result_ms <= react_cnt_ms;
                            end else begin
                                last_result_ms <= react_cnt_ms;
                                if (react_cnt_ms < 13'd100 || react_cnt_ms > 13'd5000) begin
                                    last_is_fail <= 1'b1;
                                end else begin
                                    last_is_fail <= 1'b0;
                                    hist2 <= hist1;
                                    hist1 <= hist0;
                                    hist0 <= react_cnt_ms;
                                    if (hist_valid_cnt < 2'd3) hist_valid_cnt <= hist_valid_cnt + 1'b1;
                                end
                            end
                        end
                    end
                    default: ;
                endcase
            end
        end
    end
endmodule
