#!/bin/bash
# skill-trader installer
# Installs MT5 backtest skill into your project or user skills directory
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/install.sh | bash -s -- --global
#   curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/install.sh | bash -s -- --full

set -e

REPO="anhnguyen123312/skill-trader"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

# Parse args
INSTALL_MODE="skill"  # skill | full | global
for arg in "$@"; do
    case "$arg" in
        --global) INSTALL_MODE="global" ;;
        --full)   INSTALL_MODE="full" ;;
        --help)
            echo "skill-trader installer"
            echo ""
            echo "Usage:"
            echo "  curl -fsSL $BASE_URL/install.sh | bash              # Skill only (project)"
            echo "  curl -fsSL $BASE_URL/install.sh | bash -s -- --global  # Skill only (global)"
            echo "  curl -fsSL $BASE_URL/install.sh | bash -s -- --full    # Full pipeline (scripts + config + EA)"
            echo ""
            exit 0
            ;;
    esac
done

echo "=== skill-trader installer ==="
echo ""

# Determine target directory
if [ "$INSTALL_MODE" = "global" ]; then
    SKILL_DIR="$HOME/.claude/skills/mt5-backtest"
    echo "Installing skill globally to: $SKILL_DIR"
elif [ "$INSTALL_MODE" = "full" ]; then
    SKILL_DIR=".claude/skills/mt5-backtest"
    echo "Installing full pipeline to current directory"
else
    SKILL_DIR=".claude/skills/mt5-backtest"
    echo "Installing skill to project: $SKILL_DIR"
fi

# Install skill file
mkdir -p "$SKILL_DIR"
curl -fsSL "$BASE_URL/skills/mt5-backtest/SKILL.md" -o "$SKILL_DIR/SKILL.md"
echo "[OK] Skill installed: $SKILL_DIR/SKILL.md"

# Full mode: also install scripts, config, and example EA
if [ "$INSTALL_MODE" = "full" ]; then
    echo ""
    echo "Installing pipeline scripts..."

    mkdir -p scripts config code/experts

    for script in login.sh compile.sh backtest.sh monitor.sh collect.sh run.sh; do
        curl -fsSL "$BASE_URL/scripts/$script" -o "scripts/$script"
        chmod +x "scripts/$script"
    done
    echo "[OK] Scripts installed: scripts/"

    curl -fsSL "$BASE_URL/config/backtest.template.ini" -o "config/backtest.template.ini"
    echo "[OK] Config template installed: config/backtest.template.ini"

    curl -fsSL "$BASE_URL/code/experts/SimpleMA_EA.mq5" -o "code/experts/SimpleMA_EA.mq5"
    echo "[OK] Example EA installed: code/experts/SimpleMA_EA.mq5"

    mkdir -p results/logs
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Claude Code will auto-discover the skill."
echo "Trigger: ask Claude to 'backtest EA' or 'compile EA'"
if [ "$INSTALL_MODE" = "full" ]; then
    echo ""
    echo "Quick start:"
    echo "  ./scripts/run.sh SimpleMA_EA XAUUSD M15 2024.01.01 2024.12.31 --no-visual"
fi
echo ""
