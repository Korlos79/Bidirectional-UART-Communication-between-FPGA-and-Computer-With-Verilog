module UartReceiver #(
    parameter DATA_BITS = 8,
    parameter FIFO_DEPTH = 16,
    parameter STOP_BITS = 1
)(
    input wire clk,
    input wire rst,
    input wire rx,
    input wire parity_enable,
    input wire parity_type,
    input wire baud_tick,
    input wire fifo_read,

    output reg [DATA_BITS-1:0] rx_data,
    output reg rx_data_ready,
    output reg parity_error,
    output reg framing_error,
    output reg [7:0] parity_error_count,
    output reg [7:0] framing_error_count,
    output reg fifo_empty,
    output reg fifo_full,
    output reg rx_overflow_error
);

parameter IDLE           = 3'b000;
parameter START_BIT      = 3'b001;
parameter DATA_BITS_STATE = 3'b010;
parameter PARITY_BIT     = 3'b011;
parameter STOP_BIT       = 3'b100;

reg [2:0] state;
reg [3:0] bit_index;
reg [DATA_BITS:0] shift_reg; // MSB for parity bit if enabled
reg [1:0] stop_bit_count;
reg calculated_parity;
reg data_valid;

reg [DATA_BITS-1:0] fifo [0:FIFO_DEPTH-1];
reg [$clog2(FIFO_DEPTH)-1:0] fifo_wr_ptr, fifo_rd_ptr;
reg [$clog2(FIFO_DEPTH):0] fifo_count;

wire [DATA_BITS-1:0] received_byte = shift_reg[DATA_BITS-1:0];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        bit_index <= 0;
        shift_reg <= 0;
        parity_error <= 0;
        framing_error <= 0;
        parity_error_count <= 0;
        framing_error_count <= 0;
        stop_bit_count <= 0;
        data_valid <= 0;
        calculated_parity <= 0;
    end else if (baud_tick) begin
        data_valid <= 0;
        parity_error <= 0;
        framing_error <= 0;

        case (state)
            IDLE: begin
                if (rx == 1'b0) begin
                    state <= START_BIT;
                end
            end

            START_BIT: begin
                if (rx == 1'b0) begin
                    bit_index <= DATA_BITS - 1;
                    shift_reg <= 0;
                    state <= DATA_BITS_STATE;
                end else begin
                    state <= IDLE;
                end
            end

            DATA_BITS_STATE: begin
                shift_reg[bit_index] <= rx;
                if (bit_index > 0) begin
                    bit_index <= bit_index - 1;
                end else begin
                    calculated_parity <= ^shift_reg[DATA_BITS-1:0];
                    state <= parity_enable ? PARITY_BIT : STOP_BIT;
                end
            end

            PARITY_BIT: begin
                shift_reg[DATA_BITS] <= rx;
                // Check parity
                if ((parity_type == 1'b0 && calculated_parity != rx) ||
                    (parity_type == 1'b1 && calculated_parity == rx)) begin
                    parity_error <= 1;
                    if (parity_error_count < 8'hFF)
                        parity_error_count <= parity_error_count + 1;
                end
                stop_bit_count <= 0;
                state <= STOP_BIT;
            end

            STOP_BIT: begin
                if (rx != 1'b1) begin
                    framing_error <= 1;
                    if (framing_error_count < 8'hFF)
                        framing_error_count <= framing_error_count + 1;
                    state <= IDLE;
                end else begin
                    if (stop_bit_count < STOP_BITS - 1) begin
                        stop_bit_count <= stop_bit_count + 1;
                    end else begin
                        if (!parity_error) begin
                            data_valid <= 1;
                        end
                        state <= IDLE;
                    end
                end
            end

            default: state <= IDLE;
        endcase
    end
end

// FIFO Logic
always @(posedge clk or posedge rst) begin
    if (rst) begin
        fifo_rd_ptr <= 0;
        fifo_wr_ptr <= 0;
        fifo_count <= 0;
        fifo_empty <= 1;
        fifo_full <= 0;
        rx_data_ready <= 0;
        rx_data <= 0;
        rx_overflow_error <= 0;
    end else begin
        rx_data_ready <= 0;
        rx_overflow_error <= 0;

        // Write to FIFO
        if (data_valid) begin
            if (!fifo_full) begin
                fifo[fifo_wr_ptr] <= received_byte;
                fifo_wr_ptr <= (fifo_wr_ptr + 1) % FIFO_DEPTH;
                fifo_count <= fifo_count + 1;
                fifo_empty <= 0;
                if (fifo_count == FIFO_DEPTH - 1)
                    fifo_full <= 1;
            end else begin
                rx_overflow_error <= 1; // Buffer full
            end
        end

        // Read from FIFO
        if (fifo_read && !fifo_empty) begin
            rx_data <= fifo[fifo_rd_ptr];
            rx_data_ready <= 1;
            fifo_rd_ptr <= (fifo_rd_ptr + 1) % FIFO_DEPTH;
            fifo_count <= fifo_count - 1;
            fifo_full <= 0;
            if (fifo_count == 1)
                fifo_empty <= 1;
        end
    end
end

endmodule
