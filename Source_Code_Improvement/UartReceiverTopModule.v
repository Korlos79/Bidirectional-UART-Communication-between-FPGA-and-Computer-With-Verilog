module UartReceiverTopModule #(
    parameter CLOCK_FREQ = 50000000,
    parameter BAUD_RATE = 9600,
    parameter DATA_BITS = 8,
    parameter FIFO_DEPTH = 16,
    parameter STOP_BITS = 1
)(
    input wire clk,
    input wire rst,
    input wire rx,
    input wire parity_enable,
    input wire parity_type,
    input wire fifo_read,

    output wire [DATA_BITS-1:0] rx_data,
    output wire rx_data_ready,
    output wire parity_error,
    output wire framing_error,
    output wire [7:0] parity_error_count,
    output wire [7:0] framing_error_count,
    output wire fifo_empty,
    output wire fifo_full,
    output wire rx_overflow_error
);

wire baud_tick;

BaudRateGenerator #(
    .CLOCK_FREQ(CLOCK_FREQ),
    .BAUD_RATE(BAUD_RATE)
) baudgen (
    .clk(clk),
    .rst(rst),
    .baud_tick(baud_tick)
);

UartReceiver #(
    .DATA_BITS(DATA_BITS),
    .FIFO_DEPTH(FIFO_DEPTH),
    .STOP_BITS(STOP_BITS)
) receiver (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .parity_enable(parity_enable),
    .parity_type(parity_type),
    .baud_tick(baud_tick),
    .fifo_read(fifo_read),

    .rx_data(rx_data),
    .rx_data_ready(rx_data_ready),
    .parity_error(parity_error),
    .framing_error(framing_error),
    .parity_error_count(parity_error_count),
    .framing_error_count(framing_error_count),
    .fifo_empty(fifo_empty),
    .fifo_full(fifo_full),
    .rx_overflow_error(rx_overflow_error)
);

endmodule
