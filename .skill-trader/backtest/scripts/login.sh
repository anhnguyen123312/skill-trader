#!/bin/bash
# MT5 Login & Credential Manager
# Usage:
#   ./scripts/login.sh                     # Auto-login (prompts for missing fields)
#   ./scripts/login.sh <LOGIN> <PASS> <SERVER>  # Login with all args
#   ./scripts/login.sh --status            # Check login status
#   ./scripts/login.sh --backup            # Backup cached credentials
#   ./scripts/login.sh --restore           # Restore from backup
#
# Auto-login reads defaults from config/credentials.env and cached common.ini.
# If any field is missing, it prompts interactively.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_BASE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
MT5_CONFIG="$MT5_BASE/config"
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
BACKUP_DIR="$PLUGIN_DIR/config/mt5-credentials"

# Credential files for auto-login
# accounts.dat = REQUIRED (encrypted cached login)
# servers.dat  = OPTIONAL (broker server configs, regenerated on connect)
# common.ini   = OPTIONAL (last login info)
CRED_FILES=("accounts.dat" "servers.dat" "common.ini")
REQUIRED_FILES=("accounts.dat")

# --- Functions ---

check_status() {
    echo "=== MT5 Login Status ==="
    echo ""

    # Check if credential files exist
    local all_ok=true
    for f in "${CRED_FILES[@]}"; do
        if [ -f "$MT5_CONFIG/$f" ]; then
            local size=$(stat -f%z "$MT5_CONFIG/$f")
            echo "[OK] $f ($size bytes)"
        else
            echo "[MISSING] $f"
            all_ok=false
        fi
    done

    echo ""

    # Try to read login from common.ini
    if [ -f "$MT5_CONFIG/common.ini" ]; then
        local login=$(iconv -f UTF-16LE -t UTF-8 "$MT5_CONFIG/common.ini" 2>/dev/null | tr -d '\r' | grep "^Login=" | head -1 | cut -d= -f2)
        local server=$(iconv -f UTF-16LE -t UTF-8 "$MT5_CONFIG/common.ini" 2>/dev/null | tr -d '\r' | grep "^Server=" | head -1 | cut -d= -f2)
        if [ -n "$login" ]; then
            echo "Cached Login:  $login"
            echo "Cached Server: $server"
        fi
    fi

    # Check backup
    echo ""
    if [ -d "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/accounts.dat" ]; then
        echo "Backup: EXISTS at $BACKUP_DIR"
    else
        echo "Backup: NONE (run ./scripts/login.sh --backup to create)"
    fi

    echo ""
    # READY = accounts.dat exists (the only truly required file)
    local ready=true
    for f in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$MT5_CONFIG/$f" ]; then
            ready=false
        fi
    done

    if [ "$ready" = true ]; then
        echo "Status: READY (credentials cached, backtest will auto-login)"
        if [ "$all_ok" = false ]; then
            echo "        (some optional files missing - will be regenerated on next connect)"
        fi
    else
        echo "Status: NOT READY"
        echo ""
        echo "To fix, either:"
        echo "  1. Login: ./scripts/login.sh <LOGIN> <PASSWORD> <SERVER>"
        echo "  2. Restore: ./scripts/login.sh --restore"
        echo "  3. Manual: Open MT5 GUI and login manually"
    fi
}

do_login() {
    local LOGIN="$1"
    local PASSWORD="$2"
    local SERVER="$3"

    echo "=== MT5 Auto-Login ==="
    echo "Login:  $LOGIN"
    echo "Server: $SERVER"
    echo ""

    # Step 0: Auto-restore servers.dat if missing (required for server name resolution)
    if [ ! -f "$MT5_CONFIG/servers.dat" ] && [ -f "$BACKUP_DIR/servers.dat" ]; then
        cp "$BACKUP_DIR/servers.dat" "$MT5_CONFIG/"
        echo "[0/4] Restored servers.dat from backup (needed for server resolution)"
    fi

    # Step 1: Create login config with [Common] + [Tester] sections
    # CRITICAL: Must include [Tester] with ShutdownTerminal=1 so MT5 exits gracefully.
    # Without [Tester], MT5 stays open after login and pkill during "scanning network"
    # corrupts accounts.dat. A minimal 1-day backtest triggers clean shutdown.
    local LOGIN_CONFIG="$WINEPREFIX/drive_c/autologin.ini"
    printf "[Common]\r\nLogin=%s\r\nPassword=%s\r\nServer=%s\r\nKeepPrivate=0\r\nNewsEnable=0\r\n[Tester]\r\nExpert=SimpleMA_EA\r\nSymbol=XAUUSD\r\nPeriod=15\r\nModel=0\r\nFromDate=2024.01.01\r\nToDate=2024.01.02\r\nDeposit=1000\r\nCurrency=USD\r\nLeverage=1:1000\r\nVisual=0\r\nShutdownTerminal=1\r\nLogin=%s\r\nServer=%s\r\nOptimization=0\r\nDelay=0\r\n" \
        "$LOGIN" "$PASSWORD" "$SERVER" "$LOGIN" "$SERVER" > "$LOGIN_CONFIG"

    echo "[1/4] Login config created"

    # Step 2: Kill any existing MT5
    pkill -f "terminal64" 2>/dev/null || true
    sleep 2

    # Step 3: Launch MT5 with login config
    echo "[2/4] Launching MT5 for login..."
    local LOG_DATE=$(date +%Y%m%d)
    local LOG_FILE="$MT5_BASE/logs/${LOG_DATE}.log"

    # Record current line count to only check NEW entries (avoid matching old auth lines)
    # Using line count on decoded text avoids UTF-16LE byte alignment issues with dd
    local LOG_LINES_BEFORE=0
    if [ -f "$LOG_FILE" ]; then
        LOG_LINES_BEFORE=$(iconv -f UTF-16LE -t UTF-8 "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
    fi

    cd "$MT5_BASE"
    WINEPREFIX="$WINEPREFIX" "$WINE" terminal64.exe \
        /config:C:\\autologin.ini \
        /portable 2>/dev/null &
    MT5_PID=$!

    # Step 4: Wait for login to complete (check logs)
    echo "[3/4] Waiting for authorization..."
    local TIMEOUT=90
    local ELAPSED=0

    while [ $ELAPSED -lt $TIMEOUT ]; do
        sleep 3
        ELAPSED=$((ELAPSED + 3))

        # Check if log file exists
        if [ -f "$LOG_FILE" ]; then
            # Decode full log, then take only NEW lines (after our launch)
            local LOG_TEXT=$(iconv -f UTF-16LE -t UTF-8 "$LOG_FILE" 2>/dev/null | tr -d '\r' | tail -n +"$((LOG_LINES_BEFORE + 1))" || true)

            # Check for successful authorization
            if echo "$LOG_TEXT" | grep -q "'${LOGIN}': authorized on"; then
                echo ""
                echo "[4/4] LOGIN SUCCESSFUL"
                local auth_line=$(echo "$LOG_TEXT" | grep "'${LOGIN}': authorized on" | tail -1)
                echo "      $auth_line"

                # Wait for MT5 to run mini-backtest and exit gracefully
                # (ShutdownTerminal=1 in [Tester] triggers clean exit)
                # DO NOT pkill - killing during "scanning network" corrupts accounts.dat
                echo "      Waiting for MT5 graceful shutdown..."
                local EXIT_WAIT=0
                while kill -0 "$MT5_PID" 2>/dev/null && [ $EXIT_WAIT -lt 60 ]; do
                    sleep 2
                    EXIT_WAIT=$((EXIT_WAIT + 2))
                done

                if kill -0 "$MT5_PID" 2>/dev/null; then
                    echo "      MT5 still running after 60s, force stopping..."
                    pkill -f "terminal64" 2>/dev/null || true
                    sleep 3
                else
                    echo "      MT5 exited cleanly"
                fi

                # Clean up login config (contains password)
                rm -f "$LOGIN_CONFIG"

                # Save credentials to credentials.env for backtest.sh
                # (backtest.sh needs Password= in [Common] to avoid Tester login popup)
                local CRED_ENV="$PLUGIN_DIR/config/credentials.env"
                cat > "$CRED_ENV" <<CREDEOF
# MT5 credentials (auto-generated by login.sh)
MT5_LOGIN=$LOGIN
MT5_PASSWORD=$PASSWORD
MT5_SERVER=$SERVER
CREDEOF
                chmod 600 "$CRED_ENV"
                echo "      Saved credentials to config/credentials.env"

                echo ""
                echo "Credentials cached. Backtest will auto-login."
                echo ""
                echo "Recommended: ./scripts/login.sh --backup"
                return 0
            fi

            # Check for failed authorization
            if echo "$LOG_TEXT" | grep -q -E "'${LOGIN}': authorization.*failed|account is not specified"; then
                local fail_line=$(echo "$LOG_TEXT" | grep -E "'${LOGIN}': authorization.*failed|account is not specified" | tail -1)
                echo ""
                echo "[4/4] LOGIN FAILED"
                echo "      $fail_line"
                pkill -f "terminal64" 2>/dev/null || true
                rm -f "$LOGIN_CONFIG"
                return 1
            fi

            # Check if MT5 exited without auth (process died)
            if ! kill -0 "$MT5_PID" 2>/dev/null && [ $ELAPSED -gt 15 ]; then
                echo ""
                echo "[4/4] LOGIN FAILED: MT5 exited without authorization"
                echo "      Check logs: $LOG_FILE"
                rm -f "$LOGIN_CONFIG"
                return 1
            fi
        fi

        printf "\r      [%02d/%02ds] Waiting..." "$ELAPSED" "$TIMEOUT"
    done

    echo ""
    echo "[4/4] TIMEOUT: Password login did not work (Wine 8.x limitation)"
    pkill -f "terminal64" 2>/dev/null || true
    rm -f "$LOGIN_CONFIG"

    # Auto-fallback: restore from backup if available
    if [ -d "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/accounts.dat" ]; then
        echo ""
        echo "      Auto-restoring from backup..."
        do_restore
        echo ""
        echo "      Credentials restored. Testing connection..."

        # Verify restored credentials work
        local VERIFY_LINES=0
        if [ -f "$LOG_FILE" ]; then
            VERIFY_LINES=$(iconv -f UTF-16LE -t UTF-8 "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
        fi

        cd "$MT5_BASE"
        WINEPREFIX="$WINEPREFIX" "$WINE" terminal64.exe /config:C:\\autologin.ini /portable 2>/dev/null &
        sleep 15

        local VERIFY_TEXT=$(iconv -f UTF-16LE -t UTF-8 "$LOG_FILE" 2>/dev/null | tr -d '\r' | tail -n +"$((VERIFY_LINES + 1))" || true)
        pkill -f "terminal64" 2>/dev/null || true
        rm -f "$LOGIN_CONFIG"

        if echo "$VERIFY_TEXT" | grep -q "'${LOGIN}': authorized on"; then
            local auth_line=$(echo "$VERIFY_TEXT" | grep "'${LOGIN}': authorized on" | tail -1)
            echo ""
            echo "LOGIN SUCCESSFUL (via backup restore)"
            echo "      $auth_line"
            return 0
        else
            echo ""
            echo "WARNING: Backup restore did not produce authorization."
            echo "         Open MT5 app manually and login via GUI."
            return 1
        fi
    fi

    echo ""
    echo "No backup available. Please:"
    echo "  1. Open MetaTrader 5 app manually"
    echo "  2. Login with: $LOGIN / $SERVER"
    echo "  3. Close MT5"
    echo "  4. Run: ./scripts/login.sh --backup"
    return 1
}

do_backup() {
    echo "=== Backup MT5 Credentials ==="
    echo ""

    # Safety: verify accounts.dat is valid before overwriting a good backup
    # A valid accounts.dat should be >4KB (corrupt ones are ~3-4KB)
    local MIN_ACCOUNTS_SIZE=4096
    if [ -f "$MT5_CONFIG/accounts.dat" ]; then
        local current_size=$(stat -f%z "$MT5_CONFIG/accounts.dat")
        if [ "$current_size" -lt "$MIN_ACCOUNTS_SIZE" ]; then
            echo "WARNING: accounts.dat is only $current_size bytes (expected >$MIN_ACCOUNTS_SIZE)"
            echo "         This may be from a failed login. Skipping backup to protect existing backup."
            echo ""
            if [ -f "$BACKUP_DIR/accounts.dat" ]; then
                local backup_size=$(stat -f%z "$BACKUP_DIR/accounts.dat")
                echo "Existing backup: accounts.dat ($backup_size bytes) - PRESERVED"
            fi
            return 1
        fi
    fi

    mkdir -p "$BACKUP_DIR"

    local count=0
    for f in "${CRED_FILES[@]}"; do
        if [ -f "$MT5_CONFIG/$f" ]; then
            local size=$(stat -f%z "$MT5_CONFIG/$f")

            # Protect common.ini: don't overwrite a larger backup with a smaller one
            # (login-generated common.ini ~242B lacks Environment field vs original ~1716B)
            if [ "$f" = "common.ini" ] && [ -f "$BACKUP_DIR/$f" ]; then
                local backup_size=$(stat -f%z "$BACKUP_DIR/$f")
                if [ "$size" -lt "$backup_size" ]; then
                    echo "[KEEP] $f (current ${size}B < backup ${backup_size}B, keeping larger backup)"
                    count=$((count + 1))
                    continue
                fi
            fi

            cp "$MT5_CONFIG/$f" "$BACKUP_DIR/"
            echo "[OK] $f ($size bytes)"
            count=$((count + 1))
        else
            echo "[SKIP] $f (not found)"
        fi
    done

    echo ""
    if [ $count -gt 0 ]; then
        echo "Backed up $count file(s) to: $BACKUP_DIR"
        echo ""
        echo "NOTE: Add config/mt5-credentials/ to .gitignore!"
        echo "      These contain encrypted login data."
    else
        echo "No credential files found to backup."
        echo "Login first: ./scripts/login.sh <LOGIN> <PASSWORD> <SERVER>"
    fi
}

do_restore() {
    echo "=== Restore MT5 Credentials ==="
    echo ""

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "ERROR: No backup found at: $BACKUP_DIR"
        echo "Run ./scripts/login.sh --backup first"
        exit 1
    fi

    # Kill MT5 first (files may be locked)
    pkill -f "terminal64" 2>/dev/null || true
    sleep 2

    local count=0
    for f in "${CRED_FILES[@]}"; do
        if [ -f "$BACKUP_DIR/$f" ]; then
            cp "$BACKUP_DIR/$f" "$MT5_CONFIG/"
            local size=$(stat -f%z "$BACKUP_DIR/$f")
            echo "[OK] Restored $f ($size bytes)"
            count=$((count + 1))
        else
            echo "[SKIP] $f (not in backup)"
        fi
    done

    echo ""
    echo "Restored $count file(s). Auto-login should work now."
}

# --- Load defaults from multiple sources ---

load_defaults() {
    # Priority: ENV vars > credentials.env > cached common.ini > hardcoded defaults
    DEFAULT_LOGIN=""
    DEFAULT_PASSWORD=""
    DEFAULT_SERVER=""

    # Source credentials.env if exists
    local CRED_FILE="$PLUGIN_DIR/config/credentials.env"
    if [ -f "$CRED_FILE" ]; then
        source "$CRED_FILE"
        DEFAULT_LOGIN="${MT5_LOGIN:-}"
        DEFAULT_PASSWORD="${MT5_PASSWORD:-}"
        DEFAULT_SERVER="${MT5_SERVER:-}"
    fi

    # Try cached common.ini for login/server if not set
    if [ -f "$MT5_CONFIG/common.ini" ]; then
        if [ -z "$DEFAULT_LOGIN" ]; then
            DEFAULT_LOGIN=$(iconv -f UTF-16LE -t UTF-8 "$MT5_CONFIG/common.ini" 2>/dev/null | tr -d '\r' | grep "^Login=" | head -1 | cut -d= -f2)
        fi
        if [ -z "$DEFAULT_SERVER" ]; then
            DEFAULT_SERVER=$(iconv -f UTF-16LE -t UTF-8 "$MT5_CONFIG/common.ini" 2>/dev/null | tr -d '\r' | grep "^Server=" | head -1 | cut -d= -f2)
        fi
    fi

    # Hardcoded fallbacks
    DEFAULT_LOGIN="${DEFAULT_LOGIN:-128364028}"
    DEFAULT_SERVER="${DEFAULT_SERVER:-Exness-MT5Real7}"
}

do_interactive_login() {
    load_defaults

    echo "=== MT5 Auto-Login ==="
    echo ""

    # --- Prompt for each missing field ---

    # Login
    local LOGIN=""
    if [ -n "$DEFAULT_LOGIN" ]; then
        printf "Login [%s]: " "$DEFAULT_LOGIN"
        read -r LOGIN
        LOGIN="${LOGIN:-$DEFAULT_LOGIN}"
    else
        while [ -z "$LOGIN" ]; do
            printf "Login: "
            read -r LOGIN
            if [ -z "$LOGIN" ]; then
                echo "  Login is required."
            fi
        done
    fi

    # Server
    local SERVER=""
    if [ -n "$DEFAULT_SERVER" ]; then
        printf "Server [%s]: " "$DEFAULT_SERVER"
        read -r SERVER
        SERVER="${SERVER:-$DEFAULT_SERVER}"
    else
        while [ -z "$SERVER" ]; do
            printf "Server: "
            read -r SERVER
            if [ -z "$SERVER" ]; then
                echo "  Server is required."
            fi
        done
    fi

    # Password (hidden input)
    local PASSWORD=""
    if [ -n "$DEFAULT_PASSWORD" ]; then
        printf "Password [****]: "
        read -rs PASSWORD
        echo ""
        PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
    else
        while [ -z "$PASSWORD" ]; do
            printf "Password: "
            read -rs PASSWORD
            echo ""
            if [ -z "$PASSWORD" ]; then
                echo "  Password is required."
            fi
        done
    fi

    echo ""
    do_login "$LOGIN" "$PASSWORD" "$SERVER"
}

# --- Main ---

case "${1:-}" in
    --backup|-b)
        do_backup
        ;;
    --restore|-r)
        do_restore
        ;;
    --status|-s)
        check_status
        ;;
    --help|-h)
        echo "MT5 Login & Credential Manager"
        echo ""
        echo "Usage:"
        echo "  ./scripts/login.sh                          # Auto-login (prompts for missing fields)"
        echo "  ./scripts/login.sh <LOGIN> <PASS> <SERVER>  # Login with all args"
        echo "  ./scripts/login.sh --status                 # Check login status"
        echo "  ./scripts/login.sh --backup                 # Backup credentials"
        echo "  ./scripts/login.sh --restore                # Restore from backup"
        echo ""
        echo "Defaults loaded from: config/credentials.env, cached common.ini"
        ;;
    "")
        do_interactive_login
        ;;
    *)
        # Positional args: LOGIN PASSWORD SERVER
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "ERROR: Need LOGIN, PASSWORD, and SERVER"
            echo "Usage: ./scripts/login.sh <LOGIN> <PASSWORD> <SERVER>"
            exit 1
        fi
        do_login "$1" "$2" "$3"
        ;;
esac
