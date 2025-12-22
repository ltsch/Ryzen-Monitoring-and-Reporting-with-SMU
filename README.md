# Ryzen Temperature Monitor Designed for Proxmox

A lightweight CPU temperature monitoring solution for AMD Ryzen processors running on Proxmox, built on top of the [ryzen_smu](https://github.com/leogx9r/ryzen_smu) kernel module.

- Note: This was designed for Proxmox, but should work on any Linux system with a Ryzen processor.

### Transparency notice: This project contains some AI generated code because I am not a very good developer.

## Features

- 📊 **Per-minute temperature logging** to CSV
- 📈 **Historical data viewer** with multiple output modes
- ⚠️ **Thermal alerts** for high temperature detection
- 🔄 **Automatic log rotation** (7-day retention)
- 📅 **Daily summaries** for long-term trend analysis
- 🔧 **[Patched ryzen_monitor](PATCHES.md)** with single-shot mode and updated driver support

## Prerequisites

- AMD Ryzen processor
- Root privileges (sudo)
- Internet connection (for cloning repositories)

## Installation

```bash
# Clone/download this folder, then:
sudo ./install.sh
```

This will automatically:
1. Check for `ryzen_smu` kernel module, and if missing:
   - Clone it from GitHub
   - Build and install it (via DKMS if available)
2. Check for `ryzen_monitor`, and if missing:
   - Clone it from GitHub
   - **Auto-patch it** for compatibility with newer drivers
   - Build and install to `/usr/local/bin/`
3. Install logging script and viewer
4. Create log directory at `/var/log/ryzen_temps/`
5. Set up cron job for per-minute data collection

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

# Thermal alert check (exit code = # of alerts)
ryzen_temps_history -a
```

### Manual Temperature Check

```bash
# Live monitoring (Ctrl+C to exit)
ryzen_monitor

# Single snapshot
ryzen_monitor -1
```

## Log Files

| File | Contents |
|------|----------|
| `/var/log/ryzen_temps/current.csv` | Today's minute-by-minute data |
| `/var/log/ryzen_temps/YYYY-MM-DD.csv` | Archived daily logs (7-day retention) |
| `/var/log/ryzen_temps/daily_summary.csv` | Daily min/avg/max (permanent) |

## CSV Format

```csv
timestamp,peak_core_temp,peak_pkg_temp,soc_temp,ppt_pct,thm_pct,socket_power
2025-12-22T17:10:46-06:00,79.98,87.75,45.37,90.79,89.22,128.898
```

## Configuration

Edit `/usr/local/bin/ryzen_temps_history` to adjust alert thresholds:

```bash
WARN_TEMP=80   # Warning threshold (yellow)
CRIT_TEMP=85   # Critical threshold (red)
```

## Uninstall

```bash
sudo ./install.sh --uninstall
```

## License

GPL-3.0 (same as ryzen_smu)
