module BaudRateGenerator (
    input clk,                // Clock 50 MHz
    input reset_n,            // Active-low reset
    input [1:0] baud_select,  // 00: 9600, 01: 14400, 10: 19200, 11: 115200

    output reg tx_clk,        // xung vuông (tần số = baudrate)
    output reg rx_clk         // xung vuông (tần số = baudrate * 16)
);

    // Divider values
    reg [15:0] divider_tx;
    reg [15:0] divider_rx;

    reg [15:0] counter_tx = 0;
    reg [15:0] counter_rx = 0;

    // Chọn hệ số chia tương ứng
    always @(*) begin
        case (baud_select)
            2'b00: begin // 9600
                divider_tx = 2604;   // Half-period: 50_000_000 / (2 * 9600)
                divider_rx = 163;    // Half-period: 50_000_000 / (2 * 9600 * 16)
            end
            2'b01: begin // 14400
                divider_tx = 1736;   // Half-period
                divider_rx = 109;    
            end
            2'b10: begin // 19200
                divider_tx = 1302;
                divider_rx = 82;
            end
            2'b11: begin // 115200
                divider_tx = 217;
                divider_rx = 13;
            end
            default: begin
                divider_tx = 2604;
                divider_rx = 163;
            end
        endcase
    end

    // Tạo tx_clk (dạng xung vuông)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter_tx <= 0;
            tx_clk <= 0;
        end else begin
            if (counter_tx >= divider_tx) begin
                counter_tx <= 0;
                tx_clk <= ~tx_clk;
            end else begin
                counter_tx <= counter_tx + 1;
            end
        end
    end

    // Tạo rx_clk (dạng xung vuông - oversample x16)
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter_rx <= 0;
            rx_clk <= 0;
        end else begin
            if (counter_rx >= divider_rx) begin
                counter_rx <= 0;
                rx_clk <= ~rx_clk;
            end else begin
                counter_rx <= counter_rx + 1;
            end
        end
    end

endmodule
