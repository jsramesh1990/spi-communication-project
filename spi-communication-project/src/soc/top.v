// Top-level SoC Module
// Integrates SPI controller with minimal SoC components

module top (
    // Clock and Reset
    input wire clk_50mhz,
    input wire reset_n,
    
    // SPI Interface
    output wire spi_sck,
    output wire spi_mosi,
    input wire spi_miso,
    output wire [3:0] spi_cs_n,
    
    // GPIO/LEDs for testing
    output wire [7:0] leds,
    
    // UART for debug (optional)
    output wire uart_tx,
    input wire uart_rx,
    
    // Push buttons for testing
    input wire [3:0] buttons
);

    // Internal signals
    wire clk;
    wire reset;
    wire locked;
    
    // Wishbone bus signals
    wire [31:0] wb_addr;
    wire [31:0] wb_data_m2s;  // Master to slave
    wire [31:0] wb_data_s2m;  // Slave to master
    wire wb_we;
    wire wb_stb;
    wire wb_cyc;
    wire wb_ack;
    wire wb_irq;
    
    // Memory signals
    wire [31:0] mem_addr;
    wire [31:0] mem_data_out;
    wire [31:0] mem_data_in;
    wire mem_we;
    wire mem_en;
    
    // Clock and reset generation
    assign clk = clk_50mhz;
    assign reset = ~reset_n;
    
    // Simple CPU/Memory Controller
    simple_cpu cpu_inst (
        .clk(clk),
        .reset(reset),
        
        // Wishbone master interface
        .wb_addr_o(wb_addr),
        .wb_data_o(wb_data_m2s),
        .wb_data_i(wb_data_s2m),
        .wb_we_o(wb_we),
        .wb_stb_o(wb_stb),
        .wb_cyc_o(wb_cyc),
        .wb_ack_i(wb_ack),
        .wb_irq_i(wb_irq),
        
        // Memory interface
        .mem_addr_o(mem_addr),
        .mem_data_o(mem_data_out),
        .mem_data_i(mem_data_in),
        .mem_we_o(mem_we),
        .mem_en_o(mem_en),
        
        // GPIO
        .gpio_o(leds),
        .gpio_i(buttons)
    );
    
    // Block RAM for program/data storage
    block_ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(32)
    ) bram_inst (
        .clk(clk),
        .addr(mem_addr[13:2]),  // Word addressing
        .data_in(mem_data_out),
        .data_out(mem_data_in),
        .we(mem_we),
        .en(mem_en)
    );
    
    // SPI Controller instance
    spi_controller #(
        .BASE_ADDR(32'h4000_0000)
    ) spi_ctrl_inst (
        .clk(clk),
        .reset(reset),
        
        // Wishbone slave interface
        .wb_addr_i(wb_addr),
        .wb_data_o(wb_data_s2m),
        .wb_data_i(wb_data_m2s),
        .wb_we_i(wb_we),
        .wb_stb_i(wb_stb),
        .wb_cyc_i(wb_cyc),
        .wb_ack_o(wb_ack),
        
        // Interrupt
        .irq_o(wb_irq),
        
        // SPI interface
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n)
    );
    
    // Simple UART for debug output
    simple_uart uart_inst (
        .clk(clk),
        .reset(reset),
        .tx_data(8'h00),
        .tx_valid(1'b0),
        .tx_ready(),
        .rx_data(),
        .rx_valid(),
        .tx(uart_tx),
        .rx(uart_rx)
    );
    
endmodule

// Simple CPU module (placeholder)
module simple_cpu (
    input wire clk,
    input wire reset,
    
    // Wishbone master interface
    output reg [31:0] wb_addr_o,
    output reg [31:0] wb_data_o,
    input wire [31:0] wb_data_i,
    output reg wb_we_o,
    output reg wb_stb_o,
    output reg wb_cyc_o,
    input wire wb_ack_i,
    input wire wb_irq_i,
    
    // Memory interface
    output wire [31:0] mem_addr_o,
    output wire [31:0] mem_data_o,
    input wire [31:0] mem_data_i,
    output wire mem_we_o,
    output wire mem_en_o,
    
    // GPIO
    output reg [7:0] gpio_o,
    input wire [3:0] gpio_i
);

    // Simple state machine for testing
    typedef enum logic [2:0] {
        IDLE,
        FETCH,
        DECODE,
        EXECUTE,
        WRITE_BACK,
        INTERRUPT
    } state_t;
    
    state_t current_state;
    reg [31:0] pc;
    reg [31:0] instruction;
    reg [4:0] reg_file [0:31];
    
    assign mem_addr_o = pc;
    assign mem_data_o = 32'h0;
    assign mem_we_o = 1'b0;
    assign mem_en_o = 1'b1;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            pc <= 32'h0000_0000;
            wb_addr_o <= 32'h0;
            wb_data_o <= 32'h0;
            wb_we_o <= 1'b0;
            wb_stb_o <= 1'b0;
            wb_cyc_o <= 1'b0;
            gpio_o <= 8'h00;
        end else begin
            case (current_state)
                IDLE: begin
                    current_state <= FETCH;
                end
                
                FETCH: begin
                    instruction <= mem_data_i;
                    pc <= pc + 4;
                    current_state <= DECODE;
                end
                
                DECODE: begin
                    // Simple decode logic
                    current_state <= EXECUTE;
                end
                
                EXECUTE: begin
                    // Simple execution
                    current_state <= WRITE_BACK;
                end
                
                WRITE_BACK: begin
                    current_state <= FETCH;
                end
                
                INTERRUPT: begin
                    if (wb_irq_i) begin
                        // Handle interrupt
                        current_state <= FETCH;
                    end
                end
            endcase
        end
    end
    
endmodule

// Block RAM module
module block_ram #(
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    input wire we,
    input wire en
);
    
    // Memory array
    reg [DATA_WIDTH-1:0] memory [0:(1<<ADDR_WIDTH)-1];
    
    // Initialize with test program
    initial begin
        // NOP instructions
        for (int i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
            memory[i] = 32'h0000_0000; // NOP
        end
        
        // Simple test program at address 0
        memory[0] = 32'h0000_0000; // NOP
        memory[1] = 32'h0000_0000; // NOP
        memory[2] = 32'h0000_0000; // NOP
    end
    
    always @(posedge clk) begin
        if (en) begin
            if (we) begin
                memory[addr] <= data_in;
            end
            data_out <= memory[addr];
        end
    end
    
endmodule

// Simple UART module
module simple_uart (
    input wire clk,
    input wire reset,
    input wire [7:0] tx_data,
    input wire tx_valid,
    output wire tx_ready,
    output wire [7:0] rx_data,
    output wire rx_valid,
    output wire tx,
    input wire rx
);
    
    // Simplified UART - just pass through for now
    assign tx = 1'b1;
    assign tx_ready = 1'b1;
    assign rx_data = 8'h00;
    assign rx_valid = 1'b0;
    
endmodule
