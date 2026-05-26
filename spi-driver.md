
# Linux SPI Driver

# 1. Introduction

SPI stands for:

```text
Serial Peripheral Interface
````

SPI is a high-speed synchronous serial communication protocol used between a processor (master) and peripheral devices (slaves).

SPI is widely used in:

* Embedded Linux
* IoT systems
* Industrial automation
* Automotive electronics
* Display systems
* Sensor communication

Linux SPI Drivers allow the kernel to communicate with SPI devices such as:

* LCD/OLED displays
* ADC/DAC devices
* Flash memory
* Touch controllers
* Sensors
* WiFi modules
* Ethernet controllers

---

# 2. What is an SPI Driver?

An SPI Driver is a Linux kernel driver that communicates with hardware devices connected through the SPI bus.

The driver:

* Configures SPI communication
* Transfers data
* Reads/writes registers
* Handles interrupts
* Controls chip-select lines

SPI drivers mainly use:

* Linux SPI subsystem
* Device Tree
* spi_device structure
* spi_driver structure

---

# 3. Why Do We Use SPI Drivers?

Without SPI drivers:

* User applications cannot safely communicate with SPI devices
* Hardware register handling becomes difficult
* Bus arbitration becomes unsafe

SPI drivers provide:

| Feature                  | Purpose                        |
| ------------------------ | ------------------------------ |
| Hardware abstraction     | Hides protocol details         |
| Safe communication       | Kernel-managed transfers       |
| High-speed data transfer | Faster than I2C                |
| Standard Linux APIs      | Reusable framework             |
| Device Tree support      | Dynamic hardware configuration |

---

# 4. Real-Time Examples

| Device                 | Usage                  |
| ---------------------- | ---------------------- |
| NOR Flash              | Boot storage           |
| TFT LCD                | Display control        |
| Touchscreen Controller | Touch input            |
| ADC                    | Analog data conversion |
| DAC                    | Audio/video output     |
| Ethernet Controller    | Network communication  |
| WiFi Module            | Wireless communication |
| IMU Sensor             | Motion sensing         |

---

# 5. SPI Signals

SPI usually uses four wires:

| Signal | Purpose             |
| ------ | ------------------- |
| MOSI   | Master Out Slave In |
| MISO   | Master In Slave Out |
| SCLK   | Serial Clock        |
| CS/SS  | Chip Select         |

---

# 6. SPI Architecture

```text id="u8k2gl"
+------------------------------+
| User Space Application       |
+--------------+---------------+
               |
               v
+------------------------------+
| Linux SPI Subsystem          |
+--------------+---------------+
               |
               v
+------------------------------+
| SPI Driver                   |
|------------------------------|
| probe()                      |
| spi_sync()                   |
| register access              |
+--------------+---------------+
               |
               v
+------------------------------+
| SPI Controller Driver        |
+--------------+---------------+
               |
               v
+------------------------------+
| SPI Slave Device             |
+------------------------------+
```

---

# 7. SPI Communication Flow

```text id="jlwm4g"
Master Selects Slave
        ↓
Clock Generated
        ↓
Data Shift Out/In
        ↓
Transfer Complete
        ↓
Chip Select Released
```

---

# 8. SPI Master and Slave

## SPI Master

Controls:

* Clock generation
* Communication timing
* Chip select

Usually:

* CPU
* SoC

---

## SPI Slave

Responds to master communication.

Examples:

* Flash memory
* Sensors
* Displays

---

# 9. Important Linux SPI Structures

## struct spi_device

Represents SPI slave device.

Contains:

* Device information
* Bus configuration
* Chip select
* Speed

---

## struct spi_driver

Represents SPI driver.

Contains:

* probe()
* remove()
* Device Tree match table

---

# 10. Important Header Files

```c id="b7v8lh"
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/spi/spi.h>
#include <linux/of.h>
#include <linux/delay.h>
```

---

# 11. Device Tree Example

## mydevice.dts

```dts id="zk4rfi"
&spi0 {

    myspi@0 {
        compatible = "myvendor,myspi";
        reg = <0>;
        spi-max-frequency = <1000000>;
    };
};
```

---

# 12. Device Tree Explanation

| Property          | Purpose            |
| ----------------- | ------------------ |
| spi0              | SPI controller     |
| compatible        | Driver matching    |
| reg               | Chip select number |
| spi-max-frequency | SPI clock speed    |

---

# 13. SPI Driver Flow

## Step 1 – Device Tree Match

Kernel matches:

```c id="g3v6vb"
compatible = "myvendor,myspi"
```

with driver.

---

## Step 2 – probe() Called

Kernel calls:

```c id="7p3m0w"
probe()
```

---

## Step 3 – SPI Device Initialized

Communication parameters configured.

---

## Step 4 – Data Transfer Begins

Using SPI APIs.

---

# 14. Full SPI Driver Example

## spi_driver.c

```c id="h9b57f"
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/spi/spi.h>
#include <linux/of.h>

#define BUFFER_SIZE 2

static int my_spi_probe(struct spi_device *spi)
{
    int ret;
    u8 tx_buffer[BUFFER_SIZE] = {0xAA, 0x55};
    u8 rx_buffer[BUFFER_SIZE];

    printk(KERN_INFO "SPI Driver Probe Called\n");

    spi->mode = SPI_MODE_0;
    spi->bits_per_word = 8;
    spi->max_speed_hz = 1000000;

    ret = spi_setup(spi);

    if (ret < 0) {
        printk(KERN_ERR "SPI Setup Failed\n");
        return ret;
    }

    ret = spi_write_then_read(spi,
                              tx_buffer,
                              BUFFER_SIZE,
                              rx_buffer,
                              BUFFER_SIZE);

    if (ret < 0) {
        printk(KERN_ERR "SPI Transfer Failed\n");
        return ret;
    }

    printk(KERN_INFO "SPI Transfer Successful\n");

    return 0;
}

static void my_spi_remove(struct spi_device *spi)
{
    printk(KERN_INFO "SPI Driver Removed\n");
}

static const struct of_device_id my_spi_of_match[] = {
    { .compatible = "myvendor,myspi" },
    { }
};

MODULE_DEVICE_TABLE(of, my_spi_of_match);

static struct spi_driver my_spi_driver = {
    .driver = {
        .name = "my_spi_driver",
        .of_match_table = my_spi_of_match,
    },

    .probe = my_spi_probe,
    .remove = my_spi_remove,
};

module_spi_driver(my_spi_driver);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("Simple Linux SPI Driver");
```

---

# 15. Makefile

```Makefile id="e0j8lh"
obj-m += spi_driver.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

all:
	make -C $(KDIR) M=$(PWD) modules

clean:
	make -C $(KDIR) M=$(PWD) clean
```

---

# 16. Compile Driver

```bash id="1fyqlj"
make
```

Output:

```bash id="g7w0zb"
spi_driver.ko
```

---

# 17. Insert Driver

```bash id="x5g2yy"
sudo insmod spi_driver.ko
```

---

# 18. Check Kernel Logs

```bash id="vgv0pb"
dmesg | tail
```

Expected:

```text id="u7g1vr"
SPI Driver Probe Called
SPI Transfer Successful
```

---

# 19. Important SPI APIs

## spi_setup()

Configures SPI parameters.

Example:

```c id="b5m0cf"
spi_setup(spi);
```

---

## spi_write()

Writes data to SPI device.

Example:

```c id="2n2k11"
spi_write(spi, tx_buf, len);
```

---

## spi_read()

Reads data from SPI device.

Example:

```c id="uzw6eo"
spi_read(spi, rx_buf, len);
```

---

## spi_write_then_read()

Writes and reads in one transaction.

Example:

```c id="w1r11k"
spi_write_then_read(spi,
                    tx_buf,
                    tx_len,
                    rx_buf,
                    rx_len);
```

---

## spi_sync()

Performs synchronous SPI transfer.

---

# 20. SPI Modes

SPI supports four modes.

| Mode       | CPOL | CPHA |
| ---------- | ---- | ---- |
| SPI_MODE_0 | 0    | 0    |
| SPI_MODE_1 | 0    | 1    |
| SPI_MODE_2 | 1    | 0    |
| SPI_MODE_3 | 1    | 1    |

Incorrect mode causes communication failure.

---

# 21. Advantages of SPI

| Advantage              | Description                |
| ---------------------- | -------------------------- |
| High Speed             | Faster than I2C            |
| Full Duplex            | Simultaneous TX/RX         |
| Simple Protocol        | Easy hardware design       |
| No Addressing Overhead | Faster communication       |
| Flexible               | Supports many device types |

---

# 22. Disadvantages of SPI

| Disadvantage         | Description              |
| -------------------- | ------------------------ |
| More Wires           | Requires 4+ lines        |
| No Device Addressing | Uses chip select         |
| More GPIO Usage      | Separate CS lines        |
| Complex PCB Routing  | Large systems difficult  |
| No Standard Protocol | Device-specific commands |

---

# 23. SPI vs I2C

| Feature    | SPI      | I2C      |
| ---------- | -------- | -------- |
| Speed      | High     | Moderate |
| Wires      | 4+       | 2        |
| Duplex     | Full     | Half     |
| Addressing | No       | Yes      |
| Complexity | Moderate | Simple   |

---

# 24. Common Interview Questions

## Q1. What is SPI?

SPI is a synchronous serial communication protocol used between processors and peripherals.

---

## Q2. Why is SPI Faster Than I2C?

SPI:

* Has dedicated clock
* No addressing overhead
* Supports full duplex communication

---

## Q3. What is spi_device?

Represents SPI slave device in Linux kernel.

Contains:

* Chip select
* Speed
* Mode
* Device information

---

## Q4. What is probe() in SPI Driver?

probe() is called when kernel matches SPI hardware with driver.

Used for:

* SPI configuration
* Hardware initialization
* Register setup

---

## Q5. What Happens if SPI Mode is Wrong?

Communication fails because clock polarity/phase mismatch occurs.

---

# 25. Common Errors

## Error: SPI Transfer Failed

Cause:

* Wrong SPI mode
* Incorrect clock speed

Fix:

* Verify device datasheet

---

## Error: Device Not Detected

Cause:

* Wrong Device Tree configuration

Fix:

* Verify compatible string
* Verify chip select

---

## Error: No Data Received

Cause:

* Wiring issue

Fix:

* Verify MOSI/MISO/SCLK lines

---

# 26. SPI Debugging Techniques

## Check SPI Devices

```bash id="t2l7k6"
ls /dev/spidev*
```

---

## Kernel Logs

```bash id="m6jv5i"
dmesg | tail
```

---

## SPI Test Utility

```bash id="5lx9ig"
spidev_test
```

---

## Device Tree Verification

```bash id="f0w4wf"
ls /proc/device-tree/
```

---

# 27. Advanced SPI Topics

After learning basic SPI drivers, move to:

* DMA-based SPI
* Asynchronous SPI transfers
* SPI NOR Flash drivers
* SPI NAND drivers
* SPI display drivers
* SPI touchscreen drivers
* Multi-slave systems
* Interrupt handling
* Power management

---

# 28. Best Practices

## Always Verify SPI Mode

```c id="zyr0nv"
SPI_MODE_0
SPI_MODE_1
SPI_MODE_2
SPI_MODE_3
```

---

## Check Return Values

```c id="o4s2m2"
if (ret < 0)
    return ret;
```

---

## Use Device Tree

Avoid hardcoded parameters.

---

## Keep Transfers Small

Large transfers may require DMA optimization.

---

# 29. Real Hardware Platforms

SPI drivers are widely used on:

* Raspberry Pi 5
* BeagleBone Black
* NVIDIA Jetson Nano
* STM32MP157

---

# 30. Popular SPI Devices

| Device   | Purpose             |
| -------- | ------------------- |
| W25Q64   | SPI NOR Flash       |
| MCP3008  | ADC                 |
| ILI9341  | TFT LCD             |
| NRF24L01 | Wireless module     |
| ADS1256  | Precision ADC       |
| ENC28J60 | Ethernet controller |

---

