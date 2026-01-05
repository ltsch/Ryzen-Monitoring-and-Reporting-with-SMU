# OpenRGB Integration for Ryzen Temperature Monitor

This project supports **optional** RGB lighting control via [OpenRGB](https://openrgb.org/), allowing your motherboard or other RGB devices to visually indicate CPU temperature.

> [!NOTE]
> OpenRGB is disabled by default. You must explicitly enable it after installation.

## Features

- **Automatic Color Control**: Updates LEDs based on CPU Core Temperature
- **Configurable Gradient**: Customize the temperature thresholds for Green/Yellow/Red
- **Multi-Device Support**: Control multiple RGB devices simultaneously
- **Hardware Compatibility**: Supports both RGB and GRB color ordering

## Prerequisites

1. **OpenRGB must be installed separately**
   - Download from [OpenRGB Releases](https://openrgb.org/releases.html)
   - For Debian/Proxmox: `dpkg -i openrgb_*.deb && apt-get install -f`
   - For other distros, see the [OpenRGB GitLab](https://gitlab.com/CalcProgrammer1/OpenRGB)

2. **Kernel modules** (may be required for some hardware):
   ```bash
   # Load I2C modules (required for motherboard RGB)
   modprobe i2c-dev
   modprobe i2c-piix4  # AMD systems
   
   # Make persistent across reboots
   echo "i2c-dev" >> /etc/modules
   echo "i2c-piix4" >> /etc/modules
   ```

3. **Verify device detection**:
   ```bash
   openrgb --list-devices
   ```
   Note the device ID (e.g., `0`) for your motherboard or RGB controller.

## Configuration

After running `install.sh`, edit the installed script:

```bash
sudo nano /usr/local/bin/ryzen_temps.sh
```

### Configuration Options

```bash
# =============================================================================
# OPENRGB CONFIGURATION
# =============================================================================

# Enable/Disable OpenRGB integration
ENABLE_OPENRGB=false          # Set to 'true' to enable

# Device IDs to control (space-separated)
OPENRGB_DEVICES="0"           # Use `openrgb --list-devices` to find IDs

# Path to OpenRGB binary
OPENRGB_BIN="/usr/bin/openrgb"

# Color byte order: "RGB" or "GRB"
# Some motherboards (e.g. ASRock) use GRB instead of RGB
OPENRGB_COLOR_ORDER="GRB"

# Debug logging (writes to /tmp/rgb_debug.log)
OPENRGB_DEBUG=false

# -----------------------------------------------------------------------------
# Temperature Thresholds (must be in order: LOW < MID < HIGH)
# -----------------------------------------------------------------------------
RGB_TEMP_LOW=60    # Below this: Pure Green
RGB_TEMP_MID=70    # Transition point (Yellow)
RGB_TEMP_HIGH=80   # Above this: Pure Red
```

## Color Gradient

The RGB color smoothly transitions based on temperature:

| Temperature | Color | Meaning |
|-------------|-------|---------|
| < 60°C | 🟢 Green | Cool/Idle |
| 60-70°C | 🟡 Yellow | Warming up |
| 70-80°C | 🟠 Orange | Hot |
| > 80°C | 🔴 Red | Critical |

## Troubleshooting

### Colors appear wrong (e.g., Red shows as Green)

Your hardware may use **GRB** color ordering instead of **RGB**:
```bash
OPENRGB_COLOR_ORDER="GRB"  # Try switching between "RGB" and "GRB"
```

### OpenRGB not controlling device

1. Check if OpenRGB can see your device: `openrgb --list-devices`
2. Ensure I2C modules are loaded: `lsmod | grep i2c`
3. Enable debug logging and check `/tmp/rgb_debug.log`

### For OpenRGB-specific issues

This project integrates with OpenRGB but does not provide support for OpenRGB itself.
For hardware detection issues, driver problems, or OpenRGB bugs, please refer to:

- **OpenRGB Website**: https://openrgb.org/
- **OpenRGB GitLab**: https://gitlab.com/CalcProgrammer1/OpenRGB
- **Supported Devices**: https://openrgb.org/devices.html
