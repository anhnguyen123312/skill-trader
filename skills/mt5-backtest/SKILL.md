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

## EA Discovery (for Agent)

NEVER hardcode EA names. Always discover dynamically:
1. Scan `code/experts/*.mq5` for available EA sources
2. Use the filename (without .mq5) as EA_NAME
3. When user says "build new EA" or "create bot":
   - Create .mq5 in code/experts/ with descriptive name
   - Use that name for compile/backtest/version commands
4. When user says "backtest" without specifying which EA:
   - List available EAs from `code/experts/*.mq5`
   - Ask user to pick, or use the most recently modified

## Versioning Workflow

After any EA code change, ALWAYS version and tag:

1. Edit/create EA source in `code/experts/<EA_NAME>.mq5`
2. Run pipeline with versioning: `./scripts/run.sh <EA_NAME> ... --no-visual --version`
3. Or manually: `./scripts/version.sh <EA_NAME> --message "description"`

This auto-generates:
- Versioned .ini config saved in `config/`
- Git commit with all changes
- Git tag: `<EA_NAME>-v<MAJOR>.<MINOR>`

Agent MUST call `version.sh` after every code change to ensure traceability.

Version commands:
```bash
# Auto-version (minor bump)
./scripts/version.sh <EA_NAME> --message "Added trailing stop"

# Major version bump
./scripts/version.sh <EA_NAME> --major --message "Complete strategy rewrite"

# View version history
git tag -l '<EA_NAME>-v*'

# View old version source
git show <EA_NAME>-v1.0:code/experts/<EA_NAME>.mq5
```

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
test -f "$MT5_BASE/config/accounts.dat" || echo "WARNING: No cached broker credentials. Run ./.skill-trader/backtest/scripts/login.sh"
```

If MT5 app is missing: `brew install --cask metatrader5` or download from metatrader5.com.
All other dependencies (Wine, MetaEditor, Terminal) come bundled with the MT5 app.

## Broker Login

MT5 requires cached credentials for backtesting. The login script handles everything automatically.

### Interactive Login (Recommended)

```bash
./.skill-trader/backtest/scripts/login.sh
# Login [128364028]:          <- Enter = use default
# Server [Exness-MT5Real7]:   <- Enter = use default
# Password:                   <- hidden input, required
```

The login script:
1. Prompts for Login, Server, Password (step by step, with defaults)
2. Auto-restores `servers.dat` from backup if missing
3. Launches MT5 with `[Common]` + `[Tester]` config (mini-backtest for graceful shutdown)
4. Monitors MT5 log for authorization success/failure
5. Waits for MT5 graceful exit (via `ShutdownTerminal=1`)
6. Saves password to `.skill-trader/backtest/config/credentials.env` (chmod 600, gitignored)
7. Auto-backs up credentials on success

### Login Management Commands

```bash
./.skill-trader/backtest/scripts/login.sh                          # Interactive login (prompts step by step)
./.skill-trader/backtest/scripts/login.sh <LOGIN> <PASS> <SERVER>  # Direct login with all args
./.skill-trader/backtest/scripts/login.sh --status                 # Check credential status
./.skill-trader/backtest/scripts/login.sh --backup                 # Backup credential files
./.skill-trader/backtest/scripts/login.sh --restore                # Restore from backup
```

### How MT5 Authentication Works (Wine macOS)

```
login.sh                          backtest.sh
   |                                  |
   v                                  v
[Common]                          [Common]
  Login=128364028                   Login=128364028
  Password=Ready@123                Password=Ready@123    <- from credentials.env
  Server=Exness-MT5Real7            Server=Exness-MT5Real7
[Tester]                          [Tester]
  ShutdownTerminal=1                Expert=<EA_NAME>
  (mini 1-day backtest)             ShutdownTerminal=1
   |                                  |
   v                                  v
MT5 authenticates              MT5 authenticates
   |                           (no login popup!)
   v                                  |
accounts.dat created                  v
credentials.env saved           Backtest runs automatically
```

### Credential Files

| File | Location | Size | Purpose |
|------|----------|------|---------|
| `accounts.dat` | MT5 config/ | ~8KB | **REQUIRED** - Encrypted cached login |
| `servers.dat` | MT5 config/ | ~900KB | Broker server configs (full version from backup) |
| `common.ini` | MT5 config/ | ~1.7KB (full) or ~242B (login-generated) | Last login info, Environment field |
| `credentials.env` | .skill-trader/backtest/config/ | ~100B | Login/Password/Server for backtest.sh |

### Credential Priority (highest first)

1. Environment variables: `MT5_LOGIN`, `MT5_PASSWORD`, `MT5_SERVER`
2. `.skill-trader/backtest/config/credentials.env` (auto-generated by `login.sh`)
3. Cached `common.ini` (for login/server defaults only)
4. Hardcoded defaults: `128364028` / `Exness-MT5Real7`

IMPORTANT: `.skill-trader/backtest/config/credentials.env` and `.skill-trader/backtest/config/mt5-credentials/` are in `.gitignore`. Never commit passwords.

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
  code/experts/                          # EA source files (.mq5)
  code/include/                          # Shared MQL5 includes (optional)
  .skill-trader/
    backtest/
      config/
        backtest.template.ini            # [Tester] config with __PLACEHOLDERS__
        credentials.env                  # Auto-generated by login.sh (gitignored)
        mt5-credentials/                 # Backup: accounts.dat, servers.dat, common.ini (gitignored)
        last_backtest.ini                # Last generated config (debug)
      scripts/
        login.sh                         # Login & credential manager (interactive)
        compile.sh                       # Step 1: Compile .mq5 -> .ex5
        backtest.sh                      # Step 2: Launch MT5 backtest (interactive or CLI)
        monitor.sh                       # Step 3: Wait for completion
        collect.sh                       # Step 4: Parse results
        run.sh                           # E2E orchestrator (all steps)
        version.sh                       # Auto-version: git commit + tag
      results/                           # CSV outputs
      results/logs/                      # MT5 tester logs
```

## How to Run

### Interactive Mode (Recommended)

```bash
# Login first (only needed once, or after credentials expire)
./.skill-trader/backtest/scripts/login.sh

# Run backtest - prompts for all params
./.skill-trader/backtest/scripts/backtest.sh
# Available EAs:
#   1. AdvancedEA
#   2. SimpleMA_EA
# EA [1]:
# Symbol [XAUUSD]:
# Period [M15]:
# From [2024.01.01]:
# To [2024.12.31]:
# Visual? (y/n) [n]:
```

### CLI Mode

```bash
# E2E (Single Command) - replace <EA_NAME> with actual EA from code/experts/
./.skill-trader/backtest/scripts/run.sh <EA_NAME> [SYMBOL] [PERIOD] [FROM] [TO] [--no-visual] [--version] [--message "msg"] [--major]

# Examples (auto-detect EA name from code/experts/*.mq5)
./.skill-trader/backtest/scripts/run.sh MyEA XAUUSD M15 2024.01.01 2024.12.31 --no-visual
./.skill-trader/backtest/scripts/run.sh MyEA XAUUSD H1 2023.01.01 2024.12.31 --no-visual --version
./.skill-trader/backtest/scripts/run.sh MyEA EURUSD M5 2024.06.01 2024.12.31 --no-visual --version --message "Tuned SL/TP"

# Individual Steps
./.skill-trader/backtest/scripts/compile.sh <EA_NAME>
./.skill-trader/backtest/scripts/backtest.sh <EA_NAME> XAUUSD M15 2024.01.01 2024.12.31 --no-visual
./.skill-trader/backtest/scripts/monitor.sh 30
./.skill-trader/backtest/scripts/collect.sh <EA_NAME> XAUUSD M15

# Versioning (standalone)
./.skill-trader/backtest/scripts/version.sh <EA_NAME> --message "description"
./.skill-trader/backtest/scripts/version.sh <EA_NAME> --major --message "major rewrite"
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

File: `.skill-trader/backtest/config/backtest.template.ini`

The template contains ONLY the `[Tester]` section. `[Common]` (with Login/Password/Server) is generated dynamically by `backtest.sh` to avoid the empty Password= corruption bug.

```ini
[Tester]
Expert=__EA_NAME__
Symbol=__SYMBOL__
Period=__PERIOD__
Model=4
FromDate=__FROM_DATE__
ToDate=__TO_DATE__
Deposit=__DEPOSIT__
Currency=USD
Leverage=__LEVERAGE__
ExecutionMode=0
Optimization=0
OptimizationCriterion=1
Visual=__VISUAL__
ShutdownTerminal=1
Login=__LOGIN__
Server=__SERVER__
Report=__EA_NAME___Report
ReplaceReport=1
Delay=__DELAY__
```

### How backtest.sh generates the final config

```
[Common]                          <- Always generated by backtest.sh
Login=128364028                   <- Always included
Password=Ready@123                <- Only if credentials.env has MT5_PASSWORD
Server=Exness-MT5Real7            <- Always included
KeepPrivate=0
NewsEnable=0
[Tester]                          <- From template with sed replacements
Expert=<EA_NAME>
Symbol=XAUUSD
...
[TesterInputs]                    <- Auto-extracted from .mq5 source
LotSize=0.01                      <- Parsed from: input double LotSize = 0.01;
StopLoss=30                       <- Ensures backtest uses EA's defaults
...
```

### Placeholders (replaced by `backtest.sh` via sed)

| Placeholder | Replaced By | Default |
|-------------|-------------|---------|
| `__EA_NAME__` | EA name (no .mq5) | required |
| `__SYMBOL__` | Trading symbol | XAUUSD |
| `__PERIOD__` | MT5 period value | 15 (M15) |
| `__FROM_DATE__` | Start YYYY.MM.DD | 2024.01.01 |
| `__TO_DATE__` | End YYYY.MM.DD | 2024.12.31 |
| `__VISUAL__` | 0=headless, 1=GUI | 0 |
| `__LOGIN__` | Broker account number | 128364028 |
| `__SERVER__` | Broker server | Exness-MT5Real7 |
| `__DEPOSIT__` | Starting capital USD | 1000 |
| `__LEVERAGE__` | Broker leverage | 1:1000 |
| `__DELAY__` | Slippage ms | 100 |

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

1. Load credentials from `credentials.env` / ENV vars / defaults
2. In interactive mode: prompt for EA, Symbol, Period, Date, Visual
3. Verify `.ex5` exists
4. Generate `[Common]` section dynamically (Login + Server always, Password only if provided)
5. Append `[Tester]` from template (sed placeholder replacement)
6. Auto-extract `[TesterInputs]` from EA's `.mq5` source (parses `input` declarations)
7. Convert to Windows CRLF line endings: `sed 's/$/\r/'`
8. Write config to `C:\autobacktest.ini` (Wine C: root - NO spaces!)
9. Clean old CSV results
10. Kill existing MT5: `pkill -f "terminal64"`
11. Launch via Wine:
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
3. Save to `.skill-trader/backtest/results/<date>_<EA>_<SYMBOL>_<PERIOD>.csv`
4. Copy tester logs to `.skill-trader/backtest/results/logs/`
5. Display summary: Win Rate, Trades, Profit, Drawdown, Profit Factor, Sharpe
6. Display trade-by-trade log: ticket, type, time, price, P/L, reason

## Results Directory Structure

Every backtest produces a result folder organized by date, EA, symbol, and period:

```
.skill-trader/backtest/results/
  {DATE}_{EA_NAME}_{SYMBOL}_{PERIOD}/
    {EA_NAME}_report.md              # Parsed Markdown report (from HTML)
    {EA_NAME}_Report.png             # Balance/equity curve chart
    {EA_NAME}_Report-hst.png         # 6 distribution histograms
    {EA_NAME}_Report-holding.png     # Holding time scatter plot
    {EA_NAME}_Report-mfemae.png      # MFE/MAE scatter plots
  {DATE}_{EA_NAME}_{SYMBOL}_{PERIOD}.csv  # OnTester CSV (if EA exports it)
  logs/                              # Tester + Agent logs (UTF-16LE)
```

**Naming convention:** `{DATE}` = `YYYY-MM-DD`, e.g. `2026-02-21_SimpleMA_EA_XAUUSD_M15/`

### Versioned Results Tracking

When using `--version` flag, results are linked to git tags:

```
git tag -l '<EA_NAME>-v*'           # List all versions
git log --oneline <EA_NAME>-v1.2    # See what changed in v1.2
```

To compare results across versions:
1. Each version's backtest config is saved as `config/backtest_{EA_NAME}_v{X.Y}.ini`
2. Results folders are timestamped, so multiple runs are preserved
3. Use git tags to correlate code changes with performance changes

## Report Analysis Guide

### Data Sources (Priority Order)

`collect.sh` tries two data sources:

1. **HTML Report** (primary) - MT5 generates `{EA_NAME}_Report.htm` automatically for ALL EAs. This is parsed by `parse_report.py` into a comprehensive Markdown file. **Works for every EA without any code changes.**

2. **OnTester CSV** (secondary) - Only available if the EA implements `OnTester()` with `FILE_COMMON` CSV export. Provides custom metrics the EA explicitly calculates.

### Markdown Report Sections

The parsed report (`{EA_NAME}_report.md`) contains these sections in order:

| Section | Content | Key Metrics |
|---------|---------|-------------|
| **Settings** | EA name, symbol, period, inputs, deposit, leverage, broker | Test configuration reference |
| **Performance** | Net profit, gross profit/loss, profit factor, Sharpe, recovery factor | Overall strategy quality |
| **Drawdown** | Balance/equity DD (absolute, maximal, relative) | Risk assessment |
| **Trades** | Total trades, win rate, long/short breakdown, consecutive wins/losses | Trade statistics |
| **Correlation & Holding** | MFE/MAE correlation, min/max/avg holding time | Trade efficiency |
| **Deals** | Every deal: ticket, type, direction, volume, price, commission, swap, profit | Full trade log |
| **Orders** | Every order: ticket, time, type, volume, price, SL, TP, state | Order execution log |

### Key Metrics Interpretation

| Metric | Description | Bad | Marginal | Good | Excellent |
|--------|-------------|-----|----------|------|-----------|
| **Profit Factor** | Gross Profit / Gross Loss | < 0.9 | 0.9-1.2 | 1.2-1.5 | > 1.5 |
| **Win Rate** | Winning trades / Total trades | < 40% | 40-50% | 50-60% | > 60% |
| **Sharpe Ratio** | Risk-adjusted return | < 0 | 0-0.5 | 0.5-1.0 | > 1.0 |
| **Max DD %** | Largest peak-to-trough drop | > 50% | 30-50% | 10-30% | < 10% |
| **Recovery Factor** | Net Profit / Max DD | < 1 | 1-2 | 2-5 | > 5 |
| **Expected Payoff** | Average profit per trade | < 0 | 0-1 | 1-5 | > 5 |
| **R/D Ratio** | Annual Return / Max DD | < 1 | 1-2 | 2-3 | > 3 |

### Direction Analysis (LONG vs SHORT)

The report includes `Short Trades (won %)` and `Long Trades (won %)`. Agent MUST analyze:

1. **Which direction is more profitable?** Compare win rates and net P/L
2. **Is the strategy directionally biased?** Large imbalance suggests strategy only works one way
3. **Should one direction be disabled?** If one direction consistently loses, recommend disabling it

### Reading the Deals Table

Each deal row contains:

| Column | Meaning | What to Look For |
|--------|---------|-----------------|
| Time | Deal execution timestamp | Cluster of losses = bad period |
| Type | buy/sell | Direction balance |
| Direction | in/out/inout | Position lifecycle |
| Volume | Lot size | Position sizing consistency |
| Price | Execution price | Slippage check |
| Commission | Broker fee | Cost impact on small trades |
| Swap | Overnight fee | Impact on long-held trades |
| Profit | Trade P/L | Win/loss distribution |
| Comment | SL/TP/manual close | How trades are exiting |

**Deal Comment Analysis:**
- `[sl]` = Stopped out (hit stop loss) - Too many = SL too tight
- `[tp]` = Take profit hit - Good, strategy hitting targets
- Empty = Manual or signal close - Check if timing is good
- `[so]` = Stop out (margin call) - CRITICAL: insufficient margin

## Chart Image Analysis (Agent Instructions)

MT5 HTML reports generate 4 PNG chart images. Agent MUST read these images using the Read tool and analyze them when presenting results to the user.

### Chart 1: Balance Curve (`{EA}_Report.png`)

**What it shows:** Line chart of account balance over the backtest period.
- **X-axis:** Trade number (sequential, left to right)
- **Y-axis:** Account balance in USD
- **Blue line:** Balance after each closed trade

**How to interpret:**
- **Smooth upward slope** = Consistent profitability (ideal)
- **Staircase pattern (up)** = Profitable with distinct winning periods
- **Steep drops** = Large drawdown events - note where they occur
- **Flat sections** = No trading activity or breakeven period
- **Downward slope** = Strategy is losing money
- **V-shaped dips** = Drawdowns followed by recovery (check recovery speed)

**What to report:** "Balance grew from $X to $Y with [smooth/choppy] progression. Notable drawdown at trade #N (-X%). Recovery took N trades."

### Chart 2: Distribution Histograms (`{EA}_Report-hst.png`)

**What it shows:** 6 histograms in a 2x3 grid:

```
Row 1: ENTRY DISTRIBUTION (count of trades opened)
  [By Hour 0-23]  [By Weekday Mon-Fri]  [By Month Jan-Dec]

Row 2: PROFIT DISTRIBUTION (total profit/loss)
  [By Hour 0-23]  [By Weekday Mon-Fri]  [By Month Jan-Dec]
```

**How to interpret:**

| Chart | Green bars | Red bars | Analysis |
|-------|-----------|----------|----------|
| Entries by Hour | Trades opened at that hour | N/A (all same color) | Which hours have most signals |
| Entries by Weekday | Trades on that day | N/A | Which days are most active |
| Entries by Month | Trades in that month | N/A | Seasonal trading activity |
| Profit by Hour | Profitable hours | Losing hours | Best/worst trading hours |
| Profit by Weekday | Profitable days | Losing days | Best/worst trading days |
| Profit by Month | Profitable months | Losing months | Seasonal profitability |

**What to report:**
- "Most trades opened during hours X-Y (London/NY session)"
- "Tuesday and Thursday most active; Friday has fewest trades"
- "March and October most profitable; June and August losing months"
- "Recommend adding time filter: trade only hours X-Y"
- "Consider seasonal filter: skip months X, Y, Z"

### Chart 3: Holding Time Scatter (`{EA}_Report-holding.png`)

**What it shows:** Scatter plot of each trade's profit vs. how long it was held.
- **X-axis:** Holding time (in seconds, from 0 upward)
- **Y-axis:** Profit/loss in USD (positive above zero, negative below)
- **Each dot:** One closed trade

**How to interpret:**
- **Dots clustered at short holding times** = Scalping strategy
- **Dots spread across wide time range** = Mixed holding strategy
- **Profitable dots (above zero) at short holds** = Quick wins, good
- **Losing dots at long holds** = Holding losers too long (bad money management)
- **Clear time cluster where most profits occur** = Optimal holding period identified

**What to report:** "Average holding time ~Xh. Most profits come from trades held X-Y hours. Trades held longer than Z hours tend to lose. Consider adding time-based exit at Z hours."

### Chart 4: MFE/MAE Scatter (`{EA}_Report-mfemae.png`)

**What it shows:** Two overlapping scatter plots measuring trade excursion:
- **Blue dots (MFE):** Profit vs. Maximum Favorable Excursion (how far price moved IN your favor before close)
- **Red dots (MAE):** Profit vs. Maximum Adverse Excursion (how far price moved AGAINST you before close)

**X-axis:** Excursion amount (USD or pips)
**Y-axis:** Final trade profit (USD)

**How to interpret MFE (blue):**
- **Dots along diagonal** = Trades captured most of the favorable move (good TP placement)
- **Dots far below diagonal** = Trades gave back lots of unrealized profit (TP too far or no trailing stop)
- **Large MFE with small/negative profit** = Letting winners turn into losers (CRITICAL issue)

**How to interpret MAE (red):**
- **Dots clustered near zero MAE** = Tight stops, quick exits on losers (good)
- **Large MAE with negative profit** = Holding losers too long, SL too wide
- **Large MAE with positive profit** = Trade went against before recovering (risky but profitable)

**What to report:**
- "MFE analysis: Trades capture X% of maximum favorable move on average. TP placement is [tight/loose]."
- "MAE analysis: Average adverse excursion is $X. SL placement at $Y is [appropriate/too wide/too tight]."
- "Recommendation: [Tighten TP to $X / Add trailing stop / Widen SL to $Y]"

## Testing Hierarchy

### Overview

```
Level 1: Quick Validation    -> Single month    (20-22 trading days)
Level 2: Seasonal Check      -> Single quarter  (3 months)
Level 3: Stability Test      -> Half year       (6 months)
Level 4: Annual Performance  -> Full year       (12 months)
Level 5: Robustness Test     -> Multi-year      (2-3+ years)
Level 6: Capital Sensitivity -> Same period, different deposits
```

Agent SHOULD run Level 1 first for quick validation, then progressively run higher levels.

### Level 1: Monthly Testing (Quick Validation)

**Purpose:** Quick check if EA works in specific market conditions. ~5-10 second backtest.

```bash
# Test a single month
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2024.03.01 2024.03.31 --no-visual
```

**Monthly Results Template (agent should fill this):**

| Month | Trades | Net Profit | Return % | Win Rate | PF | Max DD% | Sharpe |
|-------|--------|------------|----------|----------|-----|---------|--------|
| Jan 2024 | | | | | | | |
| Feb 2024 | | | | | | | |
| Mar 2024 | | | | | | | |
| ... | | | | | | | |

**What monthly tests reveal:**
- Best/worst months → identify seasonal patterns
- Months to skip (PF < 1.0 consistently)
- Optimal trading months (PF > 1.5 consistently)

### Level 2: Quarterly Testing (Seasonal Check)

**Purpose:** Evaluate performance across market quarters with different characteristics.

| Quarter | Months | Gold Market Character |
|---------|--------|---------------------|
| Q1 | Jan-Mar | High volatility, trends (New Year, Chinese NY) |
| Q2 | Apr-Jun | Mixed, often choppy (Fed meetings) |
| Q3 | Jul-Sep | Low volume, ranging (summer doldrums) |
| Q4 | Oct-Dec | Strong trends, year-end rally |

```bash
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2024.01.01 2024.03.31 --no-visual  # Q1
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2024.04.01 2024.06.30 --no-visual  # Q2
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2024.07.01 2024.09.30 --no-visual  # Q3
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2024.10.01 2024.12.31 --no-visual  # Q4
```

**Quarter Rating System:**

| PF Range | Rating | Action |
|----------|--------|--------|
| > 2.0 | Excellent | Trade full size |
| 1.5-2.0 | Good | Trade normal size |
| 1.2-1.5 | Acceptable | Trade reduced size |
| 1.0-1.2 | Marginal | Skip or minimal |
| < 1.0 | Losing | DO NOT TRADE |

### Level 3: Half-Year Testing

```bash
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2024.01.01 2024.06.30 --no-visual  # H1
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2024.07.01 2024.12.31 --no-visual  # H2
```

### Level 4: Full Year Testing

```bash
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2023.01.01 2023.12.31 --no-visual
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2024.01.01 2024.12.31 --no-visual
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2025.01.01 2025.12.31 --no-visual
```

**Annual Quality Assessment:**

| Return % | Quality | Description |
|----------|---------|-------------|
| > 100% | Excellent | Exceptional, compound aggressively |
| 50-100% | Good | Solid, continue strategy |
| 20-50% | Acceptable | Positive but conservative |
| 0-20% | Marginal | Barely profitable |
| < 0% | Poor | Losing, review strategy |

### Level 5: Multi-Year Testing (Robustness)

**RECOMMENDED:** Test across 2-3+ years covering different market conditions.

```bash
# Full multi-year validation
./.skill-trader/backtest/scripts/run.sh <EA_NAME> XAUUSD M15 2023.01.01 2025.12.31 --no-visual
```

| Year | Market Condition | Purpose |
|------|------------------|---------|
| 2023 | Rate hikes, volatility | Stress test |
| 2024 | Gold bull market | Validate trending |
| 2025 | Continued volatility | Recent validation |

### Level 6: Balance Sensitivity Testing

Test same period with different deposit amounts to find minimum viable capital:

```bash
# Modify deposit in backtest.template.ini or use different configs
# Test: $100, $250, $500, $1000, $2500, $5000, $10000
```

## Extended Report Template

When presenting backtest results to the user, agent MUST use this comprehensive format:

```markdown
# Backtest Report: <EA_NAME> v<VERSION>

**Date:** <YYYY-MM-DD HH:MM>
**Version:** <EA_NAME>-v<X.Y> (git tag)

## Test Configuration

| Parameter | Value |
|-----------|-------|
| Symbol | <SYMBOL> |
| Period | <PERIOD_NAME> (<MT5_VALUE>) |
| Date Range | <FROM> to <TO> |
| Deposit | $<AMOUNT> |
| Leverage | <LEVERAGE> |
| Model | Every tick based on real ticks |

## EA Input Parameters

| Parameter | Value |
|-----------|-------|
| <param1> | <value1> |
| <param2> | <value2> |
| ... | ... |

## Overall Performance

| Metric | Value | Rating |
|--------|-------|--------|
| Net Profit | $<X> | |
| Return % | <X>% | |
| Profit Factor | <X.XX> | Good/Bad/Excellent |
| Win Rate | <X>% | |
| Max DD | <X>% | |
| Sharpe Ratio | <X.XX> | |
| Recovery Factor | <X.XX> | |
| Total Trades | <N> | |
| R/D Ratio | <X.XX> | |

## Direction Analysis

| Metric | LONG | SHORT |
|--------|------|-------|
| Trades | <N> | <N> |
| Win Rate | <X>% | <X>% |
| Net P/L | $<X> | $<X> |

## Trade Statistics

| Metric | Value |
|--------|-------|
| Largest Win | $<X> |
| Largest Loss | $<X> |
| Average Win | $<X> |
| Average Loss | $<X> |
| Max Consecutive Wins | <N> |
| Max Consecutive Losses | <N> |
| Avg Holding Time | <X>h <X>m |

## Chart Analysis

### Balance Curve
<Describe the balance curve from {EA}_Report.png>

### Time Distribution
<Describe profitable hours/days/months from {EA}_Report-hst.png>

### Holding Time Analysis
<Describe optimal holding times from {EA}_Report-holding.png>

### MFE/MAE Analysis
<Describe TP/SL efficiency from {EA}_Report-mfemae.png>

## Recommendations

1. <Specific improvement based on data>
2. <Specific improvement based on data>
3. <Specific improvement based on data>

## Conclusion

<Final assessment: APPROVED / NEEDS WORK / REJECTED>
<Summary of strengths and weaknesses>
```

### Agent Instructions for Report Generation

1. **ALWAYS read the markdown report** at `results/{date}_{EA}_{SYMBOL}_{PERIOD}/{EA}_report.md`
2. **ALWAYS read chart images** using Read tool - there are 4 PNGs to analyze
3. **Extract metrics** from the markdown report tables
4. **Analyze each chart** following the Chart Image Analysis section above
5. **Fill the Extended Report Template** with actual data
6. **Compare to previous versions** if git tags exist (use `git tag -l '<EA_NAME>-v*'`)
7. **Never guess metrics** - always read from the actual report files

### Market Condition Classification

When analyzing monthly results, classify the market condition:

| Condition | ATR | ADX | Price Behavior | EA Impact |
|-----------|-----|-----|----------------|-----------|
| Trending Up | Medium | > 25 | Higher highs/lows | Good for trend-followers |
| Trending Down | Medium | > 25 | Lower highs/lows | Good for trend-followers |
| Ranging | Low | < 20 | Oscillating in channel | Bad for trend-followers |
| High Volatility | High | Variable | Large swings | Wider SL needed |
| Choppy | Variable | < 15 | False breakouts | DO NOT TRADE |

**From backtest results, infer market condition:**
- High WR + High PF = Likely trending
- Low WR + Low PF = Likely ranging/choppy
- High trade count = Volatile (many signals)
- Low trade count = Quiet or trending (few signals)

## Strategy Analysis Template

After comprehensive testing, agent SHOULD provide:

### Advantages (what works)
- Entry signal quality (evidence from WR and PF)
- Risk management effectiveness (evidence from DD and Recovery Factor)
- Best market conditions (evidence from monthly/quarterly data)

### Disadvantages (what doesn't work)
- Market conditions where strategy fails (evidence from losing months)
- Technical limitations (lagging indicators, no news filter, etc.)
- Capital requirements (minimum viable deposit from Level 6 testing)

### Optimization Recommendations
- Parameters to tune (based on MFE/MAE analysis)
- Filters to add (based on hour/day/month distribution charts)
- Risk adjustments (based on drawdown analysis)

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
| Terminal | `$MT5_BASE/logs/YYYYMMDD.log` | Startup, config, network, auth |
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
'128364028': authorized on Exness-MT5Real7     # Auth success
automatical testing started                    # Backtest running
last test passed with result "successfully finished"  # Complete
exit with code 0                               # Clean shutdown
```

### Failure Markers in Logs

```
'128364028': authorization failed              # Wrong password or expired
account is not specified in the Tester         # Missing Login in [Tester] or accounts.dat
not synchronized with Exness-MT5Real7          # Missing Environment in common.ini
cannot load config "..."" at start             # Spaces in config path
```

## Known Issues & Fixes

### 1. MT5 Tester Shows Login Popup (CRITICAL)

**Symptom:** Backtest launches but MT5 shows a "Login" dialog asking for password. Backtest hangs until user manually enters password or cancels.

**Root Cause:** After `login.sh` authenticates, MT5 generates a minimal `common.ini` (~242 bytes) that lacks the `Environment` field (encrypted session token). Without this field, the MT5 Tester cannot auto-authenticate and shows the login popup.

**Troubleshooting steps taken:**
1. Checked MT5 terminal logs - saw `authorized on Exness-MT5Real7` (main terminal connected OK)
2. Checked Tester agent logs - saw `account is not specified` (Tester couldn't auth separately)
3. Compared common.ini sizes: login-generated = 242B vs working backup = 1716B
4. The 1716B version has `Environment=F008C72935...` (64-char hex encrypted session)
5. The 242B version only has basic fields (Login, Server, no Environment)
6. Discovered: `Password=` in `[Common]` of backtest config allows Tester to authenticate directly

**Fix:** `login.sh` now saves password to `.skill-trader/backtest/config/credentials.env` after successful auth. `backtest.sh` reads this file and includes `Password=` in the dynamically generated `[Common]` section. The Tester uses the password to authenticate without showing a popup.

**Prevention:** Backup protects `common.ini` - won't overwrite a larger backup with a smaller login-generated one.

### 2. Empty Password= Corrupts accounts.dat (CRITICAL)

**Symptom:** After backtest, MT5 deletes cached account from `accounts.dat`. Next backtest fails with "account is not specified".

**Root Cause:** Including `Password=` (empty value) in `[Common]` section causes MT5 to attempt authentication with an empty password. The server disconnects, and MT5 DELETES the account from `accounts.dat`.

**Troubleshooting steps taken:**
1. Terminal log showed: `Password=` in [Common] section at launch
2. Log showed: server disconnect immediately after auth attempt
3. `accounts.dat` shrank from ~8KB to ~3KB (account entry removed)
4. Subsequent launches showed "account is not specified"

**Fix:** `[Common]` section is now generated dynamically by `backtest.sh`:
- `Password=<value>` is ONLY included when `MT5_PASSWORD` is non-empty
- `Login=` and `Server=` are always included (tells MT5 which cached account to use)
- The template file (`backtest.template.ini`) no longer contains `[Common]` section

### 3. pkill During "Scanning Network" Corrupts accounts.dat

**Symptom:** Login script authenticates successfully, but subsequent backtest fails. `accounts.dat` is corrupt.

**Root Cause:** After MT5 authorizes, it enters a "scanning network for access points" phase. Killing MT5 (`pkill -f terminal64`) during this phase corrupts `accounts.dat` because the file is being written.

**Troubleshooting steps taken:**
1. Login log showed: `authorized on Exness-MT5Real7` (success)
2. Script killed MT5 3-8 seconds after auth
3. Next launch: "account is not specified" (accounts.dat corrupt)
4. Tried increasing sleep (8s, 15s, 30s) - still corrupt randomly
5. Discovered: MT5 writes accounts.dat asynchronously during network scan

**Fix:** Login script now uses a mini-backtest with `ShutdownTerminal=1` in `[Tester]` section. This triggers MT5's graceful shutdown sequence after the mini-backtest completes, ensuring all files are written cleanly. The script waits up to 60s for MT5 to exit on its own, never using `pkill` during normal operation.

### 4. Login Script Matches Old Log Lines (False Positive)

**Symptom:** Login script reports "LOGIN SUCCESSFUL" immediately, but credentials are not actually cached.

**Root Cause:** MT5 appends to daily log files. The script's `grep "'128364028': authorized on"` matched authorization lines from previous sessions in the same day.

**Troubleshooting steps taken:**
1. Login script reported success in <3 seconds (too fast)
2. But MT5 was still starting up (hadn't even connected yet)
3. Found: log file had old auth lines from earlier sessions
4. First tried byte offset with `dd` - broke UTF-16LE alignment (every other byte was null)
5. Switched to line count offset approach

**Fix:** Before launching MT5, record the current line count of the decoded log. After launch, only check NEW lines using `tail -n +$((LOG_LINES_BEFORE + 1))`. This ensures only entries from the current session are matched.

### 5. Login-Generated servers.dat is Incomplete

**Symptom:** Login succeeds but backtest fails with "not synchronized with trade server".

**Root Cause:** When MT5 logs in fresh (no existing `servers.dat`), it creates a minimal `servers.dat` (~18KB). The full version from a mature MT5 installation is ~900KB and contains complete broker server configs needed for backtesting.

**Fix:** Login script auto-restores `servers.dat` from backup before launching MT5 (Step 0). The backup contains the full 900KB version. Backup protection ensures smaller files don't overwrite larger ones.

### 6. Wine stderr Causes Script Failure

**Symptom:** Script exits on `set -e` from Wine debug output (`fixme:hid:...`).
**Fix:** `2>/dev/null` on all Wine commands + `|| true` (exit codes unreliable). Check output files instead.

### 7. Compile Log Garbled Text

**Symptom:** `cat`/`grep` can't parse compile log.
**Cause:** UTF-16LE encoding.
**Fix:** `iconv -f UTF-16LE -t UTF-8 "$LOG_FILE" 2>/dev/null | tr -d '\r'`

### 8. Config Path with Spaces Breaks Auto-Start (CRITICAL)

**Symptom:** `cannot load config "C:\Program Files\...\autobacktest.ini"" at start` (trailing double-quote).
**Cause:** Wine mangles paths with spaces. No shell quoting fixes this.
**Fix:** Place config at `C:\autobacktest.ini` (Wine C: root = `$WINEPREFIX/drive_c/`).

### 9. macOS `open -a` Doesn't Pass Arguments

**Symptom:** MT5 opens but ignores `/config:` argument.
**Cause:** `open --args` doesn't reliably pass args to Wine wrapper apps.
**Fix:** Launch via Wine directly: `"$WINE" terminal64.exe /config:C:\\autobacktest.ini /portable`

### 10. Monitor Misses Fast Backtests

**Symptom:** Backtest finishes in 8-10s, monitor polls at 30s, reports failure.
**Fix:** Poll every 5 seconds + 3s grace period after MT5 exit.

### 11. CSV Location Varies by Wine User

**Symptom:** CSV not found at expected path.
**Fix:** Check both `crossover` and `$(whoami)` user directories.

### 12. Visual=1 May Not Auto-Start

**Observation:** `Visual=0` auto-starts reliably. `Visual=1` may require manual Start click.
**Recommendation:** Always use `--no-visual` for automated/CI runs.

## Troubleshooting Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| Login popup during backtest | Missing Password in [Common] | Run `./.skill-trader/backtest/scripts/login.sh` (saves credentials.env) |
| "account is not specified" | accounts.dat corrupt/missing | `./.skill-trader/backtest/scripts/login.sh --restore` then re-login |
| "not synchronized" | servers.dat incomplete or common.ini missing | `./.skill-trader/backtest/scripts/login.sh --restore` |
| `cannot load config "..."" at start` | Spaces in config path | Config must be at `C:\autobacktest.ini` |
| Login success but backtest fails | common.ini missing Environment | credentials.env provides Password as fallback |
| Empty Password= corrupts auth | Old template had [Common] with empty Password | Template now has only [Tester]; [Common] is dynamic |
| No CSV after test | EA missing `OnTester()` | Add `OnTester()` with `FILE_COMMON` |
| Login script false positive | Matched old log lines | Uses line count offset for new entries only |
| Wine warnings in output | Wine debug messages | Cosmetic, ignore (redirected to /dev/null) |
| Garbled log output | UTF-16LE encoding | Use `iconv -f UTF-16LE -t UTF-8` |
| Monitor timeout | Slow backtest or MT5 hung | Increase timeout: `./.skill-trader/backtest/scripts/monitor.sh 60` |

## Broker Account

```
Login:    128364028
Password: Ready@123
Server:   Exness-MT5Real7
```
