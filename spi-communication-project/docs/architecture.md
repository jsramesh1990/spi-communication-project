# SPI Communication Architecture

## Overview
This document describes the architecture of the SPI communication system implemented in this project.

## Block Diagram
┌─────────────────────────────────────────┐
│ SoC Top Level │
├─────────────────────────────────────────┤
│ ┌─────────┐ ┌──────────┐ ┌─────────┐ │
│ │ CPU │ │ Memory │ │ GPIO │ │
│ │ │ │ │ │ │ │
│ └────┬────┘ └────┬─────┘ └────┬────┘ │
│ │ │ │ │
│ ┌────▼─────────────▼─────────────▼────┐ │
│ │ Wishbone Bus Interface │ │
│ └─────────────────────────────────────┘ │
│ │ │
│ ┌──────▼──────┐ │
│ │ SPI Controller│ │
│ │ ┌──────────┐ │ │
│ │ │ Register │ │ │
│ │ │ Interface│ │ │
│ │ └────┬─────┘ │ │
│ │ │ │ │
│ │ ┌────▼─────┐ │ │
│ │ │ SPI Master│ │ │
│ │ └──────────┘ │ │
│ └──────────────┘ │
│ │ │
│ ┌─────▼─────┐ │
│ │ SPI Pins │ │
│ │ SCK MOSI │ │
│ │ MISO CS │ │
│ └───────────┘ │
└─────────────────────────────────────────┘

text

## Components

### 1. SPI Master Module
The core SPI master controller that:
- Generates SCK clock based on configuration
- Controls MOSI data output
- Samples MISO data input
- Manages Chip Select (CS) signals
- Supports all SPI modes (0-3)

### 2. SPI Controller
Register interface module that:
- Provides memory-mapped registers
- Handles bus interface (Wishbone compatible)
- Manages control and status registers
- Implements interrupt logic
- Supports FIFO buffering

### 3. SPI Slave Module
Optional slave implementation for:
- Testing and simulation
- Multi-master configurations
- Peripheral emulation

## Register Map

### Control Register (0x00)
Bit 0: START - Start transfer (auto-clears)
Bit 1: MODE0 - SPI mode bit 0
Bit 2: MODE1 - SPI mode bit 1
Bit 3: CS_SEL0 - Chip select 0
Bit 4: CS_SEL1 - Chip select 1
Bit 5: IRQ_EN - Interrupt enable
Bit 6: DMA_EN - DMA enable
Bit 7: LOOPBACK - Loopback mode

text

### Status Register (0x04)
Bit 0: BUSY - Transfer in progress
Bit 1: DONE - Transfer complete
Bit 2: TX_FULL - TX FIFO full
Bit 3: TX_EMPTY - TX FIFO empty
Bit 4: RX_FULL - RX FIFO full
Bit 5: RX_EMPTY - RX FIFO empty
Bit 6: ERROR - Transfer error
Bit 7: IRQ_PEND - Interrupt pending

text

## Clocking
The SPI clock is derived from the system clock using a configurable divider:
SPI_SCK = System_Clock / (2 × CLK_DIV)

text

## Interrupts
The controller can generate interrupts for:
- Transfer completion
- TX FIFO empty (ready for more data)
- RX FIFO full (data available)
- Error conditions

## DMA Support
When DMA is enabled, the controller can:
- Automatically fetch data from memory
- Store received data to memory
- Generate DMA requests
- Handle block transfers
