# EA-OAT-v3: MT5 Build & Backtest Pipeline

Claude Code skill for automated MetaTrader 5 Expert Advisor compilation and backtesting on macOS.

## What It Does

End-to-end pipeline: **Compile** (.mq5 -> .ex5) -> **Backtest** (real tick data) -> **Monitor** -> **Collect** (CSV with trade-by-trade analysis).

## Install as Claude Code Skill

```bash
# Clone into your project's .claude/skills/
mkdir -p .claude/skills
curl -sL https://raw.githubusercontent.com/anhnguyen123312/EA-OAT-v3/main/.claude/skills/mt5-backtest.md \
  -o .claude/skills/mt5-backtest.md

# Or clone full pipeline (scripts + config + skill)
git clone https://github.com/anhnguyen123312/EA-OAT-v3.git
```

## Prerequisites

- **MetaTrader 5** macOS app (`brew install --cask metatrader5` or [download](https://www.metatrader5.com/en/download))
- Wine64, MetaEditor64, Terminal64 (all bundled with MT5 app)
- macOS built-in `iconv` (for UTF-16LE log parsing)

## Quick Start

```bash
# 1. Place your EA source in code/experts/
cp MyEA.mq5 code/experts/

# 2. Run full pipeline
./scripts/run.sh MyEA XAUUSD M15 2024.01.01 2024.12.31 --no-visual

# 3. Check results
cat results/$(date +%Y-%m-%d)_MyEA_XAUUSD_M15.csv
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/run.sh` | E2E orchestrator (compile -> backtest -> monitor -> collect) |
| `scripts/compile.sh` | Compile .mq5 -> .ex5 via Wine MetaEditor |
| `scripts/backtest.sh` | Launch MT5 backtest with config |
| `scripts/monitor.sh` | Poll for backtest completion |
| `scripts/collect.sh` | Parse results CSV + trade log |

## Config

Edit `config/backtest.template.ini` to change broker, deposit, leverage, etc.
Uses `__PLACEHOLDER__` pattern - no hardcoded values.

See `.claude/skills/mt5-backtest.md` for full documentation.

## License

MIT
