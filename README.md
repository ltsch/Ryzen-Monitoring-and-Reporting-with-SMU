# Ryzen Temperature Monitor

A lightweight CPU temperature monitoring solution for AMD Ryzen processors, built on top of the [ryzen_smu](https://github.com/leogx9r/ryzen_smu) kernel module.

Originally designed for Proxmox, but should work on any apt-based Linux distribution running on a Ryzen processor.

> [!NOTE]
> Full disclosure: This project contains some AI-written code because I am not a very good developer. I have reviewed it, but transparency is key.

## Features

- 📊 **Per-minute temperature logging** to CSV
- 📈 **Historical data viewer** with multiple output modes
- ⚠️ **Thermal alerts** for high temperature detection
- 🔄 **Automatic log rotation** (7-day retention)
- 📅 **Daily summaries** for long-term trend analysis
- 🌈 **RGB lighting control** via OpenRGB (optional)
- 🔧 Built on [ryzen_monitor](https://github.com/AzagraMac/ryzen_monitor)

## Prerequisites

- AMD Ryzen processor
- Root privileges (sudo)
- Internet connection (for cloning dependencies)
- `bc` (Basic Calculator) - installed automatically

## Quick Start

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/temp_monitor.git
cd temp_monitor

# Run installer as root
sudo ./install.sh
```

The installer will automatically:
1. Install dependencies (`git`, `bc`, `dkms`, kernel headers)
2. Build and install `ryzen_smu` kernel module (via DKMS)
3. Build and install `ryzen_monitor` utility
4. Install the temperature logging scripts
5. Create log directory at `/var/log/ryzen_temps/`
6. Set up cron job for per-minute data collection

## Usage

### View Temperature History

```bash
# Default: last 10 readings + today's summary
ryzen_temps_history

# Last N readings
ryzen_temps_history -l 20

# Today's statistics
ryzen_temps_history -d

# Last hour statistics  
ryzen_temps_history -h

# Weekly daily summaries
ryzen_temps_history -w

# Peak temperatures
ryzen_temps_history -p

# Thermal alert check (exit code = number of alerts)
ryzen_temps_history -a
```

### Manual Temperature Check

```bash
# Live monitoring (Ctrl+C to exit)
ryzen_monitor

# Single snapshot
ryzen_monitor -1
```

## RGB Lighting Integration

This monitor can optionally control your motherboard's RGB LEDs to reflect CPU temperature (Green → Yellow → Red).

**See [OPENRGB.md](OPENRGB.md) for setup instructions.**

> [!IMPORTANT]
> RGB control is **disabled by default**. You must enable it after installation.

## Configuration

### Temperature Logging

The main logging script is installed to `/usr/local/bin/ryzen_temps.sh`.

### History Viewer Thresholds

Edit `/usr/local/bin/ryzen_temps_history` to adjust alert thresholds:

```bash
WARN_TEMP=80   # Warning threshold (yellow)
CRIT_TEMP=85   # Critical threshold (red)
```

### OpenRGB Settings

Edit `/usr/local/bin/ryzen_temps.sh` to configure RGB lighting:

```bash
ENABLE_OPENRGB=false   # Set to 'true' to enable
OPENRGB_DEVICES="0"    # Device ID(s) to control
RGB_TEMP_LOW=60        # Green below this temp
RGB_TEMP_MID=70        # Yellow around this temp  
RGB_TEMP_HIGH=80       # Red above this temp
```

See [OPENRGB.md](OPENRGB.md) for detailed configuration options.

## Log Files

| File | Contents |
|------|----------|
| `/var/log/ryzen_temps/current.csv` | Today's minute-by-minute data |
| `/var/log/ryzen_temps/YYYY-MM-DD.csv` | Archived daily logs (7-day retention) |
| `/var/log/ryzen_temps/daily_summary.csv` | Daily min/avg/max (permanent) |

### CSV Format

```csv
timestamp,peak_core_temp,peak_pkg_temp,soc_temp,ppt_pct,thm_pct,socket_power
2025-12-22T17:10:46-06:00,79.98,87.75,45.37,90.79,89.22,128.898
```

## Uninstall

```bash
sudo ./install.sh --uninstall
```

> [!NOTE]
> Log directory `/var/log/ryzen_temps/` is preserved. Delete manually if desired.

## License

GPL-3.0 (same as ryzen_smu)
