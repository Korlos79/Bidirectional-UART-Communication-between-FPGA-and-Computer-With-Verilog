module UartTopReceiver (
    input clk,                 // Clock 50 MHz từ KIT
    input reset_n,            // Nút reset (active low)
    input [1:0] baud_select,  // Lựa chọn baudrate (00: 9600, ...)
    input rx_in,              // Tín hiệu UART từ PuTTY

    input parity_enable,      // Bật/tắt kiểm tra parity
    input parity_odd_even,    // 0: even, 1: odd

    input rx_read,            // Tín hiệu đọc dữ liệu từ FIFO

    output [7:0] rx_data,     // Dữ liệu nhận được
    output fifo_empty,
    output fifo_full,
    output error,
    output [2:0] current_state,
	 
	 output [6:0] HEX1, HEX0
);

    wire rx_clk;

    // Kết nối BaudRateGenerator
    BaudRateGenerator baudgen (
        .clk(clk),
        .reset_n(reset_n),
        .baud_select(baud_select),
        .tx_clk(),       // Không dùng truyền trong mạch này
        .rx_clk(rx_clk)  // Dùng clock này cho UART Receiver
    );

    // Kết nối UartReceiver
    UartReceiver receiver (
        .clk(rx_clk),              // clock tốc độ cao (16x baudrate)
        .enable(reset_n),          // reset module khi reset_n = 0
        .rx_in(rx_in),

        .parity_enable(parity_enable),
        .parity_odd_even(parity_odd_even),

        .rx_read(~rx_read),

        .rx_data(rx_data),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .error(error),
        .current_state(current_state)
    );
	 //Hiển thị dữ liệu đang truyền 
	 SevenSegmentDecoder seg_low (
    .bin(rx_data[3:0]),
    .seg(HEX0)
	 );
	 
	 SevenSegmentDecoder seg_high (
    .bin(rx_data[7:4]),
    .seg(HEX1)
	 );

endmodule
