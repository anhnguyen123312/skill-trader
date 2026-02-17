#!/bin/bash
# EA-OAT-v3 Full E2E Pipeline
# Usage: ./scripts/run.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM_DATE] [TO_DATE] [--no-visual]
# Example: ./scripts/run.sh SimpleMA_EA XAUUSD M15 2024.01.01 2024.12.31

set -e

# --- Validate input ---
if [ -z "$1" ]; then
    echo "=============================================="
    echo "  EA-OAT-v3 Build & Backtest Pipeline"
    echo "=============================================="
    echo ""
    echo "Usage: ./scripts/run.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM] [TO]"
    echo ""
    echo "Arguments:"
    echo "  EA_NAME    - Name of EA in code/experts/ (without .mq5)"
    echo "  SYMBOL     - Trading symbol (default: XAUUSD)"
    echo "  PERIOD     - Timeframe: M1,M5,M15,M30,H1,H4,D1 (default: H1)"
    echo "  FROM       - Start date YYYY.MM.DD (default: 2024.01.01)"
    echo "  TO         - End date YYYY.MM.DD (default: 2025.12.31)"
    echo ""
    echo "Available EAs:"
    SELF_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    ls -1 "$SELF_DIR/code/experts"/*.mq5 2>/dev/null | xargs -I{} basename {} .mq5 | sed 's/^/  - /'
    echo ""
    echo "Example:"
    echo "  ./scripts/run.sh SimpleMA_EA XAUUSD H1 2024.01.01 2025.12.31"
    exit 0
fi

EA_NAME="$1"
SYMBOL="${2:-XAUUSD}"
PERIOD="${3:-M15}"
FROM_DATE="${4:-2024.01.01}"
TO_DATE="${5:-2024.12.31}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Pass through --no-visual flag
EXTRA_ARGS=""
for arg in "$@"; do
    if [ "$arg" = "--no-visual" ]; then
        EXTRA_ARGS="--no-visual"
    fi
done

echo "=============================================="
echo "  EA-OAT-v3 E2E Pipeline"
echo "=============================================="
echo "  EA:     $EA_NAME"
echo "  Symbol: $SYMBOL"
echo "  Period: $PERIOD"
echo "  Range:  $FROM_DATE -> $TO_DATE"
echo "=============================================="
echo ""

# --- Phase 1: Compile ---
echo ">>> PHASE 1/4: COMPILE"
echo "---"
"$SCRIPT_DIR/compile.sh" "$EA_NAME"
echo ""

# --- Phase 2: Backtest ---
echo ">>> PHASE 2/4: BACKTEST"
echo "---"
"$SCRIPT_DIR/backtest.sh" "$EA_NAME" "$SYMBOL" "$PERIOD" "$FROM_DATE" "$TO_DATE" $EXTRA_ARGS
echo ""

# --- Phase 3: Monitor ---
echo ">>> PHASE 3/4: MONITOR"
echo "---"
"$SCRIPT_DIR/monitor.sh" 30
echo ""

# --- Phase 4: Collect Results ---
echo ">>> PHASE 4/4: COLLECT RESULTS"
echo "---"
"$SCRIPT_DIR/collect.sh" "$EA_NAME" "$SYMBOL" "$PERIOD"
echo ""

echo "=============================================="
echo "  PIPELINE COMPLETE"
echo "=============================================="
echo "  $(date)"
echo "=============================================="
