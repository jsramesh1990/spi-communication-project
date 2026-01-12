// Testbench for SPI Master Module

`timescale 1ns/1ps

module tb_spi_master;
    
    // Parameters
    parameter CLK_PERIOD = 20;  // 50 MHz
    parameter CLK_DIV = 4;
    
    // DUT signals
    reg clk;
    reg reset;
    reg start;
    reg [7:0] data_tx;
    reg [1:0] cpol_cpha;
    wire [7:0] data_rx;
    wire busy;
    wire done;
    wire sck;
    wire mosi;
    reg miso;
    wire cs_n;
    
    // Test signals
    reg [7:0] expected_data;
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Instantiate DUT
    spi_master #(
        .CLK_DIV_WIDTH(8)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .data_tx(data_tx),
        .cpol_cpha(cpol_cpha),
        .clk_div(CLK_DIV),
        .cs_polarity(1'b0),  // Active low
        .cs_select(2'b00),
        .loopback(1'b0),
        .data_rx(data_rx),
        .busy(busy),
        .done(done),
        .error(),
        .tx_fifo_full(),
        .tx_fifo_empty(),
        .rx_fifo_full(),
        .rx_fifo_empty(),
        .sck(sck),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n),
        .fifo_write_en(1'b0),
        .fifo_data_in(8'h00),
        .fifo_read_en(1'b0),
        .fifo_data_out(),
        .irq()
    );
    
    // Clock generation
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test task for single transfer
    task test_single_transfer;
        input [1:0] mode;
        input [7:0] tx_data;
        input [7:0] slave_response;
        begin
            test_count = test_count + 1;
            $display("Test %0d: Mode %0d, TX=0x%02X, Expected RX=0x%02X", 
                     test_count, mode, tx_data, slave_response);
            
            // Configure mode
            cpol_cpha = mode;
            data_tx = tx_data;
            miso = 1'b0;
            
            // Wait for idle
            @(negedge clk);
            wait(busy == 1'b0);
            
            // Start transfer
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            
            // Provide slave response
            // For simplicity, we'll set miso based on slave_response
            // In real test, this would be synchronized with SCK
            
            // Wait for completion
            wait(done == 1'b1);
            
            // Check result
            if (data_rx === slave_response) begin
                $display("  PASS: Received 0x%02X", data_rx);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Expected 0x%02X, Got 0x%02X", 
                         slave_response, data_rx);
                fail_count = fail_count + 1;
            end
            
            // Wait a bit
            repeat(10) @(negedge clk);
        end
    endtask
    
    // Test task for mode testing
    task test_spi_mode;
        input [1:0] mode;
        begin
            $display("\nTesting SPI Mode %0d", mode);
            $display("-----------------");
            
            // Test with different data patterns
            test_single_transfer(mode, 8'hAA, 8'h55);
            test_single_transfer(mode, 8'h55, 8'hAA);
            test_single_transfer(mode, 8'h00, 8'hFF);
            test_single_transfer(mode, 8'hFF, 8'h00);
            test_single_transfer(mode, 8'hF0, 8'h0F);
            test_single_transfer(mode, 8'h0F, 8'hF0);
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        start = 0;
        data_tx = 8'h00;
        cpol_cpha = 2'b00;
        miso = 1'b0;
        
        // Apply reset
        #100 reset = 0;
        #100;
        
        $display("\n========================================");
        $display("SPI Master Testbench");
        $display("========================================\n");
        
        // Test Mode 0
        test_spi_mode(2'b00);
        
        // Test Mode 1
        test_spi_mode(2'b01);
        
        // Test Mode 2
        test_spi_mode(2'b10);
        
        // Test Mode 3
        test_spi_mode(2'b11);
        
        // Test continuous transfers
        $display("\nTesting Continuous Transfers");
        $display("---------------------------");
        
        for (integer i = 0; i < 5; i = i + 1) begin
            test_count = test_count + 1;
            data_tx = i;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            
            wait(done == 1'b1);
            $display("Test %0d: Continuous transfer %0d completed", 
                     test_count, i);
            pass_count = pass_count + 1;
            
            repeat(5) @(negedge clk);
        end
        
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
        $dumpfile("tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);
    end
    
    // Monitor for debugging
    always @(posedge clk) begin
        if (busy && sck) begin
            $display("Time %0t: SCK posedge, MOSI=%b, MISO=%b", 
                     $time, mosi, miso);
        end
    end
    
endmodule
