# skill-trader

Claude Code plugin for automated MetaTrader 5 Expert Advisor build & backtest on macOS.

**Compile** (.mq5 -> .ex5) -> **Backtest** (real tick data) -> **Monitor** -> **Collect** (CSV with trade-by-trade analysis)

## Installation

### Method 1: Plugin Marketplace (Recommended)

```
/plugin marketplace add anhnguyen123312/skill-trader
/plugin install skill-trader@skill-trader
```

### Method 2: One-Liner (Skill Only)

```bash
# Install to current project
curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/install.sh | bash

# Install globally (all projects)
curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/install.sh | bash -s -- --global

# Install full pipeline (skill + scripts + config + example EA)
curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/install.sh | bash -s -- --full
```

### Method 3: Manual

```bash
# Skill only
mkdir -p .claude/skills/mt5-backtest
curl -fsSL https://raw.githubusercontent.com/anhnguyen123312/skill-trader/main/skills/mt5-backtest/SKILL.md \
  -o .claude/skills/mt5-backtest/SKILL.md

# Or clone everything
git clone https://github.com/anhnguyen123312/skill-trader.git
```

## Prerequisites

| Requirement | Install | Notes |
|-------------|---------|-------|
| MetaTrader 5 | `brew install --cask metatrader5` or [download](https://www.metatrader5.com/en/download) | Includes Wine, MetaEditor, Terminal |
| macOS | Required | Wine bundled with MT5 app |
| iconv | Built-in | For UTF-16LE log parsing |

All dependencies (Wine64, MetaEditor64, Terminal64) come bundled with the MT5 app. No separate installation needed.

## Quick Start

```bash
# 1. Place your EA source
cp MyEA.mq5 code/experts/

# 2. Run full pipeline (headless)
./scripts/run.sh MyEA XAUUSD M15 2024.01.01 2024.12.31 --no-visual

# 3. Results appear in results/
```

## Skills

| Skill | Trigger | Description |
|-------|---------|-------------|
| `mt5-backtest` | "backtest EA", "compile EA", "test EA" | Full build & backtest pipeline |

## Repository Structure

```
skill-trader/
  .claude-plugin/
    plugin.json              # Plugin manifest
    marketplace.json         # Marketplace config
  skills/
    mt5-backtest/
      SKILL.md               # Skill documentation (331 lines)
  scripts/
    run.sh                   # E2E orchestrator
    compile.sh               # MQ5 -> EX5 via Wine MetaEditor
    backtest.sh              # Launch MT5 backtest
    monitor.sh               # Poll for completion
    collect.sh               # Parse CSV results
  config/
    backtest.template.ini    # Config with __PLACEHOLDERS__
  code/
    experts/
      SimpleMA_EA.mq5        # Example EA with OnTester() export
  install.sh                 # One-liner installer
```

## Usage

```bash
# E2E pipeline
./scripts/run.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM] [TO] [--no-visual]

# Examples
./scripts/run.sh SimpleMA_EA XAUUSD M15 2024.01.01 2024.12.31 --no-visual
./scripts/run.sh MyEA EURUSD H1 2023.01.01 2024.12.31 --no-visual

# Individual steps
./scripts/compile.sh SimpleMA_EA
./scripts/backtest.sh SimpleMA_EA XAUUSD M15 2024.01.01 2024.12.31 --no-visual
./scripts/monitor.sh 30
./scripts/collect.sh SimpleMA_EA XAUUSD M15
```

## Config

Edit `config/backtest.template.ini` to change broker, deposit, leverage, etc.
Uses `__PLACEHOLDER__` pattern - extend without hardcoding.

| Parameter | Default | Description |
|-----------|---------|-------------|
| Deposit | 1000 | Starting capital (USD) |
| Leverage | 1:1000 | Broker leverage |
| Model | 4 | 0=Every tick, 1=1min OHLC, 2=Open prices, 4=Real ticks |
| Delay | 100 | Slippage emulation (ms) |

See `skills/mt5-backtest/SKILL.md` for full documentation, troubleshooting, and known issues.

## License

MIT
