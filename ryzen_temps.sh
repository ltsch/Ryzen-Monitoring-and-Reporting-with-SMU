#!/bin/bash
# Ryzen CPU Temperature Logger
# Parses ryzen_monitor output and logs key metrics to CSV

LOG_DIR="/var/log/ryzen_temps"
CURRENT_LOG="$LOG_DIR/current.csv"
DAILY_SUMMARY="$LOG_DIR/daily_summary.csv"
RETENTION_DAYS=7

# Create log directory if needed
mkdir -p "$LOG_DIR"

# Prevent concurrent runs
exec 9>"$LOG_DIR/lock"
if ! flock -n 9; then
    exit 1
fi

# Initialize CSV header if file doesn't exist
if [[ ! -f "$CURRENT_LOG" ]]; then
    echo "timestamp,peak_core_temp,peak_pkg_temp,soc_temp,ppt_pct,thm_pct,socket_power" > "$CURRENT_LOG"
fi

# Get ryzen_monitor output
OUTPUT=$(/usr/local/bin/ryzen_monitor -1 2>/dev/null)

if [[ -z "$OUTPUT" ]]; then
    echo "Error: ryzen_monitor failed" >&2
    exit 1
fi

# Parse metrics using grep and awk
TIMESTAMP=$(date -Iseconds)

# Highest Core Temperature │                                        80.24 C
PEAK_CORE_TEMP=$(echo "$OUTPUT" | grep "Highest Core Temperature" | awk -F'│' '{print $3}' | grep -oP '[\d.]+' | head -1)

# Peak Temperature │                                        87.75 C  
PEAK_PKG_TEMP=$(echo "$OUTPUT" | grep -E "^\│\s+Peak Temperature" | awk -F'│' '{print $3}' | grep -oP '[\d.]+' | head -1)

# SoC Temperature │                                        45.72 C
SOC_TEMP=$(echo "$OUTPUT" | grep "SoC Temperature" | awk -F'│' '{print $3}' | grep -oP '[\d.]+' | head -1)

# PPT │             131.255 W |     142 W |    92.43 %
PPT_PCT=$(echo "$OUTPUT" | grep -E "^\│\s+PPT\s+│" | awk -F'│' '{print $3}' | grep -oP '[\d.]+(?=\s*%)' | head -1)

# THM │               80.51 C |      90 C |    89.45 %
THM_PCT=$(echo "$OUTPUT" | grep -E "^\│\s+THM\s+│" | awk -F'│' '{print $3}' | grep -oP '[\d.]+(?=\s*%)' | head -1)

# Socket Power (SMU) │                                      131.247 W
SOCKET_POWER=$(echo "$OUTPUT" | grep "Socket Power (SMU)" | awk -F'│' '{print $3}' | grep -oP '[\d.]+' | head -1)

# Validate we got data
if [[ -z "$PEAK_CORE_TEMP" ]]; then
    echo "Error: Failed to parse temperature data" >&2
    exit 1
fi

# Append to log
echo "$TIMESTAMP,$PEAK_CORE_TEMP,$PEAK_PKG_TEMP,$SOC_TEMP,$PPT_PCT,$THM_PCT,$SOCKET_POWER" >> "$CURRENT_LOG"

# Rotate logs at midnight
CURRENT_DATE=$(date +%Y-%m-%d)
LOG_DATE=$(head -2 "$CURRENT_LOG" 2>/dev/null | tail -1 | cut -d'T' -f1)

if [[ -n "$LOG_DATE" && "$LOG_DATE" != "$CURRENT_DATE" ]]; then
    # Calculate daily summary before rotating
    PREV_DATE=$(date -d "yesterday" +%Y-%m-%d)
    
    # Get min/avg/max for each metric (skip header)
    STATS=$(tail -n +2 "$CURRENT_LOG" | awk -F',' '
    NR==1 {
        min_core=max_core=$2; min_pkg=max_pkg=$3; min_soc=max_soc=$4
        sum_core=$2; sum_pkg=$3; sum_soc=$4; count=1
    }
    NR>1 {
        if($2<min_core) min_core=$2; if($2>max_core) max_core=$2; sum_core+=$2
        if($3<min_pkg) min_pkg=$3; if($3>max_pkg) max_pkg=$3; sum_pkg+=$3
        if($4<min_soc) min_soc=$4; if($4>max_soc) max_soc=$4; sum_soc+=$4
        count++
    }
    END {
        printf "%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f\n",
            "'"$PREV_DATE"'",
            min_core, sum_core/count, max_core,
            min_pkg, sum_pkg/count, max_pkg,
            min_soc, sum_soc/count, max_soc
    }')
    
    # Initialize daily summary if needed
    if [[ ! -f "$DAILY_SUMMARY" ]]; then
        echo "date,core_min,core_avg,core_max,pkg_min,pkg_avg,pkg_max,soc_min,soc_avg,soc_max" > "$DAILY_SUMMARY"
    fi
    echo "$STATS" >> "$DAILY_SUMMARY"
    
    # Archive old log
    mv "$CURRENT_LOG" "$LOG_DIR/$PREV_DATE.csv"
    
    # Start new log
    echo "timestamp,peak_core_temp,peak_pkg_temp,soc_temp,ppt_pct,thm_pct,socket_power" > "$CURRENT_LOG"
    
    # Clean up old archives
    find "$LOG_DIR" -name "????-??-??.csv" -mtime +$RETENTION_DAYS -delete
fi
