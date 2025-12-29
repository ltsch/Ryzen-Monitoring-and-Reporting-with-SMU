#!/bin/bash
# Ryzen Temperature Monitor - Install Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/ryzen_temps"
TEMP_BUILD_DIR="/tmp/ryzen_temp_build_$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
fi

# Uninstall mode
if [[ "$1" == "--uninstall" ]]; then
    info "Uninstalling Ryzen Temperature Monitor..."
    
    rm -f /usr/local/bin/ryzen_monitor
    rm -f /usr/local/bin/ryzen_temps_history
    rm -f /usr/local/bin/ryzen_temps.sh
    rm -f /etc/cron.d/ryzen_temps
    
    warn "Log directory $LOG_DIR was NOT removed. Delete manually if desired."
    
    info "Uninstall complete!"
    exit 0
fi

# Dependencies check
if ! command -v git &>/dev/null; then
    info "Installing git..."
    apt-get update && apt-get install -y git
fi

# Check for bc (required for history viewer math)
if ! command -v bc &>/dev/null; then
    info "Installing bc..."
    apt-get update && apt-get install -y bc
fi

# cleanup function
cleanup() {
    rm -rf "$TEMP_BUILD_DIR"
}
trap cleanup EXIT

mkdir -p "$TEMP_BUILD_DIR"

# Check for ryzen_smu kernel module
if [[ ! -d /sys/kernel/ryzen_smu_drv ]]; then
    warn "ryzen_smu kernel module not loaded."
    
    info "Cloning ryzen_smu..."
    cd "$TEMP_BUILD_DIR"
    git clone https://github.com/leogx9r/ryzen_smu.git
    
    if [[ -d "ryzen_smu" ]]; then
        cd ryzen_smu
        info "Building and installing ryzen_smu kernel module..."
        
        # Install build dependencies if needed
        if ! command -v dkms &>/dev/null; then
            info "Installing DKMS and headers..."
            apt-get update && apt-get install -y dkms build-essential linux-headers-$(uname -r)
        fi
        
        # Get version from dkms.conf
        SMU_VERSION=$(grep 'PACKAGE_VERSION=' dkms.conf | cut -d'"' -f2)
        SMU_NAME="ryzen_smu"
        
        # Install via DKMS for automatic rebuilds on kernel upgrades
        if [[ -n "$SMU_VERSION" ]]; then
            info "Installing ryzen_smu $SMU_VERSION via DKMS..."
            
            # Copy source to DKMS location
            mkdir -p "/usr/src/${SMU_NAME}-${SMU_VERSION}"
            cp -r * "/usr/src/${SMU_NAME}-${SMU_VERSION}/"
            
            # Add and build
            dkms add -m "$SMU_NAME" -v "$SMU_VERSION" 2>/dev/null || true
            dkms build -m "$SMU_NAME" -v "$SMU_VERSION"
            dkms install -m "$SMU_NAME" -v "$SMU_VERSION"
            
            modprobe ryzen_smu
        else
            # Fallback to manual build
            info "Building ryzen_smu manually..."
            make clean && make
            insmod ryzen_smu.ko
        fi
        
        # Verify module loaded
        if [[ -d /sys/kernel/ryzen_smu_drv ]]; then
            info "ryzen_smu module loaded successfully!"
        else
            error "Failed to load ryzen_smu module. Check dmesg for errors."
        fi
    else
        error "Failed to clone ryzen_smu."
    fi
fi

info "Installing Ryzen Temperature Monitor..."

# Check if ryzen_monitor exists, if not build it
if [[ ! -f "$SCRIPT_DIR/ryzen_monitor/src/ryzen_monitor" ]] && [[ ! -f /usr/local/bin/ryzen_monitor ]]; then
    info "Cloning ryzen_monitor..."
    cd "$TEMP_BUILD_DIR"
    # Use upstream repo which now includes my PRs for driver support and single-shot mode
    git clone https://github.com/AzagraMac/ryzen_monitor.git
    
    if [[ -d "ryzen_monitor" ]]; then
        cd ryzen_monitor
        
        info "Building ryzen_monitor..."
        make clean && make
        
        info "Installing ryzen_monitor to /usr/local/bin/"
        cp src/ryzen_monitor /usr/local/bin/
        chmod +x /usr/local/bin/ryzen_monitor
    else
        error "Failed to clone ryzen_monitor."
    fi
elif [[ -f "$SCRIPT_DIR/ryzen_monitor/src/ryzen_monitor" ]]; then
    # Use local copy if present (legacy support)
    info "Installing local ryzen_monitor binary..."
    cp "$SCRIPT_DIR/ryzen_monitor/src/ryzen_monitor" /usr/local/bin/
    chmod +x /usr/local/bin/ryzen_monitor
fi

# Install logging script
info "Installing ryzen_temps.sh"
cp "$SCRIPT_DIR/ryzen_temps.sh" /usr/local/bin/ryzen_temps.sh
chmod +x /usr/local/bin/ryzen_temps.sh



# Install history viewer
info "Installing ryzen_temps_history"
cp "$SCRIPT_DIR/ryzen_temps_history.sh" /usr/local/bin/ryzen_temps_history
chmod +x /usr/local/bin/ryzen_temps_history

# Create log directory
info "Creating log directory: $LOG_DIR"
mkdir -p "$LOG_DIR"

# Install cron job
info "Installing cron job"
cat > /etc/cron.d/ryzen_temps << 'EOF'
# Ryzen CPU Temperature Logging
# Collect temperature data every minute
* * * * * root /usr/local/bin/ryzen_temps.sh >/dev/null 2>&1
EOF
chmod 644 /etc/cron.d/ryzen_temps

# Test installation
info "Testing installation..."
if /usr/local/bin/ryzen_temps.sh; then
    info "Logging test successful!"
else
    warn "Logging test failed. Check ryzen_monitor output."
fi

echo ""
info "Installation complete!"
echo ""
echo "Usage:"
echo "  ryzen_temps_history        # View temperature history"
echo "  ryzen_temps_history -a     # Check for thermal alerts"
echo "  ryzen_temps_history -p     # View peak temperatures"
echo "  ryzen_monitor -1           # Single temperature snapshot"
echo ""
echo "Logs: $LOG_DIR"
