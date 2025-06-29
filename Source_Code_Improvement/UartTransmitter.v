module UartTransmitter #(
    parameter DATA_BITS = 8,       // Số bit dữ liệu (5-9)
    parameter STOP_BITS = 1,       // 1 hoặc 2 stop bits
    parameter TIMEOUT_CYCLES = 10400  // Timeout sau số chu kỳ không hoạt động
)(
    input wire clk,                // clock hệ thống
    input wire rst_n,              // reset đồng bộ active low
	 input wire ENABLE_PARITY,
	 input wire PARITY_TYPE,
    input wire baud_tick,          // 1 xung mỗi bit time (baud rate generator)                
    input wire write,              // start transmission
	 input wire read,
    input wire [DATA_BITS-1:0] in, // dữ liệu song song để gửi
    output reg busy,               // đang truyền
    output reg done,               // kết thúc truyền
    output reg out,                // chân TX
	 output reg data_loaded,
    output reg tx_error            // lỗi timeout/frame
);

// State machine
localparam STATE_IDLE      = 3'b000;
localparam STATE_START_BIT = 3'b001;
localparam STATE_DATA      = 3'b010;
localparam STATE_PARITY    = 3'b011;
localparam STATE_STOP      = 3'b100;

reg [2:0] state;
reg [DATA_BITS-1:0] in_data;
reg [3:0] bit_index;  // 4 bits đủ cho DATA_BITS <= 9
reg [1:0] stop_bit_count;
reg parity_bit_to_send;
reg [$clog2(TIMEOUT_CYCLES+1)-1:0] timeout_counter;

reg [DATA_BITS-1:0] fifo [0:15];
reg [4:0] fifo_count;
reg [3:0] fifo_wr_ptr, fifo_rd_ptr;
reg fifo_read;  

wire fifo_empty = (fifo_count == 0);
wire fifo_full  = (fifo_count == 16);

wire parity_even = ^in_data;
wire parity_to_send = (PARITY_TYPE == 1) ? ~parity_even : parity_even;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_wr_ptr <= 0;
        fifo_rd_ptr <= 0;
        fifo_count  <= 0;
		  data_loaded <= 0;
    end else begin
	 data_loaded <= 0;
        case ({!write && !fifo_full , fifo_read})
            2'b01: begin  
                fifo_rd_ptr <= (fifo_rd_ptr + 1) & 4'hF;
                fifo_count <= fifo_count - 1;
            end
            2'b10: begin  
                fifo[fifo_wr_ptr] <= in;
                fifo_wr_ptr <= (fifo_wr_ptr + 1) & 4'hF;
                fifo_count <= fifo_count + 1;
					 data_loaded <= 1;
            end
            2'b11: begin  
                fifo[fifo_wr_ptr] <= in;
                fifo_wr_ptr <= (fifo_wr_ptr + 1) & 4'hF;
                fifo_rd_ptr <= (fifo_rd_ptr + 1) & 4'hF;
					 data_loaded <= 1;
            end
        endcase
    end
end

// FSM chính
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        busy <= 0;
        done <= 0;
        out  <= 1;
        tx_error <= 0;
        stop_bit_count <= 0;
        bit_index <= 0;
        timeout_counter <= 0;
        in_data <= 0;
        parity_bit_to_send <= 0;
        fifo_read <= 0;
    end else begin
        fifo_read <= 0;
        done <= 0;
        if (state != STATE_IDLE) begin  
            if (baud_tick) begin
                timeout_counter <= 0;  
            end else if (timeout_counter < TIMEOUT_CYCLES) begin
                timeout_counter <= timeout_counter + 1;
            end else begin
                // Timeout occurred
                tx_error <= 1;
                state <= STATE_IDLE;
                busy <= 0;
                out <= 1;
                timeout_counter <= 0;
            end
        end else begin
            timeout_counter <= 0;
            tx_error <= 0;
        end

        if (baud_tick) begin
            case (state)
                STATE_IDLE: begin
                    if (!fifo_empty && !read) begin
                        in_data <= fifo[fifo_rd_ptr];
                        bit_index <= 0;
                       
                        if (ENABLE_PARITY)
                            parity_bit_to_send <= (PARITY_TYPE == 1) ? 
                                                 ~(^fifo[fifo_rd_ptr]) : 
                                                 (^fifo[fifo_rd_ptr]);

                        fifo_read <= 1;

                        busy <= 1;
                        state <= STATE_START_BIT;
                        out <= 0;  
                    end else begin
                        out <= 1;  
                        busy <= 0;
                    end
                end

                STATE_START_BIT: begin
                    out <= 0;  
                    state <= STATE_DATA;
                end

                STATE_DATA: begin
                    out <= in_data[bit_index];
                    if (bit_index < DATA_BITS - 1) begin
                        bit_index <= bit_index + 1;
                    end else begin
                        if (ENABLE_PARITY) begin
                            state <= STATE_PARITY;
                        end else begin
                            state <= STATE_STOP;
                            stop_bit_count <= 0;
                        end
                    end
                end

                STATE_PARITY: begin
                    out <= parity_bit_to_send;
                    state <= STATE_STOP;
                    stop_bit_count <= 0;
                end

                STATE_STOP: begin
                    out <= 1;  
                    if (stop_bit_count < STOP_BITS - 1) begin
                        stop_bit_count <= stop_bit_count + 1;
                    end else begin
                        state <= STATE_IDLE;
                        busy <= 0;
                        done <= 1;
                        stop_bit_count <= 0;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    out <= 1;
                    busy <= 0;
                end
            endcase
        end
    end
end

endmodule