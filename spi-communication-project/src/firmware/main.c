// Main Application Example
// Demonstrates SPI communication with various devices

#include "spi_driver.h"
#include <stdio.h>
#include <string.h>

// Test patterns
static const uint8_t test_pattern_asc[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static const uint8_t test_pattern_desc[] = "ZYXWVUTSRQPONMLKJIHGFEDCBA";

// Global variables for test results
static uint8_t rx_buffer[32];
static uint32_t test_count = 0;
static uint32_t pass_count = 0;
static uint32_t fail_count = 0;

// Function prototypes
void run_basic_tests(void);
void run_spi_flash_tests(void);
void run_performance_test(void);
void run_loopback_test(void);
void print_test_result(const char *test_name, spi_error_t result);
void print_buffer(const char *label, const uint8_t *buffer, uint32_t length);

// Main function
int main(void) {
    printf("SPI Communication Test Application\n");
    printf("==================================\n\n");
    
    // Initialize SPI in mode 0 with clock divider 4
    printf("Initializing SPI controller...\n");
    spi_init(SPI_MODE_0, 4);
    
    if (spi_get_version() == 0x00010000) {
        printf("SPI Controller Version: 1.0\n");
    } else {
        printf("SPI Controller Version: 0x%08X\n", spi_get_version());
    }
    
    printf("\n");
    
    // Run tests
    run_basic_tests();
    run_loopback_test();
    run_spi_flash_tests();
    run_performance_test();
    
    // Print summary
    printf("\nTest Summary:\n");
    printf("Total Tests: %lu\n", test_count);
    printf("Passed:      %lu\n", pass_count);
    printf("Failed:      %lu\n", fail_count);
    
    if (fail_count == 0) {
        printf("\nAll tests PASSED!\n");
    } else {
        printf("\nSome tests FAILED!\n");
    }
    
    // Deinitialize
    spi_deinit();
    
    return 0;
}

// Run basic SPI tests
void run_basic_tests(void) {
    printf("Running Basic SPI Tests\n");
    printf("----------------------\n");
    
    test_count = 0;
    pass_count = 0;
    fail_count = 0;
    
    // Test 1: Single byte transfer
    printf("\nTest 1: Single Byte Transfer\n");
    uint8_t tx_byte = 0xAA;
    uint8_t rx_byte;
    spi_error_t result = spi_transfer(tx_byte, &rx_byte);
    print_test_result("Single Byte", result);
    printf("  Sent: 0x%02X, Received: 0x%02X\n", tx_byte, rx_byte);
    
    // Test 2: Multiple bytes write
    printf("\nTest 2: Multiple Bytes Write\n");
    result = spi_write_bytes(test_pattern_asc, 5);
    print_test_result("Write 5 bytes", result);
    
    // Test 3: Multiple bytes read
    printf("\nTest 3: Multiple Bytes Read\n");
    memset(rx_buffer, 0, sizeof(rx_buffer));
    result = spi_read_bytes(rx_buffer, 5);
    print_test_result("Read 5 bytes", result);
    print_buffer("Received", rx_buffer, 5);
    
    // Test 4: Bidirectional transfer
    printf("\nTest 4: Bidirectional Transfer\n");
    uint8_t tx_data[] = {0x01, 0x02, 0x03, 0x04, 0x05};
    uint8_t rx_data[5];
    result = spi_transfer_bytes(tx_data, rx_data, 5);
    print_test_result("Bidirectional 5 bytes", result);
    print_buffer("Sent", tx_data, 5);
    print_buffer("Received", rx_data, 5);
    
    // Test 5: FIFO operations
    printf("\nTest 5: FIFO Operations\n");
    result = spi_fifo_write(0x55);
    if (result == SPI_OK) {
        printf("  FIFO Write: PASS\n");
        pass_count++;
    } else {
        printf("  FIFO Write: FAIL (Error: %d)\n", result);
        fail_count++;
    }
    test_count++;
    
    uint8_t fifo_data;
    result = spi_fifo_read(&fifo_data);
    if (result == SPI_OK) {
        printf("  FIFO Read: PASS (Data: 0x%02X)\n", fifo_data);
        pass_count++;
    } else {
        printf("  FIFO Read: FAIL (Error: %d)\n", result);
        fail_count++;
    }
    test_count++;
    
    // Test 6: Status checks
    printf("\nTest 6: Status Checks\n");
    printf("  Busy: %s\n", spi_is_busy() ? "Yes" : "No");
    printf("  Done: %s\n", spi_is_done() ? "Yes" : "No");
    printf("  Error: %s\n", spi_has_error() ? "Yes" : "No");
    printf("  TX FIFO Full: %s\n", spi_is_tx_fifo_full() ? "Yes" : "No");
    printf("  TX FIFO Empty: %s\n", spi_is_tx_fifo_empty() ? "Yes" : "No");
    printf("  RX FIFO Full: %s\n", spi_is_rx_fifo_full() ? "Yes" : "No");
    printf("  RX FIFO Empty: %s\n", spi_is_rx_fifo_empty() ? "Yes" : "No");
    
    printf("\nBasic Tests Completed: %lu passed, %lu failed\n", pass_count, fail_count);
}

// Run loopback test (requires loopback mode enabled)
void run_loopback_test(void) {
    printf("\nRunning Loopback Test\n");
    printf("--------------------\n");
    
    // Enable loopback mode
    spi_enable_loopback(true);
    
    // Test pattern
    const char *test_string = "SPI Loopback Test";
    uint8_t tx_data[32];
    uint8_t rx_data[32];
    
    // Copy test string
    strncpy((char *)tx_data, test_string, sizeof(tx_data));
    
    // Perform transfer
    spi_error_t result = spi_transfer_bytes(tx_data, rx_data, strlen(test_string) + 1);
    
    if (result == SPI_OK) {
        // Compare transmitted and received data
        if (memcmp(tx_data, rx_data, strlen(test_string) + 1) == 0) {
            printf("Loopback Test: PASS\n");
            printf("  Sent: %s\n", tx_data);
            printf("  Received: %s\n", rx_data);
            pass_count++;
        } else {
            printf("Loopback Test: FAIL - Data mismatch\n");
            printf("  Sent: %s\n", tx_data);
            printf("  Received: %s\n", rx_data);
            fail_count++;
        }
    } else {
        printf("Loopback Test: FAIL - Transfer error: %d\n", result);
        fail_count++;
    }
    test_count++;
    
    // Disable loopback mode
    spi_enable_loopback(false);
}

// Run SPI Flash tests (simulated)
void run_spi_flash_tests(void) {
    printf("\nRunning SPI Flash Tests (Simulated)\n");
    printf("----------------------------------\n");
    
    // In a real system, this would communicate with actual flash memory
    // For this example, we'll simulate the commands
    
    printf("Note: SPI Flash tests require actual flash hardware\n");
    printf("Simulating flash operations...\n");
    
    // Simulate read ID command
    uint8_t manufacturer_id, device_id;
    spi_error_t result = spi_flash_read_id(&manufacturer_id, &device_id);
    
    if (result == SPI_OK) {
        printf("Flash Read ID: PASS\n");
        printf("  Manufacturer ID: 0x%02X\n", manufacturer_id);
        printf("  Device ID: 0x%02X\n", device_id);
        pass_count++;
    } else {
        printf("Flash Read ID: FAIL (Error: %d)\n", result);
        fail_count++;
    }
    test_count++;
    
    // Simulate sector erase
    printf("\nSimulating Sector Erase...\n");
    printf("  Command sent to address 0x00000000\n");
    printf("  (In real hardware, this would erase 4KB sector)\n");
    
    // Simulate write operation
    printf("\nSimulating Write Operation...\n");
    uint8_t write_data[] = "Hello, SPI Flash!";
    printf("  Writing %lu bytes to address 0x00010000\n", sizeof(write_data));
    printf("  Data: %s\n", write_data);
    
    // Simulate read operation
    printf("\nSimulating Read Operation...\n");
    uint8_t read_buffer[32];
    printf("  Reading %lu bytes from address 0x00010000\n", sizeof(write_data));
    printf("  (In real hardware, this would read back the data)\n");
    
    printf("\nFlash Tests Completed (Simulated)\n");
}

// Run performance test
void run_performance_test(void) {
    printf("\nRunning Performance Test\n");
    printf("------------------------\n");
    
    const uint32_t iterations = 1000;
    uint8_t tx_data = 0x55;
    uint8_t rx_data;
    
    printf("Testing %lu single-byte transfers...\n", iterations);
    
    // Simple performance measurement (would need proper timing)
    for (uint32_t i = 0; i < iterations; i++) {
        spi_error_t result = spi_transfer(tx_data++, &rx_data);
        if (result != SPI_OK) {
            printf("  Transfer failed at iteration %lu: %d\n", i, result);
            fail_count++;
            test_count++;
            return;
        }
    }
    
    printf("  Completed %lu transfers without errors\n", iterations);
    pass_count++;
    test_count++;
    
    // Test different clock dividers
    printf("\nTesting different clock speeds...\n");
    uint8_t dividers[] = {2, 4, 8, 16, 32};
    
    for (uint32_t i = 0; i < sizeof(dividers); i++) {
        spi_set_clock_divider(dividers[i]);
        printf("  Clock divider %u: ", dividers[i]);
        
        spi_error_t result = spi_transfer(0xAA, &rx_data);
        if (result == SPI_OK) {
            printf("PASS\n");
        } else {
            printf("FAIL\n");
        }
    }
    
    // Restore default divider
    spi_set_clock_divider(4);
}

// Print test result
void print_test_result(const char *test_name, spi_error_t result) {
    test_count++;
    
    if (result == SPI_OK) {
        printf("  %s: PASS\n", test_name);
        pass_count++;
    } else {
        printf("  %s: FAIL (Error: %d)\n", test_name, result);
        fail_count++;
    }
}

// Print buffer contents
void print_buffer(const char *label, const uint8_t *buffer, uint32_t length) {
    printf("  %s: ", label);
    for (uint32_t i = 0; i < length; i++) {
        printf("%02X ", buffer[i]);
    }
    printf("(");
    for (uint32_t i = 0; i < length; i++) {
        if (buffer[i] >= 32 && buffer[i] <= 126) {
            printf("%c", buffer[i]);
        } else {
            printf(".");
        }
    }
    printf(")\n");
}
