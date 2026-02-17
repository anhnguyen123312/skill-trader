#!/bin/bash
# Compile EA via Wine MetaEditor
# Usage: ./scripts/compile.sh <EA_NAME>
# Example: ./scripts/compile.sh SimpleMA_EA

set -e

# --- Validate input ---
if [ -z "$1" ]; then
    echo "ERROR: EA name required"
    echo "Usage: ./scripts/compile.sh <EA_NAME>"
    exit 1
fi

EA_NAME="$1"
PROJECT_ROOT="/Volumes/Data/Git/EA-OAT-v3"
EA_SOURCE="$PROJECT_ROOT/code/experts/${EA_NAME}.mq5"

# --- Wine/MT5 paths ---
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_BASE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
EXPERTS_DIR="$MT5_BASE/MQL5/Experts"
INCLUDE_DIR="$MT5_BASE/MQL5/Include"

echo "=== EA-OAT-v3 Compiler ==="
echo "EA: $EA_NAME"
echo ""

# --- Step 1: Validate source ---
if [ ! -f "$EA_SOURCE" ]; then
    echo "[1/5] ERROR: Source not found: $EA_SOURCE"
    exit 1
fi
echo "[1/5] Source found: $EA_SOURCE"

# --- Step 2: Validate Wine/MT5 ---
if [ ! -f "$WINE" ]; then
    echo "[2/5] ERROR: Wine not found: $WINE"
    exit 1
fi
if [ ! -f "$MT5_BASE/metaeditor64.exe" ]; then
    echo "[2/5] ERROR: MetaEditor not found: $MT5_BASE/metaeditor64.exe"
    exit 1
fi
echo "[2/5] Wine + MetaEditor verified"

# --- Step 3: Copy source to MT5 ---
mkdir -p "$EXPERTS_DIR"
cp "$EA_SOURCE" "$EXPERTS_DIR/"
echo "[3/5] Copied to MT5/MQL5/Experts/"

# Copy includes if any
if [ -d "$PROJECT_ROOT/code/include" ]; then
    mkdir -p "$INCLUDE_DIR"
    cp -r "$PROJECT_ROOT/code/include"/* "$INCLUDE_DIR/" 2>/dev/null || true
    echo "      Includes copied"
fi

# --- Step 4: Compile ---
echo "[4/5] Compiling..."
cd "$MT5_BASE"

# Remove old log
rm -f "$EXPERTS_DIR/${EA_NAME}.log" 2>/dev/null

# Wine outputs harmless "fixme" debug messages to stderr - suppress them
# Don't fail on Wine exit code; we check .ex5 and log instead
WINEPREFIX="$WINEPREFIX" "$WINE" metaeditor64.exe /compile:"MQL5\\Experts\\${EA_NAME}.mq5" /log 2>/dev/null || true

# Wait for log file to be written
sleep 2

# --- Step 5: Check results ---
LOG_FILE="$EXPERTS_DIR/${EA_NAME}.log"
if [ -f "$LOG_FILE" ]; then
    echo ""
    echo "=== Compile Log ==="
    # Log is UTF-16LE encoded, convert to UTF-8 for display
    LOG_TEXT=$(iconv -f UTF-16LE -t UTF-8 "$LOG_FILE" 2>/dev/null | tr -d '\r' || cat "$LOG_FILE")
    echo "$LOG_TEXT"
    echo ""

    # Check result line for errors/warnings
    RESULT_LINE=$(echo "$LOG_TEXT" | grep -i "Result:" || true)
    if echo "$RESULT_LINE" | grep -q "0 error"; then
        WARNING_COUNT=$(echo "$RESULT_LINE" | grep -oE '[0-9]+ warning' | grep -oE '[0-9]+' || echo "0")
        echo "[5/5] SUCCESS: 0 errors, ${WARNING_COUNT} warning(s)"
    elif [ -n "$RESULT_LINE" ]; then
        echo "[5/5] FAILED: $RESULT_LINE"
        exit 1
    else
        echo "[5/5] Could not parse log - checking .ex5 directly..."
    fi
else
    echo "[5/5] No compile log found - checking .ex5 directly..."
fi

# Verify .ex5
if [ -f "$EXPERTS_DIR/${EA_NAME}.ex5" ]; then
    EX5_SIZE=$(stat -f%z "$EXPERTS_DIR/${EA_NAME}.ex5")
    echo ""
    echo "Compiled: ${EA_NAME}.ex5 (${EX5_SIZE} bytes)"
    echo "Location: $EXPERTS_DIR/${EA_NAME}.ex5"
else
    echo ""
    echo "ERROR: ${EA_NAME}.ex5 not found after compile"
    exit 1
fi

echo ""
echo "=== Compile Complete ==="
