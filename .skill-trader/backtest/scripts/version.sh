#!/bin/bash
# EA Version Manager - auto-increment versions via git tags
# Usage: ./scripts/version.sh <EA_NAME> [--message "changelog"] [--major]
#
# Creates versioned .ini config, git commit, and git tag.
# Version format: {EA_NAME}-v{MAJOR}.{MINOR}
# Default: auto-increment minor (v1.0 -> v1.1 -> v1.2)
# --major: bump major, reset minor (v1.2 -> v2.0)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"

# --- Parse args ---
EA_NAME=""
COMMIT_MSG=""
MAJOR_BUMP=false

while [ $# -gt 0 ]; do
    case "$1" in
        --message)
            shift
            COMMIT_MSG="$1"
            ;;
        --major)
            MAJOR_BUMP=true
            ;;
        --help|-h)
            echo "Usage: ./scripts/version.sh <EA_NAME> [--message \"changelog\"] [--major]"
            echo ""
            echo "Arguments:"
            echo "  EA_NAME              Name of EA (without .mq5)"
            echo "  --message \"text\"     Commit message / changelog entry"
            echo "  --major              Bump major version (v1.2 -> v2.0)"
            echo ""
            echo "Examples:"
            echo "  ./scripts/version.sh MyEA --message \"Added trailing stop\""
            echo "  ./scripts/version.sh MyEA --major --message \"Complete rewrite\""
            echo ""
            echo "Version history: git tag -l 'MyEA-v*'"
            echo "View old version: git show MyEA-v1.0:code/experts/MyEA.mq5"
            exit 0
            ;;
        *)
            if [ -z "$EA_NAME" ]; then
                EA_NAME="$1"
            fi
            ;;
    esac
    shift
done

if [ -z "$EA_NAME" ]; then
    echo "ERROR: EA_NAME required"
    echo "Usage: ./scripts/version.sh <EA_NAME> [--message \"changelog\"] [--major]"
    exit 1
fi

# --- Detect current version from git tags ---
# Tags follow pattern: {EA_NAME}-v{MAJOR}.{MINOR}
LATEST_TAG=$(git -C "$PROJECT_ROOT" tag -l "${EA_NAME}-v*" --sort=-version:refname 2>/dev/null | head -1)

if [ -z "$LATEST_TAG" ]; then
    # No existing tags - start at v1.0
    MAJOR=1
    MINOR=0
    echo "No existing version tags for ${EA_NAME}"
else
    # Parse version from tag
    VERSION_STR=$(echo "$LATEST_TAG" | sed "s/${EA_NAME}-v//")
    MAJOR=$(echo "$VERSION_STR" | cut -d. -f1)
    MINOR=$(echo "$VERSION_STR" | cut -d. -f2)

    # Increment
    if [ "$MAJOR_BUMP" = true ]; then
        MAJOR=$((MAJOR + 1))
        MINOR=0
    else
        MINOR=$((MINOR + 1))
    fi
    echo "Current version: $LATEST_TAG"
fi

NEW_VERSION="v${MAJOR}.${MINOR}"
NEW_TAG="${EA_NAME}-${NEW_VERSION}"
echo "New version:     ${NEW_TAG}"
echo ""

# --- Verify EA source exists ---
MQ5_SRC="$PROJECT_ROOT/code/experts/${EA_NAME}.mq5"
if [ ! -f "$MQ5_SRC" ]; then
    echo "ERROR: ${MQ5_SRC} not found"
    exit 1
fi

# --- Save versioned .ini config (if last_backtest.ini exists) ---
CONFIG_DIR="$PLUGIN_DIR/config"
LAST_INI="$CONFIG_DIR/last_backtest.ini"
if [ -f "$LAST_INI" ]; then
    VERSIONED_INI="$CONFIG_DIR/backtest_${EA_NAME}_${NEW_VERSION}.ini"
    cp "$LAST_INI" "$VERSIONED_INI"
    echo "Saved versioned config: $(basename "$VERSIONED_INI")"
else
    VERSIONED_INI=""
    echo "No last_backtest.ini found (skipping versioned config copy)"
fi

# --- Build commit message ---
if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="${EA_NAME} ${NEW_VERSION}"
fi

# --- Git: stage, commit, tag ---
cd "$PROJECT_ROOT"

# Stage EA source
git add "code/experts/${EA_NAME}.mq5"

# Stage any includes used by this EA
if [ -d "code/include" ]; then
    git add "code/include/" 2>/dev/null || true
fi

# Stage versioned config if created
if [ -n "$VERSIONED_INI" ]; then
    git add ".skill-trader/backtest/config/backtest_${EA_NAME}_${NEW_VERSION}.ini"
fi

# Check if there's anything to commit
if git diff --cached --quiet 2>/dev/null; then
    echo ""
    echo "No staged changes to commit. Creating tag only."
    git tag -a "$NEW_TAG" -m "$COMMIT_MSG"
else
    git commit -m "${COMMIT_MSG}"
    git tag -a "$NEW_TAG" -m "$COMMIT_MSG"
fi

echo ""
echo "=== Version Created ==="
echo "  Tag:     $NEW_TAG"
echo "  Commit:  $(git log -1 --format='%h %s')"
if [ -n "$VERSIONED_INI" ]; then
    echo "  Config:  $(basename "$VERSIONED_INI")"
fi
echo ""
echo "History:  git tag -l '${EA_NAME}-v*'"
echo "View old: git show ${NEW_TAG}:code/experts/${EA_NAME}.mq5"
