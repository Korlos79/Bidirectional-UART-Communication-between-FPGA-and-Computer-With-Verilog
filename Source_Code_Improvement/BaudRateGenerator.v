module BaudRateGenerator #(
    parameter CLOCK_FREQ = 50000000,    // Clock frequency in Hz
    parameter BAUD_RATE  = 9600         // Desired baudrate
)(
    input wire clk,
    input wire rst,
    output reg baud_tick
);

    localparam integer BAUD_DIVISOR = CLOCK_FREQ / BAUD_RATE;

    reg [$clog2(BAUD_DIVISOR)-1:0] counter;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            counter <= 0;
            baud_tick <= 0;
        end else begin
            if (counter == BAUD_DIVISOR - 1) begin
                counter <= 0;
                baud_tick <= 1;
            end else begin
                counter <= counter + 1;
                baud_tick <= 0;
            end
        end
    end

endmodule
