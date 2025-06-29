module DebouncePulse (
    input wire clk,
    input wire rst_n,
    input wire btn_raw,
    output reg pulse_out
);

    parameter DEBOUNCE_TIME = 50000;  // 1ms @ 50MHz

    reg [15:0] counter;
    reg btn_sync_0, btn_sync_1;
    reg btn_debounced;
    reg btn_prev;

    // Đồng bộ hóa tín hiệu bất đồng bộ
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 0;
            btn_sync_1 <= 0;
        end else begin
            btn_sync_1 <= btn_raw;
            btn_sync_0 <= btn_sync_1;
        end
    end

    // Debounce logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            btn_debounced <= 0;
        end else if (btn_sync_1 != btn_debounced) begin
            counter <= counter + 1;
            if (counter >= DEBOUNCE_TIME) begin
                btn_debounced <= btn_sync_1;
                counter <= 0;
            end
        end else begin
            counter <= 0;
        end
    end

    // Tạo xung 1 chu kỳ khi rising edge
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pulse_out <= 0;
            btn_prev <= 0;
        end else begin
            pulse_out <= btn_debounced & ~btn_prev;
            btn_prev <= btn_debounced;
        end
    end
endmodule
