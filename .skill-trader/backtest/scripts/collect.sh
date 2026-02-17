#!/bin/bash
# Collect and parse backtest results
# Usage: ./scripts/collect.sh [EA_NAME] [SYMBOL] [PERIOD]
# Example: ./scripts/collect.sh SimpleMA_EA XAUUSD H1

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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== EA-OAT-v3 Results Collector ==="
echo "EA:     $EA_NAME"
echo "Symbol: $SYMBOL"
echo "Period: $PERIOD"
echo ""

# --- Step 1: Find CSV ---
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

if [ -z "$CSV_PATH" ]; then
    echo "[1/4] ERROR: No backtest_results.csv found"
    echo ""
    echo "Searched in:"
    for DIR in "${SEARCH_DIRS[@]}"; do
        echo "  - $DIR"
    done
    echo ""
    echo "Make sure the EA has OnTester() that exports CSV with FILE_COMMON flag"
    exit 1
fi
echo "[1/4] CSV found: $CSV_PATH"

# --- Step 2: Convert and copy ---
RESULTS_DIR="$PLUGIN_DIR/results"
mkdir -p "$RESULTS_DIR/logs"

CSV_DEST="$RESULTS_DIR/${DATE}_${EA_NAME}_${SYMBOL}_${PERIOD}.csv"

# Try UTF-16LE first, fallback to direct copy
if iconv -f UTF-16LE -t UTF-8 "$CSV_PATH" > "$CSV_DEST" 2>/dev/null; then
    # Clean up carriage returns
    tr -d '\r' < "$CSV_DEST" > "${CSV_DEST}.tmp" && mv "${CSV_DEST}.tmp" "$CSV_DEST"
    echo "[2/4] Converted UTF-16LE -> UTF-8"
else
    cp "$CSV_PATH" "$CSV_DEST"
    echo "[2/4] Copied CSV (already UTF-8)"
fi
echo "      Saved to: $CSV_DEST"

# --- Step 3: Copy tester logs ---
LOG_DATE=$(date +%Y%m%d)
TESTER_LOGS="$MT5_BASE/Tester/logs"
if [ -d "$TESTER_LOGS" ]; then
    LOG_COUNT=0
    for LOG_FILE in "$TESTER_LOGS"/*.log; do
        [ -f "$LOG_FILE" ] || continue
        cp "$LOG_FILE" "$RESULTS_DIR/logs/"
        LOG_COUNT=$((LOG_COUNT + 1))
    done
    echo "[3/4] Copied $LOG_COUNT log file(s)"
else
    echo "[3/4] No tester logs found (optional)"
fi

# --- Step 4: Parse and display results ---
echo "[4/4] Parsing results..."
echo ""
echo "=============================================="
echo "  BACKTEST RESULTS: $EA_NAME | $SYMBOL | $PERIOD"
echo "=============================================="
echo ""

# Parse summary metrics from CSV
parse_metric() {
    local metric="$1"
    local file="$2"
    awk -F'\t' -v m="$metric" '$1 == m { print $2; exit }' "$file" 2>/dev/null || echo "N/A"
}

WIN_RATE=$(parse_metric "Win Rate %" "$CSV_DEST")
RISK_REWARD=$(parse_metric "Risk Reward" "$CSV_DEST")
TOTAL_TRADES=$(parse_metric "Total Trades" "$CSV_DEST")
MAX_DD=$(parse_metric "Max DD %" "$CSV_DEST")
PROFIT_FACTOR=$(parse_metric "Profit Factor" "$CSV_DEST")
NET_PROFIT=$(parse_metric "Net Profit" "$CSV_DEST")
SHARPE=$(parse_metric "Sharpe Ratio" "$CSV_DEST")

echo "  Win Rate:       ${WIN_RATE}%"
echo "  Total Trades:   $TOTAL_TRADES"
echo "  Net Profit:     \$${NET_PROFIT}"
echo "  Max Drawdown:   ${MAX_DD}%"
echo "  Profit Factor:  $PROFIT_FACTOR"
echo "  Risk:Reward:    1:$RISK_REWARD"
echo "  Sharpe Ratio:   $SHARPE"
echo ""
echo "----------------------------------------------"
echo "  TRADE LOG"
echo "----------------------------------------------"
echo ""

# Parse trade details (skip header rows until "Trade Details" section)
awk -F'\t' '
BEGIN { in_trades = 0; trade_num = 0 }
/^Trade Details/ { in_trades = 1; next }
/^Ticket/ { next }  # Skip header row
in_trades && NF >= 4 && $1 != "" {
    trade_num++
    ticket = $1
    type = $2
    open_time = $3
    close_time = $4
    open_price = $5
    close_price = $6
    profit = $7
    comment = $8

    # Determine result
    if (profit + 0 > 0) {
        result = "WIN"
        sign = "+"
    } else if (profit + 0 < 0) {
        result = "LOSS"
        sign = ""
    } else {
        result = "BE"
        sign = ""
    }

    printf "#%-3d | %-4s | %s | Price: %s | P/L: %s$%s\n", trade_num, type, open_time, open_price, sign, profit
    if (comment != "") {
        printf "     | Reason: %s\n", comment
    }
    printf "     | Result: %s | Close: %s\n\n", result, close_time
}
END {
    if (trade_num == 0) {
        print "  No trade details found in CSV"
    } else {
        printf "\nTotal: %d trades\n", trade_num
    }
}
' "$CSV_DEST"

echo ""
echo "=============================================="
echo "  Full CSV: $CSV_DEST"
echo "  Logs:     $RESULTS_DIR/logs/"
echo "=============================================="
