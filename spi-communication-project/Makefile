# SPI Communication Project Makefile
# Targets: all, sim, synth, firmware, docs, clean

# Configuration
PROJECT_ROOT := $(shell pwd)
BUILD_DIR := $(PROJECT_ROOT)/build
SRC_DIR := $(PROJECT_ROOT)/src
TB_DIR := $(SRC_DIR)/testbench
FIRMWARE_DIR := $(SRC_DIR)/firmware
DOCS_DIR := $(PROJECT_ROOT)/docs

# Tools
IVERILOG := iverilog
VVP := vvp
GTKWAVE := gtkwave
YOSYS := yosys
GCC := gcc
OBJCOPY := objcopy
PANDOC := pandoc

# Flags
IVERILOG_FLAGS := -g2012 -Wall
GCC_FLAGS := -Wall -Wextra -O2 -I$(FIRMWARE_DIR)
YOSYS_FLAGS := 

# Default target
.PHONY: all
all: sim firmware docs

# Simulation targets
.PHONY: sim
sim: $(BUILD_DIR)/spi_master_tb $(BUILD_DIR)/spi_slave_tb
	@echo "Running simulations..."
	cd $(BUILD_DIR) && $(VVP) spi_master_tb
	cd $(BUILD_DIR) && $(VVP) spi_slave_tb

$(BUILD_DIR)/spi_master_tb: $(TB_DIR)/tb_spi_master.v $(SRC_DIR)/soc/spi_master.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $@ $^

$(BUILD_DIR)/spi_slave_tb: $(TB_DIR)/tb_spi_slave.v $(SRC_DIR)/soc/spi_slave.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) $(IVERILOG_FLAGS) -o $@ $^

# Synthesis target
.PHONY: synth
synth: $(BUILD_DIR)/synth.v

$(BUILD_DIR)/synth.v: $(SRC_DIR)/soc/*.v
	@mkdir -p $(BUILD_DIR)
	@echo "# Yosys synthesis script" > $(BUILD_DIR)/synth.ys
	@echo "read_verilog -sv $(SRC_DIR)/soc/spi_master.v" >> $(BUILD_DIR)/synth.ys
	@echo "read_verilog -sv $(SRC_DIR)/soc/spi_slave.v" >> $(BUILD_DIR)/synth.ys
	@echo "read_verilog -sv $(SRC_DIR)/soc/spi_controller.v" >> $(BUILD_DIR)/synth.ys
	@echo "read_verilog -sv $(SRC_DIR)/soc/top.v" >> $(BUILD_DIR)/synth.ys
	@echo "synth -top top" >> $(BUILD_DIR)/synth.ys
	@echo "opt -purge" >> $(BUILD_DIR)/synth.ys
	@echo "abc -g AND,XOR,NAND,NOR" >> $(BUILD_DIR)/synth.ys
	@echo "write_verilog $@" >> $(BUILD_DIR)/synth.ys
	@echo "write_blif $(BUILD_DIR)/synth.blif" >> $(BUILD_DIR)/synth.ys
	@echo "stat" >> $(BUILD_DIR)/synth.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/synth.ys

# Firmware targets
.PHONY: firmware
firmware: $(BUILD_DIR)/spi_test.elf $(BUILD_DIR)/spi_test.hex

$(BUILD_DIR)/spi_driver.o: $(FIRMWARE_DIR)/spi_driver.c $(FIRMWARE_DIR)/spi_driver.h
	@mkdir -p $(BUILD_DIR)
	$(GCC) $(GCC_FLAGS) -c -o $@ $<

$(BUILD_DIR)/main.o: $(FIRMWARE_DIR)/main.c $(FIRMWARE_DIR)/spi_driver.h
	@mkdir -p $(BUILD_DIR)
	$(GCC) $(GCC_FLAGS) -c -o $@ $<

$(BUILD_DIR)/spi_test.elf: $(BUILD_DIR)/spi_driver.o $(BUILD_DIR)/main.o
	$(GCC) -o $@ $^

$(BUILD_DIR)/spi_test.hex: $(BUILD_DIR)/spi_test.elf
	$(OBJCOPY) -O ihex $< $@

# Documentation targets
.PHONY: docs
docs: $(BUILD_DIR)/docs/architecture.pdf $(BUILD_DIR)/docs/protocol.pdf

$(BUILD_DIR)/docs/architecture.pdf: $(DOCS_DIR)/architecture.md
	@mkdir -p $(BUILD_DIR)/docs
	$(PANDOC) $< -o $@ -V geometry:margin=1in

$(BUILD_DIR)/docs/protocol.pdf: $(DOCS_DIR)/protocol.md
	@mkdir -p $(BUILD_DIR)/docs
	$(PANDOC) $< -o $@ -V geometry:margin=1in

# View waveforms
.PHONY: view-master
view-master: $(BUILD_DIR)/spi_master_tb.vcd
	$(GTKWAVE) $< &

$(BUILD_DIR)/spi_master_tb.vcd: $(BUILD_DIR)/spi_master_tb
	cd $(BUILD_DIR) && $(VVP) $<

.PHONY: view-slave
view-slave: $(BUILD_DIR)/spi_slave_tb.vcd
	$(GTKWAVE) $< &

$(BUILD_DIR)/spi_slave_tb.vcd: $(BUILD_DIR)/spi_slave_tb
	cd $(BUILD_DIR) && $(VVP) $<

# Clean targets
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	find $(PROJECT_ROOT) -name "*.vcd" -delete
	find $(PROJECT_ROOT) -name "*.vvp" -delete
	find $(PROJECT_ROOT) -name "*.o" -delete
	find $(PROJECT_ROOT) -name "*.elf" -delete
	find $(PROJECT_ROOT) -name "*.hex" -delete
	find $(PROJECT_ROOT) -name "*.ys" -delete

.PHONY: distclean
distclean: clean
	rm -f *.vcd *.vvp

# Help target
.PHONY: help
help:
	@echo "SPI Communication Project Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build everything (simulation, firmware, docs)"
	@echo "  sim        - Run Verilog simulations"
	@echo "  synth      - Run synthesis (requires Yosys)"
	@echo "  firmware   - Build firmware application"
	@echo "  docs       - Generate PDF documentation (requires Pandoc)"
	@echo "  view-master - View SPI master simulation waveforms"
	@echo "  view-slave  - View SPI slave simulation waveforms"
	@echo "  clean      - Remove build artifacts"
	@echo "  distclean  - Clean everything including simulation files"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Usage:"
	@echo "  make [target]"

# Directory creation for build artifacts
$(BUILD_DIR):
	@mkdir -p $@

# Test targets
.PHONY: test
test: sim
	@echo "Running all tests..."
	@echo "Tests completed"

# Format code
.PHONY: format
format:
	@echo "Formatting Verilog files..."
	find $(SRC_DIR) -name "*.v" -exec verible-verilog-format --inplace {} \;
	@echo "Formatting C files..."
	find $(FIRMWARE_DIR) -name "*.c" -exec clang-format -i {} \;
	find $(FIRMWARE_DIR) -name "*.h" -exec clang-format -i {} \;

# Create distribution package
.PHONY: dist
dist: all
	@echo "Creating distribution package..."
	@mkdir -p $(BUILD_DIR)/dist
	cp -r $(SRC_DIR) $(BUILD_DIR)/dist/
	cp -r $(DOCS_DIR) $(BUILD_DIR)/dist/
	cp README.md LICENSE Makefile $(BUILD_DIR)/dist/
	cd $(BUILD_DIR)/dist && tar -czf ../spi_project.tar.gz .
	@echo "Distribution package created: $(BUILD_DIR)/spi_project.tar.gz"
