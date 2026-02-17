#!/bin/bash
# Compile EA via Wine MetaEditor
# Supports single-file EAs and multi-file repos with includes
#
# Usage:
#   ./scripts/compile.sh <EA_NAME>                    # Find in code/experts/ or Experts/
#   ./scripts/compile.sh <EA_NAME> --repo <PATH>      # Find in external repo/directory
#   ./scripts/compile.sh <PATH/TO/EA.mq5>             # Direct path to .mq5 file
#
# Examples:
#   ./scripts/compile.sh SimpleMA_EA                   # Simple EA in code/experts/
#   ./scripts/compile.sh V2-oat --repo ~/Git/EA        # Multi-file EA from external repo
#   ./scripts/compile.sh ~/Git/EA/Experts/V2-oat.mq5  # Direct path

set -e

# --- Parse arguments ---
EA_INPUT=""
REPO_PATH=""
while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO_PATH="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: compile.sh <EA_NAME|PATH> [--repo <PATH>]"
            echo ""
            echo "  EA_NAME           Search in code/experts/, Experts/, or root"
            echo "  PATH/TO/EA.mq5    Direct path to source file"
            echo "  --repo <PATH>     Search for EA in external repo/directory"
            echo ""
            echo "Automatically detects and copies #include dependencies."
            exit 0
            ;;
        *)
            EA_INPUT="$1"
            shift
            ;;
    esac
done

if [ -z "$EA_INPUT" ]; then
    echo "ERROR: EA name or path required"
    echo "Usage: ./scripts/compile.sh <EA_NAME> [--repo <PATH>]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"

# --- Wine/MT5 paths ---
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_BASE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
MQL5_DIR="$MT5_BASE/MQL5"
EXPERTS_DIR="$MQL5_DIR/Experts"
INCLUDE_DIR="$MQL5_DIR/Include"

# --- Step 1: Find EA source ---
EA_SOURCE=""

# Resolve repo path
if [ -n "$REPO_PATH" ]; then
    REPO_PATH="$(cd "$REPO_PATH" 2>/dev/null && pwd)" || {
        echo "[1/5] ERROR: Repo path not found: $REPO_PATH"
        exit 1
    }
fi

SEARCH_BASE="${REPO_PATH:-$PROJECT_ROOT}"

# Strip .mq5 extension if provided
EA_INPUT_CLEAN="${EA_INPUT%.mq5}"
EA_INPUT_CLEAN="$(basename "$EA_INPUT_CLEAN")"

# If input looks like a path, try it directly
if [[ "$EA_INPUT" == *"/"* ]] || [[ "$EA_INPUT" == *.mq5 ]]; then
    if [ -f "$EA_INPUT" ]; then
        EA_SOURCE="$(cd "$(dirname "$EA_INPUT")" && pwd)/$(basename "$EA_INPUT")"
    elif [ -f "${EA_INPUT}.mq5" ]; then
        EA_SOURCE="$(cd "$(dirname "${EA_INPUT}.mq5")" && pwd)/$(basename "${EA_INPUT}.mq5")"
    fi
fi

# Search in standard locations
if [ -z "$EA_SOURCE" ]; then
    SEARCH_PATHS=(
        "$SEARCH_BASE/code/experts/${EA_INPUT_CLEAN}.mq5"
        "$SEARCH_BASE/Experts/${EA_INPUT_CLEAN}.mq5"
        "$SEARCH_BASE/${EA_INPUT_CLEAN}.mq5"
    )
    for path in "${SEARCH_PATHS[@]}"; do
        if [ -f "$path" ]; then
            EA_SOURCE="$path"
            break
        fi
    done
fi

if [ -z "$EA_SOURCE" ]; then
    echo "[1/5] ERROR: Source not found for '$EA_INPUT'"
    echo ""
    echo "Searched in:"
    if [[ "$EA_INPUT" == *"/"* ]] || [[ "$EA_INPUT" == *.mq5 ]]; then
        echo "  - $EA_INPUT"
    fi
    for path in "${SEARCH_PATHS[@]}"; do
        echo "  - $path"
    done
    exit 1
fi

EA_NAME="$(basename "$EA_SOURCE" .mq5)"
EA_SOURCE_DIR="$(dirname "$EA_SOURCE")"

# Detect repo root: parent of Experts/ if source is in Experts/, otherwise SEARCH_BASE
REPO_ROOT="$SEARCH_BASE"
if [ "$(basename "$EA_SOURCE_DIR")" = "Experts" ]; then
    REPO_ROOT="$(dirname "$EA_SOURCE_DIR")"
fi

echo "=== EA-OAT-v3 Compiler ==="
echo "EA: $EA_NAME"
echo "Source: $EA_SOURCE"
echo ""

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

# --- Step 3: Copy source + dependencies to MT5 ---
mkdir -p "$EXPERTS_DIR"
cp "$EA_SOURCE" "$EXPERTS_DIR/"
echo "[3/5] Copied ${EA_NAME}.mq5 to MQL5/Experts/"

# --- 3a: Mirror MQL5-like directory structure ---
# If the repo has Include/, Experts/, Profiles/ etc., mirror them into MQL5/
# This preserves relative #include paths (e.g., #include "..\Include\foo.mqh")

INCLUDE_COUNT=0

# Check for Include/ directory (MT5-style repo like github.com/anhnguyen123312/EA)
if [ -d "$REPO_ROOT/Include" ]; then
    mkdir -p "$INCLUDE_DIR"
    for mqh_file in "$REPO_ROOT/Include"/*.mqh; do
        [ -f "$mqh_file" ] || continue
        cp "$mqh_file" "$INCLUDE_DIR/"
        INCLUDE_COUNT=$((INCLUDE_COUNT + 1))
        echo "      + $(basename "$mqh_file") -> MQL5/Include/"
    done
    # Also copy subdirectories recursively
    for sub_dir in "$REPO_ROOT/Include"/*/; do
        [ -d "$sub_dir" ] || continue
        local_name="$(basename "$sub_dir")"
        mkdir -p "$INCLUDE_DIR/$local_name"
        cp -r "$sub_dir"* "$INCLUDE_DIR/$local_name/" 2>/dev/null || true
        echo "      + Include/$local_name/ (recursive)"
    done
fi

# Check for code/include/ directory (skill-trader standard)
if [ -d "$REPO_ROOT/code/include" ]; then
    mkdir -p "$INCLUDE_DIR"
    for mqh_file in "$REPO_ROOT/code/include"/*.mqh; do
        [ -f "$mqh_file" ] || continue
        cp "$mqh_file" "$INCLUDE_DIR/"
        INCLUDE_COUNT=$((INCLUDE_COUNT + 1))
        echo "      + $(basename "$mqh_file") -> MQL5/Include/"
    done
fi

# Copy other .mq5 files from same Experts/ directory (multi-EA repos)
for other_mq5 in "$EA_SOURCE_DIR"/*.mq5; do
    [ -f "$other_mq5" ] || continue
    other_name="$(basename "$other_mq5")"
    [ "$other_name" = "${EA_NAME}.mq5" ] && continue  # Skip main EA (already copied)
    cp "$other_mq5" "$EXPERTS_DIR/"
    echo "      + $other_name -> MQL5/Experts/ (sibling)"
done

# Copy Profiles/Tester/*.set files if they exist
SET_COUNT=0
if [ -d "$REPO_ROOT/Profiles/Tester" ]; then
    PROFILES_DEST="$MQL5_DIR/Profiles/Tester"
    mkdir -p "$PROFILES_DEST"
    for set_file in "$REPO_ROOT/Profiles/Tester"/*.set; do
        [ -f "$set_file" ] || continue
        cp "$set_file" "$PROFILES_DEST/"
        SET_COUNT=$((SET_COUNT + 1))
    done
    # Copy Groups/ subfolder if present
    if [ -d "$REPO_ROOT/Profiles/Tester/Groups" ]; then
        mkdir -p "$PROFILES_DEST/Groups"
        cp "$REPO_ROOT/Profiles/Tester/Groups"/* "$PROFILES_DEST/Groups/" 2>/dev/null || true
    fi
    if [ $SET_COUNT -gt 0 ]; then
        echo "      + $SET_COUNT .set file(s) -> MQL5/Profiles/Tester/"
    fi
fi

if [ $INCLUDE_COUNT -gt 0 ]; then
    echo "      Total: ${EA_NAME}.mq5 + $INCLUDE_COUNT include(s)"
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
