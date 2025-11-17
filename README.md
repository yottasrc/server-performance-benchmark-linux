BenchX v1.4 – Modern Linux Server Benchmark
by **YottaSrc Inc.**
https://yottasrc.com

BenchX is a modern, advanced benchmark tool for Linux servers.
It analyzes **CPU, RAM, Disk I/O, RAID setup, Network performance**, and automatically runs an **Ookla Speedtest** with a random nearby server.

BenchX is designed as a clean alternative to outdated server benchmark scripts and provides a professional, colorized, easy-to-read output.

---

## Quick Run (Recommended)

Run BenchX on any Linux server:

### Using `curl`
```bash
curl -Lso- srvx.ws | bash
````

### Using `wget`

```bash
wget -qO- srvx.ws | bash
```
### Using `http`

```bash
http srvx.ws | bash
```

---

## Features

BenchX v1.4 includes:

* **System Information**

  * CPU model, cores, frequency
  * AES-NI & VMX/AMD-V virtualization flags
  * RAM & disk size (automatic conversion from KiB/MiB/GiB → KB/MB/GB)
  * OS version, kernel, architecture, uptime, load average

* **Network Information**

  * ISP, datacenter/organization
  * City, region, country
  * IPv4 & IPv6 auto-detection

* **RAID Detection**

  * Linux Software RAID (mdadm)
  * LSI / MegaRAID (storcli / megacli)
  * Dell PERC (omreport)
  * ZFS pools
  * Clean readable output

* **Disk I/O Benchmark**

  * 3× sequential write tests (1GB each)
  * MB/s or GB/s auto conversion
  * Average throughput calculation

* **Automatic Speedtest Installation**

  * Installs Ookla Speedtest (apt, yum, dnf supported)
  * Random nearest server selection
  * Download, upload, latency, distance reporting

* **Beautiful Output**

  * Unicode box drawing (╔═╗, ╚═╝) with fallback for non-UTF8 terminals
  * Colors, centered footer, consistent formatting

---

## Script Architecture Explained

Below is a breakdown of all major components of the script:

---

### 1. Terminal Capability Check

```bash
supports_unicode()
```

Detects UTF-8 support and selects between Unicode box characters or ASCII fallback.
Ensures the script looks good on all terminals (SSH, console, tmux, etc).

---

### 2. Visual Settings & Box Drawing

Functions:

* `box_open`
* `box_line`
* `box_end`
* `wrap_box_text`
* `center_text`

These generate the polished benchmark output box.
They ensure all sections look consistent and readable.

---

### 3. Unit Conversion

```bash
convert_mem_unit()
```

Converts Linux memory units like `Gi`/`Mi` into standard `GB`/`MB`.
This avoids confusion between binary and decimal units.

---

### 4. System Information

```bash
get_info()
```

Collects:

* CPU info
* Memory
* Disk usage
* OS and kernel
* Uptime
* Load average
* Location (via ipinfo.io)

This gives a full snapshot of the server hardware and environment.

---

### 5. RAID Detection

```bash
detect_raid()
```

Supports multiple RAID types:

* **Software RAID** (`mdadm`)
* **LSI/MegaRAID** (`storcli`, `megacli`)
* **Dell PERC** (`omreport`)
* **ZFS RAID** (`zpool`)

Everything is formatted inside the visual box layout.

---

### 6. Disk I/O Benchmark

```bash
io_speed()
```

Runs:

```bash
dd if=/dev/zero of=benchx_test bs=1M count=1024
```

Three times, syncs, deletes the test file, and shows MB/s (or GB/s).
Then calculates the average.

---

### 7. Speedtest Integration

Includes:

* auto-installation of Ookla Speedtest
* random nearby server selection
* clean output with download/upload/latency

Function:

```bash
print_speedtest_simple()
```

---

### 8. Output Printers

* `print_system`
* `print_network`
* `print_raid`
* `print_io`
* `print_speedtest_simple`
* `print_footer`

Each generates a structured, colorized section.

---

### 9. Main Execution Flow

```bash
clear
echo "BenchX v1.4"
get_info
detect_raid
print_system
print_network
print_raid
print_io
print_speedtest_simple
print_footer
```

Clean, easy to follow, fully modular.

---

## Requirements

BenchX works on most Linux distributions:

* Debian / Ubuntu / Kali
* CentOS / AlmaLinux / Rocky / RHEL
* Fedora
* Arch Linux
* OpenSUSE
* Proxmox
* All VPS providers (YottaSrc, Hetzner, OVH, DigitalOcean, DO, etc.)

Dependencies installed automatically:

* `speedtest-cli` from Ookla (if not available)

---

## ❤️ Powered by

**YottaSrc Inc.**
[https://yottasrc.com](https://yottasrc.com)
