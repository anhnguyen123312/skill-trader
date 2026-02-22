---
name: mt5-ea-coder
description: Generate production-quality MQL5 Expert Advisor code from formal strategy specifications for XAUUSD trading. Use when user needs EA code generation, MQL5 implementation, code review, EA architecture design, module scaffolding, or converting strategy specs to compilable code. Triggers include "write EA", "generate MQL5 code", "implement strategy", "EA code", "create indicator", "MQL5 module", "code review EA". Do NOT use for strategy research or backtesting -- use strategy-researcher for research and ea-backtest-analyst for testing.
---

# MT5 EA Coder

<!-- STATIC CONTEXT BLOCK START - Optimized for prompt caching -->
<!-- All static instructions, code patterns, and MQL5 references below this line -->
<!-- Dynamic content (strategy specs, user requirements) added after this block -->

## Core System Instructions

**Purpose:** Generate production-quality, compilable MQL5 Expert Advisor code from formal strategy specifications (JSON specs produced by strategy-spec-risk). Every output must compile without errors in MetaEditor, follow MQL5 best practices, and be structured for maintainability and backtesting.

**Context Strategy:** This skill uses context engineering best practices:
- Static code patterns and templates cached (this section)
- Progressive disclosure (load strategy spec details only when needed)
- Critical compile rules at start and end (not buried)
- Explicit section markers for rapid navigation

**Domain:** XAUUSD (Gold/USD) on MetaTrader 5. Gold-specific coding considerations:
- Point value per standard lot: $1 per $0.01 move; $100 per $1.00 move (1 lot = 100 oz)
- Typical daily range: $20-$50 (normal), $50-$150+ (news/crisis)
- Spread: 10-40 points (ECN normal), 80-500+ points (news events)
- Contract: 1 lot = 100 oz, min lot = 0.01, lot step = 0.01
- Always use `_Symbol` and `SymbolInfoDouble()` -- never hardcode symbol properties
- SetDeviationInPoints: 50+ for XAUUSD (wider than forex pairs)
- ORDER_FILLING_IOC is the most compatible filling mode for gold

**Core Principles:**
1. **Compilable First** -- Code must compile with zero errors in MetaEditor strict mode. Warnings should be minimized.
2. **1:1 Spec Mapping** -- Every JSON spec field maps to exactly one MQL5 input variable or internal constant. No orphaned parameters.
3. **Defensive Coding** -- All trade operations must check return codes. All indicator handles must be validated. All array operations must check bounds.
4. **Modular Architecture** -- Separate concerns into .mqh include files: risk management, signal generation, order management, logging.
5. **XAUUSD Calibrated** -- All defaults and magic numbers calibrated for gold characteristics (spread, volatility, pip value).
6. **Backtest Ready** -- Code must produce identical results in Strategy Tester as in live. Avoid time-dependent randomness, ensure deterministic behavior.

**What This Skill Does:**
- Generates complete EA .mq5 files from strategy specifications
- Creates modular .mqh include files for reusable components
- Implements indicator handle management with proper lifecycle
- Writes position sizing, risk management, and order management code
- Adds news filters, session filters, and spread filters
- Implements trailing stop strategies and partial close logic
- Adds logging and notification systems (Discord/Telegram)
- Reviews existing EA code for bugs, inefficiencies, and MQL5 anti-patterns

**What This Skill Does NOT Do:**
- Conduct market research (that is strategy-researcher's job)
- Define strategy logic or risk parameters (that is strategy-spec-risk's job)
- Run backtests or analyze results (that is ea-backtest-analyst's job)
- Monitor live EA performance (that is ea-ops-monitor's job)

---

## Decision Tree (Execute First)

```
Request Analysis
├─ "Write a complete EA from spec" -> Full Generation Mode (10-20 min)
│  └─ Parse JSON spec, generate all files, compile check
├─ "Create a module/component" -> Module Mode (5-10 min)
│  └─ Single .mqh file with specific functionality
├─ "Review/fix EA code" -> Review Mode (5-10 min)
│  └─ Read code, identify issues, provide fixes
├─ "Add feature to existing EA" -> Enhancement Mode (5-10 min)
│  └─ Read existing code, integrate new feature, maintain structure
└─ "Quick code snippet" -> Snippet Mode (1-2 min)
   └─ Isolated function or pattern

Input Validation
├─ Strategy spec (JSON) provided? -> Parse and validate fields
├─ No spec but clear requirements? -> Generate inline, note assumptions
├─ Existing code to modify? -> Read first, then edit
└─ Ambiguous request? -> Ask for clarification (strategy type, timeframe, risk)

Architecture Decision
├─ Simple strategy (1-2 indicators)? -> Single .mq5 file
├─ Medium strategy (3-5 indicators + filters)? -> Main .mq5 + 2-3 .mqh modules
└─ Complex strategy (6+ indicators, ML, multi-TF)? -> Full modular architecture
```

---

## Workflow (Receive Spec -> Architect -> Implement -> Verify -> Deliver)

**AUTONOMY PRINCIPLE:** This skill operates independently for code generation. Use sensible defaults for any unspecified parameters. Only stop for contradictory specs or impossible requirements.

### 1. Receive & Parse Strategy Specification

**From strategy-spec-risk JSON spec, extract:**
- Entry conditions (indicators, thresholds, logic operators)
- Exit conditions (TP, SL, trailing, time exit, signal exit)
- Filters (news, session, spread, volatility, trend alignment)
- Risk rules (per-trade, daily, weekly, drawdown limits)
- Position sizing (formula, lot constraints)
- Input parameters (name, type, default, min, max, step, group)

**Default assumptions when not specified:**
- Timeframe: H1
- Risk per trade: 1%
- Max drawdown: 15%
- Magic number: auto-generate from EA name hash
- Spread filter: 50 points max
- Session: London + NY only

### 2. Architect

Choose file structure based on complexity:

```
Simple EA:
  EA_Name.mq5              (single file, everything inline)

Standard EA:
  EA_Name.mq5              (main file: OnInit, OnTick, OnDeinit)
  Modules/
    SignalEngine.mqh        (indicator logic, signal generation)
    RiskManager.mqh         (position sizing, drawdown checks)
    OrderManager.mqh        (trade execution, trailing, partial close)

Complex EA:
  EA_Name.mq5              (main orchestrator)
  Modules/
    SignalEngine.mqh        (indicator handles, signal scoring)
    RiskManager.mqh         (position sizing, portfolio heat)
    OrderManager.mqh        (execution, modification, closing)
    FilterEngine.mqh        (news, session, spread, volatility)
    Logger.mqh              (file + console logging)
    Notifier.mqh            (Discord/Telegram webhooks)
```

### 3. Implement

Generate code following the patterns in sections below.

### 4. Verify

```
Pre-delivery checklist:
├─ All indicator handles created in OnInit()? ✓
├─ All handles checked for INVALID_HANDLE? ✓
├─ All handles released in OnDeinit()? ✓
├─ ArraySetAsSeries() called for all buffers? ✓
├─ CopyBuffer() count ≥ required lookback? ✓
├─ All trade operations check result.retcode? ✓
├─ Magic number set on CTrade instance? ✓
├─ Position loop uses PositionsTotal() correctly? ✓
├─ No hardcoded symbol names (use _Symbol)? ✓
├─ No hardcoded lot sizes (use CalculateLotSize)? ✓
├─ Input parameters have descriptive comments? ✓
├─ Input groups organize logically? ✓
└─ Compiles without errors in strict mode? ✓
```

### 5. Deliver

Output the complete code with file structure and compilation instructions.

---

## MQL5 Event Model

### Event Handler Reference

| Handler | When Called | Typical Use |
|---------|------------|-------------|
| `OnInit()` | EA loaded / timeframe changed / inputs changed | Create indicator handles, initialize variables |
| `OnDeinit(const int reason)` | EA removed / chart closed / inputs changed | Release handles, clean up resources |
| `OnTick()` | Every new tick received | Main logic: check signals, manage positions |
| `OnTimer()` | Timer interval elapsed (set by EventSetTimer) | Heartbeat, periodic checks, notifications |
| `OnTrade()` | Trade event occurs | Position tracking, statistics update |
| `OnTradeTransaction()` | Detailed trade transaction | Slippage monitoring, fill confirmation |
| `OnChartEvent()` | Chart interaction | Dashboard buttons, manual overrides |

### Deinit Reason Codes

| Reason | Constant | Meaning |
|--------|----------|---------|
| 0 | REASON_PROGRAM | EA removed by user |
| 1 | REASON_REMOVE | EA removed from chart |
| 2 | REASON_RECOMPILE | EA recompiled |
| 3 | REASON_CHARTCHANGE | Symbol or timeframe changed |
| 4 | REASON_CHARTCLOSE | Chart closed |
| 5 | REASON_PARAMETERS | Input parameters changed |
| 6 | REASON_ACCOUNT | Account changed |

---

## EA Code Structure Template

```mql5
//+------------------------------------------------------------------+
//| EA_Name.mq5                                                       |
//| Copyright 2024-2025, EA-OAT                                       |
//+------------------------------------------------------------------+
#property copyright "EA-OAT"
#property link      ""
#property version   "1.00"
#property description "Strategy description here"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Input Parameters
input group "=== Entry Settings ==="
input int         InpEMAPeriodFast     = 9;        // Fast EMA Period
input int         InpEMAPeriodSlow     = 21;       // Slow EMA Period
input int         InpRSIPeriod         = 14;       // RSI Period
input int         InpATRPeriod         = 14;       // ATR Period
input double      InpRSIOverbought     = 70.0;     // RSI Overbought Level
input double      InpRSIOversold       = 30.0;     // RSI Oversold Level

input group "=== Exit Settings ==="
input double      InpTakeProfitRR      = 2.0;      // Take Profit (Risk:Reward)
input double      InpStopLossATRMult   = 2.0;      // Stop Loss (ATR Multiplier)
input bool        InpUseTrailingStop   = true;      // Enable Trailing Stop
input double      InpTrailingATRMult   = 1.5;      // Trailing Stop (ATR Mult)
input bool        InpUsePartialClose   = true;      // Enable Partial Close
input double      InpPartialCloseRR    = 1.0;      // Partial Close at RR
input double      InpPartialClosePct   = 50.0;     // Partial Close %

input group "=== Risk Management ==="
input double      InpRiskPercent       = 1.0;      // Risk Per Trade (%)
input double      InpMaxDailyDD        = 3.0;      // Max Daily Drawdown (%)
input double      InpMaxTotalDD        = 20.0;     // Max Total Drawdown (%)
input int         InpMaxConsecLosses   = 5;        // Max Consecutive Losses
input int         InpMaxDailyTrades    = 5;        // Max Daily Trades

input group "=== Filters ==="
input bool        InpUseNewsFilter     = true;      // Enable News Filter
input int         InpNewsBefore        = 30;       // Minutes Before News
input int         InpNewsAfter         = 30;       // Minutes After News
input bool        InpUseSessionFilter  = true;      // Enable Session Filter
input int         InpMaxSpreadPoints   = 50;       // Max Spread (Points)

input group "=== System ==="
input int         InpMagicNumber       = 123456;   // Magic Number
input int         InpSlippage          = 50;       // Max Slippage (Points)

//--- Global Variables
CTrade            g_trade;
CPositionInfo     g_position;
CSymbolInfo       g_symbol;

int               g_emaFastHandle;
int               g_emaSlowHandle;
int               g_rsiHandle;
int               g_atrHandle;

double            g_emaFastBuffer[];
double            g_emaSlowBuffer[];
double            g_rsiBuffer[];
double            g_atrBuffer[];

double            g_dailyStartEquity;
int               g_dailyTradeCount;
int               g_consecLosses;
double            g_peakEquity;
datetime          g_lastTradeDay;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Create indicator handles
    g_emaFastHandle = iMA(_Symbol, PERIOD_CURRENT, InpEMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE);
    g_emaSlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpEMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE);
    g_rsiHandle     = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    g_atrHandle     = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);

    //--- Validate handles
    if(g_emaFastHandle == INVALID_HANDLE || g_emaSlowHandle == INVALID_HANDLE ||
       g_rsiHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE)
    {
        Print("ERROR: Failed to create indicator handles");
        return INIT_FAILED;
    }

    //--- Set buffer directions
    ArraySetAsSeries(g_emaFastBuffer, true);
    ArraySetAsSeries(g_emaSlowBuffer, true);
    ArraySetAsSeries(g_rsiBuffer, true);
    ArraySetAsSeries(g_atrBuffer, true);

    //--- Configure trade object
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(InpSlippage);
    g_trade.SetTypeFilling(ORDER_FILLING_IOC);

    //--- Initialize symbol info
    g_symbol.Name(_Symbol);

    //--- Initialize daily tracking
    g_dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    g_dailyTradeCount  = 0;
    g_consecLosses     = 0;
    g_peakEquity       = AccountInfoDouble(ACCOUNT_EQUITY);
    g_lastTradeDay     = 0;

    //--- Start timer for heartbeat (60s)
    EventSetTimer(60);

    Print("EA initialized successfully on ", _Symbol);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handles
    if(g_emaFastHandle != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle);
    if(g_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle);
    if(g_rsiHandle != INVALID_HANDLE)     IndicatorRelease(g_rsiHandle);
    if(g_atrHandle != INVALID_HANDLE)     IndicatorRelease(g_atrHandle);

    EventKillTimer();
    Print("EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Refresh symbol info
    g_symbol.RefreshRates();

    //--- Reset daily counters on new day
    CheckNewDay();

    //--- Copy indicator buffers
    if(!RefreshIndicators()) return;

    //--- Check filters
    if(!PassFilters()) return;

    //--- Check risk limits
    if(!PassRiskChecks()) return;

    //--- Manage existing positions (trailing, partial close)
    ManagePositions();

    //--- Check for new signals (only if no open position)
    if(!HasOpenPosition())
    {
        int signal = GetSignal();
        if(signal == 1)       ExecuteBuy();
        else if(signal == -1) ExecuteSell();
    }
}

//+------------------------------------------------------------------+
//| Timer function (heartbeat)                                         |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Heartbeat log
    Print("HEARTBEAT: ", _Symbol, " | Equity: ",
          DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
          " | Positions: ", PositionsTotal());
}
```

---

## Indicator Handle Management

### Buffer Index Reference

| Indicator | MQL5 Function | Buffer 0 | Buffer 1 | Buffer 2 |
|-----------|---------------|----------|----------|----------|
| Moving Average | iMA() | MA value | - | - |
| RSI | iRSI() | RSI value | - | - |
| ATR | iATR() | ATR value | - | - |
| MACD | iMACD() | Main line | Signal line | - |
| Bollinger Bands | iBands() | Middle band | Upper band | Lower band |
| ADX | iADX() | ADX main | +DI | -DI |
| Stochastic | iStochastic() | %K (main) | %D (signal) | - |
| CCI | iCCI() | CCI value | - | - |
| Williams %R | iWPR() | WPR value | - | - |
| Ichimoku | iIchimoku() | Tenkan | Kijun | Senkou A |

### CopyBuffer Pattern

```mql5
bool RefreshIndicators()
{
    //--- Copy with count=3 for current + 2 previous bars
    if(CopyBuffer(g_emaFastHandle, 0, 0, 3, g_emaFastBuffer) < 3) return false;
    if(CopyBuffer(g_emaSlowHandle, 0, 0, 3, g_emaSlowBuffer) < 3) return false;
    if(CopyBuffer(g_rsiHandle, 0, 0, 3, g_rsiBuffer) < 3) return false;
    if(CopyBuffer(g_atrHandle, 0, 0, 3, g_atrBuffer) < 3) return false;
    return true;
}
```

**Critical Rules:**
- Always `ArraySetAsSeries(buffer, true)` so index 0 = current bar
- CopyBuffer returns the number of elements copied; always check it
- For crossover detection: compare `buffer[1]` vs `buffer[2]` (previous bars), not `buffer[0]` (forming bar)
- Multi-timeframe: create separate handles with explicit timeframe parameter

### Multi-Timeframe Handles

```mql5
// In OnInit():
int g_emaD1Handle = iMA(_Symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
int g_emaH4Handle = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
int g_emaH1Handle = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);

// Higher TF trend filter
bool IsHigherTFBullish()
{
    double emaD1[], emaH4[];
    ArraySetAsSeries(emaD1, true);
    ArraySetAsSeries(emaH4, true);

    if(CopyBuffer(g_emaD1Handle, 0, 0, 1, emaD1) < 1) return false;
    if(CopyBuffer(g_emaH4Handle, 0, 0, 1, emaH4) < 1) return false;

    double closeD1 = iClose(_Symbol, PERIOD_D1, 0);
    double closeH4 = iClose(_Symbol, PERIOD_H4, 0);

    return (closeD1 > emaD1[0]) && (closeH4 > emaH4[0]);
}
```

---

## Position Sizing for XAUUSD

```mql5
double CalculateLotSize(double stopLossPoints)
{
    if(stopLossPoints <= 0)
    {
        Print("ERROR: Invalid SL distance: ", stopLossPoints);
        return 0;
    }

    double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = equity * InpRiskPercent / 100.0;

    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tickValue <= 0 || tickSize <= 0)
    {
        Print("ERROR: Invalid tick value/size");
        return 0;
    }

    double lotSize = riskAmount / (stopLossPoints / tickSize * tickValue);

    //--- Normalize to broker limits
    double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);   // 0.01
    double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);   // 100
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);  // 0.01

    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

    return lotSize;
}
```

**XAUUSD Lot Size Examples (1% risk on $10,000 account):**

| SL Distance | Risk Amount | Approx Lot Size |
|-------------|-------------|-----------------|
| 100 points ($1.00) | $100 | 1.00 lot |
| 200 points ($2.00) | $100 | 0.50 lot |
| 500 points ($5.00) | $100 | 0.20 lot |
| 1000 points ($10.00) | $100 | 0.10 lot |
| 2000 points ($20.00) | $100 | 0.05 lot |

---

## Order Management

### Trade Execution with Error Handling

```mql5
bool SafeOrderSend(ENUM_ORDER_TYPE type, double lots, double price,
                   double sl, double tp, string comment)
{
    int retries = 3;
    for(int i = 0; i < retries; i++)
    {
        ResetLastError();
        bool success = false;

        if(type == ORDER_TYPE_BUY)
            success = g_trade.Buy(lots, _Symbol, price, sl, tp, comment);
        else
            success = g_trade.Sell(lots, _Symbol, price, sl, tp, comment);

        uint retcode = g_trade.ResultRetcode();

        if(success && retcode == TRADE_RETCODE_DONE)
        {
            Print("Order executed: ", comment, " | Ticket: ", g_trade.ResultOrder());
            return true;
        }

        //--- Handle specific errors
        switch(retcode)
        {
            case TRADE_RETCODE_REQUOTE:
            case TRADE_RETCODE_PRICE_OFF:
                Print("Requote/price changed. Retry ", i+1, "/", retries);
                Sleep(500);
                g_symbol.RefreshRates();
                price = (type == ORDER_TYPE_BUY) ? g_symbol.Ask() : g_symbol.Bid();
                continue;

            case TRADE_RETCODE_TIMEOUT:
                Print("Timeout. Retry ", i+1, "/", retries);
                Sleep(1000);
                continue;

            case TRADE_RETCODE_NO_MONEY:
                Print("ERROR: Insufficient margin");
                return false;

            case TRADE_RETCODE_MARKET_CLOSED:
                Print("ERROR: Market closed");
                return false;

            case TRADE_RETCODE_INVALID_STOPS:
                Print("ERROR: Invalid SL/TP. SL=", sl, " TP=", tp);
                return false;

            default:
                Print("ERROR: Trade failed. Code: ", retcode,
                      " Error: ", GetLastError());
                return false;
        }
    }
    Print("ERROR: Max retries exceeded");
    return false;
}
```

### Execute Buy/Sell

```mql5
void ExecuteBuy()
{
    double atr = g_atrBuffer[1]; // Previous bar ATR (confirmed)
    double sl  = g_symbol.Ask() - atr * InpStopLossATRMult;
    double tp  = g_symbol.Ask() + atr * InpStopLossATRMult * InpTakeProfitRR;

    double slDistance = g_symbol.Ask() - sl;
    double lots = CalculateLotSize(slDistance);
    if(lots <= 0) return;

    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);

    if(SafeOrderSend(ORDER_TYPE_BUY, lots, g_symbol.Ask(), sl, tp,
                     "Buy Signal"))
    {
        g_dailyTradeCount++;
    }
}

void ExecuteSell()
{
    double atr = g_atrBuffer[1];
    double sl  = g_symbol.Bid() + atr * InpStopLossATRMult;
    double tp  = g_symbol.Bid() - atr * InpStopLossATRMult * InpTakeProfitRR;

    double slDistance = sl - g_symbol.Bid();
    double lots = CalculateLotSize(slDistance);
    if(lots <= 0) return;

    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);

    if(SafeOrderSend(ORDER_TYPE_SELL, lots, g_symbol.Bid(), sl, tp,
                     "Sell Signal"))
    {
        g_dailyTradeCount++;
    }
}
```

### Position Enumeration

```mql5
bool HasOpenPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(g_position.SelectByIndex(i))
        {
            if(g_position.Symbol() == _Symbol &&
               g_position.Magic() == InpMagicNumber)
                return true;
        }
    }
    return false;
}

int CountOpenPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(g_position.SelectByIndex(i))
        {
            if(g_position.Symbol() == _Symbol &&
               g_position.Magic() == InpMagicNumber)
                count++;
        }
    }
    return count;
}
```

---

## Risk Management

### Daily Drawdown Check

```mql5
void CheckNewDay()
{
    MqlDateTime dt;
    TimeCurrent(dt);
    datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

    if(today != g_lastTradeDay)
    {
        g_lastTradeDay     = today;
        g_dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        g_dailyTradeCount  = 0;
    }
}

bool PassRiskChecks()
{
    //--- Daily drawdown check
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dailyDD = (g_dailyStartEquity - equity) / g_dailyStartEquity * 100.0;
    if(dailyDD >= InpMaxDailyDD)
    {
        Print("RISK: Daily DD limit reached: ", DoubleToString(dailyDD, 2), "%");
        return false;
    }

    //--- Total drawdown check (high-water-mark)
    g_peakEquity = MathMax(g_peakEquity, equity);
    double totalDD = (g_peakEquity - equity) / g_peakEquity * 100.0;
    if(totalDD >= InpMaxTotalDD)
    {
        Print("RISK: Total DD limit reached: ", DoubleToString(totalDD, 2), "%");
        return false;
    }

    //--- Consecutive losses check
    if(g_consecLosses >= InpMaxConsecLosses)
    {
        Print("RISK: Consecutive loss limit reached: ", g_consecLosses);
        return false;
    }

    //--- Daily trade count
    if(g_dailyTradeCount >= InpMaxDailyTrades)
    {
        Print("RISK: Daily trade limit reached: ", g_dailyTradeCount);
        return false;
    }

    return true;
}

void UpdateConsecLosses()
{
    if(!HistorySelect(0, TimeCurrent())) return;
    int total = HistoryDealsTotal();
    if(total <= 0) return;

    ulong ticket = HistoryDealGetTicket(total - 1);
    if(ticket == 0) return;

    //--- Only count deals from this EA
    if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) return;
    //--- Only count trade deals (ignore balance/credit)
    if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
    if(profit < 0)
        g_consecLosses++;
    else
        g_consecLosses = 0;
}
```

### Equity Curve Trading

```mql5
double g_equityCurve[];
double g_equityMA;

void UpdateEquityCurve()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    int size = ArraySize(g_equityCurve);
    ArrayResize(g_equityCurve, size + 1);
    g_equityCurve[size] = equity;

    int period = MathMin(20, ArraySize(g_equityCurve));
    g_equityMA = 0;
    for(int i = ArraySize(g_equityCurve) - period; i < ArraySize(g_equityCurve); i++)
        g_equityMA += g_equityCurve[i];
    g_equityMA /= period;
}

bool IsEquityCurveHealthy()
{
    return AccountInfoDouble(ACCOUNT_EQUITY) >= g_equityMA;
}
```

---

## Filters

### Spread Filter

```mql5
bool IsSpreadAcceptable()
{
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(spread > InpMaxSpreadPoints)
    {
        Print("FILTER: Spread too wide: ", spread, " > ", InpMaxSpreadPoints);
        return false;
    }
    return true;
}
```

### News Filter (MQL5 Calendar API)

```mql5
bool IsHighImpactNewsTime()
{
    if(!InpUseNewsFilter) return false;

    datetime now  = TimeCurrent();
    datetime from = now - InpNewsBefore * 60;
    datetime to   = now + InpNewsAfter * 60;

    MqlCalendarValue values[];
    if(!CalendarValueHistory(values, from, to)) return false;
    int count = ArraySize(values);

    for(int i = 0; i < count; i++)
    {
        MqlCalendarEvent event;
        CalendarEventById(values[i].event_id, event);

        MqlCalendarCountry country;
        CalendarCountryById(event.country_id, country);

        if(country.code == "US" && event.importance == CALENDAR_IMPORTANCE_HIGH)
            return true;
    }
    return false;
}
```

**Events to filter for XAUUSD:**

| Event | Impact | Pause Window |
|-------|--------|-------------|
| NFP (Non-Farm Payrolls) | 50-200+ pts spike | 60 min before/after |
| FOMC Rate Decision | 100-300 pts swing | 120 min before/after |
| CPI (Inflation) | 50-150 pts | 30 min before/after |
| GDP | 30-80 pts | 30 min before/after |
| Jobless Claims | 20-50 pts | 15 min before/after |
| Fed Chair Speech | Variable | 30 min before/after |

### Session Filter

```mql5
enum ENUM_SESSION { SESSION_ASIAN, SESSION_LONDON, SESSION_NEWYORK, SESSION_OVERLAP };

ENUM_SESSION GetCurrentSession()
{
    MqlDateTime dt;
    TimeGMT(dt);
    int hour = dt.hour;

    if(hour >= 13 && hour < 16) return SESSION_OVERLAP;   // London+NY overlap
    if(hour >= 8 && hour < 13)  return SESSION_LONDON;    // London only (pre-overlap)
    if(hour >= 16 && hour < 22) return SESSION_NEWYORK;   // NY only (post-overlap)
    return SESSION_ASIAN;                                  // 22:00-08:00
}

bool IsSessionActive()
{
    if(!InpUseSessionFilter) return true;
    ENUM_SESSION session = GetCurrentSession();
    return (session == SESSION_LONDON ||
            session == SESSION_NEWYORK ||
            session == SESSION_OVERLAP);
}
```

**XAUUSD Session Characteristics:**

| Session | GMT Hours | Volatility | Characteristics |
|---------|-----------|-----------|-----------------|
| Asian | 00:00-08:00 | Low (9-15 pts) | Range-bound, accumulation |
| London | 08:00-16:00 | Medium (12-20 pts) | Trend formation, breakout |
| NY | 13:00-22:00 | High (18-28 pts) | Strongest moves |
| London-NY Overlap | 13:00-16:00 | Very high (20-30+ pts) | Peak volatility |

### Combined Filter Check

```mql5
bool PassFilters()
{
    if(!IsSpreadAcceptable()) return false;
    if(IsHighImpactNewsTime()) return false;
    if(!IsSessionActive()) return false;
    return true;
}
```

---

## Trailing Stop Implementations

### ATR-Based Trailing

```mql5
void ATRTrailingStop(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;

    double atr = g_atrBuffer[1];
    double trailDistance = atr * InpTrailingATRMult;
    double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL   = PositionGetDouble(POSITION_SL);
    double currentTP   = PositionGetDouble(POSITION_TP);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);

    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
        double newSL = NormalizeDouble(currentPrice - trailDistance, _Digits);
        if(newSL > openPrice && (currentSL == 0 || newSL > currentSL))
            g_trade.PositionModify(ticket, newSL, currentTP);
    }
    else // SELL
    {
        double newSL = NormalizeDouble(currentPrice + trailDistance, _Digits);
        if(newSL < openPrice && (currentSL == 0 || newSL < currentSL))
            g_trade.PositionModify(ticket, newSL, currentTP);
    }
}
```

### Partial Close at RR + Trail Remainder

```mql5
void CheckPartialClose(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return;

    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl        = PositionGetDouble(POSITION_SL);
    double price     = PositionGetDouble(POSITION_PRICE_CURRENT);
    double volume    = PositionGetDouble(POSITION_VOLUME);

      if(sl == 0) return;  // No SL set, cannot calculate RR target

    double riskDistance = MathAbs(openPrice - sl);
    double profitDistance = 0;

    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        profitDistance = price - openPrice;
    else
        profitDistance = openPrice - price;

    //--- Partial close at target RR
    if(profitDistance >= riskDistance * InpPartialCloseRR && volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
    {
        double closeLots = MathFloor(volume * InpPartialClosePct / 100.0 /
                           SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) *
                           SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

        if(closeLots >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            g_trade.PositionClosePartial(ticket, closeLots);
            //--- Move SL to breakeven
            g_trade.PositionModify(ticket, openPrice,
                                   PositionGetDouble(POSITION_TP));
        }
    }
}
```

### Manage All Positions

```mql5
void ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!g_position.SelectByIndex(i)) continue;
        if(g_position.Symbol() != _Symbol) continue;
        if(g_position.Magic() != InpMagicNumber) continue;

        ulong ticket = g_position.Ticket();

        if(InpUsePartialClose) CheckPartialClose(ticket);
        if(InpUseTrailingStop) ATRTrailingStop(ticket);
    }
}
```

---

## Logging System

```mql5
enum ENUM_LOG_LEVEL { LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR };

void Log(ENUM_LOG_LEVEL level, string message)
{
    string prefix[] = {"[DEBUG]", "[INFO]", "[WARN]", "[ERROR]"};
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    string logLine = StringFormat("%s %s %s", timestamp, prefix[level], message);

    //--- Console output
    Print(logLine);

    //--- File output
    string filename = "EA_Log_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    int handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
    if(handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        FileWrite(handle, timestamp, prefix[level], message);
        FileClose(handle);
    }
}
```

---

## Notification System

### Discord Webhook

```mql5
bool SendDiscordMessage(string message)
{
    string url = InpDiscordWebhookURL;  // input string InpDiscordWebhookURL
    string headers = "Content-Type: application/json\r\n";
    string payload = "{\"content\":\"" + message + "\"}";

    char data[];
    StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);

    char result[];
    string resultHeaders;

    int res = WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
    return (res == 204);
}
```

### Telegram Bot

```mql5
bool SendTelegramMessage(string botToken, string chatId, string message)
{
    string url = "https://api.telegram.org/bot" + botToken + "/sendMessage";
    string headers = "Content-Type: application/json\r\n";
    string payload = "{\"chat_id\":\"" + chatId + "\",\"text\":\"" + message + "\"}";

    char data[];
    StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);

    char result[];
    string resultHeaders;

    int res = WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
    return (res == 200);
}
```

**Note:** Add URLs to MT5 Options -> Expert Advisors -> Allow WebRequest for listed URLs.

---

## ONNX Integration

```mql5
#resource "\\Files\\gold_model.onnx" as uchar OnnxModel[]

long g_onnxHandle;

int InitOnnx()
{
    g_onnxHandle = OnnxCreate(OnnxModel, ONNX_DEFAULT);
    if(g_onnxHandle == INVALID_HANDLE)
    {
        Print("Failed to load ONNX model");
        return INIT_FAILED;
    }

    long inputShape[]  = {1, 10};
    long outputShape[] = {1, 3};
    OnnxSetInputShape(g_onnxHandle, 0, inputShape);
    OnnxSetOutputShape(g_onnxHandle, 0, outputShape);

    return INIT_SUCCEEDED;
}

int PredictSignal()
{
    float features[10];
    features[0] = (float)g_rsiBuffer[1];
    features[1] = (float)g_atrBuffer[1];
    features[2] = (float)(g_emaFastBuffer[1] - g_emaSlowBuffer[1]);
    // ... additional features

    float output[3]; // [buy_prob, sell_prob, hold_prob]
    OnnxRun(g_onnxHandle, ONNX_DEFAULT, features, output);

    if(output[0] > 0.7) return 1;   // BUY
    if(output[1] > 0.7) return -1;  // SELL
    return 0;                        // HOLD
}
```

---

## Code Quality Standards

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Input parameters | `Inp` prefix + PascalCase | `InpRiskPercent` |
| Global variables | `g_` prefix + camelCase | `g_emaFastHandle` |
| Local variables | camelCase | `lotSize` |
| Functions | PascalCase | `CalculateLotSize()` |
| Enums | `ENUM_` prefix + UPPER_SNAKE | `ENUM_SESSION` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRIES` |
| Include files | PascalCase.mqh | `RiskManager.mqh` |

### Common MQL5 Errors

| Error Code | Constant | Meaning | Resolution |
|------------|----------|---------|------------|
| 4756 | ERR_TRADE_SEND_FAILED | Trade request failed | Check retcode, retry |
| 10004 | TRADE_RETCODE_REQUOTE | Price changed | Refresh price, retry |
| 10006 | TRADE_RETCODE_REJECT | Request rejected | Check params, retry |
| 10007 | TRADE_RETCODE_CANCEL | Cancelled by trader | Don't retry |
| 10010 | TRADE_RETCODE_DONE | Success | Continue |
| 10013 | TRADE_RETCODE_INVALID_STOPS | Invalid SL/TP | Check stop level |
| 10014 | TRADE_RETCODE_INVALID_VOLUME | Invalid lot size | Check min/max/step |
| 10015 | TRADE_RETCODE_INVALID_PRICE | Invalid price | Refresh rates |
| 10016 | TRADE_RETCODE_NO_MONEY | Insufficient margin | Reduce lot size |
| 10018 | TRADE_RETCODE_MARKET_CLOSED | Market closed | Wait for market open |

### Common Compilation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `'xxx' - undeclared identifier` | Missing variable/function | Check spelling, add declaration |
| `'xxx' - function not defined` | Missing include file | Add `#include <xxx.mqh>` |
| `possible loss of data due to type conversion` | Implicit cast | Use explicit cast: `(int)value` |
| `array required` | Using `[]` on non-array | Check variable type |
| `constant cannot be modified` | Modifying const/input | Use local copy |
| `'OnInit' - wrong parameters count` | Wrong OnInit signature | Use `int OnInit()` |

---

## Output Contract

```json
{
  "ea_name": "string (e.g., 'GoldTrendFollower_v1')",
  "version": "string (e.g., '1.00')",
  "strategy_spec_ref": "string (JSON spec filename or hash)",
  "architecture": "simple | standard | complex",
  "files": [
    {
      "filename": "GoldTrendFollower_v1.mq5",
      "type": "expert",
      "description": "Main EA file with event handlers"
    },
    {
      "filename": "Modules/SignalEngine.mqh",
      "type": "include",
      "description": "Indicator logic and signal generation"
    },
    {
      "filename": "Modules/RiskManager.mqh",
      "type": "include",
      "description": "Position sizing, drawdown checks, risk limits"
    },
    {
      "filename": "Modules/OrderManager.mqh",
      "type": "include",
      "description": "Trade execution, trailing, partial close"
    }
  ],
  "input_parameters": [
    {
      "name": "InpRiskPercent",
      "type": "double",
      "default": 1.0,
      "min": 0.1,
      "max": 5.0,
      "step": 0.1,
      "group": "Risk Management",
      "mql5_declaration": "input double InpRiskPercent = 1.0; // Risk Per Trade (%)"
    }
  ],
  "indicator_handles": [
    {
      "name": "g_emaFastHandle",
      "function": "iMA",
      "params": {"period": "InpEMAPeriodFast", "method": "MODE_EMA"},
      "buffers_used": [0]
    }
  ],
  "compilation_checks": {
    "strict_mode": true,
    "warnings_as_errors": false,
    "target_build": "4000+",
    "required_includes": ["Trade\\Trade.mqh"]
  },
  "filters_enabled": ["spread", "news", "session"],
  "risk_modules": ["daily_dd", "total_dd", "consec_loss", "daily_trade_limit"]
}
```

---

## Error Handling & Quality Standards

### Pre-Generation Validation

```
Before generating ANY code:
├─ Strategy spec provided and parseable? -> CONTINUE
├─ All entry conditions have indicator + threshold? -> CONTINUE
├─ All exit conditions defined (at minimum SL + TP)? -> CONTINUE
├─ Risk parameters within safe bounds? -> CONTINUE
│  ├─ Risk per trade: 0.1% to 5.0% (warn > 2%)
│  ├─ Max DD: 5% to 50% (warn > 30%)
│  └─ Max daily trades: 1 to 50 (warn > 20)
├─ Any condition missing? -> Use default, note assumption in comment
└─ Contradictory conditions? -> STOP, request clarification
```

### Post-Generation Quality Checklist

```
[ ] All indicator handles created in OnInit() and validated
[ ] All handles released in OnDeinit()
[ ] ArraySetAsSeries() called for every buffer
[ ] CopyBuffer() return value checked
[ ] All trade operations use SafeOrderSend pattern
[ ] Magic number set on CTrade object
[ ] Position loop iterates backwards (i = Total-1; i >= 0; i--)
[ ] No hardcoded symbol names (always _Symbol)
[ ] No hardcoded lot sizes (always CalculateLotSize)
[ ] NormalizeDouble() used for all price comparisons
[ ] Input parameters have descriptive comments
[ ] Input parameters organized in groups
[ ] Logging system included for trade events
[ ] Spread check before every trade entry
[ ] Code compiles without errors in strict mode
```

### Common Mistakes to Avoid

| Mistake | Why It's Wrong | Correct Pattern |
|---------|---------------|-----------------|
| Using `iMA()` return directly as price | Returns handle, not value | Use `CopyBuffer()` to get value |
| Comparing doubles with `==` | Floating point precision | Use `MathAbs(a-b) < _Point` |
| Not checking `PositionSelect` result | May fail silently | Always check return boolean |
| Looping positions forward (0 to Total) | Index shifts when closing | Loop backward (Total-1 to 0) |
| Using `Sleep()` in OnTick() | Blocks tick processing | Use timer or state flags |
| Hardcoding spread as 30 points | Spread varies by session/broker | Use `SymbolInfoInteger()` |
| Creating handles in OnTick() | Memory leak, performance | Create once in OnInit() |
| Forgetting `ArraySetAsSeries` | Index 0 = oldest bar | Always set for price-like data |

---

## References

- MQL5 Documentation: https://www.mql5.com/en/docs
- MQL5 Trade Classes: https://www.mql5.com/en/docs/standardlibrary/tradeclasses
- MQL5 Indicator Functions: https://www.mql5.com/en/docs/indicators
- MQL5 Calendar: https://www.mql5.com/en/docs/calendar
- ONNX in MQL5: https://www.mql5.com/en/docs/onnx
- MQL5 Articles: https://www.mql5.com/en/articles

---

<!-- STATIC CONTEXT BLOCK END -->

## Inputs & Assumptions

| Input | Source | Required | Default |
|-------|--------|----------|---------|
| Strategy Specification JSON | strategy-spec-risk output | YES | None |
| Target broker type | User/orchestrator | NO | Generic ECN |
| MT5 build version | User/orchestrator | NO | Latest stable |
| Existing EA code (for modification) | File system | NO | None |

**Standing Assumptions:**
- XAUUSD on MT5, 5-digit pricing (0.01 = 1 point)
- Point value: $1.00 per point per standard lot (100 oz)
- H1 primary timeframe unless strategy spec overrides
- Max drawdown default: 15% when no spec provided
- Risk per trade default: 1% when no spec provided

## Dynamic Execution Zone
<!-- Orchestrator injects per-task context below this line -->
