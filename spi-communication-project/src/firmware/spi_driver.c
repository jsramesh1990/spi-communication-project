// SPI Driver Implementation

#include "spi_driver.h"
#include <stddef.h>

// Memory-mapped register access macros
#define SPI_REG(offset) (*((volatile uint32_t *)(SPI_BASE_ADDR + (offset))))
#define SPI_REG8(offset) (*((volatile uint8_t *)(SPI_BASE_ADDR + (offset))))

// Private variables
static spi_mode_t current_mode = SPI_MODE_0;
static spi_cs_t current_cs = SPI_CS_0;
static bool initialized = false;

// Initialize SPI controller
void spi_init(spi_mode_t mode, uint8_t clk_div) {
    uint32_t control = 0;
    
    // Set mode bits
    switch (mode) {
        case SPI_MODE_0:
            control = 0;  // CPOL=0, CPHA=0
            break;
        case SPI_MODE_1:
            control = CTRL_MODE0;  // CPOL=0, CPHA=1
            break;
        case SPI_MODE_2:
            control = CTRL_MODE1;  // CPOL=1, CPHA=0
            break;
        case SPI_MODE_3:
            control = CTRL_MODE0 | CTRL_MODE1;  // CPOL=1, CPHA=1
            break;
        default:
            // Invalid mode, default to MODE 0
            control = 0;
            mode = SPI_MODE_0;
            break;
    }
    
    // Set chip select
    control |= (current_cs == SPI_CS_0) ? CTRL_CS0 :
               (current_cs == SPI_CS_1) ? CTRL_CS1 : 0;
    
    // Write control register
    SPI_REG(SPI_CONTROL) = control;
    
    // Set clock divider
    SPI_REG(SPI_CLK_DIV) = clk_div;
    
    // Clear status
    SPI_REG(SPI_STATUS) = 0;
    
    current_mode = mode;
    initialized = true;
}

// Deinitialize SPI controller
spi_error_t spi_deinit(void) {
    if (!initialized) {
        return SPI_OK;
    }
    
    // Reset control register
    SPI_REG(SPI_CONTROL) = 0;
    
    // Clear FIFOs (if any)
    while (!spi_is_rx_fifo_empty()) {
        uint8_t dummy;
        spi_fifo_read(&dummy);
    }
    
    initialized = false;
    return SPI_OK;
}

// Set SPI mode
spi_error_t spi_set_mode(spi_mode_t mode) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    uint32_t control = SPI_REG(SPI_CONTROL);
    
    // Clear mode bits
    control &= ~(CTRL_MODE0 | CTRL_MODE1);
    
    // Set new mode bits
    switch (mode) {
        case SPI_MODE_0:
            // Already cleared
            break;
        case SPI_MODE_1:
            control |= CTRL_MODE0;
            break;
        case SPI_MODE_2:
            control |= CTRL_MODE1;
            break;
        case SPI_MODE_3:
            control |= CTRL_MODE0 | CTRL_MODE1;
            break;
        default:
            return SPI_ERROR_INVALID_MODE;
    }
    
    SPI_REG(SPI_CONTROL) = control;
    current_mode = mode;
    
    return SPI_OK;
}

// Set clock divider
spi_error_t spi_set_clock_divider(uint8_t divider) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    if (divider < 2) {
        divider = 2;  // Minimum divider
    }
    
    SPI_REG(SPI_CLK_DIV) = divider;
    return SPI_OK;
}

// Set chip select polarity
spi_error_t spi_set_cs_polarity(bool active_high) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    uint32_t control = SPI_REG(SPI_CONTROL);
    
    if (active_high) {
        control |= CTRL_CS_POL;
    } else {
        control &= ~CTRL_CS_POL;
    }
    
    SPI_REG(SPI_CONTROL) = control;
    return SPI_OK;
}

// Enable/disable loopback mode
spi_error_t spi_enable_loopback(bool enable) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    uint32_t control = SPI_REG(SPI_CONTROL);
    
    if (enable) {
        control |= CTRL_LOOPBACK;
    } else {
        control &= ~CTRL_LOOPBACK;
    }
    
    SPI_REG(SPI_CONTROL) = control;
    return SPI_OK;
}

// Select SPI device
spi_error_t spi_select_device(spi_cs_t cs_line) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    uint32_t control = SPI_REG(SPI_CONTROL);
    
    // Clear CS bits
    control &= ~(CTRL_CS0 | CTRL_CS1);
    
    // Set new CS
    switch (cs_line) {
        case SPI_CS_0:
            control |= CTRL_CS0;
            break;
        case SPI_CS_1:
            control |= CTRL_CS1;
            break;
        case SPI_CS_2:
            // For CS2 and CS3, need to extend the register if supported
            // For now, treat as CS0
            control |= CTRL_CS0;
            break;
        case SPI_CS_3:
            control |= CTRL_CS1;
            break;
        default:
            return SPI_ERROR_INVALID_MODE;
    }
    
    SPI_REG(SPI_CONTROL) = control;
    current_cs = cs_line;
    
    return SPI_OK;
}

// Deselect SPI device
spi_error_t spi_deselect_device(spi_cs_t cs_line) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    uint32_t control = SPI_REG(SPI_CONTROL);
    
    // Clear the specific CS bit
    switch (cs_line) {
        case SPI_CS_0:
            control &= ~CTRL_CS0;
            break;
        case SPI_CS_1:
            control &= ~CTRL_CS1;
            break;
        default:
            // For CS2 and CS3, just clear all for now
            control &= ~(CTRL_CS0 | CTRL_CS1);
            break;
    }
    
    SPI_REG(SPI_CONTROL) = control;
    
    return SPI_OK;
}

// Single byte transfer (non-blocking)
spi_error_t spi_transfer(uint8_t tx_data, uint8_t *rx_data) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    if (spi_is_busy()) {
        return SPI_ERROR_BUSY;
    }
    
    // Write transmit data
    SPI_REG8(SPI_TX_DATA) = tx_data;
    
    // Start transfer
    uint32_t control = SPI_REG(SPI_CONTROL);
    control |= CTRL_START;
    SPI_REG(SPI_CONTROL) = control;
    
    // If rx_data pointer is provided, wait for completion and read
    if (rx_data != NULL) {
        // Wait for transfer to complete
        while (spi_is_busy()) {
            // Busy wait
        }
        
        // Check for errors
        if (spi_has_error()) {
            return SPI_ERROR_TIMEOUT;
        }
        
        // Read received data
        *rx_data = SPI_REG8(SPI_RX_DATA);
    }
    
    return SPI_OK;
}

// Single byte transfer (blocking with timeout)
spi_error_t spi_transfer_blocking(uint8_t tx_data, uint8_t *rx_data, uint32_t timeout_ms) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    spi_error_t error = spi_transfer(tx_data, NULL);
    if (error != SPI_OK) {
        return error;
    }
    
    // Wait with timeout
    uint32_t start_time = 0;  // Would need a timer implementation
    while (spi_is_busy()) {
        // Check timeout
        if (timeout_ms > 0) {
            // Implement timeout checking with system timer
            // For now, just busy wait
        }
    }
    
    // Check for errors
    if (spi_has_error()) {
        return SPI_ERROR_TIMEOUT;
    }
    
    // Read received data
    if (rx_data != NULL) {
        *rx_data = SPI_REG8(SPI_RX_DATA);
    }
    
    return SPI_OK;
}

// Write multiple bytes
spi_error_t spi_write_bytes(const uint8_t *data, uint32_t length) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    if (data == NULL) {
        return SPI_OK;  // Nothing to do
    }
    
    for (uint32_t i = 0; i < length; i++) {
        spi_error_t error = spi_transfer(data[i], NULL);
        if (error != SPI_OK) {
            return error;
        }
    }
    
    return SPI_OK;
}

// Read multiple bytes
spi_error_t spi_read_bytes(uint8_t *buffer, uint32_t length) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    if (buffer == NULL) {
        return SPI_OK;  // Nothing to do
    }
    
    for (uint32_t i = 0; i < length; i++) {
        spi_error_t error = spi_transfer(0xFF, &buffer[i]);
        if (error != SPI_OK) {
            return error;
        }
    }
    
    return SPI_OK;
}

// Transfer multiple bytes (bidirectional)
spi_error_t spi_transfer_bytes(const uint8_t *tx_data, uint8_t *rx_data, uint32_t length) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    if (tx_data == NULL && rx_data == NULL) {
        return SPI_OK;  // Nothing to do
    }
    
    for (uint32_t i = 0; i < length; i++) {
        uint8_t tx_byte = (tx_data != NULL) ? tx_data[i] : 0xFF;
        uint8_t rx_byte;
        
        spi_error_t error = spi_transfer(tx_byte, &rx_byte);
        if (error != SPI_OK) {
            return error;
        }
        
        if (rx_data != NULL) {
            rx_data[i] = rx_byte;
        }
    }
    
    return SPI_OK;
}

// Write to TX FIFO
spi_error_t spi_fifo_write(uint8_t data) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    if (spi_is_tx_fifo_full()) {
        return SPI_ERROR_FIFO_FULL;
    }
    
    SPI_REG8(SPI_TX_FIFO) = data;
    return SPI_OK;
}

// Read from RX FIFO
spi_error_t spi_fifo_read(uint8_t *data) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    if (spi_is_rx_fifo_empty()) {
        return SPI_ERROR_FIFO_EMPTY;
    }
    
    *data = SPI_REG8(SPI_RX_FIFO);
    return SPI_OK;
}

// Check if TX FIFO is full
bool spi_is_tx_fifo_full(void) {
    return (SPI_REG(SPI_STATUS) & STAT_TX_FULL) != 0;
}

// Check if TX FIFO is empty
bool spi_is_tx_fifo_empty(void) {
    return (SPI_REG(SPI_STATUS) & STAT_TX_EMPTY) != 0;
}

// Check if RX FIFO is full
bool spi_is_rx_fifo_full(void) {
    return (SPI_REG(SPI_STATUS) & STAT_RX_FULL) != 0;
}

// Check if RX FIFO is empty
bool spi_is_rx_fifo_empty(void) {
    return (SPI_REG(SPI_STATUS) & STAT_RX_EMPTY) != 0;
}

// Check if SPI is busy
bool spi_is_busy(void) {
    return (SPI_REG(SPI_STATUS) & STAT_BUSY) != 0;
}

// Check if transfer is done
bool spi_is_done(void) {
    return (SPI_REG(SPI_STATUS) & STAT_DONE) != 0;
}

// Check for errors
bool spi_has_error(void) {
    return (SPI_REG(SPI_STATUS) & STAT_ERROR) != 0;
}

// Get SPI version
uint32_t spi_get_version(void) {
    return SPI_REG(SPI_VERSION);
}

// Enable/disable interrupts
spi_error_t spi_enable_interrupt(bool enable) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    uint32_t control = SPI_REG(SPI_CONTROL);
    
    if (enable) {
        control |= CTRL_IRQ_EN;
    } else {
        control &= ~CTRL_IRQ_EN;
    }
    
    SPI_REG(SPI_CONTROL) = control;
    return SPI_OK;
}

// Clear interrupt
spi_error_t spi_clear_interrupt(void) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    // Reading the status register may clear some bits
    // depending on hardware implementation
    (void)SPI_REG(SPI_STATUS);
    
    return SPI_OK;
}

// Check if interrupt is pending
bool spi_is_interrupt_pending(void) {
    return (SPI_REG(SPI_STATUS) & STAT_IRQ_PEND) != 0;
}

// Simple delay functions (would need proper implementation)
void spi_delay_ms(uint32_t ms) {
    // Implementation depends on system
    // For now, just a rough loop
    for (volatile uint32_t i = 0; i < ms * 1000; i++) {
        __asm__("nop");
    }
}

void spi_delay_us(uint32_t us) {
    // Implementation depends on system
    for (volatile uint32_t i = 0; i < us; i++) {
        __asm__("nop");
    }
}

// Example: Read SPI Flash ID
spi_error_t spi_flash_read_id(uint8_t *manufacturer_id, uint8_t *device_id) {
    if (!initialized) {
        return SPI_ERROR_INVALID_MODE;
    }
    
    uint8_t cmd = 0x9F;  // Read ID command
    uint8_t response[3];
    
    // Select flash device
    spi_select_device(SPI_CS_0);
    
    // Send command and read response
    spi_transfer(cmd, NULL);
    spi_read_bytes(response, 3);
    
    // Deselect device
    spi_deselect_device(SPI_CS_0);
    
    if (manufacturer_id != NULL) {
        *manufacturer_id = response[0];
    }
    
    if (device_id != NULL) {
        *device_id = response[1];
    }
    
    return SPI_OK;
}
