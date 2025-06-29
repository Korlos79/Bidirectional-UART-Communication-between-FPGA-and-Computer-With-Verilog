module UartTransmitterTopModule #(
    parameter CLOCK_FREQ = 50000000,
    parameter BAUD_RATE = 9600,
    parameter DATA_BITS = 8,
    parameter STOP_BITS = 1,
    parameter TIMEOUT_CYCLES = 10400
)(
    input wire clk,
    input wire rst_n,
    input wire [DATA_BITS-1:0] tx_data,
    input wire enable_parity,
    input wire parity_type,  // 0: even, 1: odd
    input wire key_read,     // KEY[1]
    input wire key_write,    // KEY[2]

    output wire tx,
    output wire busy,
    output wire done,
    output wire data_loaded,
    output wire tx_error
);

    wire baud_tick;
    wire tx_write_pulse;
    wire tx_read_pulse;

    // Module tạo tick theo baudrate
    BaudRateGenerator #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) baud_gen (
        .clk(clk),
        .rst(rst_n),      
        .baud_tick(baud_tick)
    );

    // Debounce & pulse KEY[2] -> write
    DebouncePulse debounce_write (
        .clk(clk),
        .rst_n(rst_n),
        .btn_raw(key_write),
        .pulse_out(tx_write_pulse)
    );

    // Debounce & pulse KEY[1] -> read
    DebouncePulse debounce_read (
        .clk(clk),
        .rst_n(rst_n),
        .btn_raw(key_read),
        .pulse_out(tx_read_pulse)
    );

    // UartTransmitter chính
    UartTransmitter #(
        .DATA_BITS(DATA_BITS),
        .STOP_BITS(STOP_BITS),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .ENABLE_PARITY(enable_parity),
        .PARITY_TYPE(parity_type),
        .baud_tick(baud_tick),
        .write(tx_write_pulse),
        .read(tx_read_pulse),
        .in(tx_data),
        .busy(busy),
        .done(done),
        .out(tx),
        .data_loaded(data_loaded),
        .tx_error(tx_error)
    );

endmodule
