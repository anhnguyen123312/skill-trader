# MT5 Backtest Pipeline - macOS

Pipeline tự động build và backtest MQL5 Expert Advisor trên macOS sử dụng Wine.

## Quick Start

```bash
# 1. Login (chỉ cần 1 lần đầu tiên)
./scripts/login.sh

# 2. Run full pipeline
./scripts/run.sh <EA_NAME> XAUUSD M15 2025.01.01 2025.12.31 --no-visual

# Ví dụ
./scripts/run.sh SimpleMA_EA XAUUSD M15 2025.01.01 2025.12.31 --no-visual
```

## Yêu cầu hệ thống

### 1. MetaTrader 5

```bash
# Cài đặt MT5
brew install --cask metatrader5

# Hoặc download từ: https://www.metatrader5.com/en/download
```

### 2. Khởi tạo MT5 lần đầu

```bash
# Mở MT5 app để tạo data directory
open -a "MetaTrader 5"
# Đóng app sau khi mở xong
```

### 3. Verify setup

```bash
# Check MT5 app
test -d "/Applications/MetaTrader 5.app" && echo "OK: MT5 app" || echo "MISSING: Install MT5"

# Check Wine (bundled with MT5)
WINE="/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64"
test -f "$WINE" && echo "OK: Wine64" || echo "MISSING: Wine"

# Check data directory
WINEPREFIX="$HOME/Library/Application Support/net.metaquotes.wine.metatrader5"
test -d "$WINEPREFIX" && echo "OK: Data dir" || echo "MISSING: Launch MT5 once"
```

## Cấu trúc Project

```
.skill-trader/backtest/
├── config/
│   ├── backtest.template.ini    # Template config cho backtest
│   ├── credentials.env          # Login credentials (auto-generated, gitignored)
│   └── mt5-credentials/         # Backup credentials (gitignored)
├── scripts/
│   ├── login.sh                 # Đăng nhập broker
│   ├── compile.sh               # Compile .mq5 -> .ex5
│   ├── backtest.sh              # Chạy backtest
│   ├── monitor.sh               # Monitor progress
│   ├── collect.sh               # Thu thập kết quả
│   ├── run.sh                   # E2E orchestrator
│   └── parse_report.py          # Parse HTML report -> Markdown
├── results/                     # Output (gitignored)
│   ├── YYYY-MM-DD_EA_SYMBOL_PERIOD/
│   │   ├── EA_report.md         # Full report (metrics, deals, orders)
│   │   ├── EA_Report.png        # Equity curve chart
│   │   ├── EA_Report-hst.png    # History chart
│   │   ├── EA_Report-mfemae.png # MFE/MAE chart
│   │   └── EA_Report-holding.png # Position holding chart
│   └── logs/                    # Tester logs
└── README.md
```

## Pipeline Steps

### Step 1: Login

Đăng nhập broker để MT5 cache credentials. Chỉ cần chạy 1 lần.

```bash
./scripts/login.sh
```

Interactive mode sẽ prompt:
```
Login [128364028]:     <- Enter = default
Server [Exness-MT5Real7]: <- Enter = default
Password:              <- Nhập password (hidden)
```

**Kết quả:**
- `accounts.dat` - encrypted cached login
- `credentials.env` - password cho backtest.sh

### Step 2: Compile

Compile MQL5 source thành .ex5 executable.

```bash
# EA trong project hiện tại
./scripts/compile.sh SimpleMA_EA

# EA từ repo khác
./scripts/compile.sh GoldScalperV5 --repo /path/to/EA-OAT-v4
```

**Yêu cầu source structure:**
```
EA-repo/
└── code/
    └── experts/
        └── YourEA.mq5
```

### Step 3: Backtest

Chạy backtest với real tick data.

```bash
# CLI mode
./scripts/backtest.sh <EA> <SYMBOL> <PERIOD> <FROM> <TO> [--no-visual]

# Ví dụ
./scripts/backtest.sh SimpleMA_EA XAUUSD M15 2025.01.01 2025.12.31 --no-visual
./scripts/backtest.sh GoldScalperV5 XAUUSD M1 2025.12.18 2026.02.18 --no-visual

# Interactive mode (không có args)
./scripts/backtest.sh
```

**Period mapping:**
| Period | MT5 Value |
|--------|-----------|
| M1     | 1         |
| M5     | 5         |
| M15    | 15        |
| M30    | 30        |
| H1     | 16385     |
| H4     | 16388     |
| D1     | 16408     |

### Step 4: Monitor

Đợi backtest hoàn thành.

```bash
# Default 30 phút timeout
./scripts/monitor.sh

# Custom timeout (phút)
./scripts/monitor.sh 60
```

### Step 5: Collect

Thu thập kết quả từ MT5.

```bash
./scripts/collect.sh <EA> <SYMBOL> <PERIOD>

# Ví dụ
./scripts/collect.sh SimpleMA_EA XAUUSD M15
```

**Output:**
- Markdown report (46 metrics, deals table, orders table)
- Chart PNGs (equity, history, MFE/MAE, holding)
- Tester logs

## E2E Command

```bash
./scripts/run.sh <EA> [SYMBOL] [PERIOD] [FROM] [TO] [--no-visual]
```

Chạy tất cả 4 steps: compile -> backtest -> monitor -> collect

**Ví dụ:**
```bash
# Quick test 1 tháng
./scripts/run.sh SimpleMA_EA XAUUSD M15 2026.01.01 2026.02.01 --no-visual

# Full year
./scripts/run.sh SimpleMA_EA XAUUSD H1 2025.01.01 2025.12.31 --no-visual

# M1 scalping test
./scripts/run.sh GoldScalperV5 XAUUSD M1 2025.12.18 2026.02.18 --no-visual

# External EA repo
./scripts/compile.sh GoldScalperV5 --repo /Volumes/Data/Git/EA-OAT-v4
./scripts/run.sh GoldScalperV5 XAUUSD M1 2025.12.18 2026.02.18 --no-visual
```

## Report Format

Markdown report chứa:

### Settings
- Expert name, Symbol, Period
- Date range, Broker, Currency
- Initial deposit, Leverage

### Performance Metrics (18)
- Total Net Profit, Gross Profit/Loss
- Profit Factor, Expected Payoff
- Recovery Factor, Sharpe Ratio
- Z-Score, Margin Level
- AHPR, GHPR, LR Correlation

### Drawdown (6)
- Balance Drawdown (Absolute, Max, Relative)
- Equity Drawdown (Absolute, Max, Relative)

### Trades (16)
- Total Trades/Deals
- Win Rate (Short/Long)
- Largest/Average Profit/Loss
- Consecutive Wins/Losses

### Deals Table
- Ticket, Time, Type, Direction
- Volume, Price, Profit, Balance
- Reason code

### Orders Table
- Order ticket, Time, Type
- Volume, Price, State, Reason

## Troubleshooting

### Login popup xuất hiện

**Nguyên nhân:** Credentials chưa được cache.

**Fix:**
```bash
./scripts/login.sh
```

### "account is not specified"

**Nguyên nhân:** `accounts.dat` bị corrupt.

**Fix:**
```bash
./scripts/login.sh --restore
./scripts/login.sh
```

### "not synchronized with trade server"

**Nguyên nhân:** `servers.dat` incomplete.

**Fix:**
```bash
./scripts/login.sh --restore
```

### Backtest không chạy

**Check logs:**
```bash
# Terminal log
iconv -f UTF-16LE -t UTF-8 "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/logs/$(date +%Y%m%d).log" | tr -d '\r'

# Agent log
iconv -f UTF-16LE -t UTF-8 "$HOME/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/Tester/Agent-127.0.0.1-3000/logs/$(date +%Y%m%d).log" | tr -d '\r'
```

### Compile errors

```bash
# Check compile log
cat /tmp/compile.log
```

### CSV not found

**Nguyên nhân:** EA không có `OnTester()` với CSV export.

**Fix:** HTML report vẫn được parse thành MD. CSV là optional.

## EA Requirements

EA KHÔNG cần `OnTester()` để có report. Pipeline tự động parse HTML report từ MT5.

Nếu EA có `OnTester()` với CSV export:
```mql5
double OnTester()
{
    string filename = "backtest_results.csv";
    int fileHandle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON, '\t');
    // ... write metrics
    FileClose(fileHandle);
    return profitFactor;
}
```

## Key Paths

```
WINEPREFIX  = ~/Library/Application Support/net.metaquotes.wine.metatrader5
MT5_BASE    = $WINEPREFIX/drive_c/Program Files/MetaTrader 5
WINE        = /Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine64
EXPERTS_DIR = $MT5_BASE/MQL5/Experts
CONFIG_FILE = $WINEPREFIX/drive_c/autobacktest.ini
```

## Config Template

File `config/backtest.template.ini`:

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

`[Common]` section được generate động bởi `backtest.sh` để tránh empty password bug.

## Broker Account

```
Login:    128364028
Server:   Exness-MT5Real7
```

Password được lưu trong `credentials.env` (gitignored).

## Version History

| Version | Changes |
|---------|---------|
| v2.2.0 | HTML report parser, backtest double-CR bugfix |
| v2.1.0 | Clean up unused files |
| v2.0.0 | Restructure to .skill-trader/backtest/ |
| v1.0.0 | Initial implementation |
