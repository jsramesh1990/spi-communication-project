// SPI Driver Header File
#ifndef SPI_DRIVER_H
#define SPI_DRIVER_H

#include <stdint.h>
#include <stdbool.h>

// SPI Base Address
#define SPI_BASE_ADDR   0x40000000

// Register Offsets
#define SPI_CONTROL     0x00
#define SPI_STATUS      0x04
#define SPI_TX_DATA     0x08
#define SPI_RX_DATA     0x0C
#define SPI_CLK_DIV     0x10
#define SPI_TX_FIFO     0x14
#define SPI_RX_FIFO     0x18
#define SPI_IRQ_EN      0x1C
#define SPI_VERSION     0x20

// Control Register Bits
#define CTRL_START      (1 << 0)
#define CTRL_MODE0      (1 << 1)
#define CTRL_MODE1      (2 << 1)
#define CTRL_CS0        (1 << 3)
#define CTRL_CS1        (1 << 4)
#define CTRL_IRQ_EN     (1 << 5)
#define CTRL_DMA_EN     (1 << 6)
#define CTRL_LOOPBACK   (1 << 7)
#define CTRL_CS_POL     (1 << 8)

// Status Register Bits
#define STAT_BUSY       (1 << 0)
#define STAT_DONE       (1 << 1)
#define STAT_TX_FULL    (1 << 2)
#define STAT_TX_EMPTY   (1 << 3)
#define STAT_RX_FULL    (1 << 4)
#define STAT_RX_EMPTY   (1 << 5)
#define STAT_ERROR      (1 << 6)
#define STAT_IRQ_PEND   (1 << 7)

// SPI Modes
typedef enum {
    SPI_MODE_0 = 0,  // CPOL=0, CPHA=0
    SPI_MODE_1 = 1,  // CPOL=0, CPHA=1
    SPI_MODE_2 = 2,  // CPOL=1, CPHA=0
    SPI_MODE_3 = 3,  // CPOL=1, CPHA=1
} spi_mode_t;

// Chip Select Lines
typedef enum {
    SPI_CS_0 = 0,
    SPI_CS_1 = 1,
    SPI_CS_2 = 2,
    SPI_CS_3 = 3,
} spi_cs_t;

// Error Codes
typedef enum {
    SPI_OK = 0,
    SPI_ERROR_BUSY,
    SPI_ERROR_TIMEOUT,
    SPI_ERROR_FIFO_FULL,
    SPI_ERROR_FIFO_EMPTY,
    SPI_ERROR_INVALID_MODE,
} spi_error_t;

// Function Prototypes

// Initialization
void spi_init(spi_mode_t mode, uint8_t clk_div);
spi_error_t spi_deinit(void);

// Configuration
spi_error_t spi_set_mode(spi_mode_t mode);
spi_error_t spi_set_clock_divider(uint8_t divider);
spi_error_t spi_set_cs_polarity(bool active_high);
spi_error_t spi_enable_loopback(bool enable);

// Control
spi_error_t spi_select_device(spi_cs_t cs_line);
spi_error_t spi_deselect_device(spi_cs_t cs_line);

// Data Transfer
spi_error_t spi_transfer(uint8_t tx_data, uint8_t *rx_data);
spi_error_t spi_transfer_blocking(uint8_t tx_data, uint8_t *rx_data, uint32_t timeout_ms);
spi_error_t spi_write_bytes(const uint8_t *data, uint32_t length);
spi_error_t spi_read_bytes(uint8_t *buffer, uint32_t length);
spi_error_t spi_transfer_bytes(const uint8_t *tx_data, uint8_t *rx_data, uint32_t length);

// FIFO Operations
spi_error_t spi_fifo_write(uint8_t data);
spi_error_t spi_fifo_read(uint8_t *data);
bool spi_is_tx_fifo_full(void);
bool spi_is_tx_fifo_empty(void);
bool spi_is_rx_fifo_full(void);
bool spi_is_rx_fifo_empty(void);

// Status
bool spi_is_busy(void);
bool spi_is_done(void);
bool spi_has_error(void);
uint32_t spi_get_version(void);

// Interrupt
spi_error_t spi_enable_interrupt(bool enable);
spi_error_t spi_clear_interrupt(void);
bool spi_is_interrupt_pending(void);

// Utility
void spi_delay_ms(uint32_t ms);
void spi_delay_us(uint32_t us);

// Example device drivers
spi_error_t spi_flash_read_id(uint8_t *manufacturer_id, uint8_t *device_id);
spi_error_t spi_flash_read(uint32_t address, uint8_t *buffer, uint32_t length);
spi_error_t spi_flash_write(uint32_t address, const uint8_t *data, uint32_t length);
spi_error_t spi_flash_erase_sector(uint32_t address);

#endif // SPI_DRIVER_H
