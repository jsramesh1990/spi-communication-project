// SPI Slave Module
// Implements SPI slave functionality

module spi_slave (
    // Clock and Reset
    input wire clk,
    input wire reset,
    
    // Control Interface
    input wire [7:0] data_tx,
    input wire tx_valid,
    output reg tx_ready,
    output reg [7:0] data_rx,
    output reg rx_valid,
    input wire rx_read,
    
    // SPI Physical Interface
    input wire sck,
    input wire mosi,
    output reg miso,
    input wire cs_n,
    
    // Status
    output reg busy,
    output reg error
);

    // Internal signals
    reg [7:0] shift_tx;
    reg [7:0] shift_rx;
    reg [2:0] bit_counter;
    reg last_cs_n;
    reg last_sck;
    reg sck_rising;
    reg sck_falling;
    
    // Synchronizers for external signals
    reg cs_n_sync;
    reg sck_sync;
    reg mosi_sync;
    
    // Double synchronizers for metastability protection
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cs_n_sync <= 1'b1;
            sck_sync <= 1'b0;
            mosi_sync <= 1'b0;
            last_cs_n <= 1'b1;
            last_sck <= 1'b0;
        end else begin
            // Synchronize external signals
            cs_n_sync <= cs_n;
            sck_sync <= sck;
            mosi_sync <= mosi;
            
            // Detect edges
            last_cs_n <= cs_n_sync;
            last_sck <= sck_sync;
        end
    end
    
    // Edge detection
    assign sck_rising = (sck_sync && !last_sck);
    assign sck_falling = (!sck_sync && last_sck);
    
    // Main state machine
    typedef enum logic [1:0] {
        IDLE        = 2'b00,
        TRANSFER    = 2'b01,
        COMPLETE    = 2'b10
    } state_t;
    
    state_t current_state;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            shift_tx <= 8'h00;
            shift_rx <= 8'h00;
            bit_counter <= 3'h0;
            miso <= 1'b0;
            data_rx <= 8'h00;
            rx_valid <= 1'b0;
            tx_ready <= 1'b1;
            busy <= 1'b0;
            error <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    tx_ready <= 1'b1;
                    busy <= 1'b0;
                    error <= 1'b0;
                    rx_valid <= 1'b0;
                    bit_counter <= 3'h0;
                    
                    // Load transmit data if available
                    if (tx_valid && tx_ready) begin
                        shift_tx <= data_tx;
                        tx_ready <= 1'b0;
                    end
                    
                    // CS falling edge starts transfer
                    if (cs_n_sync == 0 && last_cs_n == 1) begin
                        current_state <= TRANSFER;
                        busy <= 1'b1;
                    end
                end
                
                TRANSFER: begin
                    // Handle SCK edges
                    if (sck_rising) begin
                        // Sample MOSI on rising edge (for CPHA=0)
                        shift_rx <= {shift_rx[6:0], mosi_sync};
                        bit_counter <= bit_counter + 1;
                    end
                    
                    if (sck_falling) begin
                        // Output MISO on falling edge (for CPHA=0)
                        miso <= shift_tx[7];
                        shift_tx <= {shift_tx[6:0], 1'b0};
                    end
                    
                    // Check for completion
                    if (bit_counter == 8) begin
                        current_state <= COMPLETE;
                        data_rx <= shift_rx;
                    end
                    
                    // CS rising edge aborts transfer
                    if (cs_n_sync == 1 && last_cs_n == 0) begin
                        current_state <= IDLE;
                        error <= 1'b1;
                    end
                end
                
                COMPLETE: begin
                    rx_valid <= 1'b1;
                    current_state <= IDLE;
                    
                    // Clear rx_valid when data is read
                    if (rx_read) begin
                        rx_valid <= 1'b0;
                    end
                end
                
                default: begin
                    current_state <= IDLE;
                end
            endcase
        end
    end
    
endmodule
