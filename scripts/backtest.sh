#!/bin/bash
# Run backtest via MT5
# Usage: ./scripts/backtest.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM_DATE] [TO_DATE] [--no-visual]
# Example: ./scripts/backtest.sh SimpleMA_EA XAUUSD M15 2024.01.01 2024.12.31
#
# Period values: M1=1, M5=5, M15=15, M30=30, H1=16385, H4=16388, D1=16408
# Default: M15, XAUUSD, 2024.01.01-2024.12.31, Visual=ON

set -e

# --- Validate input ---
if [ -z "$1" ]; then
    echo "ERROR: EA name required"
    echo "Usage: ./scripts/backtest.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM] [TO] [--no-visual]"
    exit 1
fi

EA_NAME="$1"
SYMBOL="${2:-XAUUSD}"
PERIOD_NAME="${3:-M15}"
FROM_DATE="${4:-2024.01.01}"
TO_DATE="${5:-2024.12.31}"

# Check for --no-visual flag
VISUAL=1
for arg in "$@"; do
    if [ "$arg" = "--no-visual" ]; then
        VISUAL=0
    fi
done

# --- Map period name to MT5 value ---
case "$PERIOD_NAME" in
    M1)  PERIOD=1 ;;
    M5)  PERIOD=5 ;;
    M15) PERIOD=15 ;;
    M30) PERIOD=30 ;;
    H1)  PERIOD=16385 ;;
    H4)  PERIOD=16388 ;;
    D1)  PERIOD=16408 ;;
    *)   PERIOD="$PERIOD_NAME" ;;
esac

PROJECT_ROOT="/Volumes/Data/Git/EA-OAT-v3"
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_BASE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
TEMPLATE="$PROJECT_ROOT/config/backtest.template.ini"

echo "=== EA-OAT-v3 Backtest Launcher ==="
echo "EA:       $EA_NAME"
echo "Symbol:   $SYMBOL"
echo "Period:   $PERIOD_NAME ($PERIOD)"
echo "Range:    $FROM_DATE -> $TO_DATE"
echo "Leverage: 1:1000"
echo "Delay:    100ms"
echo "Visual:   $([ "$VISUAL" = "1" ] && echo 'ON' || echo 'OFF')"
echo ""

# --- Step 1: Verify .ex5 exists ---
if [ ! -f "$MT5_BASE/MQL5/Experts/${EA_NAME}.ex5" ]; then
    echo "[1/4] ERROR: ${EA_NAME}.ex5 not found in MT5/Experts/"
    echo "       Run ./scripts/compile.sh $EA_NAME first"
    exit 1
fi
echo "[1/4] ${EA_NAME}.ex5 verified"

# --- Step 2: Generate .ini config ---
# Use Wine C:\ root to avoid spaces in path (MT5 chokes on quoted paths via Wine)
CONFIG_DIR="$WINEPREFIX/drive_c"
CONFIG_FILE="$CONFIG_DIR/autobacktest.ini"

# Generate config with Windows CRLF line endings (required by MT5)
sed -e "s/__EA_NAME__/$EA_NAME/g" \
    -e "s/__SYMBOL__/$SYMBOL/" \
    -e "s/__PERIOD__/$PERIOD/" \
    -e "s/__FROM_DATE__/$FROM_DATE/" \
    -e "s/__TO_DATE__/$TO_DATE/" \
    -e "s/__VISUAL__/$VISUAL/" \
    "$TEMPLATE" | sed 's/$/\r/' > "$CONFIG_FILE"

echo "[2/4] Config generated (CRLF)"

# Also save a copy in project
cp "$CONFIG_FILE" "$PROJECT_ROOT/config/last_backtest.ini"

# --- Step 3: Clean old results ---
CSV_COMMON="$WINEPREFIX/drive_c/users/$(whoami)/AppData/Roaming/MetaQuotes/Terminal/Common/Files"
CSV_CROSSOVER="$WINEPREFIX/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files"

for CSV_DIR in "$CSV_COMMON" "$CSV_CROSSOVER"; do
    if [ -f "$CSV_DIR/backtest_results.csv" ]; then
        rm -f "$CSV_DIR/backtest_results.csv"
    fi
done
echo "[3/4] Old results cleaned"

# --- Step 4: Launch MT5 ---
echo "[4/4] Launching MT5..."

# Kill any existing MT5 instance first
pkill -f "terminal64" 2>/dev/null || true
sleep 3

# Launch via Wine terminal64.exe with config
# Suppress Wine stderr noise (fixme messages)
cd "$MT5_BASE"
WINEPREFIX="$WINEPREFIX" "$WINE" terminal64.exe \
    /config:C:\\autobacktest.ini \
    /portable 2>/dev/null &
MT5_PID=$!

# Verify it started
sleep 3
if kill -0 "$MT5_PID" 2>/dev/null; then
    echo "      MT5 launched (PID: $MT5_PID)"
else
    echo "      WARNING: MT5 process may have exited. Check manually."
fi

echo ""
echo "=== Backtest Started ==="
echo "Use ./scripts/monitor.sh to track progress."
