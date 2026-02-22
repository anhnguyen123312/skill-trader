---
name: ea-ops-monitor
description: Monitor live EA performance, analyze logs, detect anomalies, issue alerts, and provide runbook decisions for XAUUSD Expert Advisors running on MT5 VPS environments. Use when user needs live monitoring setup, anomaly detection, alert configuration, runbook automation, or incident response for deployed EAs. Triggers include "monitor EA", "check EA status", "anomaly detection", "EA alerts", "runbook", "VPS monitor", "heartbeat", "why did EA stop", "EA logs". Do NOT use for backtesting, strategy development, or position sizing -- use trading-risk-portfolio for risk calculations.
---

# EA Operations & Monitoring

<!-- STATIC CONTEXT BLOCK START - Optimized for prompt caching -->
<!-- All static instructions, runbook logic, and alert configurations below this line -->
<!-- Dynamic content (live data, logs, incident context) added after this block -->

## Core System Instructions

**Purpose:** Provide operational monitoring, anomaly detection, and automated runbook decisions for live XAUUSD Expert Advisors running on MetaTrader 5 VPS environments. This skill covers the full operational lifecycle: deploy -> monitor -> detect -> classify -> decide -> alert -> recover.

**Context Strategy:** This skill uses context engineering best practices:
- Static runbook rules and thresholds cached (this section)
- Alert templates preloaded for immediate use
- Critical runbook decisions at start and end (not buried)
- Explicit severity levels for rapid triage

**Domain:** Live XAUUSD EA operations on MetaTrader 5. Operational characteristics:
- EA runs 24/5 (Sunday 22:00 GMT to Friday 22:00 GMT)
- VPS must maintain < 5ms latency to broker
- Heartbeat interval: 60 seconds (OnTimer)
- Log rotation: daily files, 30-day retention
- Alert channels: Telegram (primary), Discord (secondary)
- Gold-specific: high volatility, spread spikes during news, gap risk on Sunday open

---

## Decision Tree (Execute First)

```
Request Analysis
├─ "Is my EA running?" -> Heartbeat Check (30s)
│  └─ Check last heartbeat timestamp, broker connection, pending orders
├─ "Why did EA stop/lose money?" -> Incident Analysis (3-5 min)
│  └─ Parse logs, correlate with market events, classify root cause
├─ "Set up monitoring" -> Configuration Mode (5-10 min)
│  └─ Heartbeat + alerts + metrics baseline + runbook rules
├─ "Review EA performance" -> Performance Audit (5-10 min) [DEFAULT]
│  └─ Full metrics analysis, anomaly scan, drift detection
└─ "Emergency: EA acting weird" -> Emergency Triage (1-2 min)
   └─ Immediate: check positions, check margin, check connectivity

Severity Assessment
├─ INFO: routine status, normal fluctuations
├─ WARNING: deviation from baseline, approaching limits
├─ CRITICAL: limit breach, immediate action required
├─ EMERGENCY: potential capital loss, human intervention needed
└─ Severity determines: alert channel, response time, escalation path
```

---

## Workflow (Collect -> Analyze -> Detect -> Classify -> Decide -> Alert)

**AUTONOMY PRINCIPLE:** This skill operates independently for monitoring and alerting. For actions that modify trading (stopping EA, closing positions), always recommend action and explain rationale but flag for human confirmation unless pre-authorized by runbook rules.

### 1. Collect Data

Gather data from all available sources before analysis.

### 2. Analyze Metrics

Compare current values against baselines and thresholds.

### 3. Detect Anomalies

Apply statistical and rule-based detection methods.

### 4. Classify Issue

Determine root cause category (CODE, MARKET, INFRA).

### 5. Execute Runbook Decision

Apply the appropriate runbook rule for the classified issue.

### 6. Issue Alert

Send formatted alert to the configured channel with severity, context, and recommended action.

---

## Data Sources

### MT5 Journal & Log Files

**Location:** `<MT5_Data>/MQL5/Logs/` and `<MT5_Data>/logs/`

**Key log files:**
```
MQL5/Logs/
├─ YYYYMMDD.log          # EA Print() output, daily rotation
├─ Journal tab logs       # Platform-level events
└─ Experts tab logs       # Expert Advisor messages

logs/
├─ YYYYMMDD.log          # Terminal journal
└─ weblog.txt            # WebRequest activity (alerts sent)
```

**Critical log patterns to monitor:**

| Pattern | Meaning | Severity |
|---|---|---|
| `OrderSend error` | Trade execution failure | WARNING-CRITICAL |
| `not enough money` | Insufficient margin | CRITICAL |
| `market is closed` | Trading outside hours | INFO |
| `requote` | Broker rejected price | WARNING |
| `no connection` | Broker disconnect | CRITICAL |
| `timeout` | Server response timeout | WARNING |
| `invalid stops` | SL/TP rejected by broker | WARNING |
| `trade context busy` | MT5 busy processing | INFO-WARNING |
| `ONNX` errors | ML model failure | CRITICAL |
| `array out of range` | Code bug (index error) | CRITICAL |
| `zero divide` | Code bug (division by zero) | CRITICAL |
| `memory allocation` | Memory leak / exhaustion | EMERGENCY |

**Log parsing (MQL5):**
```mql5
// Structured logging for monitoring
void LogMetric(string metric, double value, string context="") {
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    string logEntry = StringFormat("[METRIC] %s | %s=%.4f | %s",
                                   timestamp, metric, value, context);
    Print(logEntry);

    // Write to dedicated metrics file
    int handle = FileOpen("EA_Metrics_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv",
                          FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
    if(handle != INVALID_HANDLE) {
        FileSeek(handle, 0, SEEK_END);
        FileWrite(handle, timestamp, metric, DoubleToString(value, 4), context);
        FileClose(handle);
    }
}

// Usage in EA
void OnTick() {
    LogMetric("EQUITY", AccountInfoDouble(ACCOUNT_EQUITY));
    LogMetric("SPREAD", (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
    LogMetric("MARGIN_LEVEL", AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
}
```

### Trade History (Deals & Positions)

**Access via MQL5:**
```mql5
// Get recent trade history
void AnalyzeRecentTrades(int lookbackDays=7) {
    datetime from = TimeCurrent() - lookbackDays * 86400;
    datetime to = TimeCurrent();

    HistorySelect(from, to);
    int totalDeals = HistoryDealsTotal();

    int wins = 0, losses = 0;
    double totalProfit = 0, totalLoss = 0;
    double maxWin = 0, maxLoss = 0;

    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
        double netPL = profit + commission + swap;

        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            if(netPL > 0) { wins++; totalProfit += netPL; maxWin = MathMax(maxWin, netPL); }
            else { losses++; totalLoss += MathAbs(netPL); maxLoss = MathMax(maxLoss, MathAbs(netPL)); }
        }
    }

    double winRate = (wins + losses > 0) ? (double)wins / (wins + losses) * 100 : 0;
    double profitFactor = (totalLoss > 0) ? totalProfit / totalLoss : 0;

    LogMetric("WIN_RATE_7D", winRate);
    LogMetric("PROFIT_FACTOR_7D", profitFactor);
    LogMetric("TOTAL_TRADES_7D", wins + losses);
    LogMetric("NET_PL_7D", totalProfit - totalLoss);
}
```

### Account Metrics (Real-Time)

**Key metrics to poll every tick or every 60 seconds:**

| Metric | MQL5 Function | Alert Threshold |
|---|---|---|
| Equity | `AccountInfoDouble(ACCOUNT_EQUITY)` | < 80% of peak |
| Balance | `AccountInfoDouble(ACCOUNT_BALANCE)` | Daily change > -3% |
| Margin Level | `AccountInfoDouble(ACCOUNT_MARGIN_LEVEL)` | < 300% |
| Free Margin | `AccountInfoDouble(ACCOUNT_MARGIN_FREE)` | < 30% of equity |
| Open Positions | `PositionsTotal()` | > configured max |
| Pending Orders | `OrdersTotal()` | Unexpected count |
| Spread | `SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)` | > 80 points |

### External Monitoring (Myfxbook / FXBlue)

**Myfxbook Integration:**
- Auto-publish via MT5 Publisher (Tools -> Options -> Community)
- Tracks: daily gain, monthly return, max DD, open trades, equity curve
- API access for programmatic monitoring: `https://www.myfxbook.com/api/`
- Key reports: monthly summary, daily statements, open trades

**FXBlue Integration:**
- Plugin installation in MT5
- Real-time dashboard with equity curve
- TradeTalk alerts (configurable thresholds)
- Trade journaling with tags and notes

---

## Metrics Tracking

### Daily P&L Tracking

```mql5
// Track daily P&L with rolling comparison
struct DailyMetrics {
    datetime date;
    double startEquity;
    double endEquity;
    double dailyPL;
    double dailyPLPercent;
    int tradesOpened;
    int tradesClosed;
    double maxEquity;
    double minEquity;
    double maxDrawdown;
};

DailyMetrics todayMetrics;

void InitDailyMetrics() {
    todayMetrics.date = TimeCurrent();
    todayMetrics.startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    todayMetrics.maxEquity = todayMetrics.startEquity;
    todayMetrics.minEquity = todayMetrics.startEquity;
    todayMetrics.tradesOpened = 0;
    todayMetrics.tradesClosed = 0;
}

void UpdateDailyMetrics() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    todayMetrics.endEquity = equity;
    todayMetrics.dailyPL = equity - todayMetrics.startEquity;
    todayMetrics.dailyPLPercent = todayMetrics.dailyPL / todayMetrics.startEquity * 100;
    todayMetrics.maxEquity = MathMax(todayMetrics.maxEquity, equity);
    todayMetrics.minEquity = MathMin(todayMetrics.minEquity, equity);
    todayMetrics.maxDrawdown = (todayMetrics.maxEquity - todayMetrics.minEquity)
                               / todayMetrics.maxEquity * 100;
}
```

### Win Rate Rolling Window

```
Track win rate across multiple windows for trend detection:

- Last 10 trades:  Immediate signal quality
- Last 50 trades:  Short-term performance
- Last 100 trades: Medium-term baseline
- Last 200 trades: Strategy-level benchmark

Alert triggers:
- 10-trade WR < 20%: WARNING (possible regime mismatch)
- 50-trade WR < 35%: WARNING (sustained underperformance)
- 50-trade WR < 30%: CRITICAL (strategy breakdown)
- 100-trade WR drops > 15% from 200-trade WR: CRITICAL (drift detected)
```

### Drawdown vs Baseline

```
Compare live drawdown against backtest expectations:

- Live DD < 50% of backtest max DD: GREEN (normal)
- Live DD = 50-80% of backtest max DD: YELLOW (approaching limits)
- Live DD = 80-100% of backtest max DD: ORANGE (at limit, reduce size)
- Live DD > 100% of backtest max DD: RED (exceeded expectations, STOP EA)
- Live DD > 150% of backtest max DD: EMERGENCY (strategy failure, FULL STOP)
```

### Slippage Monitoring

```mql5
// Track slippage on every fill
void MonitorSlippage(double requestedPrice, double filledPrice, string direction) {
    double slippagePoints = MathAbs(filledPrice - requestedPrice) / _Point;
    double slippageDollars = MathAbs(filledPrice - requestedPrice)
        * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE); // per-lot dollar impact

    // Log every fill
    LogMetric("SLIPPAGE_POINTS", slippagePoints,
              StringFormat("%s req=%.2f fill=%.2f", direction, requestedPrice, filledPrice));

    // Alert on excessive slippage
    if(slippagePoints > 30) {
        SendAlert(ALERT_WARNING,
            StringFormat("High slippage: %.0f pts ($%.2f) on %s fill",
                         slippagePoints, slippageDollars, direction));
    }
    if(slippagePoints > 100) {
        SendAlert(ALERT_CRITICAL,
            StringFormat("Extreme slippage: %.0f pts ($%.2f) - check broker/VPS",
                         slippagePoints, slippageDollars));
    }
}

// Slippage benchmarks for XAUUSD (per standard lot = 100 oz):
// 1 point = 0.01 price = $1.00 per standard lot
// Normal ECN:  0-5 points ($0-$5)
// Normal STP:  5-15 points ($5-$15)
// News event:  15-50 points ($15-$50)
// Flash crash: 50-500+ points ($50-$500+)
```

### Execution Latency

```mql5
// Measure order execution time
void MeasureExecutionLatency() {
    uint startTime = GetTickCount();

    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    // ... prepare order ...

    bool sent = OrderSend(request, result);
    uint latency = GetTickCount() - startTime;

    LogMetric("EXEC_LATENCY_MS", (double)latency,
              StringFormat("retcode=%d", result.retcode));

    if(latency > 500) {
        SendAlert(ALERT_WARNING,
            StringFormat("High execution latency: %d ms (threshold: 500ms)", latency));
    }
    if(latency > 2000) {
        SendAlert(ALERT_CRITICAL,
            StringFormat("Extreme latency: %d ms - VPS/broker issue suspected", latency));
    }
}

// Latency benchmarks:
// TradingFXVPS:  50-150ms (excellent)
// ForexVPS.net:  100-300ms (good)
// MetaQuotes VPS: 80-200ms (good)
// Remote desktop: 200-1000ms (acceptable for swing)
// Home PC:       500-3000ms (not recommended for scalping)
```

---

## Anomaly Detection

### Performance Drift vs Backtest Baseline

**Method:** Compare rolling live metrics against backtest reference values.

```
For each metric M in {win_rate, profit_factor, avg_trade, max_dd}:

1. Calculate backtest baseline (BT_M) from Strategy Tester report
2. Calculate live rolling value (LIVE_M) over 50+ trades
3. Calculate Z-score: Z = (LIVE_M - BT_M) / StdDev(BT_M)

Interpretation:
- |Z| < 1.0: Normal variation -> INFO
- |Z| 1.0-1.5: Mild drift -> INFO (log, no action)
- |Z| 1.5-2.0: Moderate drift -> WARNING (increase monitoring frequency)
- |Z| 2.0-2.5: Significant drift -> WARNING (prepare to reduce lot size)
- |Z| > 2.5: Severe drift -> CRITICAL (pause EA, investigate root cause)
```

**Common drift causes:**
- Market regime change (trend -> range or vice versa)
- Spread/commission change by broker
- Slippage increase due to liquidity change
- Parameter staleness (needs re-optimization)
- Data feed quality degradation

### Regime Breakdown Detection

```
Detect when market regime no longer matches EA design:

Trend-Following EA in Ranging Market:
├─ ADX < 18 for 5+ consecutive days
├─ ATR declining 3+ consecutive weeks
├─ Win rate drops below 40% (rolling 20 trades)
└─ ACTION: PAUSE EA, switch to range-appropriate EA if available

Range-Trading EA in Trending Market:
├─ ADX > 30 for 3+ consecutive days
├─ Price breaks and holds beyond 2x ATR from range midpoint
├─ Multiple stop-outs on same side (all buys lose or all sells lose)
└─ ACTION: PAUSE EA, switch to trend-following EA if available

Detection MQL5:
// iADX/iATR return indicator handles in MQL5, not values
int adxHandle = iADX(_Symbol, PERIOD_H1, 14);
int atrHandle = iATR(_Symbol, PERIOD_H1, 14);
double adxBuf[], atrBuf[];
ArraySetAsSeries(adxBuf, true);
ArraySetAsSeries(atrBuf, true);
CopyBuffer(adxHandle, 0, 0, 1, adxBuf);   // ADX main line = buffer 0
CopyBuffer(atrHandle, 0, 0, 1, atrBuf);
double adx = adxBuf[0];
double atr = atrBuf[0];
IndicatorRelease(adxHandle);
IndicatorRelease(atrHandle);

// Get simple moving average of ATR(14, H1) over N bars
double GetATRMovingAverage(int period) {
    int atrH = iATR(_Symbol, PERIOD_H1, 14);
    if(atrH == INVALID_HANDLE) return 0.0;

    double atrValues[];
    ArraySetAsSeries(atrValues, true);
    if(CopyBuffer(atrH, 0, 0, period, atrValues) < period) {
        IndicatorRelease(atrH);
        return 0.0;
    }
    IndicatorRelease(atrH);

    double sum = 0.0;
    for(int i = 0; i < period; i++)
        sum += atrValues[i];
    return sum / period;
}

double atrMA = GetATRMovingAverage(20); // 20-period SMA of ATR

bool isTrendBreakdown = (eaType == EA_TREND_FOLLOWING && adx < 18);
bool isRangeBreakdown = (eaType == EA_RANGE_TRADING && adx > 30);
```

### Latency Increase Detection

```
Baseline: Calculate median execution latency over first 100 trades
Rolling: Track 20-trade rolling median

Alert when:
- Rolling median > 2x baseline: WARNING (VPS load or network issue)
- Rolling median > 3x baseline: CRITICAL (immediate VPS investigation)
- Single execution > 5000ms: CRITICAL (possible broker server issue)
- 3+ timeouts in 1 hour: EMERGENCY (connectivity failure)
```

### Slippage Spike Detection

```
Baseline: Calculate median slippage over first 200 fills
Rolling: Track 20-fill rolling median

Alert when:
- Rolling median > 3x baseline: WARNING (liquidity change)
- 3+ fills with slippage > 30 points in 1 hour: CRITICAL
- Single fill slippage > 100 points: CRITICAL (check for news event)
- Negative slippage pattern (always unfavorable): WARNING (broker issue)
```

### Consecutive Losses Beyond Statistical Norm

```
Expected consecutive losses based on win rate:

| Win Rate | Expected Max Run | Alert Threshold |
|---|---|---|
| 70% | 3-4 losses | > 6 consecutive |
| 60% | 4-5 losses | > 7 consecutive |
| 55% | 5-6 losses | > 8 consecutive |
| 50% | 6-7 losses | > 9 consecutive |
| 45% | 7-8 losses | > 10 consecutive |

Formula: Alert if consecutive_losses > ceil(log(1/1000) / log(1 - win_rate))
This is the 1-in-1000 probability threshold.

Action on breach:
1. PAUSE EA for 4 hours minimum
2. Check if market regime matches EA design
3. Verify no code bugs (check for error logs)
4. If regime mismatch: keep paused until regime changes
5. If no explanation found: reduce lot by 50% and resume with tight monitoring
```

### Error Code Pattern Detection

```
Track MQL5 error codes with rolling frequency:

High-frequency errors (> 5 per hour):
├─ TRADE_RETCODE_REQUOTE (10004): Price changed -> WARNING
├─ TRADE_RETCODE_REJECT (10006): Order rejected -> CRITICAL
├─ TRADE_RETCODE_TIMEOUT (10008): Broker timeout -> WARNING
├─ TRADE_RETCODE_ERROR (10011): General error -> CRITICAL
└─ TRADE_RETCODE_NO_MONEY (10019): Margin issue -> EMERGENCY

Error pattern analysis:
- Same error 3+ times in 10 minutes: cluster detected -> escalate severity
- Error rate increasing over hours: degrading condition -> investigate
- Error only during specific hours: session/liquidity related
- Error correlates with spread spikes: news-related
```

---

## Issue Classification

When an anomaly is detected, classify it into one of three categories. Classification determines the runbook response.

### CODE BUG: Logic Error, Unhandled Exception, Memory Leak

**Indicators:**
- `array out of range` in logs
- `zero divide` errors
- `stack overflow` or `memory allocation failed`
- EA produces trades outside configured parameters
- Lot size different from expected calculation
- SL/TP not set when they should be
- EA opens positions on wrong symbol
- Increasing memory usage over time (memory leak)

**Diagnostic steps:**
```
1. Check Experts tab in MT5 for error messages
2. Search logs for error codes and stack traces
3. Compare actual trade parameters vs configured parameters
4. Check if error started after recent code update
5. Test: does error reproduce on demo account?
```

**Response:** STOP EA immediately. Do not resume until code fix is verified on demo. Report exact error, line number (if available), and timestamp.

### MARKET REGIME: Trend Change, Volatility Shift, Correlation Break

**Indicators:**
- Performance drift detected (Z-score > 2.0) but no error codes
- Win rate decline correlates with ADX/ATR regime change
- Strategy logic executing correctly but losing
- Losses cluster on one side (all longs lose in downtrend)
- Correlation with DXY changes significantly

**Diagnostic steps:**
```
1. Check ADX, ATR, EMA alignment for regime assessment
2. Compare current regime vs EA design assumptions
3. Look at DXY correlation: has it shifted?
4. Check economic calendar: major policy shift?
5. Compare current market stats with backtest period stats
```

**Response:** PAUSE EA (do not stop permanently). Reduce lot size by 50%. Monitor for regime return. If new regime persists > 2 weeks, EA may need re-optimization or replacement.

### INFRA ISSUE: VPS Down, Broker Disconnect, Platform Outage

**Indicators:**
- Heartbeat stops (no log entries for > 2 minutes)
- `no connection` or `connection lost` in logs
- Execution latency spikes > 5x baseline
- Spread spikes to extreme levels (> 200 points) for extended period
- MT5 terminal not responding
- VPS CPU/RAM at 100%

**Diagnostic steps:**
```
1. Check VPS status (ping, remote desktop access)
2. Check broker status page / community forums
3. Check MT5 connection status indicator (bottom-right)
4. Check if other EAs on same VPS are also affected
5. Check Windows Event Viewer for OS-level errors
6. Check MT5 auto-update: did platform restart?
```

**Response:** Depends on sub-type:
- VPS down: failover to backup or restart
- Broker disconnect: wait 5 min, then alert human
- Platform outage: check positions manually via broker web portal
- Spread spike: pause EA, resume when spread normalizes

---

## Runbook Decisions (CRITICAL SECTION)

These are the automated decision rules. They are ordered by severity and must be evaluated top-to-bottom.

### Runbook 1: Drawdown Management

```
IF current_DD > 25%:
  ACTION: EMERGENCY STOP ALL EAs
  ALERT: EMERGENCY
  MESSAGE: "Max drawdown exceeded (25%). All trading halted. Manual review required."
  RECOVERY: Full strategy review. Do not resume without explicit human approval.

IF current_DD > 15% AND current_DD <= 25%:
  ACTION: STOP the specific EA causing majority of DD
  ALERT: CRITICAL
  MESSAGE: "DD at {X}%. EA {name} stopped. Other EAs lot reduced by 50%."
  RECOVERY: Investigate cause. Resume at 50% size only after DD recovers to < 10%.

IF current_DD > 10% AND current_DD <= 15%:
  ACTION: REDUCE lot size by 50% for all EAs
  ALERT: WARNING
  MESSAGE: "DD at {X}%. All EAs reduced to 50% lot size."
  RECOVERY: Restore full size when DD recovers to < 7%.

IF current_DD > 7% AND current_DD <= 10%:
  ACTION: REDUCE lot size by 25% for all EAs
  ALERT: WARNING
  MESSAGE: "DD at {X}%. Precautionary lot reduction by 25%."
  RECOVERY: Restore full size when DD recovers to < 5%.
```

### Runbook 2: Consecutive Loss Management

```
IF consecutive_losses >= 8:
  ACTION: STOP EA for remainder of trading day
  ALERT: CRITICAL
  MESSAGE: "EA {name}: 8+ consecutive losses. Stopped until next trading day."
  RECOVERY: Resume next day at 50% lot size. Full size after 3 winning trades.

IF consecutive_losses >= 5 AND consecutive_losses < 8:
  ACTION: PAUSE EA for 4 hours
  ALERT: WARNING
  MESSAGE: "EA {name}: {N} consecutive losses. Paused for 4 hours."
  RECOVERY: Resume at 75% lot size after 4 hours. Full size after 2 winning trades.

IF consecutive_losses >= 3:
  ACTION: LOG and monitor closely (no position size change)
  ALERT: INFO
  MESSAGE: "EA {name}: {N} consecutive losses. Monitoring."
```

### Runbook 3: Spread Management

```
IF spread > 200 points (> $2.00 price spread = $200.00/lot for XAUUSD):
  ACTION: DISABLE trading immediately, keep existing positions
  ALERT: CRITICAL
  MESSAGE: "Extreme spread: {X} points. Trading disabled. Likely major news event."
  RECOVERY: Re-enable when spread < 80 points for 5+ consecutive minutes.

IF spread > 80 points AND spread <= 200 points:
  ACTION: Block new entries, allow exits only
  ALERT: WARNING
  MESSAGE: "Elevated spread: {X} points. New entries blocked."
  RECOVERY: Resume when spread < 50 points for 3+ consecutive minutes.

IF spread > 50 points AND spread <= 80 points:
  ACTION: LOG, reduce lot by 30% for new entries
  ALERT: INFO
  MESSAGE: "Spread elevated: {X} points. Lot reduced 30% for new entries."
```

### Runbook 4: Error Code Response

```
IF error_code IN {ERR_TRADE_NOT_ENOUGH_MONEY}:
  ACTION: STOP EA immediately
  ALERT: EMERGENCY
  MESSAGE: "Insufficient margin. EA stopped. Check account funding."
  RECOVERY: Verify account funded. Resume only after margin level > 500%.

IF error_code IN {10004, 10008} AND frequency > 5 per hour:  // requotes + timeouts (transient)
  ACTION: PAUSE EA for 30 minutes
  ALERT: WARNING
  MESSAGE: "Frequent {error_name}: {count} in last hour. Possible broker issue."
  RECOVERY: Resume after 30 min. If recurs, switch to limit orders.

IF error_code IN {array out of range, zero divide, access violation}:
  ACTION: STOP EA immediately, DO NOT restart
  ALERT: CRITICAL
  MESSAGE: "Code error detected: {error}. EA stopped. Bug fix required."
  RECOVERY: Fix code, test on demo, deploy new version.

IF any_error repeats > 10 times in 10 minutes:
  ACTION: STOP EA + send notification to human
  ALERT: CRITICAL
  MESSAGE: "Error storm: {error} x{count} in 10 min. EA halted."
  RECOVERY: Investigate root cause before any restart.
```

### Runbook 5: Broker Disconnect

```
IF disconnect_duration > 10 minutes:
  ACTION: ALERT human + check positions via broker web portal
  ALERT: EMERGENCY
  MESSAGE: "Broker disconnected for {X} min. Positions may be unmanaged."
  RECOVERY: Verify all positions have SL set. Reconnect or failover.

IF disconnect_duration > 5 minutes AND disconnect_duration <= 10 minutes:
  ACTION: ALERT human
  ALERT: CRITICAL
  MESSAGE: "Broker disconnected for {X} min. Monitoring reconnection."
  RECOVERY: If reconnects within 10 min, verify positions and continue.

IF disconnect_duration > 2 minutes AND disconnect_duration <= 5 minutes:
  ACTION: LOG, prepare failover
  ALERT: WARNING
  MESSAGE: "Brief disconnect: {X} min. Connection unstable."
  RECOVERY: Monitor. If 3+ disconnects in 1 hour, investigate VPS/network.

IF disconnect_count > 3 in 1 hour:
  ACTION: Initiate VPS health check
  ALERT: CRITICAL
  MESSAGE: "Multiple disconnects ({count} in 1hr). VPS/network investigation needed."
```

### Runbook 6: Position Anomaly

```
IF position_open_duration > 48 hours AND strategy != POSITION_TRADING:
  ACTION: ALERT human for review
  ALERT: WARNING
  MESSAGE: "Position #{ticket} open for {X} hours. Expected max: 48h."
  RECOVERY: Manual review. Close if SL/TP missing or EA logic failure.

IF position_count > configured_max:
  ACTION: STOP EA (prevent new positions), keep existing
  ALERT: CRITICAL
  MESSAGE: "Position limit exceeded: {count}/{max}. EA stopped."
  RECOVERY: Close excess positions manually, then resume EA.

IF position_without_SL detected:
  ACTION: EMERGENCY set SL at 3x ATR from entry
  ALERT: EMERGENCY
  MESSAGE: "Position #{ticket} has NO stop loss! Emergency SL placed."
  RECOVERY: Investigate why SL was not set. Code bug likely.

IF unexpected_position (not from known EA magic number):
  ACTION: ALERT human immediately
  ALERT: EMERGENCY
  MESSAGE: "Unknown position detected. Magic={X}, Ticket={Y}."
  RECOVERY: Verify no unauthorized access. Check EA configuration.
```

---

## Alert Integration

### Telegram Integration

**Setup:**
1. Create bot via @BotFather -> get bot token
2. Get chat ID via @userinfobot or `getUpdates` API
3. Add `https://api.telegram.org` to MT5 allowed URLs (Tools -> Options -> Expert Advisors)

**MQL5 Implementation:**
```mql5
// Telegram alert sender with HTML formatting
bool SendTelegramAlert(string botToken, string chatID, string message,
                       string parseMode="HTML") {
    string url = StringFormat("https://api.telegram.org/bot%s/sendMessage", botToken);
    string headers = "Content-Type: application/x-www-form-urlencoded\r\n";

    // URL-encode the message
    string payload = StringFormat("chat_id=%s&parse_mode=%s&text=%s",
                                  chatID, parseMode, UrlEncode(message));

    char data[];
    StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);

    char result[];
    string resultHeaders;

    int res = WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
    if(res != 200) {
        Print("Telegram alert failed: HTTP ", res);
        return false;
    }
    return true;
}

// URL encoding helper
string UrlEncode(string text) {
    string result = "";
    for(int i = 0; i < StringLen(text); i++) {
        ushort c = StringGetCharacter(text, i);
        if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
           (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
            result += ShortToString(c);
        else if(c == ' ')
            result += "+";
        else
            result += StringFormat("%%%02X", c);
    }
    return result;
}
```

**Alert message templates (HTML format):**

```html
<!-- TRADE OPENED -->
<b>TRADE OPENED</b>
Symbol: XAUUSD
Direction: {BUY/SELL}
Lot: {0.05}
Entry: {2050.50}
SL: {2035.00} (-$15.50)
TP: {2075.00} (+$24.50)
Risk: {$77.50} ({1.5%})
R:R: {1:1.58}

<!-- TRADE CLOSED -->
<b>TRADE CLOSED</b>
Symbol: XAUUSD
Direction: {BUY}
P&L: <b>{+$125.30}</b> ({+2.5%})
Duration: {4h 23m}
Pips: {+25.1}

<!-- DAILY SUMMARY -->
<b>DAILY REPORT</b>
Date: {2026-02-22}
Trades: {5} (W:{3} L:{2})
P&L: {+$85.40} ({+0.85%})
Win Rate: {60%}
Max DD: {1.2%}
Equity: {$10,285.40}

<!-- ALERT -->
{SEVERITY_EMOJI} <b>{SEVERITY}: {TITLE}</b>
{Description}
Current: {metric_value}
Threshold: {threshold_value}
Action: {recommended_action}
Time: {2026-02-22 14:30:00 GMT}
```

### Discord Integration

**Setup:**
1. Server Settings -> Integrations -> Webhooks -> New Webhook
2. Copy webhook URL
3. Add webhook domain to MT5 allowed URLs

**MQL5 Implementation:**
```mql5
// Discord webhook sender with JSON payload
bool SendDiscordAlert(string webhookURL, string content,
                      string username="EA Monitor", int color=0xFF0000) {
    string headers = "Content-Type: application/json\r\n";

    // Build JSON payload with embed for rich formatting
    string payload = StringFormat(
        "{\"username\":\"%s\",\"embeds\":[{\"description\":\"%s\",\"color\":%d,\"timestamp\":\"%s\"}]}",
        username, EscapeJSON(content), color, TimeToISO8601(TimeCurrent()));

    char data[];
    StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);

    char result[];
    string resultHeaders;

    int res = WebRequest("POST", webhookURL, headers, 5000, data, result, resultHeaders);
    return (res == 204 || res == 200);
}

// JSON string escaping
string EscapeJSON(string text) {
    StringReplace(text, "\\", "\\\\");
    StringReplace(text, "\"", "\\\"");
    StringReplace(text, "\n", "\\n");
    StringReplace(text, "\r", "\\r");
    StringReplace(text, "\t", "\\t");
    return text;
}

// ISO 8601 timestamp
string TimeToISO8601(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
                        dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
}
```

### Unified Alert Dispatcher

```mql5
// Alert severity levels used throughout monitoring code
enum ENUM_ALERT_LEVEL {
    ALERT_INFO,       // Routine status, normal fluctuations
    ALERT_WARNING,    // Deviation from baseline, approaching limits
    ALERT_CRITICAL,   // Limit breach, immediate action required
    ALERT_EMERGENCY   // Potential capital loss, human intervention needed
};

// Unified SendAlert dispatcher -- routes to Print + Telegram + Discord
// based on severity level. Called by all monitoring functions.
void SendAlert(ENUM_ALERT_LEVEL level, string message) {
    string levelStr;
    switch(level) {
        case ALERT_INFO:      levelStr = "INFO";      break;
        case ALERT_WARNING:   levelStr = "WARNING";   break;
        case ALERT_CRITICAL:  levelStr = "CRITICAL";  break;
        case ALERT_EMERGENCY: levelStr = "EMERGENCY"; break;
    }

    // Always print to EA log
    Print(StringFormat("[%s] %s", levelStr, message));

    // Telegram: send for WARNING and above
    if(level >= ALERT_WARNING) {
        string telegramMsg = StringFormat("<b>%s</b>\n%s\nTime: %s",
            levelStr, message, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
        SendTelegramAlert(TelegramBotToken, TelegramChatID, telegramMsg);
    }

    // Discord: send for CRITICAL and above
    if(level >= ALERT_CRITICAL) {
        int color = (level == ALERT_EMERGENCY) ? 0xFF0000 : 0xFF8C00; // red or dark orange
        string discordMsg = StringFormat("[%s] %s", levelStr, message);
        SendDiscordAlert(DiscordWebhookURL, discordMsg, EA_NAME, color);
    }
}
```

### Alert Level Configuration

| Level | Telegram | Discord | Sound | Email | Response Time |
|---|---|---|---|---|---|
| INFO | Quiet channel | #ea-logs | None | No | Next check-in |
| WARNING | Main channel | #ea-alerts | Chime | Optional | Within 2 hours |
| CRITICAL | Main channel + reply | #ea-alerts + @role | Alarm | Yes | Within 30 min |
| EMERGENCY | Main channel + call? | #ea-emergency + @everyone | Siren | Yes + SMS | Immediate |

**Rate limiting:** Max 10 alerts per minute per channel. Batch duplicate alerts into summary.

**Quiet hours:** INFO/WARNING suppressed 22:00-06:00 local time. CRITICAL/EMERGENCY always delivered.

---

## Heartbeat Monitoring

### EA Running Check

```mql5
// Heartbeat system using OnTimer
input string EA_NAME = "EA_OAT_v5";   // EA identifier for alerts and heartbeat
input int HeartbeatIntervalSec = 60;  // Check every 60 seconds
input string HeartbeatFile = "EA_Heartbeat.json";

datetime lastHeartbeat = 0;
int heartbeatMissCount = 0;

int OnInit() {
    EventSetTimer(HeartbeatIntervalSec);
    SendHeartbeat(); // Initial heartbeat on startup
    return INIT_SUCCEEDED;
}

void OnTimer() {
    SendHeartbeat();
    CheckBrokerConnection();
    CheckStuckOrders();
    UpdateDailyMetrics();
    AnalyzeRecentTrades(1); // Last 24 hours
}

void SendHeartbeat() {
    lastHeartbeat = TimeCurrent();

    // Write heartbeat file (external monitor can check this)
    int handle = FileOpen(HeartbeatFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
    if(handle != INVALID_HANDLE) {
        string json = StringFormat(
            "{\"ea\":\"%s\",\"symbol\":\"%s\",\"time\":\"%s\","
            "\"equity\":%.2f,\"margin_level\":%.2f,"
            "\"positions\":%d,\"spread\":%d,\"connected\":%s}",
            EA_NAME, _Symbol, TimeToString(TimeCurrent()),
            AccountInfoDouble(ACCOUNT_EQUITY),
            AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),
            PositionsTotal(),
            (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
            TerminalInfoInteger(TERMINAL_CONNECTED) ? "true" : "false"
        );
        FileWriteString(handle, json);
        FileClose(handle);
    }

    // Also log to metrics
    LogMetric("HEARTBEAT", 1.0, "alive");
}
```

### Broker Connection Status

```mql5
void CheckBrokerConnection() {
    static datetime lastDisconnect = 0;
    static int disconnectCount = 0;
    static datetime disconnectWindowStart = 0;

    bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);

    if(!connected) {
        if(lastDisconnect == 0) {
            lastDisconnect = TimeCurrent();
            disconnectCount++;

            // Reset window counter hourly
            if(TimeCurrent() - disconnectWindowStart > 3600) {
                disconnectWindowStart = TimeCurrent();
                disconnectCount = 1;
            }
        }

        int disconnectMinutes = (int)(TimeCurrent() - lastDisconnect) / 60;

        if(disconnectMinutes > 10) {
            SendAlert(ALERT_EMERGENCY,
                StringFormat("Broker disconnected for %d minutes! Check positions via web portal.",
                             disconnectMinutes));
        } else if(disconnectMinutes > 5) {
            SendAlert(ALERT_CRITICAL,
                StringFormat("Broker disconnected for %d minutes. Monitoring.", disconnectMinutes));
        } else if(disconnectMinutes > 2) {
            SendAlert(ALERT_WARNING,
                StringFormat("Broker disconnect: %d minutes.", disconnectMinutes));
        }

        // Multiple disconnects in 1 hour
        if(disconnectCount > 3) {
            SendAlert(ALERT_CRITICAL,
                StringFormat("Multiple disconnects: %d in last hour. VPS investigation needed.",
                             disconnectCount));
        }
    } else {
        if(lastDisconnect > 0) {
            int totalMinutes = (int)(TimeCurrent() - lastDisconnect) / 60;
            SendAlert(ALERT_INFO,
                StringFormat("Broker reconnected after %d minutes.", totalMinutes));
            lastDisconnect = 0;
        }
    }
}
```

### Orders Stuck > 48h Alert

```mql5
void CheckStuckOrders() {
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;

        string symbol = PositionGetString(POSITION_SYMBOL);
        if(symbol != _Symbol) continue;

        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        int hoursOpen = (int)(TimeCurrent() - openTime) / 3600;

        // Check for missing SL (EMERGENCY)
        double sl = PositionGetDouble(POSITION_SL);
        if(sl == 0) {
            SendAlert(ALERT_EMERGENCY,
                StringFormat("Position #%llu has NO STOP LOSS! Open for %d hours. "
                             "Setting emergency SL.", ticket, hoursOpen));
            SetEmergencySL(ticket);
        }

        // Check for stuck positions (non-position-trading EAs)
        if(hoursOpen > 48) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            SendAlert(ALERT_WARNING,
                StringFormat("Position #%llu stuck for %d hours. P&L: $%.2f. "
                             "Review if this is intentional.", ticket, hoursOpen, profit));
        }

        // Check for very old positions
        if(hoursOpen > 120) { // 5 days
            SendAlert(ALERT_CRITICAL,
                StringFormat("Position #%llu open for %d hours (5+ days). "
                             "Likely stuck. Manual review required.", ticket, hoursOpen));
        }
    }
}

void SetEmergencySL(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return;

    double entry = PositionGetDouble(POSITION_PRICE_OPEN);

    // iATR returns a handle; use CopyBuffer to get value, then release
    int atrHandle = iATR(_Symbol, PERIOD_H1, 14);
    if(atrHandle == INVALID_HANDLE) return;

    double atrBuf[];
    ArraySetAsSeries(atrBuf, true);
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) < 1) {
        IndicatorRelease(atrHandle);
        return;
    }
    double atr = atrBuf[0];
    IndicatorRelease(atrHandle);  // prevent handle leak

    double emergencySL;
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        emergencySL = entry - atr * 3.0;
    else
        emergencySL = entry + atr * 3.0;

    CTrade trade;
    trade.PositionModify(ticket, emergencySL, PositionGetDouble(POSITION_TP));
}
```

### Recovery Protocol on Restart

```mql5
// OnInit recovery: check state after EA restart (crash, VPS reboot, update)
int OnInit() {
    // 1. Log restart event
    Print("EA RESTARTED at ", TimeToString(TimeCurrent()));
    SendAlert(ALERT_INFO, "EA restarted. Running recovery checks.");

    // 2. Check for open positions from previous session
    int openPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

        openPositions++;

        // Verify SL/TP are set
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        if(sl == 0) {
            SendAlert(ALERT_EMERGENCY,
                StringFormat("Recovery: Position #%llu missing SL! Setting emergency SL.", ticket));
            SetEmergencySL(ticket);
        }

        // Log existing position details
        SendAlert(ALERT_INFO,
            StringFormat("Recovery: Found position #%llu %s %.2f lots, P&L=$%.2f",
                         ticket,
                         PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL",
                         PositionGetDouble(POSITION_VOLUME),
                         PositionGetDouble(POSITION_PROFIT)));
    }

    // 3. Check account health
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

    if(marginLevel > 0 && marginLevel < 300) {
        SendAlert(ALERT_CRITICAL,
            StringFormat("Recovery: Margin level LOW at %.1f%%. Positions may be at risk.", marginLevel));
    }

    // 4. Restore daily metrics baseline
    InitDailyMetrics();

    // 5. Start heartbeat timer
    EventSetTimer(HeartbeatIntervalSec);

    SendAlert(ALERT_INFO,
        StringFormat("Recovery complete. %d open positions. Equity=$%.2f, Margin=%.1f%%",
                     openPositions, equity, marginLevel));

    return INIT_SUCCEEDED;
}
```

---

## VPS Management

### Recommended Providers for XAUUSD EAs

| Provider | Monthly Cost | Latency to Major Brokers | Uptime SLA | Best For |
|---|---|---|---|---|
| **TradingFXVPS** | $15-20 | 0.3-0.78ms (Equinix NY/LD) | 99.99% | Scalping, HFT gold |
| **ForexVPS.net** | $29-31 | ~1ms | 99.9% | General EA, multi-EA setups |
| **MetaQuotes VPS** | $15 | Low (integrated with MT5) | 99.9% | Simple single-EA deployment |
| **ForexBox** | $7.99 | Low | 99.9% | Budget, swing trading |
| **Contabo** | $5-10 | 5-20ms | 99.9% | Development, testing |
| **Vultr** | $5-24 | Variable | 99.95% | Custom setups, API access |

### VPS Requirements

```
Minimum Specifications:
├─ CPU: 1 vCPU (2+ for multi-EA)
├─ RAM: 1 GB (2 GB recommended, 4 GB for 5+ EAs)
├─ Storage: 20 GB SSD (NVMe preferred)
├─ Network: 100 Mbps minimum
├─ OS: Windows Server 2019/2022 (for MT5)
├─ Latency: < 5ms to broker server (< 1ms for scalping)
├─ Uptime: 99.9% minimum (99.99% for production)
└─ Location: Same datacenter as broker (NY4/LD4/TY3)
```

### Latency Monitoring

```mql5
// Monitor network latency to broker
void CheckLatency() {
    // MT5 provides ping in the status bar
    // Programmatic check via trade server response time
    uint start = GetTickCount();
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    uint latency = GetTickCount() - start;

    LogMetric("PING_MS", (double)latency);

    if(latency > 50) {
        SendAlert(ALERT_WARNING,
            StringFormat("Network latency elevated: %d ms (threshold: 50ms)", latency));
    }
    if(latency > 200) {
        SendAlert(ALERT_CRITICAL,
            StringFormat("Network latency critical: %d ms. VPS health check needed.", latency));
    }
}
```

### Failover Procedures

```
Primary VPS Failure Checklist:

Immediate (0-5 min):
├─ 1. Alert received (heartbeat missed)
├─ 2. Attempt VPS restart via provider control panel
├─ 3. Check broker web portal for open positions
├─ 4. Verify all positions have SL set
└─ 5. If positions at risk: set SL via broker mobile app

Short-term (5-30 min):
├─ 6. If VPS unrecoverable: activate backup VPS
├─ 7. Login to backup MT5 instance
├─ 8. Verify same account, same EA, same settings
├─ 9. Check for duplicate magic numbers (avoid double-trading)
└─ 10. Resume EA on backup VPS

Post-incident (1-24 hours):
├─ 11. Investigate root cause of primary failure
├─ 12. Review all trades during downtime
├─ 13. Update failover documentation
├─ 14. Consider adding secondary VPS as warm standby
└─ 15. Test failover procedure monthly

Backup VPS Configuration:
- Keep a second VPS with MT5 installed and configured
- Same EA files, same settings, but EA DISABLED by default
- Monthly test: enable backup EA on demo account, verify functionality
- Emergency: enable backup EA on live account
- CRITICAL: Never run same EA on same account from two VPS simultaneously
```

### VPS Health Monitoring Checklist

| Check | Frequency | Method | Alert Threshold |
|---|---|---|---|
| CPU usage | Every 5 min | Performance Monitor | > 80% sustained |
| RAM usage | Every 5 min | Performance Monitor | > 85% |
| Disk space | Daily | dir/df | < 2 GB free |
| Network latency | Every 60s | Heartbeat response time | > 50ms |
| MT5 running | Every 60s | Process check | Not found |
| MT5 connected | Every 60s | Heartbeat file | "connected: false" |
| Windows Update | Daily | Check pending updates | Restart required |
| Time sync | Hourly | NTP check | Drift > 1 second |

---

## Output Contract: Runbook Decision Format

Every monitoring analysis MUST produce output in this structured format:

```json
{
  "monitoring_timestamp": "2026-02-22T14:30:00Z",
  "system_status": {
    "overall": "YELLOW",
    "ea_name": "EA_TrendFollower_v3",
    "ea_running": true,
    "vps_status": "healthy",
    "broker_connected": true,
    "last_heartbeat": "2026-02-22T14:29:45Z",
    "uptime_hours": 168.5
  },
  "account_snapshot": {
    "equity": 10285.40,
    "balance": 10200.00,
    "margin_level_percent": 720.0,
    "open_positions": 2,
    "pending_orders": 0,
    "daily_pl": 85.40,
    "daily_pl_percent": 0.84,
    "current_drawdown_percent": 3.2
  },
  "metrics_rolling": {
    "win_rate_10": 60.0,
    "win_rate_50": 54.0,
    "win_rate_100": 56.0,
    "profit_factor_50": 1.72,
    "avg_slippage_points": 4.2,
    "avg_execution_latency_ms": 120,
    "consecutive_losses_current": 1,
    "spread_current_points": 28
  },
  "anomalies_detected": [
    {
      "type": "PERFORMANCE_DRIFT",
      "severity": "WARNING",
      "description": "Win rate (50-trade) dropped from 58% baseline to 54%",
      "z_score": 1.3,
      "detected_at": "2026-02-22T14:00:00Z"
    }
  ],
  "issue_classification": "MARKET_REGIME",
  "regime_assessment": {
    "current": "RANGING",
    "ea_designed_for": "TRENDING",
    "mismatch": true,
    "adx": 17.5,
    "atr": 12.8
  },
  "runbook_decision": {
    "rule_triggered": "Regime mismatch: trend EA in ranging market",
    "action": "REDUCE lot size by 40%",
    "severity": "WARNING",
    "auto_executed": false,
    "requires_human_approval": true,
    "rationale": "ADX at 17.5 (< 20 threshold) for 3 consecutive days. EA designed for trending markets. Historical performance in ranging regime shows PF < 1.2."
  },
  "alerts_sent": [
    {
      "channel": "telegram",
      "severity": "WARNING",
      "message": "EA_TrendFollower_v3: Regime mismatch detected. ADX=17.5, market ranging. Recommend 40% lot reduction.",
      "sent_at": "2026-02-22T14:30:05Z",
      "delivered": true
    }
  ],
  "recommendations": [
    "Consider pausing trend-following EA until ADX recovers above 22",
    "Range-trading EA (if available) may perform better in current conditions",
    "Next high-impact event: FOMC in 3 days -- prepare for volatility spike",
    "Review and re-optimize EA parameters if ranging persists > 2 weeks"
  ],
  "next_check": "2026-02-22T15:30:00Z"
}
```

---

## Error Handling & Quality Standards

### Monitoring System Self-Check

```
Before ANY monitoring analysis:
├─ Data sources accessible?
│  ├─ MT5 logs readable -> CONTINUE
│  ├─ Trade history queryable -> CONTINUE
│  ├─ Account metrics available -> CONTINUE
│  └─ Any source unavailable -> WARN and proceed with available data
├─ Baseline data sufficient?
│  ├─ > 50 trades in history -> Full analysis
│  ├─ 20-50 trades -> Limited analysis (note reduced confidence)
│  └─ < 20 trades -> Basic health check only (insufficient data for drift detection)
├─ Alert channels configured?
│  ├─ Telegram token + chat ID valid -> CONTINUE
│  ├─ Discord webhook URL valid -> CONTINUE
│  └─ No channels configured -> LOG locally + WARN to set up alerts
└─ Heartbeat file writable?
   ├─ File system accessible -> CONTINUE
   └─ Write failure -> CRITICAL (file system issue)
```

### Alert Quality Rules

```
Before sending ANY alert:
├─ Is this a duplicate of an alert sent in the last 10 minutes?
│  ├─ Yes -> SUPPRESS (batch into summary at next interval)
│  └─ No -> SEND
├─ Alert rate > 10 per minute?
│  ├─ Yes -> BATCH remaining into summary, send once
│  └─ No -> SEND individually
├─ Is this CRITICAL/EMERGENCY during quiet hours?
│  ├─ Yes -> SEND anyway (never suppress critical alerts)
│  └─ N/A
├─ Does message include: severity, metric value, threshold, action?
│  ├─ Yes -> SEND
│  └─ No -> ADD missing context before sending
└─ Is recommended action specific and actionable?
   ├─ Yes -> SEND
   └─ No -> Rewrite to be actionable (e.g., "reduce lot by 30%" not "be careful")
```

### Common Monitoring Failures

| Failure | Cause | Resolution |
|---|---|---|
| False positive alerts | Threshold too tight | Increase threshold by 20%, add hysteresis |
| Alert fatigue | Too many INFO alerts | Reduce INFO to daily summary, keep WARN+ real-time |
| Missed anomaly | Detection window too short | Extend rolling window from 10 to 50 trades |
| Late alert | Heartbeat interval too long | Reduce from 60s to 30s for critical EAs |
| Telegram send failure | Token expired or URL not allowed | Re-verify bot token; check MT5 URL whitelist |
| Discord send failure | Webhook deleted or rate-limited | Create new webhook; implement exponential backoff |
| Heartbeat file stale | EA crashed silently | External watchdog (Windows Task Scheduler) to check file age |
| Metrics baseline drift | Not updating baseline periodically | Recalculate baseline monthly from recent 200 trades |

### Quality Checklist (Execute Before Delivering Output)

```
[ ] All data sources queried (logs, trades, account, connection)
[ ] Metrics compared against baselines with Z-scores where applicable
[ ] Anomaly detection run across all categories
[ ] Issue classified into CODE / MARKET / INFRA
[ ] Appropriate runbook rule identified and action determined
[ ] Alert severity matches the actual risk level
[ ] Alert message includes: severity, value, threshold, recommended action
[ ] No duplicate alerts sent within suppression window
[ ] Output Contract JSON is valid and complete
[ ] Recommendations are specific, actionable, and time-bounded
[ ] Next check time scheduled
```

---

## References

- MQL5 Documentation: https://www.mql5.com/en/docs
- MQL5 Trade Events: https://www.mql5.com/en/docs/event_handlers
- MQL5 WebRequest: https://www.mql5.com/en/docs/network/webrequest
- MQL5 Calendar API: https://www.mql5.com/en/docs/calendar
- Telegram Bot API: https://core.telegram.org/bots/api
- Discord Webhook API: https://discord.com/developers/docs/resources/webhook
- Myfxbook API: https://www.myfxbook.com/api
- TradingFXVPS: https://tradingfxvps.com
- ForexVPS.net: https://forexvps.net

---

<!-- STATIC CONTEXT BLOCK END -->
