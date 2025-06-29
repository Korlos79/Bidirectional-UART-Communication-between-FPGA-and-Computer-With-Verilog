module UartTransmitter (
    input clk,                // Xung baud rate (1 clk = 1 bit truyền)
    input enable,            // Nếu enable = 0, reset toàn bộ module
    input tx_start,          // Ghi dữ liệu vào FIFO
    input [7:0] tx_in,       // Dữ liệu đầu vào

    input parity_enable,     // Bật/tắt parity
    input parity_odd_even,   // 0: chẵn, 1: lẻ

    output reg out,          // Tín hiệu UART nối tiếp
    output reg busy,			  // Cờ báo đang truyền dữ liệu (1: đang bận)
    output reg done,			  // Cờ báo truyền xong 1 chu kì truyền 
	 output [2:0] current_state  // Trạng thái hiện tại
);

localparam STATE_IDLE        = 3'd0,
           STATE_START_BIT   = 3'd1,
           STATE_DATA_BIT    = 3'd2,
           STATE_PARITY_BIT  = 3'd3,
           STATE_STOP_BIT    = 3'd4;

reg [2:0] state = STATE_IDLE;
reg [2:0] bit_index = 0;
reg [7:0] tx_shift = 0;
reg [7:0] parity_calc_data = 0;
reg parity_bit;

// FIFO 16-byte
reg [7:0] fifo [0:15];
reg [3:0] fifo_wr_ptr = 0;
reg [3:0] fifo_rd_ptr = 0;
reg [4:0] fifo_count = 0;

wire fifo_empty = (fifo_count == 0);
wire fifo_full  = (fifo_count == 16);

assign current_state = state; // Trạng thái hiện tại

// Tính parity
always @(*) begin
    if (parity_enable)
        parity_bit = parity_odd_even ^ (^parity_calc_data);
    else
        parity_bit = 1'b0;
end

// FIFO điều khiển ghi/đọc
always @(posedge clk) begin
    if (!enable) begin
        fifo_wr_ptr <= 0;
        fifo_rd_ptr <= 0;
        fifo_count <= 0;
    end else begin
        if (tx_start && !fifo_full) begin
            fifo[fifo_wr_ptr] <= tx_in;
            fifo_wr_ptr <= fifo_wr_ptr + 1;
            fifo_count <= fifo_count + 1;
        end
        if (state == STATE_IDLE && !fifo_empty) begin
            fifo_rd_ptr <= fifo_rd_ptr + 1;
            fifo_count <= fifo_count - 1;
        end
    end
end

// FSM UART
always @(posedge clk) begin
    if (!enable) begin
        state <= STATE_IDLE;
        out <= 1'b1;
        busy <= 0;
        done <= 0;
        bit_index <= 0;
        tx_shift <= 0;
    end else begin
		done <= 0;
        case (state)
            STATE_IDLE: begin
                out <= 1'b1;
                busy <= 0;
                if (!fifo_empty) begin
                    tx_shift <= fifo[fifo_rd_ptr];
                    parity_calc_data <= fifo[fifo_rd_ptr];
                    state <= STATE_START_BIT;
                    busy <= 1;
                end
            end

            STATE_START_BIT: begin
                out <= 1'b0;
                bit_index <= 0;
                state <= STATE_DATA_BIT;
            end

            STATE_DATA_BIT: begin
                out <= tx_shift[0];
                tx_shift <= tx_shift >> 1; // Truyền từ LSB trước
                bit_index <= bit_index + 1;
                if (bit_index == 3'd7) begin
                    state <= (parity_enable) ? STATE_PARITY_BIT : STATE_STOP_BIT;
                end
            end

            STATE_PARITY_BIT: begin
                out <= parity_bit;
                state <= STATE_STOP_BIT;
            end

            STATE_STOP_BIT: begin
                out <= 1'b1;
                state <= STATE_IDLE;
                busy <= 0;
                done <= 1;
            end
        endcase
    end
end

endmodule
