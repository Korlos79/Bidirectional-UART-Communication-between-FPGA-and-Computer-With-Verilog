module UartTopTransmitter (
    input clk,                 // Clock 50 MHz từ KIT
    input reset_n,             // Reset active low
    input [1:0] baud_select,   // Chọn baudrate: 00:9600, 01:14400, 10:19200, 11:115200

    input tx_start,            // Tín hiệu bắt đầu gửi dữ liệu (1 pulse)
    input [7:0] tx_data_in,    // Dữ liệu cần truyền

    input parity_enable,       // Bật/tắt parity
    input parity_odd_even,     // 0: even parity, 1: odd parity

    output tx,                 // Tín hiệu UART truyền ra
    output busy,               // Báo transmitter đang bận truyền
	 output done,
	 
	 output [6:0] HEX1, HEX0
);

    wire baud_clk;

    // Tạo clock baud rate truyền
    BaudRateGenerator baudgen (
        .clk(clk),
        .reset_n(reset_n),
        .baud_select(baud_select),
        .tx_clk(baud_clk),
        .rx_clk()            // Không dùng
    );

    // Kết nối UART Transmitter
    UartTransmitter uart_tx (
        .clk(baud_clk),
        .enable(reset_n),
        .tx_start(~tx_start),
        .tx_in(tx_data_in),
        .parity_enable(parity_enable),
        .parity_odd_even(parity_odd_even),
        .out(tx),
        .busy(busy),
        .done(done)
    );
	 
	 //Hiển thị dữ liệu đang truyền 
	 SevenSegmentDecoder seg_low (
    .bin(tx_data_in[3:0]),
    .seg(HEX0)
	 );
	 
	 SevenSegmentDecoder seg_high (
    .bin(tx_data_in[7:4]),
    .seg(HEX1)
	 );
endmodule
