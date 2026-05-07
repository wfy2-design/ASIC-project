module debouncer #(
    parameter int CLK_HZ = 50_000_000,
    parameter int DEBOUNCE_MS = 20,
    parameter bit ACTIVE_LOW = 1'b1
)(
    input  logic clk,
    input  logic rst_n,
    input  logic key_in,
    output logic key_pressed
);
    localparam int SAMPLE_DIV   = CLK_HZ / 1000;
    localparam int STABLE_TICKS = DEBOUNCE_MS;

    logic [$clog2(SAMPLE_DIV)-1:0] sdiv;
    logic sample_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sdiv <= '0;
            sample_tick <= 1'b0;
        end else begin
            if (sdiv == SAMPLE_DIV-1) begin
                sdiv <= '0;
                sample_tick <= 1'b1;
            end else begin
                sdiv <= sdiv + 1'b1;
                sample_tick <= 1'b0;
            end
        end
    end

    logic key_norm, key_sync0, key_sync1;
    logic [$clog2(STABLE_TICKS+1)-1:0] stable_cnt;
    logic stable_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync0 <= 1'b0;
            key_sync1 <= 1'b0;
            key_norm  <= 1'b0;
        end else begin
            key_norm  <= ACTIVE_LOW ? ~key_in : key_in;
            key_sync0 <= key_norm;
            key_sync1 <= key_sync0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stable_cnt   <= '0;
            stable_state <= 1'b0;
        end else if (sample_tick) begin
            if (key_sync1 == stable_state) begin
                stable_cnt <= '0;
            end else begin
                if (stable_cnt == STABLE_TICKS-1) begin
                    stable_state <= key_sync1;
                    stable_cnt   <= '0;
                end else begin
                    stable_cnt <= stable_cnt + 1'b1;
                end
            end
        end
    end

    assign key_pressed = stable_state;
endmodule
