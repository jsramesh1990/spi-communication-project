// SPI Master Module
// Implements SPI master functionality with configurable modes

module spi_master #(
    parameter CLK_DIV_WIDTH = 8,
    parameter FIFO_DEPTH = 8
)(
    // Clock and Reset
    input wire clk,
    input wire reset,
    
    // Control Interface
    input wire start,
    input wire [7:0] data_tx,
    input wire [1:0] cpol_cpha,    // {CPOL, CPHA}
    input wire [CLK_DIV_WIDTH-1:0] clk_div,
    input wire cs_polarity,        // 0=active low, 1=active high
    input wire [1:0] cs_select,    // Chip select lines
    input wire loopback,           // Loopback mode for testing
    
    // Status Outputs
    output reg [7:0] data_rx,
    output reg busy,
    output reg done,
    output reg error,
    
    // FIFO Status
    output wire tx_fifo_full,
    output wire tx_fifo_empty,
    output wire rx_fifo_full,
    output wire rx_fifo_empty,
    
    // SPI Physical Interface
    output reg sck,
    output reg mosi,
    input wire miso,
    output reg [3:0] cs_n,
    
    // FIFO Interface
    input wire fifo_write_en,
    input wire [7:0] fifo_data_in,
    input wire fifo_read_en,
    output wire [7:0] fifo_data_out,
    
    // Interrupt
    output reg irq
);

    // Internal signals
    reg [CLK_DIV_WIDTH-1:0] clk_counter;
    reg [3:0] bit_counter;
    reg [7:0] shift_tx;
    reg [7:0] shift_rx;
    reg sck_int;
    reg last_sck;
    
    // FIFO signals
    wire [7:0] tx_fifo_out;
    wire tx_fifo_read_en;
    wire tx_fifo_write_en;
    wire rx_fifo_write_en;
    
    // State machine
    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        LOAD_DATA   = 3'b001,
        TRANSFER    = 3'b010,
        SAMPLE      = 3'b011,
        COMPLETE    = 3'b100,
        ERROR_STATE = 3'b101
    } state_t;
    
    state_t current_state, next_state;
    
    // FIFO Instances
    fifo #(
        .WIDTH(8),
        .DEPTH(FIFO_DEPTH)
    ) tx_fifo (
        .clk(clk),
        .reset(reset),
        .write_en(tx_fifo_write_en),
        .data_in(fifo_data_in),
        .read_en(tx_fifo_read_en),
        .data_out(tx_fifo_out),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty)
    );
    
    fifo #(
        .WIDTH(8),
        .DEPTH(FIFO_DEPTH)
    ) rx_fifo (
        .clk(clk),
        .reset(reset),
        .write_en(rx_fifo_write_en),
        .data_in(data_rx),
        .read_en(fifo_read_en),
        .data_out(fifo_data_out),
        .full(rx_fifo_full),
        .empty(rx_fifo_empty)
    );
    
    // FIFO control
    assign tx_fifo_write_en = fifo_write_en;
    assign tx_fifo_read_en = (current_state == LOAD_DATA) && !tx_fifo_empty;
    assign rx_fifo_write_en = (current_state == COMPLETE) && done;
    
    // Main state machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            sck <= 1'b0;
            mosi <= 1'b0;
            cs_n <= 4'b1111;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            irq <= 1'b0;
            clk_counter <= 0;
            bit_counter <= 0;
            shift_tx <= 8'h00;
            shift_rx <= 8'h00;
            sck_int <= 1'b0;
            last_sck <= 1'b0;
        end else begin
            current_state <= next_state;
            last_sck <= sck_int;
            
            case (current_state)
                IDLE: begin
                    sck_int <= cpol_cpha[1]; // Set idle state based on CPOL
                    sck <= cpol_cpha[1];
                    mosi <= 1'b0;
                    cs_n <= 4'b1111 ^ {4{cs_polarity}}; // Invert if active high
                    busy <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                    irq <= 1'b0;
                    clk_counter <= 0;
                    bit_counter <= 0;
                    
                    if (start || !tx_fifo_empty) begin
                        next_state <= LOAD_DATA;
                    end
                end
                
                LOAD_DATA: begin
                    // Activate chip select
                    cs_n <= ~(1 << cs_select) ^ {4{cs_polarity}};
                    busy <= 1'b1;
                    
                    if (!tx_fifo_empty) begin
                        shift_tx <= tx_fifo_out;
                        next_state <= TRANSFER;
                    end else if (start) begin
                        shift_tx <= data_tx;
                        next_state <= TRANSFER;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                TRANSFER: begin
                    clk_counter <= clk_counter + 1;
                    
                    // Generate SCK
                    if (clk_counter == (clk_div - 1)) begin
                        clk_counter <= 0;
                        sck_int <= ~sck_int;
                        sck <= sck_int;
                        
                        // Data handling based on CPHA
                        if (cpol_cpha[0] == 0) begin // CPHA=0
                            if (sck_int == cpol_cpha[1]) begin
                                // Output data on first edge
                                mosi <= shift_tx[7];
                                shift_tx <= {shift_tx[6:0], 1'b0};
                            end else begin
                                // Sample data on second edge
                                shift_rx <= {shift_rx[6:0], (loopback ? mosi : miso)};
                                bit_counter <= bit_counter + 1;
                            end
                        end else begin // CPHA=1
                            if (sck_int == cpol_cpha[1]) begin
                                // Sample data on first edge
                                shift_rx <= {shift_rx[6:0], (loopback ? mosi : miso)};
                                bit_counter <= bit_counter + 1;
                            end else begin
                                // Output data on second edge
                                mosi <= shift_tx[7];
                                shift_tx <= {shift_tx[6:0], 1'b0};
                            end
                        end
                        
                        if (bit_counter == 8) begin
                            next_state <= COMPLETE;
                        end
                    end
                end
                
                COMPLETE: begin
                    data_rx <= shift_rx;
                    done <= 1'b1;
                    irq <= 1'b1;
                    
                    if (!tx_fifo_empty) begin
                        next_state <= LOAD_DATA;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                ERROR_STATE: begin
                    error <= 1'b1;
                    irq <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
    
    // Continuous assignment for next_state (combinational)
    always @(*) begin
        next_state = current_state;
    end
    
endmodule

// Simple FIFO module
module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
)(
    input wire clk,
    input wire reset,
    input wire write_en,
    input wire [WIDTH-1:0] data_in,
    input wire read_en,
    output wire [WIDTH-1:0] data_out,
    output reg full,
    output reg empty
);
    
    reg [WIDTH-1:0] memory [0:DEPTH-1];
    reg [3:0] write_ptr;
    reg [3:0] read_ptr;
    reg [3:0] count;
    
    assign data_out = memory[read_ptr];
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            write_ptr <= 0;
            read_ptr <= 0;
            count <= 0;
            full <= 1'b0;
            empty <= 1'b1;
        end else begin
            // Write operation
            if (write_en && !full) begin
                memory[write_ptr] <= data_in;
                write_ptr <= (write_ptr == DEPTH-1) ? 0 : write_ptr + 1;
                count <= count + 1;
            end
            
            // Read operation
            if (read_en && !empty) begin
                read_ptr <= (read_ptr == DEPTH-1) ? 0 : read_ptr + 1;
                count <= count - 1;
            end
            
            // Update flags
            full <= (count == DEPTH);
            empty <= (count == 0);
        end
    end
    
endmodule
