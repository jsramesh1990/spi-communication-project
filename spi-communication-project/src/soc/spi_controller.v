// SPI Controller with Register Interface
// Provides memory-mapped interface for SPI operations

module spi_controller #(
    parameter BASE_ADDR = 32'h4000_0000
)(
    // Clock and Reset
    input wire clk,
    input wire reset,
    
    // Wishbone Bus Interface
    input wire [31:0] wb_addr_i,
    output reg [31:0] wb_data_o,
    input wire [31:0] wb_data_i,
    input wire wb_we_i,
    input wire wb_stb_i,
    input wire wb_cyc_i,
    output reg wb_ack_o,
    
    // Interrupt
    output wire irq_o,
    
    // SPI Interface
    output wire spi_sck,
    output wire spi_mosi,
    input wire spi_miso,
    output wire [3:0] spi_cs_n
);

    // Register addresses
    localparam REG_CONTROL  = 8'h00;
    localparam REG_STATUS   = 8'h04;
    localparam REG_TX_DATA  = 8'h08;
    localparam REG_RX_DATA  = 8'h0C;
    localparam REG_CLK_DIV  = 8'h10;
    localparam REG_TX_FIFO  = 8'h14;
    localparam REG_RX_FIFO  = 8'h18;
    localparam REG_IRQ_EN   = 8'h1C;
    localparam REG_VERSION  = 8'h20;
    
    // Control register bits
    localparam CTRL_START     = 0;
    localparam CTRL_MODE0     = 1;
    localparam CTRL_MODE1     = 2;
    localparam CTRL_CS_SEL0   = 3;
    localparam CTRL_CS_SEL1   = 4;
    localparam CTRL_IRQ_EN    = 5;
    localparam CTRL_DMA_EN    = 6;
    localparam CTRL_LOOPBACK  = 7;
    localparam CTRL_CS_POL    = 8;
    
    // Status register bits
    localparam STAT_BUSY      = 0;
    localparam STAT_DONE      = 1;
    localparam STAT_TX_FULL   = 2;
    localparam STAT_TX_EMPTY  = 3;
    localparam STAT_RX_FULL   = 4;
    localparam STAT_RX_EMPTY  = 5;
    localparam STAT_ERROR     = 6;
    localparam STAT_IRQ_PEND  = 7;
    
    // Internal registers
    reg [31:0] control_reg;
    reg [31:0] status_reg;
    reg [31:0] tx_data_reg;
    reg [31:0] rx_data_reg;
    reg [31:0] clk_div_reg;
    reg [31:0] irq_en_reg;
    reg [31:0] version_reg;
    
    // Internal signals
    wire spi_busy;
    wire spi_done;
    wire spi_error;
    wire [7:0] spi_data_rx;
    wire tx_fifo_full;
    wire tx_fifo_empty;
    wire rx_fifo_full;
    wire rx_fifo_empty;
    wire [7:0] fifo_data_out;
    
    // SPI mode
    wire [1:0] spi_mode = {control_reg[CTRL_MODE1], control_reg[CTRL_MODE0]};
    
    // Chip select
    wire [1:0] cs_sel = {control_reg[CTRL_CS_SEL1], control_reg[CTRL_CS_SEL0]};
    
    // FIFO signals
    reg fifo_write_en;
    reg fifo_read_en;
    wire [7:0] fifo_data_in = wb_data_i[7:0];
    
    // Wishbone address match
    wire addr_match = (wb_addr_i[31:8] == BASE_ADDR[31:8]);
    wire [7:0] reg_addr = wb_addr_i[7:0];
    
    // SPI Master instance
    spi_master #(
        .CLK_DIV_WIDTH(8),
        .FIFO_DEPTH(8)
    ) spi_master_inst (
        .clk(clk),
        .reset(reset),
        .start(control_reg[CTRL_START]),
        .data_tx(tx_data_reg[7:0]),
        .cpol_cpha(spi_mode),
        .clk_div(clk_div_reg[7:0]),
        .cs_polarity(control_reg[CTRL_CS_POL]),
        .cs_select(cs_sel),
        .loopback(control_reg[CTRL_LOOPBACK]),
        .data_rx(spi_data_rx),
        .busy(spi_busy),
        .done(spi_done),
        .error(spi_error),
        .tx_fifo_full(tx_fifo_full),
        .tx_fifo_empty(tx_fifo_empty),
        .rx_fifo_full(rx_fifo_full),
        .rx_fifo_empty(rx_fifo_empty),
        .sck(spi_sck),
        .mosi(spi_mosi),
        .miso(spi_miso),
        .cs_n(spi_cs_n),
        .fifo_write_en(fifo_write_en),
        .fifo_data_in(fifo_data_in),
        .fifo_read_en(fifo_read_en),
        .fifo_data_out(fifo_data_out),
        .irq(irq_o)
    );
    
    // Register initialization
    initial begin
        control_reg = 32'h0000_0000;
        status_reg = 32'h0000_0020; // TX_EMPTY and RX_EMPTY set
        tx_data_reg = 32'h0000_0000;
        rx_data_reg = 32'h0000_0000;
        clk_div_reg = 32'h0000_0004; // Default divider = 4
        irq_en_reg = 32'h0000_0000;
        version_reg = 32'h0001_0000; // Version 1.0
    end
    
    // Wishbone write cycle
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            control_reg <= 32'h0000_0000;
            tx_data_reg <= 32'h0000_0000;
            clk_div_reg <= 32'h0000_0004;
            irq_en_reg <= 32'h0000_0000;
            fifo_write_en <= 1'b0;
            fifo_read_en <= 1'b0;
            wb_ack_o <= 1'b0;
        end else begin
            // Default values
            fifo_write_en <= 1'b0;
            fifo_read_en <= 1'b0;
            wb_ack_o <= 1'b0;
            
            // Wishbone transaction
            if (wb_cyc_i && wb_stb_i && addr_match) begin
                wb_ack_o <= 1'b1;
                
                if (wb_we_i) begin
                    // Write operation
                    case (reg_addr)
                        REG_CONTROL: begin
                            control_reg <= wb_data_i;
                            // Auto-clear start bit after setting
                            if (wb_data_i[CTRL_START]) begin
                                control_reg[CTRL_START] <= 1'b1;
                            end
                        end
                        REG_TX_DATA: begin
                            tx_data_reg <= wb_data_i;
                        end
                        REG_CLK_DIV: begin
                            clk_div_reg <= wb_data_i;
                        end
                        REG_TX_FIFO: begin
                            fifo_write_en <= 1'b1;
                        end
                        REG_RX_FIFO: begin
                            fifo_read_en <= 1'b1;
                        end
                        REG_IRQ_EN: begin
                            irq_en_reg <= wb_data_i;
                        end
                        default: begin
                            // Do nothing for unknown registers
                        end
                    endcase
                end
                
                // Auto-clear start bit
                if (control_reg[CTRL_START] && spi_busy) begin
                    control_reg[CTRL_START] <= 1'b0;
                end
            end
        end
    end
    
    // Status register update
    always @(posedge clk) begin
        status_reg[STAT_BUSY] <= spi_busy;
        status_reg[STAT_DONE] <= spi_done;
        status_reg[STAT_TX_FULL] <= tx_fifo_full;
        status_reg[STAT_TX_EMPTY] <= tx_fifo_empty;
        status_reg[STAT_RX_FULL] <= rx_fifo_full;
        status_reg[STAT_RX_EMPTY] <= rx_fifo_empty;
        status_reg[STAT_ERROR] <= spi_error;
        
        // Interrupt pending
        status_reg[STAT_IRQ_PEND] <= irq_o && control_reg[CTRL_IRQ_EN];
        
        // Update RX data register when transfer completes
        if (spi_done) begin
            rx_data_reg <= {24'h0, spi_data_rx};
        end
        
        // Update from FIFO read
        if (fifo_read_en) begin
            rx_data_reg <= {24'h0, fifo_data_out};
        end
    end
    
    // Wishbone read cycle
    always @(*) begin
        wb_data_o = 32'h0000_0000;
        
        if (addr_match) begin
            case (reg_addr)
                REG_CONTROL:  wb_data_o = control_reg;
                REG_STATUS:   wb_data_o = status_reg;
                REG_TX_DATA:  wb_data_o = tx_data_reg;
                REG_RX_DATA:  wb_data_o = rx_data_reg;
                REG_CLK_DIV:  wb_data_o = clk_div_reg;
                REG_IRQ_EN:   wb_data_o = irq_en_reg;
                REG_VERSION:  wb_data_o = version_reg;
                default:      wb_data_o = 32'hDEAD_BEEF;
            endcase
        end
    end
    
endmodule
