#!/bin/bash

# SPI Communication Project Build Script
# Usage: ./scripts/build.sh [target]
# Targets: sim, synth, clean, all

set -e

# Configuration
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$PROJECT_ROOT/build"
SRC_DIR="$PROJECT_ROOT/src"
TB_DIR="$SRC_DIR/testbench"
FIRMWARE_DIR="$SRC_DIR/firmware"

# Tool paths (modify as needed)
IVERILOG=iverilog
VVP=vvp
GTKWAVE=gtkwave
YOSYS=yosys
NEXTPNR=nextpnr-ice40
ICEPACK=icepack

# Default target
TARGET=${1:-all}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored message
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create build directory
create_build_dir() {
    if [ ! -d "$BUILD_DIR" ]; then
        print_info "Creating build directory: $BUILD_DIR"
        mkdir -p "$BUILD_DIR"
    fi
}

# Run simulation
run_simulation() {
    print_info "Running simulation..."
    
    create_build_dir
    
    # Compile testbench
    print_info "Compiling SPI Master testbench..."
    cd "$BUILD_DIR"
    $IVERILOG -g2012 -o spi_master_tb \
        "$TB_DIR/tb_spi_master.v" \
        "$SRC_DIR/soc/spi_master.v"
    
    if [ $? -eq 0 ]; then
        print_info "Running SPI Master testbench..."
        $VVP spi_master_tb
    else
        print_error "Failed to compile SPI Master testbench"
        exit 1
    fi
    
    # Compile and run slave testbench
    print_info "Compiling SPI Slave testbench..."
    $IVERILOG -g2012 -o spi_slave_tb \
        "$TB_DIR/tb_spi_slave.v" \
        "$SRC_DIR/soc/spi_slave.v"
    
    if [ $? -eq 0 ]; then
        print_info "Running SPI Slave testbench..."
        $VVP spi_slave_tb
    else
        print_error "Failed to compile SPI Slave testbench"
        exit 1
    fi
    
    print_info "Simulation completed successfully"
}

# Synthesize for FPGA
run_synthesis() {
    print_info "Running synthesis..."
    
    create_build_dir
    
    # Check if synthesis tools are available
    if ! command -v $YOSYS &> /dev/null; then
        print_error "Yosys not found. Please install it first."
        exit 1
    fi
    
    # Create synthesis script
    cat > "$BUILD_DIR/synth.ys" << EOF
# Yosys synthesis script for SPI controller

# Read Verilog files
read_verilog -sv $SRC_DIR/soc/spi_master.v
read_verilog -sv $SRC_DIR/soc/spi_slave.v
read_verilog -sv $SRC_DIR/soc/spi_controller.v
read_verilog -sv $SRC_DIR/soc/top.v

# Generic synthesis
synth -top top

# Optimize
opt -purge

# Technology mapping (generic)
abc -g AND,XOR,NAND,NOR

# Write output files
write_verilog $BUILD_DIR/synth.v
write_blif $BUILD_DIR/synth.blif
stat
EOF
    
    # Run synthesis
    cd "$BUILD_DIR"
    $YOSYS synth.ys
    
    if [ $? -eq 0 ]; then
        print_info "Synthesis completed successfully"
        print_info "Output files:"
        print_info "  - $BUILD_DIR/synth.v (synthesized Verilog)"
        print_info "  - $BUILD_DIR/synth.blif (BLIF netlist)"
    else
        print_error "Synthesis failed"
        exit 1
    fi
}

# Build firmware
build_firmware() {
    print_info "Building firmware..."
    
    create_build_dir
    
    # Check for GCC
    if ! command -v gcc &> /dev/null; then
        print_warning "GCC not found. Skipping firmware build."
        return
    fi
    
    # Compile firmware
    cd "$BUILD_DIR"
    
    # Compile driver
    gcc -c -Wall -Wextra -O2 \
        -I "$FIRMWARE_DIR" \
        -o spi_driver.o \
        "$FIRMWARE_DIR/spi_driver.c"
    
    # Compile main application
    gcc -c -Wall -Wextra -O2 \
        -I "$FIRMWARE_DIR" \
        -o main.o \
        "$FIRMWARE_DIR/main.c"
    
    # Link
    gcc -o spi_test.elf \
        spi_driver.o \
        main.o
    
    if [ $? -eq 0 ]; then
        print_info "Firmware built successfully: $BUILD_DIR/spi_test.elf"
        
        # Create hex file (for simulation)
        if command -v objcopy &> /dev/null; then
            objcopy -O ihex spi_test.elf spi_test.hex
            print_info "Created hex file: $BUILD_DIR/spi_test.hex"
        fi
    else
        print_error "Firmware build failed"
        exit 1
    fi
}

# Generate documentation
generate_docs() {
    print_info "Generating documentation..."
    
    # Check if pandoc is available for markdown to PDF conversion
    if command -v pandoc &> /dev/null; then
        mkdir -p "$BUILD_DIR/docs"
        
        # Convert architecture documentation
        pandoc "$PROJECT_ROOT/docs/architecture.md" \
            -o "$BUILD_DIR/docs/architecture.pdf" \
            -V geometry:margin=1in
        
        # Convert protocol documentation
        pandoc "$PROJECT_ROOT/docs/protocol.md" \
            -o "$BUILD_DIR/docs/protocol.pdf" \
            -V geometry:margin=1in
        
        print_info "Documentation generated: $BUILD_DIR/docs/"
    else
        print_warning "Pandoc not found. Skipping PDF generation."
    fi
}

# Clean build directory
clean_build() {
    print_info "Cleaning build directory..."
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_info "Build directory removed"
    else
        print_info "Build directory does not exist"
    fi
    
    # Clean temporary files
    find "$PROJECT_ROOT" -name "*.vcd" -delete
    find "$PROJECT_ROOT" -name "*.vvp" -delete
    find "$PROJECT_ROOT" -name "*.o" -delete
    find "$PROJECT_ROOT" -name "*.elf" -delete
    find "$PROJECT_ROOT" -name "*.hex" -delete
    
    print_info "Clean completed"
}

# Run all targets
run_all() {
    print_info "Building complete project..."
    
    clean_build
    create_build_dir
    run_simulation
    build_firmware
    generate_docs
    
    print_info "All build targets completed successfully"
}

# Main build process
case "$TARGET" in
    sim)
        run_simulation
        ;;
    synth)
        run_synthesis
        ;;
    firmware)
        build_firmware
        ;;
    docs)
        generate_docs
        ;;
    clean)
        clean_build
        ;;
    all)
        run_all
        ;;
    *)
        print_error "Unknown target: $TARGET"
        echo "Usage: $0 [sim|synth|firmware|docs|clean|all]"
        exit 1
        ;;
esac

print_info "Build process completed"
