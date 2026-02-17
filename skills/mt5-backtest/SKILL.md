---
name: mt5-backtest
description: Use when building, backtesting, or analyzing MT5 Expert Advisors on macOS. Compiles MQ5 source via Wine MetaEditor, runs backtest with real tick data, collects CSV results with trade-by-trade analysis.
---

# MT5 Build & Backtest Pipeline

## When to Use

- User says "backtest EA", "run backtest", "compile EA", "test EA"
- User wants to build and test an MQL5 Expert Advisor
- User asks to analyze backtest results or trade logs
- User wants to run E2E pipeline: compile -> backtest -> monitor -> collect

## Prerequisites

Run this check before any operation. If anything fails, guide user to install.

```bash
# 1. MetaTrader 5 app (includes Wine + MetaEditor + Terminal)
test -d "/Applications/MetaTrader 5.app" || echo "MISSING: Install MetaTrader 5 from https://www.metatrader5.com/en/download"

# 2. Wine64 (bundled with MT5 app - NOT separately installed)
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
test -f "$WINE" || echo "MISSING: Wine64 not found in MT5 bundle"

# 3. MT5 data directory (created on first MT5 launch)
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
test -d "$WINEPREFIX" || echo "MISSING: Launch MetaTrader 5 app once to create data directory"

# 4. MetaEditor + Terminal executables
MT5_BASE="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
test -f "$MT5_BASE/metaeditor64.exe" || echo "MISSING: metaeditor64.exe"
test -f "$MT5_BASE/terminal64.exe" || echo "MISSING: terminal64.exe"

# 5. iconv (macOS built-in, required for UTF-16LE log parsing)
which iconv > /dev/null || echo "MISSING: iconv (should be built-in on macOS)"

# 6. Broker login cached (MT5 must have logged in at least once)
test -f "$MT5_BASE/config/accounts.dat" || echo "WARNING: No cached broker credentials. Open MT5 GUI and login manually first."
```

If MT5 app is missing: `brew install --cask metatrader5` or download from metatrader5.com.
All other dependencies (Wine, MetaEditor, Terminal) come bundled with the MT5 app.

## Key Paths

```
WINEPREFIX  = ~/Library/Application Support/net.metaquotes.wine.metatrader5
MT5_BASE    = $WINEPREFIX/drive_c/Program Files/MetaTrader 5
WINE        = /Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64
EXPERTS_DIR = $MT5_BASE/MQL5/Experts
INCLUDE_DIR = $MT5_BASE/MQL5/Include
CSV_OUTPUT  = $WINEPREFIX/drive_c/users/crossover/AppData/Roaming/MetaQuotes/Terminal/Common/Files
```

CRITICAL: The native macOS MT5 app IS a Wine wrapper (bundle ID: `net.metaquotes.wine.MetaTrader5`). Native app and Wine share the SAME data directory.

## Project Structure

```
EA-OAT-v3/
  code/experts/           # EA source files (.mq5)
  code/include/           # Shared MQL5 includes (optional)
  config/
    backtest.template.ini # Config template with __PLACEHOLDERS__
    last_backtest.ini     # Last generated config (debug)
  scripts/
    compile.sh            # Step 1: Compile .mq5 -> .ex5
    backtest.sh           # Step 2: Launch MT5 backtest
    monitor.sh            # Step 3: Wait for completion
    collect.sh            # Step 4: Parse results
    run.sh                # E2E orchestrator (all 4 steps)
  results/                # CSV outputs
  results/logs/           # MT5 tester logs
```

## How to Run

### E2E (Single Command)

```bash
./scripts/run.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM] [TO] [--no-visual]
```

### Examples

```bash
# Default: XAUUSD M15 2024, headless (recommended for automation)
./scripts/run.sh SimpleMA_EA XAUUSD M15 2024.01.01 2024.12.31 --no-visual

# Different timeframe
./scripts/run.sh SimpleMA_EA XAUUSD H1 2023.01.01 2024.12.31 --no-visual

# Different symbol
./scripts/run.sh MyEA EURUSD M5 2024.06.01 2024.12.31 --no-visual

# Visual mode (may require manual Start click)
./scripts/run.sh SimpleMA_EA
```

### Individual Steps

```bash
./scripts/compile.sh SimpleMA_EA
./scripts/backtest.sh SimpleMA_EA XAUUSD M15 2024.01.01 2024.12.31 --no-visual
./scripts/monitor.sh 30
./scripts/collect.sh SimpleMA_EA XAUUSD M15
```

### Period Mapping

| Name | MT5 Value |
|------|-----------|
| M1   | 1         |
| M5   | 5         |
| M15  | 15        |
| M30  | 30        |
| H1   | 16385     |
| H4   | 16388     |
| D1   | 16408     |

## Config Template

File: `config/backtest.template.ini`

```ini
[Tester]
Expert=__EA_NAME__
Symbol=__SYMBOL__
Period=__PERIOD__
Model=4
FromDate=__FROM_DATE__
ToDate=__TO_DATE__
Deposit=1000
Currency=USD
Leverage=1:1000
ExecutionMode=0
Optimization=0
OptimizationCriterion=1
Visual=__VISUAL__
ShutdownTerminal=1
Login=128364028
Server=Exness-MT5Real7
Report=__EA_NAME___Report
ReplaceReport=1
Delay=100
```

### Placeholders (replaced by `backtest.sh` via sed)

| Placeholder | Replaced By | Default |
|-------------|-------------|---------|
| `__EA_NAME__` | EA name (no .mq5) | required |
| `__SYMBOL__` | Trading symbol | XAUUSD |
| `__PERIOD__` | MT5 period value | 15 (M15) |
| `__FROM_DATE__` | Start YYYY.MM.DD | 2024.01.01 |
| `__TO_DATE__` | End YYYY.MM.DD | 2024.12.31 |
| `__VISUAL__` | 0=headless, 1=GUI | 1 |

### Extending Config

To add new parameters without hardcoding:

1. Add `__NEW_PARAM__` placeholder to `config/backtest.template.ini`
2. Add `sed -e "s/__NEW_PARAM__/$VALUE/"` in `scripts/backtest.sh`
3. Add CLI argument parsing in `backtest.sh`

Parameterizable fields:

| Field | Default | Description |
|-------|---------|-------------|
| Deposit | 1000 | Starting capital USD |
| Leverage | 1:1000 | Broker leverage |
| Model | 4 | 0=Every tick, 1=1min OHLC, 2=Open prices, 4=Real ticks |
| Delay | 100 | Slippage emulation (ms) |
| Login/Server | Exness | Broker credentials |

## Pipeline Steps (What Each Script Does)

### Step 1: `compile.sh` - Compile EA

1. Validate `.mq5` source in `code/experts/`
2. Copy source + includes to MT5 directories
3. Run MetaEditor via Wine:
   ```bash
   WINEPREFIX="$WINEPREFIX" "$WINE" metaeditor64.exe /compile:"MQL5\\Experts\\<EA>.mq5" /log 2>/dev/null || true
   ```
4. Parse compile log (UTF-16LE -> UTF-8 via `iconv`)
5. Verify `.ex5` binary exists

### Step 2: `backtest.sh` - Launch Backtest

1. Verify `.ex5` exists
2. Generate `.ini` from template (sed placeholder replacement)
3. Convert to Windows CRLF line endings: `sed 's/$/\r/'`
4. Write config to `C:\autobacktest.ini` (Wine C: root - NO spaces!)
5. Clean old CSV results
6. Kill existing MT5: `pkill -f "terminal64"`
7. Launch via Wine:
   ```bash
   WINEPREFIX="$WINEPREFIX" "$WINE" terminal64.exe /config:C:\\autobacktest.ini /portable 2>/dev/null &
   ```

### Step 3: `monitor.sh` - Wait for Completion

1. Poll every 5 seconds for CSV or MT5 exit
2. CSV found (modification time > start time) -> success
3. MT5 exited without CSV -> 3s grace period, then fail
4. Configurable timeout (default: 30 minutes)

### Step 4: `collect.sh` - Parse Results

1. Find CSV in Common/Files (checks both `crossover` and `$(whoami)` user dirs)
2. Convert UTF-16LE -> UTF-8
3. Save to `results/<date>_<EA>_<SYMBOL>_<PERIOD>.csv`
4. Copy tester logs to `results/logs/`
5. Display summary: Win Rate, Trades, Profit, Drawdown, Profit Factor, Sharpe
6. Display trade-by-trade log: ticket, type, time, price, P/L, reason

## EA Requirements

The EA MUST implement `OnTester()` with CSV export to Common/Files:

```mql5
double OnTester()
{
    string filename = "backtest_results.csv";
    int fileHandle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON, '\t');
    if(fileHandle != INVALID_HANDLE)
    {
        FileWrite(fileHandle, "Metric", "Value");
        FileWrite(fileHandle, "Win Rate %", DoubleToString(winRate, 2));
        FileWrite(fileHandle, "Total Trades", IntegerToString(totalTrades));
        FileWrite(fileHandle, "Net Profit", DoubleToString(netProfit, 2));
        FileWrite(fileHandle, "Max DD %", DoubleToString(maxDD, 2));
        FileWrite(fileHandle, "Profit Factor", DoubleToString(pf, 2));
        FileWrite(fileHandle, "Risk Reward", DoubleToString(rr, 2));
        FileWrite(fileHandle, "Sharpe Ratio", DoubleToString(sharpe, 2));
        FileWrite(fileHandle, "");
        FileWrite(fileHandle, "Trade Details");
        FileWrite(fileHandle, "Ticket", "Type", "Open Time", "Close Time", "Open Price", "Close Price", "Profit", "Comment");
        // ... loop through trades
        FileClose(fileHandle);
    }
    return profitFactor;
}
```

Key: `FILE_COMMON` flag writes to Common/Files directory (shared across terminals).

## Debugging

### Log Locations

| Log | Path | Contains |
|-----|------|----------|
| Terminal | `$MT5_BASE/logs/YYYYMMDD.log` | Startup, config, network |
| Tester | `$MT5_BASE/Tester/logs/YYYYMMDD.log` | Tester orchestration |
| Agent | `$MT5_BASE/Tester/Agent-127.0.0.1-3000/logs/YYYYMMDD.log` | EA output, trades |

All logs are UTF-16LE. Read with:
```bash
iconv -f UTF-16LE -t UTF-8 "$LOG_PATH" | tr -d '\r'
```

### Success Markers in Logs

```
launched with C:\autobacktest.ini              # Config loaded
successfully initialized from start config     # Settings applied
automatical testing started                    # Backtest running
last test passed with result "successfully finished"  # Complete
exit with code 0                               # Clean shutdown
```

## Known Issues & Fixes

### 1. Wine stderr causes script failure
**Symptom:** Script exits on `set -e` from Wine debug output (`fixme:hid:...`).
**Fix:** `2>/dev/null` on all Wine commands + `|| true` (exit codes unreliable). Check output files instead.

### 2. Compile log garbled text
**Symptom:** `cat`/`grep` can't parse compile log.
**Cause:** UTF-16LE encoding.
**Fix:** `iconv -f UTF-16LE -t UTF-8 "$LOG_FILE" 2>/dev/null | tr -d '\r'`

### 3. Config path with spaces breaks auto-start (CRITICAL)
**Symptom:** `cannot load config "C:\Program Files\...\autobacktest.ini"" at start` (trailing double-quote).
**Cause:** Wine mangles paths with spaces. No shell quoting fixes this.
**Fix:** Place config at `C:\autobacktest.ini` (Wine C: root = `$WINEPREFIX/drive_c/`).

### 4. macOS `open -a` doesn't pass arguments
**Symptom:** MT5 opens but ignores `/config:` argument.
**Cause:** `open --args` doesn't reliably pass args to Wine wrapper apps.
**Fix:** Launch via Wine directly: `"$WINE" terminal64.exe /config:C:\\autobacktest.ini /portable`

### 5. Login without [Common] section
**Note:** Login/Server in `[Tester]` section IS sufficient. Password NOT needed (MT5 uses cached `accounts.dat`). If login fails, open MT5 GUI and login manually to refresh cache.

### 6. Monitor misses fast backtests
**Symptom:** Backtest finishes in 8-10s, monitor polls at 30s, reports failure.
**Fix:** Poll every 5 seconds + 3s grace period after MT5 exit.

### 7. CSV location varies by Wine user
**Symptom:** CSV not found at expected path.
**Fix:** Check both `crossover` and `$(whoami)` user directories.

### 8. Visual=1 may not auto-start
**Observation:** `Visual=0` auto-starts reliably. `Visual=1` may require manual Start click.
**Recommendation:** Always use `--no-visual` for automated/CI runs.

## Troubleshooting Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| `cannot load config "..."" at start` | Spaces in config path | Config must be at `C:\autobacktest.ini` |
| No auto-start | Config not loaded or Visual=1 | Check logs, use `--no-visual` |
| No CSV after test | EA missing `OnTester()` | Add `OnTester()` with `FILE_COMMON` |
| Login failed | Cached credentials expired | Open MT5 GUI, login manually |
| Wine warnings in output | Old Wine version | Cosmetic, ignore |
| Garbled log output | UTF-16LE encoding | Use `iconv -f UTF-16LE -t UTF-8` |
| Monitor timeout | Slow backtest or MT5 hung | Increase timeout: `./scripts/monitor.sh 60` |

## Broker Account

```
Login:    128364028
Password: Ready@123
Server:   Exness-MT5Real7
```
