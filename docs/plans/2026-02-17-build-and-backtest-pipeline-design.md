# EA-OAT-v3: Build & Backtest Pipeline Design

## Goal
Single-command E2E pipeline: compile EA via Wine -> backtest via MT5 GUI -> collect & parse results. Pure shell, no Python.

## Environment
- macOS with MT5 app (Wine wrapper: `net.metaquotes.wine.MetaTrader5`)
- Wine64: `/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64`
- MT5 base: `~/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/`
- MT5 native app = Wine wrapper = same data directory
- Account: 128364028 / Exness-MT5Real7

## Pipeline Steps

```
run.sh (orchestrator)
  |
  +-> [1] compile.sh     - Copy .mq5 + compile via metaeditor64.exe
  +-> [2] backtest.sh    - Generate .ini + launch MT5 with config
  +-> [3] monitor.sh     - Poll for completion (CSV or process exit)
  +-> [4] collect.sh     - Collect CSV + logs, parse & display results
```

## Components

### 1. `scripts/compile.sh <EA_NAME>`
- Copy `code/experts/<EA>.mq5` -> MT5 `MQL5/Experts/`
- Copy `code/include/*` -> MT5 `MQL5/Include/` (if exists)
- Run: `wine64 metaeditor64.exe /compile:"MQL5\Experts\<EA>.mq5" /log`
- Parse compile log for errors/warnings
- Verify `.ex5` binary created

### 2. `scripts/backtest.sh <EA_NAME> [SYMBOL] [PERIOD]`
- Generate `.ini` from `config/backtest.template.ini`
- Fill in: Expert, Symbol, Period, Login, Server, dates
- Copy `.ini` to MT5 config dir
- Launch: `open -a "MetaTrader 5"` (native GUI)
  - Fallback: `wine64 terminal64.exe /config:<ini_path> /portable`
- ShutdownTerminal=1 for auto-close after backtest

### 3. `scripts/monitor.sh [TIMEOUT_MINUTES]`
- Poll every 30s for:
  - CSV file creation in Common/Files
  - MT5 process exit (pgrep)
- Timeout default: 30 minutes
- Show progress dots

### 4. `scripts/collect.sh <EA_NAME> <SYMBOL> <PERIOD>`
- Find CSV in Common/Files
- Convert UTF-16LE -> UTF-8 via iconv
- Copy to `results/<date>_<EA>_<SYMBOL>_<PERIOD>.csv`
- Copy tester logs to `results/logs/`
- Parse CSV with awk:
  - Summary: win rate, total trades, net profit, max DD, profit factor, R:R
  - Trade-by-trade log with entry/SL/TP/reason/result

### 5. `scripts/run.sh <EA_NAME> [SYMBOL] [PERIOD]`
- Sequential orchestrator calling 1-4
- Exit on any step failure
- Final summary display

### 6. `code/experts/SimpleMA_EA.mq5`
- Copied from v2 with enhanced Print() logging
- OnTester() exports CSV with metrics + trade details

### 7. `config/backtest.template.ini`
- Template with placeholders for EA name, symbol, period
- Pre-filled: Login=128364028, Server=Exness-MT5Real7
- Deposit=1000, Leverage=1:100

## Output Format

### Summary
```
=== BACKTEST RESULTS: SimpleMA_EA | XAUUSD | H1 ===
Period:        2024.01.01 - 2025.12.31
Total Trades:  156
Win Rate:      62.5%
Net Profit:    $1,234.56
Max Drawdown:  8.3%
Profit Factor: 1.85
Risk:Reward:   1:2.0
```

### Trade Log
```
#1  | BUY  | 2024-01-15 09:30 | Entry: 2045.50 | SL: 2042.50 | TP: 2051.50
    | Reason: MA5 crossed above MA20 (bullish)
    | Result: TP HIT | +$6.00

#2  | SELL | 2024-01-15 14:00 | Entry: 2055.20 | SL: 2058.20 | TP: 2049.20
    | Reason: MA5 crossed below MA20 (bearish)
    | Result: SL HIT | -$3.00
```

## Directory Structure
```
EA-OAT-v3/
  code/experts/          # EA source (.mq5)
  config/                # .ini templates
  scripts/               # Shell scripts
  results/               # Backtest outputs
  results/logs/          # MT5 tester logs
  docs/plans/            # Design docs
```

## Decisions
- Pure shell (no Python) - keep it simple
- MT5 native app for backtest (GUI mode, more stable on macOS)
- Wine metaeditor64 for compile (headless, reliable)
- Same data directory for both (no .ex5 copy needed)
- SimpleMA_EA from v2 as test EA
