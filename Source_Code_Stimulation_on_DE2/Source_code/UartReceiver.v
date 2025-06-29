module UartReceiver (
    input clk,                // Tín hiệu lấy mẫu UART (1 clk = 1/16 bit)
    input enable,             // Reset toàn module khi = 0
    input rx_in,              // Dữ liệu UART nối tiếp

    input parity_enable,      // Bật kiểm tra parity
    input parity_odd_even,    // 0: chẵn, 1: lẻ

    input rx_read,            // Đọc từ FIFO

    output reg [7:0] rx_data, // Dữ liệu nhận được
    output reg fifo_empty,
    output reg fifo_full,
    output reg error,
    output [2:0] current_state
);

    localparam STATE_IDLE        = 3'd0,
               STATE_START_BIT   = 3'd1,
               STATE_DATA_BIT    = 3'd2,
               STATE_PARITY_BIT  = 3'd3,
               STATE_STOP_BIT    = 3'd4;

    reg [2:0] state = STATE_IDLE;
    reg [2:0] bit_index = 0;
    reg [7:0] rx_shift = 0;
    reg parity_calc = 0;
    reg [3:0] tick_count = 0;   // đếm từ 0..15
    reg data_ready = 0;
	 assign current_state = state;
    // FIFO buffer
    reg [7:0] fifo [0:15];
    reg [3:0] fifo_wr_ptr = 0;
    reg [3:0] fifo_rd_ptr = 0;
    reg [4:0] fifo_count = 0;

    always @(*) begin
        fifo_empty = (fifo_count == 0);
        fifo_full  = (fifo_count == 16);
    end

    always @(posedge clk) begin
        if (!enable) begin
            fifo_wr_ptr <= 0;
            fifo_rd_ptr <= 0;
            fifo_count <= 0;
            rx_data <= 0;
        end else begin
            if (data_ready && !fifo_full) begin
                fifo[fifo_wr_ptr] <= rx_shift;
                fifo_wr_ptr <= fifo_wr_ptr + 1;
                fifo_count <= fifo_count + 1;
            end
            if (rx_read && !fifo_empty) begin
                rx_data <= fifo[fifo_rd_ptr];
                fifo_rd_ptr <= fifo_rd_ptr + 1;
                fifo_count <= fifo_count - 1;
            end
        end
    end

    always @(posedge clk) begin
        if (!enable) begin
            state <= STATE_IDLE;
            bit_index <= 0;
            rx_shift <= 0;
            parity_calc <= 0;
            tick_count <= 0;
            data_ready <= 0;
            error <= 0;
        end else begin
            data_ready <= 0;
            case (state)
                STATE_IDLE: begin
                    error <= 0;
                    tick_count <= 0;
                    if (rx_in == 0) begin
                        state <= STATE_START_BIT;
                        tick_count <= 0; // bắt đầu đếm baudtick
                    end
                end

                STATE_START_BIT: begin
                    tick_count <= tick_count + 1;
                    if (tick_count == 7) begin  // Lấy mẫu giữa bit start
                        if (rx_in == 0) begin
                            // chuẩn bị nhận data bits
                            tick_count <= 0;
                            bit_index <= 0;
                            parity_calc <= 0;
                            state <= STATE_DATA_BIT;
                        end else begin
                            state <= STATE_IDLE; // lỗi start bit
                        end
                    end
                end

                STATE_DATA_BIT: begin
                    tick_count <= tick_count + 1;
                    if (tick_count == 15) begin  // Lấy mẫu giữa bit data
                        rx_shift <= {rx_in, rx_shift[7:1]};		// LSB => MSB
                        parity_calc <= parity_calc ^ rx_in;
                        
								tick_count <= 0;
                        if (bit_index == 7) begin
                            state <= (parity_enable) ? STATE_PARITY_BIT : STATE_STOP_BIT;
                            bit_index <= 0;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end
                end
 
                STATE_PARITY_BIT: begin
                    tick_count <= tick_count + 1;
                    if (tick_count == 15) begin // lấy mẫu parity bit
                        if ((parity_odd_even && rx_in != ~parity_calc) ||
                            (!parity_odd_even && rx_in != parity_calc))
                            error <= 1;
                        tick_count <= 0;
                        state <= STATE_STOP_BIT;
                    end
                end

                STATE_STOP_BIT: begin
                    tick_count <= tick_count + 1;
                    if (tick_count == 15) begin // lấy mẫu stop bit
                        if (rx_in == 1) begin
                            if (!error)
                                data_ready <= 1;
                        end else begin
                            error <= 1;
                        end
                        tick_count <= 0;
                        state <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
