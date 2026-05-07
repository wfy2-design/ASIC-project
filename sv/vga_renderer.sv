module vga_renderer(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [2:0] state,
    input  logic [4:0] d3,
    input  logic [4:0] d2,
    input  logic [4:0] d1,
    input  logic [4:0] d0,
    input  logic       last_is_fail,
    input  logic [1:0] hist_valid_cnt,
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue,
    output logic       Hsync,
    output logic       Vsync
);
    localparam logic [2:0] S_IDLE        = 3'd0;
    localparam logic [2:0] S_WAIT_RANDOM = 3'd1;
    localparam logic [2:0] S_REACT       = 3'd2;
    localparam logic [2:0] S_SHOW_RESULT = 3'd3;
    localparam logic [2:0] S_SHOW_AVG    = 3'd4;

    localparam logic [4:0] C_DASH  = 5'd10;
    localparam logic [4:0] C_F     = 5'd12;
    localparam logic [4:0] C_A     = 5'd13;
    localparam logic [4:0] C_I     = 5'd14;
    localparam logic [4:0] C_L     = 5'd15;
    localparam logic [4:0] C_BLANK = 5'd16;
    localparam logic [4:0] C_S     = 5'd17;
    localparam logic [4:0] C_T     = 5'd18;
    localparam logic [4:0] C_R     = 5'd19;

    logic [1:0] pix_div;
    logic       pix_tick;
    logic [9:0] h_cnt, v_cnt;
    logic       vga_active;
    logic [3:0] r_next, g_next, b_next;
    logic       in_border;
    logic [2:0] text_len;
    logic [4:0] text_c4, text_c3, text_c2, text_c1, text_c0, text_sel;
    logic [3:0] text_r, text_g, text_b;
    logic text_hit;
    int unsigned text_w;
    int unsigned text_x0;
    int unsigned text_y0;
    int unsigned text_x_local;
    int unsigned text_y_local;
    int unsigned text_char_slot;
    int unsigned text_x_in_char;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pix_div  <= 2'd0;
            pix_tick <= 1'b0;
        end else begin
            pix_div  <= pix_div + 1'b1;
            pix_tick <= (pix_div == 2'd3);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else if (pix_tick) begin
            if (h_cnt == 10'd799) begin
                h_cnt <= 10'd0;
                if (v_cnt == 10'd524) v_cnt <= 10'd0;
                else                  v_cnt <= v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    assign vga_active = (h_cnt < 10'd640) && (v_cnt < 10'd480);
    assign Hsync      = ~((h_cnt >= 10'd656) && (h_cnt < 10'd752));
    assign Vsync      = ~((v_cnt >= 10'd490) && (v_cnt < 10'd492));

    always_comb begin
        in_border = (h_cnt < 10'd8) || (h_cnt >= 10'd632) ||
                    (v_cnt < 10'd8) || (v_cnt >= 10'd472);

        r_next = 4'h0;
        g_next = 4'h0;
        b_next = 4'h0;
        text_len = 3'd0;
        text_c4 = C_BLANK; text_c3 = C_BLANK; text_c2 = C_BLANK; text_c1 = C_BLANK; text_c0 = C_BLANK;
        text_r = 4'h0; text_g = 4'h0; text_b = 4'h0;
        text_hit = 1'b0;
        text_w = 0;
        text_x0 = 0;
        text_y0 = 10'd226;
        text_x_local = 0;
        text_y_local = 0;
        text_char_slot = 0;
        text_x_in_char = 0;
        text_sel = C_BLANK;

        if (vga_active) begin
            unique case (state)
                S_IDLE: begin
                    r_next = 4'h0; g_next = 4'h0; b_next = 4'h3;
                    text_len = 3'd5;
                    text_c4 = C_S; text_c3 = C_T; text_c2 = C_A; text_c1 = C_R; text_c0 = C_T;
                    text_r = 4'hF; text_g = 4'hF; text_b = 4'hF;
                end
                S_WAIT_RANDOM: begin
                    r_next = 4'h8; g_next = 4'h0; b_next = 4'h0;
                end
                S_REACT: begin
                    r_next = 4'h0; g_next = 4'h8; b_next = 4'h0;
                end
                S_SHOW_RESULT: begin
                    r_next = 4'h1; g_next = 4'h1; b_next = 4'h1;
                    text_len = 3'd4;
                    if (last_is_fail) begin
                        text_c3 = C_F; text_c2 = C_A; text_c1 = C_I; text_c0 = C_L;
                        text_r = 4'hF; text_g = 4'h0; text_b = 4'h0;
                    end else begin
                        text_c3 = d3; text_c2 = d2; text_c1 = d1; text_c0 = d0;
                        text_r = 4'h0; text_g = 4'hF; text_b = 4'h0;
                    end
                end
                S_SHOW_AVG: begin
                    r_next = 4'h1; g_next = 4'h1; b_next = 4'h1;
                    text_len = 3'd4;
                    if (hist_valid_cnt == 0) begin
                        text_c3 = C_DASH; text_c2 = C_DASH; text_c1 = C_DASH; text_c0 = C_DASH;
                    end else begin
                        text_c3 = d3; text_c2 = d2; text_c1 = d1; text_c0 = d0;
                    end
                    text_r = 4'hF; text_g = 4'hF; text_b = 4'h0;
                end
                default: begin
                    r_next = 4'h0; g_next = 4'h0; b_next = 4'h0;
                end
            endcase

            if (text_len != 0) begin
                text_w = text_len * 20 + (text_len - 1) * 8;
                text_x0 = (640 - text_w) / 2;
                if ((h_cnt >= text_x0) && (h_cnt < (text_x0 + text_w)) &&
                    (v_cnt >= text_y0) && (v_cnt < (text_y0 + 28))) begin
                    text_x_local = h_cnt - text_x0;
                    text_y_local = v_cnt - text_y0;
                    text_char_slot = text_x_local / 28;
                    text_x_in_char = text_x_local % 28;
                    if (text_x_in_char < 20) begin
                        if (text_len == 5) begin
                            unique case (text_char_slot)
                                0: text_sel = text_c4;
                                1: text_sel = text_c3;
                                2: text_sel = text_c2;
                                3: text_sel = text_c1;
                                default: text_sel = text_c0;
                            endcase
                        end else begin
                            unique case (text_char_slot)
                                0: text_sel = text_c3;
                                1: text_sel = text_c2;
                                2: text_sel = text_c1;
                                default: text_sel = text_c0;
                            endcase
                        end
                        text_hit = glyph_on(text_sel, text_x_in_char, text_y_local);
                        if (text_hit) begin
                            r_next = text_r;
                            g_next = text_g;
                            b_next = text_b;
                        end
                    end
                end
            end

            if (in_border) begin
                r_next = 4'hF;
                g_next = 4'hF;
                b_next = 4'hF;
            end
        end
    end

    function automatic logic [4:0] font_row(input logic [4:0] c, input int row);
        begin
            unique case (c)
                5'd0: unique case (row)
                    0: font_row = 5'b01110;
                    1: font_row = 5'b10001;
                    2: font_row = 5'b10011;
                    3: font_row = 5'b10101;
                    4: font_row = 5'b11001;
                    5: font_row = 5'b10001;
                    default: font_row = 5'b01110;
                endcase
                5'd1: unique case (row)
                    0: font_row = 5'b00100;
                    1: font_row = 5'b01100;
                    2: font_row = 5'b00100;
                    3: font_row = 5'b00100;
                    4: font_row = 5'b00100;
                    5: font_row = 5'b00100;
                    default: font_row = 5'b01110;
                endcase
                5'd2: unique case (row)
                    0: font_row = 5'b01110;
                    1: font_row = 5'b10001;
                    2: font_row = 5'b00001;
                    3: font_row = 5'b00010;
                    4: font_row = 5'b00100;
                    5: font_row = 5'b01000;
                    default: font_row = 5'b11111;
                endcase
                5'd3: unique case (row)
                    0: font_row = 5'b11110;
                    1: font_row = 5'b00001;
                    2: font_row = 5'b00001;
                    3: font_row = 5'b01110;
                    4: font_row = 5'b00001;
                    5: font_row = 5'b00001;
                    default: font_row = 5'b11110;
                endcase
                5'd4: unique case (row)
                    0: font_row = 5'b10010;
                    1: font_row = 5'b10010;
                    2: font_row = 5'b10010;
                    3: font_row = 5'b11111;
                    4: font_row = 5'b00010;
                    5: font_row = 5'b00010;
                    default: font_row = 5'b00010;
                endcase
                5'd5: unique case (row)
                    0: font_row = 5'b11111;
                    1: font_row = 5'b10000;
                    2: font_row = 5'b11110;
                    3: font_row = 5'b00001;
                    4: font_row = 5'b00001;
                    5: font_row = 5'b00001;
                    default: font_row = 5'b11110;
                endcase
                5'd6: unique case (row)
                    0: font_row = 5'b01110;
                    1: font_row = 5'b10000;
                    2: font_row = 5'b11110;
                    3: font_row = 5'b10001;
                    4: font_row = 5'b10001;
                    5: font_row = 5'b10001;
                    default: font_row = 5'b01110;
                endcase
                5'd7: unique case (row)
                    0: font_row = 5'b11111;
                    1: font_row = 5'b00001;
                    2: font_row = 5'b00010;
                    3: font_row = 5'b00100;
                    4: font_row = 5'b01000;
                    5: font_row = 5'b01000;
                    default: font_row = 5'b01000;
                endcase
                5'd8: unique case (row)
                    0: font_row = 5'b01110;
                    1: font_row = 5'b10001;
                    2: font_row = 5'b10001;
                    3: font_row = 5'b01110;
                    4: font_row = 5'b10001;
                    5: font_row = 5'b10001;
                    default: font_row = 5'b01110;
                endcase
                5'd9: unique case (row)
                    0: font_row = 5'b01110;
                    1: font_row = 5'b10001;
                    2: font_row = 5'b10001;
                    3: font_row = 5'b01111;
                    4: font_row = 5'b00001;
                    5: font_row = 5'b00010;
                    default: font_row = 5'b01100;
                endcase
                C_F: unique case (row)
                    0: font_row = 5'b11111;
                    1: font_row = 5'b10000;
                    2: font_row = 5'b11110;
                    3: font_row = 5'b10000;
                    4: font_row = 5'b10000;
                    5: font_row = 5'b10000;
                    default: font_row = 5'b10000;
                endcase
                C_A: unique case (row)
                    0: font_row = 5'b01110;
                    1: font_row = 5'b10001;
                    2: font_row = 5'b10001;
                    3: font_row = 5'b11111;
                    4: font_row = 5'b10001;
                    5: font_row = 5'b10001;
                    default: font_row = 5'b10001;
                endcase
                C_I: unique case (row)
                    0: font_row = 5'b11111;
                    1: font_row = 5'b00100;
                    2: font_row = 5'b00100;
                    3: font_row = 5'b00100;
                    4: font_row = 5'b00100;
                    5: font_row = 5'b00100;
                    default: font_row = 5'b11111;
                endcase
                C_L: unique case (row)
                    0: font_row = 5'b10000;
                    1: font_row = 5'b10000;
                    2: font_row = 5'b10000;
                    3: font_row = 5'b10000;
                    4: font_row = 5'b10000;
                    5: font_row = 5'b10000;
                    default: font_row = 5'b11111;
                endcase
                C_DASH: unique case (row)
                    0, 1, 5, 6: font_row = 5'b00000;
                    2, 3, 4:    font_row = 5'b11111;
                    default:    font_row = 5'b00000;
                endcase
                C_S: unique case (row)
                    0: font_row = 5'b01111;
                    1: font_row = 5'b10000;
                    2: font_row = 5'b01110;
                    3: font_row = 5'b00001;
                    4: font_row = 5'b00001;
                    5: font_row = 5'b00001;
                    default: font_row = 5'b11110;
                endcase
                C_T: unique case (row)
                    0: font_row = 5'b11111;
                    1: font_row = 5'b00100;
                    2: font_row = 5'b00100;
                    3: font_row = 5'b00100;
                    4: font_row = 5'b00100;
                    5: font_row = 5'b00100;
                    default: font_row = 5'b00100;
                endcase
                C_R: unique case (row)
                    0: font_row = 5'b11110;
                    1: font_row = 5'b10001;
                    2: font_row = 5'b10001;
                    3: font_row = 5'b11110;
                    4: font_row = 5'b10100;
                    5: font_row = 5'b10010;
                    default: font_row = 5'b10001;
                endcase
                default: font_row = 5'b00000;
            endcase
        end
    endfunction

    function automatic logic glyph_on(
        input logic [4:0] c,
        input int unsigned x_off,
        input int unsigned y_off
    );
        int unsigned col;
        int unsigned row;
        logic [4:0] row_bits;
        begin
            col = x_off >> 2;
            row = y_off >> 2;
            if (col >= 5 || row >= 7) begin
                glyph_on = 1'b0;
            end else begin
                row_bits = font_row(c, row);
                glyph_on = row_bits[4-col];
            end
        end
    endfunction

    assign vgaRed   = r_next;
    assign vgaGreen = g_next;
    assign vgaBlue  = b_next;
endmodule
