#!/bin/bash
# Ryzen Temperature History Viewer
# Shows recent temperature data and peak detection

LOG_DIR="/var/log/ryzen_temps"
CURRENT_LOG="$LOG_DIR/current.csv"
DAILY_SUMMARY="$LOG_DIR/daily_summary.csv"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Thresholds
WARN_TEMP=80
CRIT_TEMP=85

show_help() {
    echo "Ryzen Temperature History Viewer"
    echo ""
    echo "Usage: $(basename $0) [OPTION]"
    echo ""
    echo "Options:"
    echo "  -l, --last N     Show last N entries (default: 10)"
    echo "  -h, --hour       Show stats for the last hour"
    echo "  -d, --day        Show stats for today"
    echo "  -w, --week       Show daily summaries for the week"
    echo "  -p, --peaks      Show peak temperatures only"
    echo "  -a, --alerts     Check for thermal alerts"
    echo "  --help           Show this help"
    exit 0
}

# Check if log exists
if [[ ! -f "$CURRENT_LOG" ]]; then
    echo "No temperature logs found. Run ryzen_temps.sh first."
    exit 1
fi

format_temp() {
    local temp=$1
    if [[ -z "$temp" ]]; then return; fi
    if (( $(echo "$temp > $CRIT_TEMP" | bc -l) )); then
        echo -e "${RED}${temp}°C${NC}"
    elif (( $(echo "$temp > $WARN_TEMP" | bc -l) )); then
        echo -e "${YELLOW}${temp}°C${NC}"
    else
        echo -e "${GREEN}${temp}°C${NC}"
    fi
}

show_last() {
    local n=${1:-10}
    echo -e "${BOLD}Last $n Temperature Readings${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-20s %10s %10s %10s %8s %8s %10s\n" "Timestamp" "Core" "Pkg" "SoC" "PPT%" "THM%" "Power"
    echo "────────────────────────────────────────────────────────────────────────────────"
    tail -n "$n" "$CURRENT_LOG" | tail -n +1 | while IFS=',' read -r ts core pkg soc ppt thm power; do
        [[ "$ts" == "timestamp" ]] && continue
        time_short=$(echo "$ts" | cut -d'T' -f2 | cut -d'+' -f1 | cut -d'-' -f1)
        date_short=$(echo "$ts" | cut -d'T' -f1 | cut -d'-' -f2-)
        printf "%-20s %10s %10s %10s %7s%% %7s%% %9sW\n" \
            "$date_short $time_short" "$core°C" "$pkg°C" "$soc°C" "$ppt" "$thm" "$power"
    done
}

show_hour() {
    local one_hour_ago=$(date -d '1 hour ago' -Iseconds)
    echo -e "${BOLD}Last Hour Statistics${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    tail -n +2 "$CURRENT_LOG" | awk -F',' -v cutoff="$one_hour_ago" '
    $1 >= cutoff {
        if(NR==1 || $2<min_core) min_core=$2
        if(NR==1 || $2>max_core) max_core=$2
        sum_core+=$2
        if(NR==1 || $3<min_pkg) min_pkg=$3
        if(NR==1 || $3>max_pkg) max_pkg=$3
        sum_pkg+=$3
        count++
    }
    END {
        if(count>0) {
            printf "Samples: %d\n\n", count
            printf "Core Temp:  Min: %.1f°C  Avg: %.1f°C  Max: %.1f°C\n", min_core, sum_core/count, max_core
            printf "Pkg Temp:   Min: %.1f°C  Avg: %.1f°C  Max: %.1f°C\n", min_pkg, sum_pkg/count, max_pkg
        } else {
            print "No data in the last hour"
        }
    }'
}

show_day() {
    echo -e "${BOLD}Today's Statistics${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    tail -n +2 "$CURRENT_LOG" | awk -F',' '
    {
        if(NR==1 || $2<min_core) min_core=$2
        if(NR==1 || $2>max_core) max_core=$2
        sum_core+=$2
        if(NR==1 || $3<min_pkg) min_pkg=$3  
        if(NR==1 || $3>max_pkg) max_pkg=$3
        sum_pkg+=$3
        if(NR==1 || $4<min_soc) min_soc=$4
        if(NR==1 || $4>max_soc) max_soc=$4
        sum_soc+=$4
        sum_ppt+=$5
        sum_thm+=$6
        sum_power+=$7
        count++
    }
    END {
        if(count>0) {
            printf "Samples: %d (since midnight)\n\n", count
            printf "Core Temp:    Min: %5.1f°C   Avg: %5.1f°C   Max: %5.1f°C\n", min_core, sum_core/count, max_core
            printf "Package Temp: Min: %5.1f°C   Avg: %5.1f°C   Max: %5.1f°C\n", min_pkg, sum_pkg/count, max_pkg
            printf "SoC Temp:     Min: %5.1f°C   Avg: %5.1f°C   Max: %5.1f°C\n", min_soc, sum_soc/count, max_soc
            printf "\nAvg PPT: %.1f%%   Avg THM: %.1f%%   Avg Power: %.1fW\n", sum_ppt/count, sum_thm/count, sum_power/count
        } else {
            print "No data today"
        }
    }'
}

show_week() {
    echo -e "${BOLD}Daily Summaries (Last 7 Days)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ ! -f "$DAILY_SUMMARY" ]]; then
        echo "No daily summaries yet. Data is collected at midnight."
        return
    fi
    
    printf "%-12s %8s %8s %8s │ %8s %8s %8s\n" "Date" "Core↓" "Core~" "Core↑" "Pkg↓" "Pkg~" "Pkg↑"
    echo "────────────────────────────────────────────────────────────────────────────────"
    tail -7 "$DAILY_SUMMARY" | tail -n +1 | while IFS=',' read -r date cmin cavg cmax pmin pavg pmax smin savg smax; do
        [[ "$date" == "date" ]] && continue
        printf "%-12s %7.1f° %7.1f° %7.1f° │ %7.1f° %7.1f° %7.1f°\n" \
            "$date" "$cmin" "$cavg" "$cmax" "$pmin" "$pavg" "$pmax"
    done
}

show_peaks() {
    echo -e "${BOLD}Peak Temperatures${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Today's peaks
    echo -e "\n${CYAN}Today:${NC}"
    tail -n +2 "$CURRENT_LOG" | sort -t',' -k2 -rn | head -1 | while IFS=',' read -r ts core pkg soc ppt thm power; do
        time_short=$(echo "$ts" | cut -d'T' -f2 | cut -d'+' -f1)
        echo "  Peak Core: ${core}°C at $time_short"
    done
    tail -n +2 "$CURRENT_LOG" | sort -t',' -k3 -rn | head -1 | while IFS=',' read -r ts core pkg soc ppt thm power; do
        time_short=$(echo "$ts" | cut -d'T' -f2 | cut -d'+' -f1)
        echo "  Peak Pkg:  ${pkg}°C at $time_short"
    done
    
    # All-time from daily summaries
    if [[ -f "$DAILY_SUMMARY" ]]; then
        echo -e "\n${CYAN}All-Time (from daily logs):${NC}"
        max_core=$(tail -n +2 "$DAILY_SUMMARY" | cut -d',' -f4 | sort -rn | head -1)
        max_pkg=$(tail -n +2 "$DAILY_SUMMARY" | cut -d',' -f7 | sort -rn | head -1)
        echo "  Peak Core: ${max_core}°C"
        echo "  Peak Pkg:  ${max_pkg}°C"
    fi
}

check_alerts() {
    echo -e "${BOLD}Thermal Alert Check${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local alerts=0
    
    # Check today's peaks
    max_core=$(tail -n +2 "$CURRENT_LOG" | cut -d',' -f2 | sort -rn | head -1)
    max_pkg=$(tail -n +2 "$CURRENT_LOG" | cut -d',' -f3 | sort -rn | head -1)
    
    if [[ -z "$max_core" ]]; then max_core=0; fi
    if [[ -z "$max_pkg" ]]; then max_pkg=0; fi
    
    if (( $(echo "$max_core > $CRIT_TEMP" | bc -l) )); then
        echo -e "${RED}⚠ CRITICAL: Core temp reached ${max_core}°C (threshold: ${CRIT_TEMP}°C)${NC}"
        alerts=$((alerts+1))
    elif (( $(echo "$max_core > $WARN_TEMP" | bc -l) )); then
        echo -e "${YELLOW}⚡ WARNING: Core temp reached ${max_core}°C (threshold: ${WARN_TEMP}°C)${NC}"
    else
        echo -e "${GREEN}✓ Core temps OK (max: ${max_core}°C)${NC}"
    fi
    
    if (( $(echo "$max_pkg > $CRIT_TEMP" | bc -l) )); then
        echo -e "${RED}⚠ CRITICAL: Package temp reached ${max_pkg}°C (threshold: ${CRIT_TEMP}°C)${NC}"
        alerts=$((alerts+1))
    elif (( $(echo "$max_pkg > $WARN_TEMP" | bc -l) )); then
        echo -e "${YELLOW}⚡ WARNING: Package temp reached ${max_pkg}°C (threshold: ${WARN_TEMP}°C)${NC}"
    else
        echo -e "${GREEN}✓ Package temps OK (max: ${max_pkg}°C)${NC}"
    fi
    
    # Check for throttling (THM > 95%)
    max_thm=$(tail -n +2 "$CURRENT_LOG" | cut -d',' -f6 | sort -rn | head -1)
    if [[ -z "$max_thm" ]]; then max_thm=0; fi
    if (( $(echo "$max_thm > 95" | bc -l) )); then
        echo -e "${RED}⚠ CRITICAL: Thermal throttling detected (THM: ${max_thm}%)${NC}"
        alerts=$((alerts+1))
    elif (( $(echo "$max_thm > 90" | bc -l) )); then
        echo -e "${YELLOW}⚡ WARNING: Near thermal limit (THM: ${max_thm}%)${NC}"
    else
        echo -e "${GREEN}✓ Thermal headroom OK (max THM: ${max_thm}%)${NC}"
    fi
    
    exit $alerts
}

# Parse arguments
case "${1:-}" in
    -l|--last)
        show_last "${2:-10}"
        ;;
    -h|--hour)
        show_hour
        ;;
    -d|--day)
        show_day
        ;;
    -w|--week)
        show_week
        ;;
    -p|--peaks)
        show_peaks
        ;;
    -a|--alerts)
        check_alerts
        ;;
    --help)
        show_help
        ;;
    "")
        show_last 10
        echo ""
        show_day
        ;;
    *)
        show_help
        ;;
esac
