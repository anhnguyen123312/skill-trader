#!/bin/bash
# Run backtest via MT5
# Usage: ./scripts/backtest.sh                                    # Interactive (prompts all params)
#        ./scripts/backtest.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM] [TO] [--no-visual]
#
# Period values: M1, M5, M15, M30, H1, H4, D1
# Credentials: config/credentials.env or ENV vars or cached common.ini

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_BASE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
TEMPLATE="$PLUGIN_DIR/config/backtest.template.ini"
CRED_FILE="$PLUGIN_DIR/config/credentials.env"

# --- Load credentials ---
if [ -f "$CRED_FILE" ]; then
    source "$CRED_FILE"
fi
MT5_LOGIN="${MT5_LOGIN:-128364028}"
MT5_PASSWORD="${MT5_PASSWORD:-}"
MT5_SERVER="${MT5_SERVER:-Exness-MT5Real7}"
MT5_DEPOSIT="${MT5_DEPOSIT:-1000}"
MT5_LEVERAGE="${MT5_LEVERAGE:-1:1000}"
MT5_DELAY="${MT5_DELAY:-100}"

# --- Map period name to MT5 value ---
map_period() {
    case "$1" in
        M1)  echo 1 ;;
        M5)  echo 5 ;;
        M15) echo 15 ;;
        M30) echo 30 ;;
        H1)  echo 16385 ;;
        H4)  echo 16388 ;;
        D1)  echo 16408 ;;
        *)   echo "$1" ;;
    esac
}

# --- Interactive mode: prompt for all params ---
if [ -z "$1" ] || [ "$1" = "--interactive" ] || [ "$1" = "-i" ]; then
    echo "=== EA-OAT Backtest Setup ==="
    echo ""

    # 1. EA Name - list available .ex5 files
    echo "Available EAs:"
    EA_LIST=()
    while IFS= read -r f; do
        ea=$(basename "$f" .ex5)
        EA_LIST+=("$ea")
    done < <(find "$MT5_BASE/MQL5/Experts" -maxdepth 1 -name "*.ex5" 2>/dev/null | sort)

    if [ ${#EA_LIST[@]} -eq 0 ]; then
        echo "  (none found - compile first with ./scripts/compile.sh)"
        printf "EA Name: "
        read -r EA_NAME
    else
        for i in "${!EA_LIST[@]}"; do
            echo "  $((i+1)). ${EA_LIST[$i]}"
        done
        printf "EA [1]: "
        read -r ea_input
        if [ -z "$ea_input" ]; then
            EA_NAME="${EA_LIST[0]}"
        elif [[ "$ea_input" =~ ^[0-9]+$ ]] && [ "$ea_input" -ge 1 ] && [ "$ea_input" -le ${#EA_LIST[@]} ]; then
            EA_NAME="${EA_LIST[$((ea_input-1))]}"
        else
            EA_NAME="$ea_input"
        fi
    fi

    # 2. Symbol
    printf "Symbol [XAUUSD]: "
    read -r SYMBOL
    SYMBOL="${SYMBOL:-XAUUSD}"

    # 3. Period
    echo "Periods: M1, M5, M15, M30, H1, H4, D1"
    printf "Period [M15]: "
    read -r PERIOD_NAME
    PERIOD_NAME="${PERIOD_NAME:-M15}"

    # 4. Date range
    printf "From [2024.01.01]: "
    read -r FROM_DATE
    FROM_DATE="${FROM_DATE:-2024.01.01}"

    printf "To [2024.12.31]: "
    read -r TO_DATE
    TO_DATE="${TO_DATE:-2024.12.31}"

    # 5. Visual mode
    printf "Visual? (y/n) [n]: "
    read -r vis_input
    if [ "$vis_input" = "y" ] || [ "$vis_input" = "Y" ]; then
        VISUAL=1
    else
        VISUAL=0
    fi

    PERIOD=$(map_period "$PERIOD_NAME")
    echo ""
else
    # --- CLI mode: positional args ---
    EA_NAME="$1"
    SYMBOL="${2:-XAUUSD}"
    PERIOD_NAME="${3:-M15}"
    FROM_DATE="${4:-2024.01.01}"
    TO_DATE="${5:-2024.12.31}"

    VISUAL=1
    for arg in "$@"; do
        if [ "$arg" = "--no-visual" ]; then
            VISUAL=0
        fi
    done

    PERIOD=$(map_period "$PERIOD_NAME")
fi

echo "=== EA-OAT Backtest Launcher ==="
echo "EA:       $EA_NAME"
echo "Symbol:   $SYMBOL"
echo "Period:   $PERIOD_NAME ($PERIOD)"
echo "Range:    $FROM_DATE -> $TO_DATE"
echo "Login:    $MT5_LOGIN"
echo "Server:   $MT5_SERVER"
echo "Deposit:  \$$MT5_DEPOSIT"
echo "Leverage: $MT5_LEVERAGE"
echo "Delay:    ${MT5_DELAY}ms"
echo "Visual:   $([ "$VISUAL" = "1" ] && echo 'ON' || echo 'OFF')"
echo ""

# --- Check credentials ---
if [ ! -f "$MT5_BASE/config/accounts.dat" ] && [ -z "$MT5_PASSWORD" ]; then
    echo "WARNING: No cached credentials and no password provided."
    echo "         Backtest may fail to connect."
    echo ""
    echo "Fix: ./scripts/login.sh $MT5_LOGIN <PASSWORD> $MT5_SERVER"
    echo " Or: export MT5_PASSWORD=yourpassword"
    echo ""
fi

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
# [Common] MUST always include Login + Server (tells MT5 which cached account to use).
# Password is ONLY included when explicitly provided (empty Password= corrupts accounts.dat).
COMMON_SECTION="[Common]\nLogin=${MT5_LOGIN}\nServer=${MT5_SERVER}\nKeepPrivate=0\nNewsEnable=0\n"
if [ -n "$MT5_PASSWORD" ]; then
    COMMON_SECTION="[Common]\nLogin=${MT5_LOGIN}\nPassword=${MT5_PASSWORD}\nServer=${MT5_SERVER}\nKeepPrivate=0\nNewsEnable=0\n"
fi

# Build config: optional [Common] + [Tester] from template
{
    if [ -n "$COMMON_SECTION" ]; then
        printf "$COMMON_SECTION"
    fi
    sed -e "s/__EA_NAME__/$EA_NAME/g" \
        -e "s/__SYMBOL__/$SYMBOL/" \
        -e "s/__PERIOD__/$PERIOD/" \
        -e "s/__FROM_DATE__/$FROM_DATE/" \
        -e "s/__TO_DATE__/$TO_DATE/" \
        -e "s/__VISUAL__/$VISUAL/" \
        -e "s/__LOGIN__/$MT5_LOGIN/g" \
        -e "s/__SERVER__/$MT5_SERVER/g" \
        -e "s/__DEPOSIT__/$MT5_DEPOSIT/" \
        -e "s/__LEVERAGE__/$MT5_LEVERAGE/" \
        -e "s/__DELAY__/$MT5_DELAY/" \
        "$TEMPLATE"
    # Extract default input values from .mq5 source and append [TesterInputs]
    MQ5_SRC="$PROJECT_ROOT/code/experts/${EA_NAME}.mq5"
    if [ -f "$MQ5_SRC" ]; then
        printf "\n[TesterInputs]\n"
        grep -E '^\s*input\s+' "$MQ5_SRC" | while IFS= read -r line; do
            # Extract variable name and default value from: input <type> <name> = <value>;
            varname=$(echo "$line" | sed -E 's/^\s*input\s+\S+\s+(\w+)\s*=.*/\1/')
            # Extract value: everything between = and ; (trim whitespace)
            val=$(echo "$line" | sed -E 's/^[^=]+=\s*([^;]+);.*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "$varname" ] && [ -n "$val" ]; then
                printf "%s=%s\n" "$varname" "$val"
            fi
        done
    fi
} | sed 's/$/\r/' > "$CONFIG_FILE"

echo "[2/4] Config generated (CRLF) with [TesterInputs]"

# Also save a copy in project
cp "$CONFIG_FILE" "$PLUGIN_DIR/config/last_backtest.ini"

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
