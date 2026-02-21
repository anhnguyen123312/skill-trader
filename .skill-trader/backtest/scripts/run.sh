#!/bin/bash
# EA-OAT-v3 Full E2E Pipeline
# Usage: ./scripts/run.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM_DATE] [TO_DATE] [--no-visual] [--version] [--message "msg"] [--major]
# Example: ./scripts/run.sh MyEA XAUUSD M15 2024.01.01 2024.12.31 --no-visual --version

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"

# --- Validate input ---
if [ -z "$1" ]; then
    echo "=============================================="
    echo "  EA-OAT-v3 Build & Backtest Pipeline"
    echo "=============================================="
    echo ""
    echo "Usage: ./scripts/run.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM] [TO] [OPTIONS]"
    echo ""
    echo "Arguments:"
    echo "  EA_NAME    - Name of EA in code/experts/ (without .mq5)"
    echo "  SYMBOL     - Trading symbol (default: XAUUSD)"
    echo "  PERIOD     - Timeframe: M1,M5,M15,M30,H1,H4,D1 (default: H1)"
    echo "  FROM       - Start date YYYY.MM.DD (default: 2024.01.01)"
    echo "  TO         - End date YYYY.MM.DD (default: 2025.12.31)"
    echo ""
    echo "Options:"
    echo "  --no-visual          Run headless (no GUI)"
    echo "  --version            Auto-version after pipeline (git commit + tag)"
    echo "  --message \"text\"     Commit message for versioning"
    echo "  --major              Major version bump (v1.2 -> v2.0)"
    echo ""
    echo "Available EAs:"
    ls -1 "$PROJECT_ROOT/code/experts"/*.mq5 2>/dev/null | xargs -I{} basename {} .mq5 | sed 's/^/  - /'
    echo ""
    echo "Example:"
    echo "  ./scripts/run.sh MyEA XAUUSD H1 2024.01.01 2025.12.31 --no-visual --version"
    exit 0
fi

EA_NAME="$1"
SYMBOL="${2:-XAUUSD}"
PERIOD="${3:-M15}"
FROM_DATE="${4:-2024.01.01}"
TO_DATE="${5:-2024.12.31}"
# Parse optional flags
EXTRA_ARGS=""
DO_VERSION=false
VERSION_MSG=""
VERSION_MAJOR=""
for arg in "$@"; do
    case "$arg" in
        --no-visual)
            EXTRA_ARGS="--no-visual"
            ;;
        --version)
            DO_VERSION=true
            ;;
        --major)
            VERSION_MAJOR="--major"
            ;;
    esac
done
# Extract --message value (next arg after --message)
ARGS=("$@")
for i in "${!ARGS[@]}"; do
    if [ "${ARGS[$i]}" = "--message" ] && [ $((i+1)) -lt ${#ARGS[@]} ]; then
        VERSION_MSG="${ARGS[$((i+1))]}"
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

# --- Phase 5 (Optional): Version ---
if [ "$DO_VERSION" = true ]; then
    echo ">>> PHASE 5/5: VERSION"
    echo "---"
    VERSION_ARGS="$EA_NAME"
    if [ -n "$VERSION_MSG" ]; then
        VERSION_ARGS="$VERSION_ARGS --message \"$VERSION_MSG\""
    fi
    if [ -n "$VERSION_MAJOR" ]; then
        VERSION_ARGS="$VERSION_ARGS $VERSION_MAJOR"
    fi
    eval "$SCRIPT_DIR/version.sh" $VERSION_ARGS
    echo ""
fi

echo "=============================================="
echo "  PIPELINE COMPLETE"
echo "=============================================="
echo "  $(date)"
echo "=============================================="
