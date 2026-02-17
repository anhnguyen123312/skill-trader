#!/bin/bash
# skill-trader setup script
# Sets up a new EA project with the full backtest pipeline
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/setup.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/setup.sh | bash -s -- my-ea-project
#
# What it does:
#   1. Creates project directory structure
#   2. Downloads all pipeline scripts (login, compile, backtest, monitor, collect, run)
#   3. Downloads config template
#   4. Downloads example EA (SimpleMA_EA.mq5)
#   5. Installs Claude Code skill (auto-discovered by Claude)
#   6. Creates .gitignore with proper exclusions
#   7. Optionally inits git repo

set -e

REPO="anhnguyen123312/skill-trader"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

# Project name from arg or current directory
PROJECT_NAME="${1:-}"

if [ -n "$PROJECT_NAME" ]; then
    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    echo "=== skill-trader Setup ==="
    echo "Project: $PROJECT_NAME"
else
    echo "=== skill-trader Setup ==="
    echo "Project: $(basename "$(pwd)")"
fi
echo ""

# --- 1. Directory structure ---
echo "[1/6] Creating directory structure..."
mkdir -p code/experts code/include config scripts results/logs .claude/skills/mt5-backtest
echo "      code/experts/    - EA source files (.mq5)"
echo "      code/include/    - Shared MQL5 includes"
echo "      config/          - Config templates & credentials"
echo "      scripts/         - Pipeline scripts"
echo "      results/         - Backtest CSV outputs"

# --- 2. Download scripts ---
echo ""
echo "[2/6] Downloading pipeline scripts..."
SCRIPTS="login.sh compile.sh backtest.sh monitor.sh collect.sh run.sh"
for script in $SCRIPTS; do
    curl -fsSL "$BASE_URL/scripts/$script" -o "scripts/$script"
    chmod +x "scripts/$script"
    echo "      [OK] scripts/$script"
done

# --- 3. Download config ---
echo ""
echo "[3/6] Downloading config template..."
curl -fsSL "$BASE_URL/config/backtest.template.ini" -o "config/backtest.template.ini"
echo "      [OK] config/backtest.template.ini"

# --- 4. Download example EA ---
echo ""
echo "[4/6] Downloading example EA..."
curl -fsSL "$BASE_URL/code/experts/SimpleMA_EA.mq5" -o "code/experts/SimpleMA_EA.mq5"
echo "      [OK] code/experts/SimpleMA_EA.mq5"

# --- 5. Install Claude Code skill ---
echo ""
echo "[5/6] Installing Claude Code skill..."
curl -fsSL "$BASE_URL/skills/mt5-backtest/SKILL.md" -o ".claude/skills/mt5-backtest/SKILL.md"
echo "      [OK] .claude/skills/mt5-backtest/SKILL.md"

# --- 6. Create .gitignore ---
echo ""
echo "[6/6] Creating .gitignore..."
if [ ! -f .gitignore ]; then
    cat > .gitignore <<'GITIGNORE'
# Results (generated, large CSVs)
results/*.csv
results/logs/

# MT5 generated configs
config/last_backtest.ini

# Credentials (NEVER commit these)
config/credentials.env
config/mt5-credentials/

# macOS
.DS_Store

# Editor
*.swp
*.swo
*~
GITIGNORE
    echo "      [OK] .gitignore created"
else
    echo "      [SKIP] .gitignore already exists"
fi

# --- Optional: init git ---
if [ ! -d .git ]; then
    echo ""
    printf "Initialize git repo? (y/n) [y]: "
    read -r git_init
    if [ "$git_init" != "n" ] && [ "$git_init" != "N" ]; then
        git init -q
        echo "      [OK] git repo initialized"
    fi
fi

echo ""
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo ""
echo "  1. Login to your broker:"
echo "     ./scripts/login.sh"
echo ""
echo "  2. Place your EA source files in code/experts/"
echo "     (SimpleMA_EA.mq5 included as example)"
echo ""
echo "  3. Run a backtest:"
echo "     ./scripts/backtest.sh"
echo ""
echo "  4. Or run the full pipeline:"
echo "     ./scripts/run.sh SimpleMA_EA XAUUSD M15 2024.01.01 2024.12.31 --no-visual"
echo ""
echo "  5. Use Claude Code: ask 'backtest EA' or 'compile EA'"
echo "     (skill auto-discovered from .claude/skills/)"
echo ""
