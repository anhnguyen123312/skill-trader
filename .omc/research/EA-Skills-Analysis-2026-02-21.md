# PHAN TICH CHI TIET KY NANG & CONG CU XAY DUNG EA XAUUSD

> Ngay: 2026-02-21 | Nguon: Perplexity Deep Research + GitHub claude-scientific-skills + MQL5 Docs

---

## MUC LUC

1. [Tong Quan Kien Truc EA](#1-tong-quan-kien-truc-ea)
2. [Skill 1: Lap Trinh MQL4/MQL5](#2-skill-1-lap-trinh-mql4mql5)
3. [Skill 2: Chien Luoc Giao Dich (Strategy)](#3-skill-2-chien-luoc-giao-dich)
4. [Skill 3: Quan Ly Rui Ro (Risk Management)](#4-skill-3-quan-ly-rui-ro)
5. [Skill 4: Quan Ly Lenh (Order Management)](#5-skill-4-quan-ly-lenh)
6. [Skill 5: Backtest & Toi Uu Hoa](#6-skill-5-backtest--toi-uu-hoa)
7. [Skill 6: Phan Tich Thi Truong](#7-skill-6-phan-tich-thi-truong)
8. [Skill 7: Xu Ly Loi & Logging](#8-skill-7-xu-ly-loi--logging)
9. [Skill 8: Multi-Timeframe Analysis](#9-skill-8-multi-timeframe-analysis)
10. [Skill 9: News Filter](#10-skill-9-news-filter)
11. [Skill 10: Session-Based Trading](#11-skill-10-session-based-trading)
12. [Skill 11: Phan Tich Du Lieu Nang Cao (Data Science)](#12-skill-11-phan-tich-du-lieu-nang-cao)
13. [Skill 12: Trien Khai & Giam Sat](#13-skill-12-trien-khai--giam-sat)
14. [Skill 13: Machine Learning & ONNX](#14-skill-13-machine-learning--onnx)
15. [Tong Hop Cong Cu & Thu Vien](#15-tong-hop-cong-cu--thu-vien)

---

## 1. TONG QUAN KIEN TRUC EA

### 1.1 Kien Truc Module Hoa (Modular Architecture)

EA chuyen nghiep duoc xay dung theo kien truc module, tach biet cac thanh phan:

```
EA-OAT-v5/
├── Expert/
│   ├── EA_Main.mq5              # Controller chinh
│   ├── Signals/
│   │   ├── SignalBase.mqh       # Base class cho signals
│   │   ├── SignalMA.mqh         # MA crossover signal
│   │   ├── SignalRSI.mqh        # RSI signal
│   │   └── SignalComposite.mqh  # Weighted scoring
│   ├── Risk/
│   │   ├── RiskManager.mqh      # Risk management module
│   │   ├── LotSizer.mqh         # Dynamic lot sizing
│   │   └── DrawdownGuard.mqh    # Max DD protection
│   ├── Orders/
│   │   ├── OrderManager.mqh     # Order execution
│   │   ├── TrailingStop.mqh     # Trailing stop logic
│   │   └── PartialClose.mqh    # Partial close logic
│   ├── Filters/
│   │   ├── NewsFilter.mqh       # News event filter
│   │   ├── SessionFilter.mqh    # Session-based filter
│   │   ├── SpreadFilter.mqh     # Spread filter
│   │   └── VolatilityFilter.mqh # ATR volatility filter
│   ├── Utils/
│   │   ├── Logger.mqh           # Logging system
│   │   ├── Notifier.mqh         # Discord/Telegram
│   │   └── StateManager.mqh     # State machine
│   └── Config/
│       └── Settings.mqh         # EA parameters
```

### 1.2 Design Patterns trong MQL5

| Pattern | Ung Dung | Mo Ta |
|---------|----------|-------|
| **Strategy** | Signal modules | `CExpertSignal` derived classes, doi logic entry/exit |
| **Factory** | Component creation | `InitSignal()`, `InitTrailing()`, `InitMoney()` |
| **Observer** | Event handling | Components `Update()` khi co tick moi |
| **State Machine** | Trade lifecycle | IDLE -> PENDING -> OPEN -> TRAILING -> CLOSING |
| **Composite** | Multi-signal | Ket hop nhieu signal voi weighted scoring |

### 1.3 Class Hierarchy (MQL5 Standard Library)

```
CObject
  └── CExpertBase (symbol, period, magic, series)
       ├── CExpert (main controller)
       ├── CExpertSignal (CheckOpenLong/Short, CheckCloseLong/Short)
       ├── CExpertTrailing (trailing stop logic)
       └── CExpertMoney (position sizing)
```

### 1.4 State Machine cho Trade Management

```mql5
enum TRADE_STATE {
    STATE_IDLE,      // Khong co vi the
    STATE_PENDING,   // Lenh cho
    STATE_OPEN,      // Vi the mo, chua trailing
    STATE_TRAILING,  // Vi the voi trailing SL
    STATE_CLOSING    // Dang dong vi the
};

TRADE_STATE currentState = STATE_IDLE;

void OnTick() {
    UpdateState();
    switch(currentState) {
        case STATE_IDLE:     CheckSignals(); break;
        case STATE_PENDING:  MonitorOrder(); break;
        case STATE_OPEN:     EnableTrailing(); break;
        case STATE_TRAILING: AdjustTrailingStop(); break;
        case STATE_CLOSING:  ExecuteClose(); break;
    }
}
```

---

## 2. SKILL 1: LAP TRINH MQL4/MQL5

### 2.1 Sub-skills Can Thiet

| Sub-skill | Mo Ta | Do Kho |
|-----------|-------|--------|
| Event-driven programming | `OnInit()`, `OnTick()`, `OnDeinit()`, `OnTimer()`, `OnTrade()` | Trung binh |
| OOP trong MQL5 | Classes, inheritance, virtual methods, interfaces | Cao |
| Indicator handles | `iMA()`, `iATR()`, `iRSI()`, `iMACD()`, `iBands()` | Co ban |
| Array management | Dynamic arrays, CopyBuffer, CopyRates, series arrays | Trung binh |
| Trade functions | CTrade class, PositionSelect, OrderSend, OrderModify | Trung binh |
| File I/O | FileOpen, FileWrite, FileRead cho logging | Co ban |
| Custom indicators | #property indicator, OnCalculate(), buffers | Cao |
| DLL imports | #import, WebRequest, external API calls | Cao |
| Error handling | GetLastError(), retry logic, ERR_TRADE codes | Trung binh |

### 2.2 Cong Cu Phat Trien

| Tool | Muc Dich | Link |
|------|----------|------|
| **MetaEditor** | IDE chinh, debugger, profiler | Built-in MT5 |
| **MQL5 Standard Library** | Trade, Expert, Signal classes | `<Trade\Trade.mqh>` |
| **MQL5 Cloud Network** | Distributed backtesting | mql5.com |
| **Git** | Version control cho MQL projects | github.com |

### 2.3 XAUUSD-Specific

```mql5
// Xu ly 5-digit broker cho vang
double GoldPoint() {
    return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    // Gold: 0.01 (2 decimal places)
}

// Normalize lots cho vang
double NormalizeLots(double lots) {
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);   // 0.01
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);   // 100.0
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); // 0.01
    lots = MathMax(minLot, MathMin(maxLot, lots));
    return NormalizeDouble(MathFloor(lots / lotStep) * lotStep, 2);
}

// Pip value cho 1 lot XAUUSD ~ $10
double PipValue() {
    return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) *
           (GoldPoint() / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
}
```

---

## 3. SKILL 2: CHIEN LUOC GIAO DICH

### 3.1 Cac Chien Luoc Pho Bien cho XAUUSD

| Chien Luoc | Timeframe | Mo Ta | Win Rate |
|------------|-----------|-------|----------|
| **MA Crossover** | H1/H4 | 9/15 EMA cross, filter ADX>25 | 55-60% |
| **Bollinger Breakout** | M15/H1 | Price break upper/lower band | 50-55% |
| **Supply/Demand Zones** | H4/D1 | Tim vung cung/cau, trade reversal | 60-65% |
| **London Breakout** | M15 | Trade pha vung Asian range tai London open | 55-60% |
| **RSI Divergence** | H1/H4 | Tim phan ky RSI voi gia | 60-65% |
| **ATR Channel** | H1 | Keltner Channel voi ATR dynamic | 55-58% |

### 3.2 Weighted Scoring System

```mql5
// Multi-indicator signal scoring
double CalculateSignalScore() {
    double score = 0;

    // Trend (weight 40%)
    if(ema9 > ema21) score += 40;
    else if(ema9 < ema21) score -= 40;

    // Momentum (weight 30%)
    if(rsi > 50 && rsi < 70) score += 30;
    else if(rsi < 50 && rsi > 30) score -= 30;

    // Volatility (weight 20%)
    if(atr > atrAvg * 1.2) score += 20; // High vol = trending

    // Volume (weight 10%)
    if(volume > volumeAvg) score += 10;

    return score; // [-100, +100]
}

// Entry khi score > 70 (buy) hoac < -70 (sell)
```

### 3.3 Signal Confirmation Logic

```
Entry Conditions (Buy):
1. Higher TF trend (H4): Price > EMA200 ✓
2. Signal TF (H1): EMA9 cross above EMA21 ✓
3. Momentum: RSI(14) > 50 ✓
4. Volatility: ATR(14) > threshold ✓
5. Filter: Not in news window ✓
6. Filter: Session = London/NY ✓
7. Filter: Spread < max_spread ✓
=> All confirmed => OPEN BUY
```

### 3.4 Tools cho Strategy Development

| Tool | Muc Dich |
|------|----------|
| **TradingView** | Pine Script prototyping, visualize strategies |
| **MT5 Strategy Tester** | Backtest chien luoc |
| **QuantAnalyzer** | Phan tich ket qua backtest |
| **Python + pandas-ta** | Tinh indicator, thong ke |
| **Jupyter Notebook** | Interactive analysis |

---

## 4. SKILL 3: QUAN LY RUI RO

### 4.1 Dynamic Lot Sizing (ATR-Based cho Gold)

```mql5
double CalculateLotSize(double riskPercent, double slPoints) {
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = accountEquity * riskPercent / 100.0; // 1-2%

    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // SL in points -> tick value
    double pipValue = tickValue * (point / tickSize);
    double lotSize = riskAmount / (slPoints * pipValue);

    return NormalizeLots(lotSize);
}

// ATR-based SL cho gold
double slPoints = iATR(_Symbol, PERIOD_H1, 14, 0) * 1.5; // 1.5x ATR
double lots = CalculateLotSize(1.5, slPoints / _Point);   // Risk 1.5%
```

### 4.2 Risk Management Rules cho XAUUSD

| Quy Tac | Gia Tri | Ly Do |
|---------|---------|-------|
| Max risk/trade | 1-2% equity | Gold volatility cao, spike lon |
| Max daily loss | 5-7% equity | Dung giao dich khi thua qua nhieu |
| Max positions | 2-3 cung luc | Tranh over-exposure |
| Max drawdown | 15-20% | Ngung EA, review strategy |
| Min R:R | 1:1.5 tro len | Dam bao positive expectancy |
| Recovery factor | > 2.0 | Tieu chi backtest |

### 4.3 Equity Curve Trading

```mql5
// Dung giao dich khi equity curve duoi MA
double equityCurve[];  // Luu equity sau moi trade
double equityMA = 0;

void UpdateEquityCurve() {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    ArrayResize(equityCurve, ArraySize(equityCurve) + 1);
    equityCurve[ArraySize(equityCurve)-1] = equity;

    // Tinh MA20 cua equity curve
    int period = MathMin(20, ArraySize(equityCurve));
    equityMA = 0;
    for(int i = ArraySize(equityCurve)-period; i < ArraySize(equityCurve); i++)
        equityMA += equityCurve[i];
    equityMA /= period;
}

bool IsEquityCurveHealthy() {
    return AccountInfoDouble(ACCOUNT_EQUITY) >= equityMA;
}
```

---

## 5. SKILL 4: QUAN LY LENH

### 5.1 Gold-Specific Spread Handling

```mql5
double GetCurrentSpread() {
    return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
    // Normal: 20-40 points (0.20-0.40)
    // News: 100-500 points (1.00-5.00)
}

bool IsSpreadAcceptable(int maxSpreadPoints = 50) {
    return (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= maxSpreadPoints;
}

// Dac diem XAUUSD
// Spread binh thuong: 0.0-0.4 pips (ECN)
// Spread tin tuc: 1-5 pips
// Pip value 1 lot: ~$10
// Min lot: 0.01 (micro)
```

### 5.2 Trailing Stop Strategies

| Kieu Trailing | Mo Ta | Phu Hop |
|---------------|-------|---------|
| **Classic** | Di chuyen SL theo gia, giu khoang cach co dinh | Trending market |
| **ATR-based** | SL = Price - ATR*multiplier, tu dong dieu chinh | Volatile gold |
| **Chandelier** | Highest High - ATR*3, trailing tu dinh | Strong trends |
| **Breakeven + Trail** | Move SL to BE tai 1:1, trail sau do | Conservative |
| **Partial Close** | Dong 50% tai 1:1 RR, trail phan con lai | Balanced |

```mql5
// ATR Trailing Stop
void ATRTrailingStop(ulong ticket, int atrPeriod=14, double multiplier=2.0) {
    double atr = iATR(_Symbol, PERIOD_CURRENT, atrPeriod, 0);

    if(PositionSelectByTicket(ticket)) {
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);

        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            double newSL = currentPrice - atr * multiplier;
            if(newSL > currentSL && newSL > openPrice) { // Chi move len
                trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
        }
    }
}
```

### 5.3 Partial Close

```mql5
// Dong 50% tai 1:1 RR
void CheckPartialClose(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return;

    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double volume = PositionGetDouble(POSITION_VOLUME);

    double riskDistance = MathAbs(openPrice - sl);
    double profitDistance = 0;

    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        profitDistance = currentPrice - openPrice;
    else
        profitDistance = openPrice - currentPrice;

    // Khi dat 1:1 RR, dong 50%
    if(profitDistance >= riskDistance && volume > 0.01) {
        double closeVolume = NormalizeLots(volume * 0.5);
        trade.PositionClosePartial(ticket, closeVolume);
        // Move SL to breakeven
        trade.PositionModify(ticket, openPrice, PositionGetDouble(POSITION_TP));
    }
}
```

---

## 6. SKILL 5: BACKTEST & TOI UU HOA

### 6.1 MT5 Strategy Tester

| Cai Dat | Gia Tri | Ghi Chu |
|---------|---------|---------|
| Model | Every tick based on real ticks | Chinh xac nhat cho gold |
| Spread | Variable (20-50 points) | Phan anh thuc te |
| Deposit | $10,000 | Realistic account size |
| Leverage | 1:100 - 1:500 | Tuy broker |
| Period | 2020-2025 | Bao gom COVID, rate hikes |
| Optimization | Genetic algorithm | Nhanh hon exhaustive |

### 6.2 Metrics Can Danh Gia

| Metric | Muc Tot | Mo Ta |
|--------|---------|-------|
| Profit Factor | > 1.5 | Tong profit / tong loss |
| Sharpe Ratio | > 1.0 | Risk-adjusted return |
| Max Drawdown | < 20% | Toi da mat mat tu dinh |
| Recovery Factor | > 2.0 | Net profit / max DD |
| Win Rate | > 50% | Ty le thang |
| Avg Win/Loss | > 1.5 | Trung binh thang/thua |
| Total Trades | > 200 | Du sample size |

### 6.3 Walk-Forward Analysis

```
Quy trinh Walk-Forward:
1. Chia data thanh cac window (VD: 6 thang optimize + 3 thang test)
2. Optimize parameters tren in-sample
3. Test tren out-of-sample
4. Truot window, lap lai
5. Danh gia out-of-sample performance

Window 1: [Jan-Jun 2023 optimize] [Jul-Sep 2023 test]
Window 2: [Apr-Sep 2023 optimize] [Oct-Dec 2023 test]
Window 3: [Jul-Dec 2023 optimize] [Jan-Mar 2024 test]
...

Tieu chi: Out-of-sample PF > 70% cua in-sample PF
```

### 6.4 Tools

| Tool | Muc Dich |
|------|----------|
| **MT5 Strategy Tester** | Backtest + genetic optimization |
| **QuantAnalyzer** | Phan tich portfolio, monte carlo |
| **Tick Data Suite** | Du lieu tick chat luong 99% |
| **Python + backtrader** | Backtest ngoai MT5 |
| **Walk-Forward Analyzer** | Built-in MT5 |

---

## 7. SKILL 6: PHAN TICH THI TRUONG

### 7.1 Ky Thuat (Technical Analysis)

| Indicator | Muc Dich | Setting cho Gold |
|-----------|----------|-----------------|
| EMA 9/21/50/200 | Trend detection | Tat ca timeframe |
| RSI(14) | Overbought/oversold | 30/70 levels |
| ATR(14) | Volatility measure | Filter entry khi > 15 points |
| Bollinger Bands(20,2) | Breakout/reversion | H1/H4 |
| MACD(12,26,9) | Momentum | Confirm trend |
| ADX(14) | Trend strength | > 25 = trending |
| Stochastic(14,3,3) | Entry timing | M15/H1 |
| Volume | Confirmation | So voi average |

### 7.2 Co Ban (Fundamental Analysis)

| Yeu To | Anh Huong | Nguon Data |
|--------|-----------|-----------|
| **Fed Interest Rate** | Hawkish = gold giam, Dovish = gold tang | MQL5 Calendar |
| **NFP** | Spike 50-200+ points | MQL5 Calendar |
| **CPI/Inflation** | Inflation cao = gold tang | fredapi |
| **DXY (USD Index)** | Tuong quan am (-0.7 to -0.9) | Symbol USDX |
| **US 10Y Bond Yield** | Yield tang = gold giam | External API |
| **Geopolitical Risk** | Bat on = gold tang (safe haven) | News API |
| **Central Bank Gold Buying** | Mua rong = gold tang | WGC reports |

### 7.3 Sentiment Analysis

```mql5
// COT Report integration (manual)
// - Commercial positions: Smart money
// - Non-commercial: Speculators
// - Net long > extreme = potential top
// - Net short > extreme = potential bottom

// DXY Correlation Filter
double GetDXYCorrelation() {
    // Lay gia DXY tu symbol khac
    double dxy = iClose("USDX", PERIOD_D1, 0);
    if(dxy > 105) return -1; // Strong USD = bearish gold
    if(dxy < 95) return 1;   // Weak USD = bullish gold
    return 0; // Neutral
}
```

---

## 8. SKILL 7: XU LY LOI & LOGGING

### 8.1 Error Handling

```mql5
bool SafeOrderSend(MqlTradeRequest &request, MqlTradeResult &result) {
    int retries = 3;
    for(int i = 0; i < retries; i++) {
        ResetLastError();
        bool success = OrderSend(request, result);

        if(success && result.retcode == TRADE_RETCODE_DONE) return true;

        int error = GetLastError();
        switch(error) {
            case ERR_TRADE_TIMEOUT:
            case ERR_TRADE_RETCODE_REQUOTE:
                Sleep(1000); // Retry sau 1s
                continue;
            case ERR_TRADE_NOT_ENOUGH_MONEY:
                LogError("Khong du tien. Giam lot size.");
                return false;
            case ERR_TRADE_RETCODE_MARKET_CLOSED:
                LogError("Thi truong dong.");
                return false;
            default:
                LogError(StringFormat("Error %d: %s", error, ErrorDescription(error)));
                return false;
        }
    }
    return false;
}
```

### 8.2 Logging System

```mql5
enum LOG_LEVEL { LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR };

void Log(LOG_LEVEL level, string message) {
    string prefix[] = {"[DEBUG]", "[INFO]", "[WARN]", "[ERROR]"};
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    string logLine = StringFormat("%s %s %s", timestamp, prefix[level], message);

    // Console
    Print(logLine);

    // File
    int handle = FileOpen("EA_Log_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv",
                          FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI, ',');
    if(handle != INVALID_HANDLE) {
        FileSeek(handle, 0, SEEK_END);
        FileWrite(handle, timestamp, prefix[level], message);
        FileClose(handle);
    }
}
```

### 8.3 Slippage Monitoring

```mql5
// Giam sat slippage cho XAUUSD
void MonitorSlippage(double requestedPrice, double filledPrice) {
    double slippage = MathAbs(filledPrice - requestedPrice) / _Point;
    if(slippage > 10) { // > 10 points
        Log(LOG_WARN, StringFormat(
            "Slippage cao: %.0f points (req=%.2f, fill=%.2f)",
            slippage, requestedPrice, filledPrice));
        // Alert qua Discord
        SendDiscordAlert("Slippage Alert: " + DoubleToString(slippage, 0) + " points");
    }
}
```

---

## 9. SKILL 8: MULTI-TIMEFRAME ANALYSIS

### 9.1 MTF Framework

```
D1 (Daily)     -> Xac dinh xu huong lon (EMA200)
H4 (4-Hour)    -> Tim vung entry (Supply/Demand, EMA50)
H1 (1-Hour)    -> Signal entry (EMA9/21 cross, RSI)
M15 (15-Min)   -> Fine-tune entry point
M5  (5-Min)    -> Execution timing (optional)
```

### 9.2 Implementation

```mql5
// Higher timeframe trend filter
bool IsHigherTFBullish() {
    // D1 trend
    double ema200_d1 = iMA(_Symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
    double close_d1 = iClose(_Symbol, PERIOD_D1, 0);

    // H4 trend
    double ema50_h4 = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
    double close_h4 = iClose(_Symbol, PERIOD_H4, 0);

    return (close_d1 > ema200_d1) && (close_h4 > ema50_h4);
}

// Entry signal on H1
bool IsBuySignal_H1() {
    double ema9 = iMA(_Symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
    double ema21 = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
    double ema9_prev = iMA(_Symbol, PERIOD_H1, 9, 1, MODE_EMA, PRICE_CLOSE);
    double ema21_prev = iMA(_Symbol, PERIOD_H1, 21, 1, MODE_EMA, PRICE_CLOSE);

    return (ema9_prev < ema21_prev) && (ema9 > ema21); // Cross up
}

// Full MTF check
bool ShouldBuy() {
    return IsHigherTFBullish() && IsBuySignal_H1()
           && IsSpreadAcceptable() && !IsNewsTime()
           && IsSessionActive() && IsEquityCurveHealthy();
}
```

---

## 10. SKILL 9: NEWS FILTER

### 10.1 MQL5 Calendar API

```mql5
bool IsHighImpactNewsTime(int minutesBefore=30, int minutesAfter=30) {
    datetime now = TimeCurrent();
    datetime from = now - minutesBefore * 60;
    datetime to = now + minutesAfter * 60;

    MqlCalendarValue values[];
    int count = CalendarValueHistory(values, from, to);

    for(int i = 0; i < count; i++) {
        MqlCalendarEvent event;
        CalendarEventById(values[i].event_id, event);

        // Chi filter USD events (anh huong XAUUSD)
        MqlCalendarCountry country;
        CalendarCountryById(event.country_id, country);

        if(country.code == "US" && event.importance == CALENDAR_IMPORTANCE_HIGH) {
            return true; // Co tin quan trong
        }
    }
    return false;
}
```

### 10.2 Events Can Filter cho XAUUSD

| Event | Impact | Action |
|-------|--------|--------|
| **NFP** (Non-Farm Payrolls) | 50-200+ pts spike | Pause 60 min before/after |
| **FOMC Rate Decision** | 100-300 pts swing | Pause 120 min before/after |
| **CPI (Inflation)** | 50-150 pts | Pause 30 min before/after |
| **GDP** | 30-80 pts | Pause 30 min before/after |
| **Jobless Claims** | 20-50 pts | Pause 15 min before/after |
| **Fed Chair Speech** | Variable | Pause 30 min before/after |
| **ECB Rate Decision** | 20-60 pts | Pause 30 min before/after |

---

## 11. SKILL 10: SESSION-BASED TRADING

### 11.1 XAUUSD Session Behavior

| Session | Gio (GMT) | Volatility | Dac Diem |
|---------|-----------|-----------|---------|
| **Asian** | 00:00-08:00 | Thap (9-15 pts) | Range-bound, accumulation |
| **London** | 08:00-16:00 | Trung binh (12-20 pts) | Trend formation, breakout |
| **NY** | 13:00-22:00 | Cao (18-28 pts) | Strongest moves, volatile |
| **London-NY Overlap** | 13:00-16:00 | Rat cao (20-30+ pts) | Peak volatility |

### 11.2 Implementation

```mql5
enum SESSION_TYPE { SESSION_ASIAN, SESSION_LONDON, SESSION_NEWYORK, SESSION_OVERLAP };

SESSION_TYPE GetCurrentSession() {
    MqlDateTime dt;
    TimeGMT(dt);
    int hour = dt.hour;

    if(hour >= 13 && hour < 16) return SESSION_OVERLAP;  // Best
    if(hour >= 8 && hour < 16)  return SESSION_LONDON;   // Good
    if(hour >= 13 && hour < 22) return SESSION_NEWYORK;  // Good
    return SESSION_ASIAN;  // Low vol
}

bool IsSessionActive() {
    SESSION_TYPE session = GetCurrentSession();
    // Chi trade London va NY (hoac overlap)
    return (session == SESSION_LONDON || session == SESSION_NEWYORK || session == SESSION_OVERLAP);
}

// London Breakout Strategy
double asianHigh, asianLow;

void CalculateAsianRange() {
    // Tim High/Low cua Asian session (00:00-08:00 GMT)
    double high = 0, low = 999999;
    for(int i = 0; i < 480; i++) { // 8 hours * 60 min
        int shift = iBarShift(_Symbol, PERIOD_M1,
                              TimeGMT() - (TimeGMT() % 86400) + i * 60);
        high = MathMax(high, iHigh(_Symbol, PERIOD_M1, shift));
        low = MathMin(low, iLow(_Symbol, PERIOD_M1, shift));
    }
    asianHigh = high;
    asianLow = low;
}
```

---

## 12. SKILL 11: PHAN TICH DU LIEU NANG CAO (Data Science)

### 12.1 Python + MetaTrader5 Integration

```python
import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime

# Ket noi MT5
mt5.initialize()

# Lay du lieu XAUUSD
rates = mt5.copy_rates_range("XAUUSD", mt5.TIMEFRAME_H1,
                              datetime(2024, 1, 1), datetime.now())
df = pd.DataFrame(rates)
df['time'] = pd.to_datetime(df['time'], unit='s')

# Feature engineering
df['atr'] = df['high'].rolling(14).max() - df['low'].rolling(14).min()
df['rsi'] = compute_rsi(df['close'], 14)
df['ema9'] = df['close'].ewm(span=9).mean()
df['ema21'] = df['close'].ewm(span=21).mean()
df['returns'] = df['close'].pct_change()
df['volatility'] = df['returns'].rolling(20).std()
```

### 12.2 Scientific Skills tu claude-scientific-skills (GitHub)

**Cac skills lien quan cho trading data analysis:**

| Skill | Thu Vien | Ung Dung cho EA |
|-------|---------|-----------------|
| **Exploratory Data Analysis** | pandas, seaborn | Phan tich gold price patterns |
| **Statistical Analysis** | scipy, statsmodels | Hypothesis testing, regression |
| **Time Series (aeon)** | aeon | Forecast gold price |
| **Machine Learning (scikit-learn)** | sklearn | Signal prediction model |
| **Deep Learning (PyTorch Lightning)** | pytorch | Complex pattern recognition |
| **Bayesian Methods (PyMC)** | pymc | Uncertainty quantification |
| **Model Interpretability (SHAP)** | shap | Hieu tai sao model du doan |
| **Data Visualization** | matplotlib, plotly | Chart gold patterns |
| **Network Analysis (NetworkX)** | networkx | Correlation network giua assets |
| **Dimensionality Reduction (UMAP)** | umap-learn | Giam chieu du lieu market |
| **Statistical Modeling (statsmodels)** | statsmodels | ARIMA, GARCH cho gold |
| **GeoPandas** | geopandas | Phan tich dia ly san xuat vang |
| **Symbolic Math (SymPy)** | sympy | Tinh toan cong thuc trading |
| **Polars/Dask** | polars, dask | Xu ly big data tick gold |

### 12.3 Advanced Analysis Pipeline

```python
# Pipeline phan tich XAUUSD voi scientific skills

# 1. Data Collection
import MetaTrader5 as mt5
rates = mt5.copy_rates_range("XAUUSD", mt5.TIMEFRAME_M1, start, end)

# 2. EDA (Exploratory Data Analysis)
from scipy import stats
from statsmodels.tsa.stattools import adfuller
adf_result = adfuller(df['close'])  # Stationarity test

# 3. Feature Engineering
from ta import add_all_ta_features
df = add_all_ta_features(df, open="open", high="high", low="low",
                          close="close", volume="tick_volume")

# 4. Time Series Decomposition
from statsmodels.tsa.seasonal import seasonal_decompose
result = seasonal_decompose(df['close'], period=24)  # 24H cycle

# 5. Machine Learning Signal
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import TimeSeriesSplit
model = GradientBoostingClassifier()
tscv = TimeSeriesSplit(n_splits=5)

# 6. SHAP Interpretability
import shap
explainer = shap.TreeExplainer(model)
shap_values = explainer.shap_values(X_test)

# 7. Export to ONNX for MT5
import onnx
from skl2onnx import convert_sklearn
onnx_model = convert_sklearn(model, initial_types=initial_type)
```

---

## 13. SKILL 12: TRIEN KHAI & GIAM SAT

### 13.1 VPS cho EA Trading

| Provider | Gia | Latency | Uptime | Phu Hop |
|----------|-----|---------|--------|---------|
| **TradingFXVPS** | $15-20/mo | 0.3-0.78ms | 99.99% | HFT/Scalping |
| **ForexVPS.net** | $29-31/mo | ~1ms | 99.9% | General EA |
| **Contabo** | $5-10/mo | 5-20ms | 99.9% | Budget |
| **Vultr** | $5-24/mo | Variable | 99.95% | Flexible |

### 13.2 Discord/Telegram Notifications

```mql5
// Discord Webhook tu EA
bool SendDiscordMessage(string message) {
    string url = "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL";
    string headers = "Content-Type: application/json\r\n";
    string payload = "{\"content\":\"" + message + "\"}";

    char data[];
    StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);

    char result[];
    string resultHeaders;

    int res = WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
    return (res == 204); // Discord returns 204 on success
}

// Gui thong bao khi mo/dong lenh
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result) {
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        string msg = StringFormat(
            "Trade: %s %s %.2f lots @ %.2f | SL: %.2f | TP: %.2f",
            (trans.deal_type == DEAL_TYPE_BUY ? "BUY" : "SELL"),
            _Symbol, trans.volume, trans.price,
            trans.price_sl, trans.price_tp);
        SendDiscordMessage(msg);
    }
}
```

### 13.3 Monitoring Tools

| Tool | Muc Dich | Link |
|------|----------|------|
| **Myfxbook** | Track performance, share results | myfxbook.com |
| **FXBlue** | Live analytics, TradeTalk alerts | fxblue.com |
| **Custom Dashboard** | Real-time equity, DD monitor | Python Flask |

---

## 14. SKILL 13: MACHINE LEARNING & ONNX

### 14.1 ONNX trong MT5

```mql5
// Load ONNX model trong EA
#resource "\\Files\\gold_model.onnx" as uchar OnnxModel[]

long onnxHandle;

int OnInit() {
    onnxHandle = OnnxCreate(OnnxModel, ONNX_DEFAULT);
    if(onnxHandle == INVALID_HANDLE) {
        Print("Failed to load ONNX model");
        return INIT_FAILED;
    }

    // Set input/output shapes
    long inputShape[] = {1, 10}; // batch=1, features=10
    OnnxSetInputShape(onnxHandle, 0, inputShape);

    long outputShape[] = {1, 3}; // batch=1, classes=3 (buy/sell/hold)
    OnnxSetOutputShape(onnxHandle, 0, outputShape);

    return INIT_SUCCEEDED;
}

int PredictSignal() {
    // Prepare features
    float features[10];
    features[0] = (float)iRSI(_Symbol, PERIOD_H1, 14, 0);
    features[1] = (float)iATR(_Symbol, PERIOD_H1, 14, 0);
    // ... more features

    float output[3]; // [buy_prob, sell_prob, hold_prob]
    OnnxRun(onnxHandle, ONNX_DEFAULT, features, output);

    if(output[0] > 0.7) return 1;  // BUY
    if(output[1] > 0.7) return -1; // SELL
    return 0; // HOLD
}
```

### 14.2 Python Training Pipeline

```python
# Train model cho XAUUSD signals
from sklearn.ensemble import GradientBoostingClassifier
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType

# Features: RSI, ATR, EMA_diff, MACD, Volume, Hour, DayOfWeek, Spread, Volatility, Momentum
X_train = df[['rsi', 'atr', 'ema_diff', 'macd', 'volume',
              'hour', 'dayofweek', 'spread', 'volatility', 'momentum']]
y_train = df['signal']  # 0=hold, 1=buy, 2=sell

model = GradientBoostingClassifier(
    n_estimators=200, max_depth=5, learning_rate=0.05,
    min_samples_leaf=50  # Tranh overfit
)
model.fit(X_train, y_train)

# Export ONNX
initial_type = [('features', FloatTensorType([1, 10]))]
onnx_model = convert_sklearn(model, initial_types=initial_type)
with open("gold_model.onnx", "wb") as f:
    f.write(onnx_model.SerializeToString())
```

---

## 15. TONG HOP CONG CU & THU VIEN

### 15.1 MQL5 Development

| Cong Cu | Muc Dich |
|---------|----------|
| MetaEditor | IDE, debugger, profiler |
| `<Trade\Trade.mqh>` | CTrade class |
| `<Expert\Expert.mqh>` | CExpert base |
| `<Expert\Signal\SignalMA.mqh>` | MA signal |
| `<Indicators\Trend.mqh>` | Trend indicators |
| Custom `.mqh` libraries | Modular code |

### 15.2 Python Data Science

| Thu Vien | Muc Dich |
|----------|----------|
| `MetaTrader5` | MT5 API connection |
| `pandas` + `numpy` | Data manipulation |
| `pandas-ta` / `ta-lib` | Technical indicators |
| `scikit-learn` | ML models |
| `pytorch` / `tensorflow` | Deep learning |
| `skl2onnx` | Export to ONNX |
| `shap` | Model interpretability |
| `statsmodels` | Time series, GARCH |
| `matplotlib` / `plotly` | Visualization |
| `backtrader` | Python backtesting |

### 15.3 Backtest & Analysis

| Tool | Muc Dich |
|------|----------|
| MT5 Strategy Tester | Backtest, optimization |
| QuantAnalyzer | Portfolio analysis |
| Tick Data Suite | 99% modeling quality |
| Jupyter Notebook | Interactive analysis |
| TradingView | Visual strategy prototyping |

### 15.4 Deployment & Monitoring

| Tool | Muc Dich |
|------|----------|
| VPS (TradingFXVPS/ForexVPS) | 24/7 EA running |
| Discord Webhook | Trade notifications |
| Myfxbook | Performance tracking |
| FXBlue | Live analytics |
| Git | Version control |

---

## ROADMAP: THU TU HOC & THUC HANH

```
Phase 1 (Tuan 1-2): MQL5 Basics
├── Hoc MQL5 syntax, event model
├── Viet EA don gian (MA crossover)
└── Backtest co ban

Phase 2 (Tuan 3-4): Core Modules
├── Risk management module
├── Order management + trailing
└── Logging system

Phase 3 (Tuan 5-6): Filters & MTF
├── News filter (MQL5 Calendar)
├── Session filter
├── Spread/volatility filter
└── Multi-timeframe analysis

Phase 4 (Tuan 7-8): Strategy Development
├── Implement 2-3 strategies
├── Weighted scoring system
├── Walk-forward analysis
└── Optimization

Phase 5 (Tuan 9-10): Data Science
├── Python + MT5 integration
├── Feature engineering
├── ML model training
├── ONNX deployment

Phase 6 (Tuan 11-12): Production
├── VPS setup
├── Discord notifications
├── Live monitoring
├── Equity curve trading
└── Continuous improvement
```

---

> **Tham Khao:**
> - MQL5 Documentation: https://www.mql5.com/en/docs
> - Claude Scientific Skills: https://github.com/K-Dense-AI/claude-scientific-skills
> - Perplexity Deep Research (2026-02-21)
> - MQL5 Articles: https://www.mql5.com/en/articles
