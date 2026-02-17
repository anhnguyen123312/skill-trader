#!/bin/bash
# Monitor backtest progress
# Usage: ./scripts/monitor.sh [TIMEOUT_MINUTES]
# Default timeout: 30 minutes

TIMEOUT_MIN="${1:-30}"
TIMEOUT_SEC=$((TIMEOUT_MIN * 60))
ELAPSED=0
POLL_INTERVAL=5  # Poll every 5s (fast backtests can finish in <10s)

WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"

# Check both possible CSV locations
CSV_PATHS=(
    "$WINEPREFIX/drive_c/users/$(whoami)/AppData/Roaming/MetaQuotes/Terminal/Common/Files/backtest_results.csv"
    "$WINEPREFIX/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files/backtest_results.csv"
)

# Record start time for CSV freshness check
START_TIME=$(date +%s)

echo "=== EA-OAT-v3 Backtest Monitor ==="
echo "Timeout: ${TIMEOUT_MIN} minutes"
echo "Polling every 5s..."
echo "Press Ctrl+C to stop"
echo ""

while [ $ELAPSED -lt $TIMEOUT_SEC ]; do
    # Check if MT5/Wine is still running
    MT5_RUNNING=false
    if pgrep -f "terminal64" > /dev/null 2>&1; then
        MT5_RUNNING=true
    fi

    # Check for new CSV file
    for CSV_PATH in "${CSV_PATHS[@]}"; do
        if [ -f "$CSV_PATH" ]; then
            CSV_MOD=$(stat -f %m "$CSV_PATH" 2>/dev/null || echo 0)
            if [ "$CSV_MOD" -ge "$START_TIME" ]; then
                echo ""
                echo ""
                echo "=== BACKTEST COMPLETE ==="
                echo "CSV found: $CSV_PATH"
                echo "Size: $(stat -f%z "$CSV_PATH") bytes"
                echo "Time: $(date)"
                echo "Duration: $((ELAPSED / 60))m $((ELAPSED % 60))s"
                echo ""
                echo "Next: ./scripts/collect.sh"
                exit 0
            fi
        fi
    done

    # MT5 exited without producing CSV
    if [ "$MT5_RUNNING" = false ] && [ $ELAPSED -gt 30 ]; then
        echo ""
        echo ""
        echo "MT5 process exited after $((ELAPSED / 60))m $((ELAPSED % 60))s"

        # One more check for CSV (might have been written just before exit)
        sleep 3
        for CSV_PATH in "${CSV_PATHS[@]}"; do
            if [ -f "$CSV_PATH" ]; then
                CSV_MOD=$(stat -f %m "$CSV_PATH" 2>/dev/null || echo 0)
                if [ "$CSV_MOD" -ge "$START_TIME" ]; then
                    echo "CSV found after MT5 exit!"
                    echo "Next: ./scripts/collect.sh"
                    exit 0
                fi
            fi
        done

        echo "WARNING: MT5 exited but no CSV found"
        echo "Check MT5 logs: $WINEPREFIX/drive_c/Program Files/MetaTrader 5/MQL5/Logs/"
        exit 1
    fi

    # Progress indicator
    MINS=$((ELAPSED / 60))
    SECS=$((ELAPSED % 60))
    printf "\r[%02d:%02d] Waiting... MT5=%s" "$MINS" "$SECS" "$([ "$MT5_RUNNING" = true ] && echo 'running' || echo 'starting')"

    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

echo ""
echo ""
echo "TIMEOUT: Backtest did not complete within ${TIMEOUT_MIN} minutes"
echo "MT5 may still be running. Check manually."
exit 1
