module display_7seg #(
    parameter int CLK_HZ         = 100_000_000,
    parameter bit SEG_ACTIVE_LOW = 1'b1,
    parameter bit AN_ACTIVE_LOW  = 1'b1
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [2:0]  state,
    input  logic [12:0] last_result_ms,
    input  logic        last_is_fail,
    input  logic [1:0]  hist_valid_cnt,
    input  logic [13:0] avg_ms,
    output logic [6:0]  seg,
    output logic        dp,
    output logic [3:0]  an,
    output logic [4:0]  d3,
    output logic [4:0]  d2,
    output logic [4:0]  d1,
    output logic [4:0]  d0
);
    localparam logic [2:0] S_IDLE        = 3'd0;
    localparam logic [2:0] S_WAIT_RANDOM = 3'd1;
    localparam logic [2:0] S_REACT       = 3'd2;
    localparam logic [2:0] S_SHOW_RESULT = 3'd3;
    localparam logic [2:0] S_SHOW_AVG    = 3'd4;

    localparam logic [4:0] C_0 = 5'd0;
    localparam logic [4:0] C_1 = 5'd1;
    localparam logic [4:0] C_2 = 5'd2;
    localparam logic [4:0] C_3 = 5'd3;
    localparam logic [4:0] C_4 = 5'd4;
    localparam logic [4:0] C_5 = 5'd5;
    localparam logic [4:0] C_6 = 5'd6;
    localparam logic [4:0] C_7 = 5'd7;
    localparam logic [4:0] C_8 = 5'd8;
    localparam logic [4:0] C_9 = 5'd9;
    localparam logic [4:0] C_DASH  = 5'd10;
    localparam logic [4:0] C_PIPE  = 5'd11;
    localparam logic [4:0] C_F     = 5'd12;
    localparam logic [4:0] C_A     = 5'd13;
    localparam logic [4:0] C_I     = 5'd14;
    localparam logic [4:0] C_L     = 5'd15;
    localparam logic [4:0] C_BLANK = 5'd16;

    logic [13:0] disp_num;
    logic show_num;
    logic [7:0] seg8;
    logic [7:0] seg_raw;
    logic [3:0] an_raw;
    logic [$clog2(CLK_HZ/4000)-1:0] scan_div_cnt;
    logic [1:0] scan_idx;

    always_comb begin
        d3 = C_BLANK;
        d2 = C_BLANK;
        d1 = C_BLANK;
        d0 = C_BLANK;
        disp_num = 14'd0;
        show_num = 1'b0;

        unique case (state)
            S_IDLE: begin
                show_num = 1'b1;
                disp_num = 14'd0;
            end
            S_WAIT_RANDOM: begin
                d3 = C_DASH; d2 = C_DASH; d1 = C_DASH; d0 = C_DASH;
            end
            S_REACT: begin
                d3 = C_PIPE; d2 = C_PIPE; d1 = C_PIPE; d0 = C_PIPE;
            end
            S_SHOW_RESULT: begin
                if (last_is_fail) begin
                    d3 = C_F; d2 = C_A; d1 = C_I; d0 = C_L;
                end else begin
                    show_num = 1'b1;
                    disp_num = last_result_ms;
                end
            end
            S_SHOW_AVG: begin
                if (hist_valid_cnt == 0) begin
                    d3 = C_DASH; d2 = C_DASH; d1 = C_DASH; d0 = C_DASH;
                end else begin
                    show_num = 1'b1;
                    disp_num = avg_ms;
                end
            end
            default: ;
        endcase

        if (show_num) begin
            d3 = 5'((disp_num / 1000) % 10);
            d2 = 5'((disp_num / 100)  % 10);
            d1 = 5'((disp_num / 10)   % 10);
            d0 = 5'( disp_num % 10);
        end
    end

    function automatic logic [7:0] char_to_seg(input logic [4:0] c);
        logic [7:0] s;
        begin
            unique case (c)
                C_0:    s = 8'b0_0111111;
                C_1:    s = 8'b0_0000110;
                C_2:    s = 8'b0_1011011;
                C_3:    s = 8'b0_1001111;
                C_4:    s = 8'b0_1100110;
                C_5:    s = 8'b0_1101101;
                C_6:    s = 8'b0_1111101;
                C_7:    s = 8'b0_0000111;
                C_8:    s = 8'b0_1111111;
                C_9:    s = 8'b0_1101111;
                C_DASH: s = 8'b0_1000000;
                C_PIPE: s = 8'b0_0000110;
                C_F:    s = 8'b0_1110001;
                C_A:    s = 8'b0_1110111;
                C_I:    s = 8'b0_0000110;
                C_L:    s = 8'b0_0111000;
                default:s = 8'b0_0000000;
            endcase
            char_to_seg = s;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_div_cnt <= '0;
            scan_idx     <= 2'd0;
        end else begin
            if (scan_div_cnt == (CLK_HZ/4000)-1) begin
                scan_div_cnt <= '0;
                scan_idx     <= scan_idx + 1'b1;
            end else begin
                scan_div_cnt <= scan_div_cnt + 1'b1;
            end
        end
    end

    always_comb begin
        an_raw  = 4'b0000;
        seg_raw = 8'h00;
        unique case (scan_idx)
            2'd0: begin an_raw = 4'b0001; seg_raw = char_to_seg(d0); end
            2'd1: begin an_raw = 4'b0010; seg_raw = char_to_seg(d1); end
            2'd2: begin an_raw = 4'b0100; seg_raw = char_to_seg(d2); end
            default: begin an_raw = 4'b1000; seg_raw = char_to_seg(d3); end
        endcase
    end

    always_comb begin
        seg8 = SEG_ACTIVE_LOW ? ~seg_raw : seg_raw;
        an   = AN_ACTIVE_LOW  ? ~an_raw  : an_raw;
    end

    assign seg = seg8[6:0];
    assign dp  = seg8[7];
endmodule
