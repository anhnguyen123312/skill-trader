#!/bin/bash
# Collect and parse backtest results from MT5
#
# Supports two data sources (tried in order):
#   1. HTML Report (Report=EA_Report in .ini) - works for ALL EAs
#   2. CSV from OnTester() export - for EAs with custom CSV export
#
# Usage: ./scripts/collect.sh [EA_NAME] [SYMBOL] [PERIOD]
# Example: ./scripts/collect.sh SimpleMA_EA XAUUSD H1
#          ./scripts/collect.sh V2-oat XAUUSD M15

set -e

EA_NAME="${1:-SimpleMA_EA}"
SYMBOL="${2:-XAUUSD}"
PERIOD="${3:-H1}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_BASE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
DATE=$(date +%Y-%m-%d)

echo "=== EA-OAT-v3 Results Collector ==="
echo "EA:     $EA_NAME"
echo "Symbol: $SYMBOL"
echo "Period: $PERIOD"
echo ""

RESULTS_DIR="$PLUGIN_DIR/results"
mkdir -p "$RESULTS_DIR/logs"

# ============================================================
# Source 1: HTML Report (primary - works for ALL EAs)
# ============================================================
REPORT_HTM="$MT5_BASE/${EA_NAME}_Report.htm"
REPORT_FOUND=false

if [ -f "$REPORT_HTM" ]; then
    echo "[1/5] HTML report found: $(basename "$REPORT_HTM")"

    # Parse with Python script
    PARSE_SCRIPT="$SCRIPT_DIR/parse_report.py"
    if [ ! -f "$PARSE_SCRIPT" ]; then
        echo "      ERROR: parse_report.py not found at $PARSE_SCRIPT"
        echo "      Cannot parse HTML report."
    else
        REPORT_OUTPUT_DIR="$RESULTS_DIR/${DATE}_${EA_NAME}_${SYMBOL}_${PERIOD}"
        mkdir -p "$REPORT_OUTPUT_DIR"

        echo "[2/5] Parsing HTML report -> Markdown..."
        python3 "$PARSE_SCRIPT" "$REPORT_HTM" --output-dir "$REPORT_OUTPUT_DIR"

        REPORT_FOUND=true
    fi

    # Copy chart PNGs
    echo "[3/5] Collecting chart images..."
    PNG_COUNT=0
    for png in "$MT5_BASE/${EA_NAME}_Report"*.png; do
        [ -f "$png" ] || continue
        cp "$png" "$REPORT_OUTPUT_DIR/"
        PNG_COUNT=$((PNG_COUNT + 1))
        echo "      + $(basename "$png")"
    done
    if [ $PNG_COUNT -eq 0 ]; then
        echo "      No chart images found"
    else
        echo "      $PNG_COUNT chart(s) copied"
    fi
else
    echo "[1/5] No HTML report found: ${EA_NAME}_Report.htm"
    echo "      (Backtest template should have Report=${EA_NAME}_Report)"
fi

# ============================================================
# Source 2: CSV from OnTester() (fallback for custom EAs)
# ============================================================
CSV_PATH=""
SEARCH_DIRS=(
    "$WINEPREFIX/drive_c/users/$(whoami)/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
    "$WINEPREFIX/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
    "$MT5_BASE/MQL5/Files"
)

for DIR in "${SEARCH_DIRS[@]}"; do
    if [ -f "$DIR/backtest_results.csv" ]; then
        CSV_PATH="$DIR/backtest_results.csv"
        break
    fi
done

if [ -n "$CSV_PATH" ]; then
    echo "[4/5] OnTester CSV found: $CSV_PATH"

    CSV_DEST="$RESULTS_DIR/${DATE}_${EA_NAME}_${SYMBOL}_${PERIOD}.csv"

    # Try UTF-16LE first, fallback to direct copy
    if iconv -f UTF-16LE -t UTF-8 "$CSV_PATH" > "$CSV_DEST" 2>/dev/null; then
        tr -d '\r' < "$CSV_DEST" > "${CSV_DEST}.tmp" && mv "${CSV_DEST}.tmp" "$CSV_DEST"
        echo "      Converted UTF-16LE -> UTF-8"
    else
        cp "$CSV_PATH" "$CSV_DEST"
        echo "      Copied CSV (already UTF-8)"
    fi
    echo "      Saved to: $CSV_DEST"
else
    if [ "$REPORT_FOUND" = true ]; then
        echo "[4/5] No OnTester CSV (not needed - HTML report has all data)"
    else
        echo "[4/5] No OnTester CSV found"
        echo ""
        echo "      Searched in:"
        for DIR in "${SEARCH_DIRS[@]}"; do
            echo "        - $DIR"
        done
    fi
fi

# ============================================================
# Copy tester logs
# ============================================================
TESTER_LOGS="$MT5_BASE/Tester/logs"
if [ -d "$TESTER_LOGS" ]; then
    LOG_COUNT=0
    for LOG_FILE in "$TESTER_LOGS"/*.log; do
        [ -f "$LOG_FILE" ] || continue
        cp "$LOG_FILE" "$RESULTS_DIR/logs/"
        LOG_COUNT=$((LOG_COUNT + 1))
    done
    echo "[5/5] Copied $LOG_COUNT tester log(s)"
else
    echo "[5/5] No tester logs found"
fi

# Also copy agent logs
AGENT_LOGS="$MT5_BASE/Tester/Agent-127.0.0.1-3000/logs"
if [ -d "$AGENT_LOGS" ]; then
    for LOG_FILE in "$AGENT_LOGS"/*.log; do
        [ -f "$LOG_FILE" ] || continue
        cp "$LOG_FILE" "$RESULTS_DIR/logs/"
    done
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=============================================="
echo "  COLLECTION COMPLETE"
echo "=============================================="
echo ""

if [ "$REPORT_FOUND" = true ]; then
    echo "  Report dir: $REPORT_OUTPUT_DIR"
    echo ""
    echo "  Files:"
    ls -1 "$REPORT_OUTPUT_DIR" 2>/dev/null | while read f; do
        SIZE=$(stat -f%z "$REPORT_OUTPUT_DIR/$f" 2>/dev/null || echo "?")
        echo "    $f (${SIZE} bytes)"
    done
fi

if [ -n "$CSV_PATH" ]; then
    echo ""
    echo "  OnTester CSV: $CSV_DEST"
fi

echo ""
echo "  Logs: $RESULTS_DIR/logs/"
echo "=============================================="
