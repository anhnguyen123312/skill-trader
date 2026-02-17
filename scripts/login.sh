#!/bin/bash
# MT5 Login & Credential Manager
# Usage:
#   ./scripts/login.sh                     # Check login status
#   ./scripts/login.sh <LOGIN> <PASS> <SERVER>  # Login and cache credentials
#   ./scripts/login.sh --backup            # Backup cached credentials
#   ./scripts/login.sh --restore           # Restore from backup
#
# Example:
#   ./scripts/login.sh 128364028 Ready@123 Exness-MT5Real7

set -e

PROJECT_ROOT="/Volumes/Data/Git/EA-OAT-v3"
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
MT5_BASE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
MT5_CONFIG="$MT5_BASE/config"
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
BACKUP_DIR="$PROJECT_ROOT/config/mt5-credentials"

# Credential files needed for auto-login
CRED_FILES=("accounts.dat" "servers.dat" "common.ini")

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
    if [ "$all_ok" = true ]; then
        echo "Status: READY (credentials cached, backtest will auto-login)"
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

    # Step 1: Create login config with [Common] section containing password
    local LOGIN_CONFIG="$WINEPREFIX/drive_c/autologin.ini"
    printf "[Common]\r\nLogin=%s\r\nPassword=%s\r\nServer=%s\r\nKeepPrivate=0\r\nNewsEnable=0\r\n" \
        "$LOGIN" "$PASSWORD" "$SERVER" > "$LOGIN_CONFIG"

    echo "[1/4] Login config created"

    # Step 2: Kill any existing MT5
    pkill -f "terminal64" 2>/dev/null || true
    sleep 2

    # Step 3: Launch MT5 with login config
    echo "[2/4] Launching MT5 for login..."
    cd "$MT5_BASE"
    WINEPREFIX="$WINEPREFIX" "$WINE" terminal64.exe \
        /config:C:\\autologin.ini \
        /portable 2>/dev/null &
    MT5_PID=$!

    # Step 4: Wait for login to complete (check logs)
    echo "[3/4] Waiting for authorization..."
    local LOG_DATE=$(date +%Y%m%d)
    local LOG_FILE="$MT5_BASE/logs/${LOG_DATE}.log"
    local TIMEOUT=60
    local ELAPSED=0

    while [ $ELAPSED -lt $TIMEOUT ]; do
        sleep 3
        ELAPSED=$((ELAPSED + 3))

        # Check if log file exists and contains authorization result
        if [ -f "$LOG_FILE" ]; then
            local LOG_TEXT=$(iconv -f UTF-16LE -t UTF-8 "$LOG_FILE" 2>/dev/null | tr -d '\r' || true)

            # Check for successful authorization
            if echo "$LOG_TEXT" | grep -q "'${LOGIN}': authorized on"; then
                echo ""
                echo "[4/4] LOGIN SUCCESSFUL"
                local auth_line=$(echo "$LOG_TEXT" | grep "'${LOGIN}': authorized on" | tail -1)
                echo "      $auth_line"

                # Wait a moment for credential files to be written
                sleep 3

                # Kill MT5 (we just needed the login)
                pkill -f "terminal64" 2>/dev/null || true

                # Clean up login config (contains password)
                rm -f "$LOGIN_CONFIG"

                echo ""
                echo "Credentials cached in MT5. Auto-login will work for backtests."
                echo ""
                echo "Recommended: ./scripts/login.sh --backup"
                return 0
            fi

            # Check for failed authorization
            if echo "$LOG_TEXT" | grep -q "'${LOGIN}': authorization.*failed"; then
                local fail_line=$(echo "$LOG_TEXT" | grep "'${LOGIN}': authorization.*failed" | tail -1)
                echo ""
                echo "[4/4] LOGIN FAILED"
                echo "      $fail_line"
                pkill -f "terminal64" 2>/dev/null || true
                rm -f "$LOGIN_CONFIG"
                return 1
            fi
        fi

        printf "\r      [%02d/%02ds] Waiting..." "$ELAPSED" "$TIMEOUT"
    done

    echo ""
    echo "[4/4] TIMEOUT: No authorization response in ${TIMEOUT}s"
    echo "      MT5 may still be connecting. Check manually."
    pkill -f "terminal64" 2>/dev/null || true
    rm -f "$LOGIN_CONFIG"
    return 1
}

do_backup() {
    echo "=== Backup MT5 Credentials ==="
    echo ""

    mkdir -p "$BACKUP_DIR"

    local count=0
    for f in "${CRED_FILES[@]}"; do
        if [ -f "$MT5_CONFIG/$f" ]; then
            cp "$MT5_CONFIG/$f" "$BACKUP_DIR/"
            local size=$(stat -f%z "$MT5_CONFIG/$f")
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

# --- Main ---

case "${1:-}" in
    --backup|-b)
        do_backup
        ;;
    --restore|-r)
        do_restore
        ;;
    --help|-h)
        echo "MT5 Login & Credential Manager"
        echo ""
        echo "Usage:"
        echo "  ./scripts/login.sh                          # Check status"
        echo "  ./scripts/login.sh <LOGIN> <PASS> <SERVER>  # Login & cache"
        echo "  ./scripts/login.sh --backup                 # Backup credentials"
        echo "  ./scripts/login.sh --restore                # Restore from backup"
        echo ""
        echo "Example:"
        echo "  ./scripts/login.sh 128364028 Ready@123 Exness-MT5Real7"
        ;;
    "")
        check_status
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
