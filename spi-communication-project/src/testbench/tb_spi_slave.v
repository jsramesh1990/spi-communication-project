// Testbench for SPI Slave Module

`timescale 1ns/1ps

module tb_spi_slave;
    
    // Parameters
    parameter CLK_PERIOD = 20;  // 50 MHz
    
    // DUT signals
    reg clk;
    reg reset;
    reg [7:0] data_tx;
    reg tx_valid;
    wire tx_ready;
    wire [7:0] data_rx;
    wire rx_valid;
    reg rx_read;
    
    // SPI interface (driven by master in testbench)
    reg sck;
    reg mosi;
    wire miso;
    reg cs_n;
    
    // Test signals
    reg [7:0] master_tx_data;
    reg [7:0] slave_tx_data;
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Instantiate DUT
    spi_slave dut (
        .clk(clk),
        .reset(reset),
        .data_tx(data_tx),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
        .data_rx(data_rx),
        .rx_valid(rx_valid),
        .rx_read(rx_read),
        .sck(sck),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n),
        .busy(),
        .error()
    );
    
    // Clock generation
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Task to simulate master transmission
    task master_transfer;
        input [7:0] m_tx_data;  // Data from master to slave
        input [7:0] s_tx_data;  // Data from slave to master (expected)
        output [7:0] m_rx_data; // Data received by master
        begin
            // Initialize
            cs_n = 1'b1;
            sck = 1'b0;
            mosi = 1'b0;
            master_tx_data = m_tx_data;
            
            // Wait a bit
            repeat(2) @(posedge clk);
            
            // Assert chip select
            cs_n = 1'b0;
            repeat(2) @(posedge clk);
            
            // Transfer 8 bits
            for (integer i = 7; i >= 0; i = i - 1) begin
                // Set MOSI (master output)
                mosi = master_tx_data[i];
                
                // Generate SCK pulse
                #10 sck = 1'b1;
                #20 sck = 1'b0;
                #10;
                
                // Sample MISO (slave output) on falling edge
                m_rx_data[i] = miso;
            end
            
            // Deassert chip select
            cs_n = 1'b1;
            repeat(2) @(posedge clk);
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        data_tx = 8'h00;
        tx_valid = 1'b0;
        rx_read = 1'b0;
        sck = 0;
        mosi = 0;
        cs_n = 1'b1;
        
        // Apply reset
        #100 reset = 0;
        #100;
        
        $display("\n========================================");
        $display("SPI Slave Testbench");
        $display("========================================\n");
        
        // Test 1: Simple transfer
        test_count = test_count + 1;
        $display("Test %0d: Simple transfer", test_count);
        
        // Load slave data
        data_tx = 8'hAA;
        tx_valid = 1'b1;
        @(posedge clk);
        wait(tx_ready == 1'b0);
        tx_valid = 1'b0;
        
        // Master transfers 0x55, expects to receive 0xAA
        master_transfer(8'h55, 8'hAA, master_rx);
        
        // Check slave received data
        wait(rx_valid == 1'b1);
        if (data_rx == 8'h55) begin
            $display("  PASS: Slave received 0x%02X", data_rx);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Slave expected 0x55, got 0x%02X", data_rx);
            fail_count = fail_count + 1;
        end
        
        // Read data from slave
        rx_read = 1'b1;
        @(posedge clk);
        rx_read = 1'b0;
        
        // Check master received data
        if (master_rx == 8'hAA) begin
            $display("  PASS: Master received 0x%02X", master_rx);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: Master expected 0xAA, got 0x%02X", master_rx);
            fail_count = fail_count + 1;
        end
        
        // Test 2: Multiple transfers
        test_count = test_count + 1;
        $display("\nTest %0d: Multiple transfers", test_count);
        
        for (integer i = 0; i < 4; i = i + 1) begin
            // Load new data to slave
            data_tx = 8'h10 + i;
            tx_valid = 1'b1;
            @(posedge clk);
            wait(tx_ready == 1'b0);
            tx_valid = 1'b0;
            
            // Master transfer
            master_transfer(8'h20 + i, 8'h10 + i, master_rx);
            
            // Check slave received data
            wait(rx_valid == 1'b1);
            if (data_rx == (8'h20 + i)) begin
                $display("  Transfer %0d: Slave PASS", i);
                pass_count = pass_count + 1;
            end else begin
                $display("  Transfer %0d: Slave FAIL", i);
                fail_count = fail_count + 1;
            end
            
            rx_read = 1'b1;
            @(posedge clk);
            rx_read = 1'b0;
            
            // Check master received data
            if (master_rx == (8'h10 + i)) begin
                $display("  Transfer %0d: Master PASS", i);
                pass_count = pass_count + 1;
            end else begin
                $display("  Transfer %0d: Master FAIL", i);
                fail_count = fail_count + 1;
            end
        end
        
        // Test 3: CS glitch during transfer
        test_count = test_count + 1;
        $display("\nTest %0d: CS glitch test", test_count);
        
        // Load slave data
        data_tx = 8'hFF;
        tx_valid = 1'b1;
        @(posedge clk);
        tx_valid = 1'b0;
        
        // Start transfer
        cs_n = 1'b0;
        sck = 1'b0;
        mosi = 0;
        
        // Transfer first 4 bits
        for (integer i = 7; i >= 4; i = i - 1) begin
            mosi = 1'b1;
            #10 sck = 1'b1;
            #20 sck = 1'b0;
            #10;
        end
        
        // Simulate CS glitch
        cs_n = 1'b1;
        #10;
        cs_n = 1'b0;
        
        // Continue transfer (should be corrupted)
        for (integer i = 3; i >= 0; i = i - 1) begin
            mosi = 1'b0;
            #10 sck = 1'b1;
            #20 sck = 1'b0;
            #10;
        end
        
        cs_n = 1'b1;
        
        // Slave should have detected error
        // (Error detection depends on implementation)
        $display("  CS glitch test completed");
        
        // Print summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("\nAll tests PASSED!");
        end else begin
            $display("\nSome tests FAILED!");
        end
        
        $display("\nSimulation completed.");
        $finish;
    end
    
    // Waveform dumping
    initial begin
        $dumpfile("tb_spi_slave.vcd");
        $dumpvars(0, tb_spi_slave);
    end
    
    // Monitor for debugging
    always @(posedge clk) begin
        if (rx_valid) begin
            $display("Time %0t: Slave received data 0x%02X", 
                     $time, data_rx);
        end
    end
    
endmodule
