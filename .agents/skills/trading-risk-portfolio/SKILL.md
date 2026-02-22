---
name: trading-risk-portfolio
description: Analyze portfolio risk, calculate position sizing, manage portfolio heat, perform VaR/CVaR analysis, and stress-test EA portfolios across market regimes for XAUUSD trading. Use when user needs position sizing calculations, portfolio risk assessment, drawdown analysis, correlation-adjusted exposure, or stress testing across trending/ranging/crisis regimes. Triggers include "position size", "portfolio risk", "VaR", "drawdown analysis", "stress test", "portfolio heat", "risk budget", "Kelly criterion". Do NOT use for live monitoring, deployment, or trade execution -- use ea-ops-monitor for operational concerns.
---

# Trading Risk & Portfolio Management

## When to Use

- User needs position sizing calculations for XAUUSD EAs
- Portfolio risk assessment across multiple running EAs
- VaR/CVaR analysis for gold exposure
- Drawdown analysis or Monte Carlo projections
- Correlation-adjusted exposure management (XAUUSD + silver, DXY, etc.)
- Stress testing EA performance across market regimes
- Risk budget allocation across multi-EA portfolio
- Kelly criterion or fractional sizing evaluation

## When NOT to Use

- **Live monitoring/alerting** → use `ea-ops-monitor`
- **Generating or debugging MQL5 code** → use `mt5-ea-coder`
- **Designing strategy entry/exit rules** → use `strategy-spec-risk`
- **Researching new strategy ideas** → use `strategy-researcher`
- **Analyzing backtest HTML/CSV reports** → use `ea-backtest-analyst`
- **Trade execution or order management** → out of scope (manual or EA handles this)

<!-- STATIC CONTEXT BLOCK START - Optimized for prompt caching -->
<!-- All static instructions, methodology, and risk frameworks below this line -->
<!-- Dynamic content (account data, EA stats, market regime) added after this block -->

## Core System Instructions

**Purpose:** Deliver quantitative risk analysis and position sizing recommendations for multi-EA XAUUSD portfolios through a structured pipeline (Collect -> Calculate -> Size -> Stress Test -> Report) with regime-aware adjustments and correlation-based exposure management.

**Context Strategy:** This skill uses context engineering best practices:
- Static risk rules and formulas cached (this section)
- Progressive disclosure (load market data only when needed)
- Critical thresholds at start and end (not buried in methodology)
- Explicit section markers for rapid navigation

**Domain:** XAUUSD (Gold/USD) on MetaTrader 5. Gold-specific characteristics:
- Point value per standard lot: $1 per $0.01 move; $100 per $1.00 move (1 lot = 100 oz)
- Typical daily range: $20-$50 (normal), $50-$150+ (news/crisis)
- Spread: 10-40 points (ECN normal), 80-500+ points (news events)
- Contract: 1 lot = 100 oz, min lot = 0.01, lot step = 0.01
- Swap: Long swap typically -$14 to -$46/lot/night, triple Wednesday

---

## Decision Tree (Execute First)

```
Request Analysis
├─ Simple lot size calculation? -> Quick Mode (1-2 min)
│  └─ Apply fixed fraction formula, return lot + rationale
├─ Single EA risk check? -> Standard Mode (3-5 min)
│  └─ Position sizing + drawdown check + basic stress test
├─ Multi-EA portfolio assessment? -> Portfolio Mode (5-10 min) [DEFAULT]
│  └─ Full pipeline: sizing + heat + correlation + VaR + stress test
└─ Comprehensive regime analysis? -> Deep Mode (10-20 min)
   └─ All above + Monte Carlo + regime detection + scenario matrix

Input Validation
├─ Account balance/equity provided? -> CONTINUE
├─ No account data? -> Use $10,000 default, note assumption
├─ EA backtest stats available? -> Load 33-metric framework
└─ No EA stats? -> Request minimum: win rate, avg win/loss, max DD

Risk Check Gate (ALWAYS EXECUTE)
├─ Recommended lot within broker limits? -> PASS
├─ Portfolio heat < 6%? -> PASS
├─ Max DD projection < 15%? -> PASS
├─ Any check fails? -> REDUCE exposure + add WARNING to output
└─ Multiple checks fail? -> EMERGENCY: recommend pause trading
```

---

## Workflow (Collect -> Calculate -> Size -> Stress Test -> Report)

**AUTONOMY PRINCIPLE:** This skill operates independently. Infer defaults from available data. Only stop for critical errors or contradictory inputs.

### 1. Collect EA Statistics

**Required inputs (minimum):**
- Account equity/balance
- EA name(s) and strategy type(s)
- Win rate (rolling 100+ trades)
- Average win / average loss ratio
- Maximum historical drawdown
- Current open positions (if any)

**Optional inputs (enhance accuracy):**
- Full trade history (CSV or MT5 report)
- Backtest report (Strategy Tester HTML)
- Profit factor, Sharpe ratio, recovery factor
- Current ATR value for XAUUSD
- Active market regime assessment

**Default assumptions when data is missing:**
- Account: $10,000 equity
- Risk per trade: 1.5% (conservative for gold)
- Max simultaneous positions: 3
- ATR(H1, 14): $10 (normal volatility, H1 normal range $8-$12)
- Regime: trending (most common productive regime)

---

### 2. Calculate Position Sizing

Execute ALL applicable methods, then recommend the most conservative result.

---

### 3. Stress Test Across Regimes

Run the recommended sizing through regime scenarios. Adjust if any scenario breaches thresholds.

---

### 4. Generate Report

Produce structured output with the Output Contract format. Include rationale for every recommendation.

---

## Position Sizing Methods

### Method 1: Fixed Fractional (Baseline)

The foundation method. Always calculate this first.

**Formula:**
```
Lot Size = (Equity * Risk%) / (SL_distance_in_dollars * Value_per_lot_per_dollar)

Where for XAUUSD:
- Value_per_lot_per_dollar = $100 (1 lot = 100 oz, $1 move = $100)
- SL_distance_in_dollars = ATR(H1,14) * multiplier

Example:
- Equity: $10,000
- Risk: 1.5% = $150
- ATR(H1): $10, multiplier: 1.5x, SL = $15.00
- Lot = $150 / ($15.00 * 100) = $150 / $1,500 = 0.10 lots
```

**Risk percentage guidelines for XAUUSD:**

| Account Size | Max Risk/Trade | Rationale |
|---|---|---|
| < $5,000 | 1.0% | Gold spikes can exceed SL; micro account protection |
| $5,000 - $25,000 | 1.0-1.5% | Standard conservative approach |
| $25,000 - $100,000 | 1.5-2.0% | Sufficient buffer for normal drawdowns |
| > $100,000 | 0.5-1.5% | Capital preservation priority |

**MQL5 Implementation:**
```mql5
double CalculateLotSize_FixedFraction(double riskPercent, double slPoints) {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = equity * riskPercent / 100.0;

    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    double pipValue = tickValue * (point / tickSize);
    double lotSize = riskAmount / (slPoints * pipValue);

    // Normalize to broker limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);   // 0.01
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);   // 100.0
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); // 0.01
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    return NormalizeDouble(MathFloor(lotSize / lotStep) * lotStep, 2);
}
```

### Method 2: Kelly Criterion (Optimal f)

Calculates the theoretically optimal fraction to maximize geometric growth. **Always apply half-Kelly or quarter-Kelly for live trading** -- full Kelly is too aggressive.

**Formula:**
```
Kelly% = W - [(1 - W) / R]

Where:
- W = Win rate (decimal, e.g., 0.58)
- R = Avg Win / Avg Loss ratio (e.g., 1.5)

Example:
- W = 0.58, R = 1.5
- Kelly% = 0.58 - [(1 - 0.58) / 1.5] = 0.58 - 0.28 = 0.30 (30%)
- Half-Kelly = 15% -> Still too aggressive for gold
- Quarter-Kelly = 7.5% -> Still high
- Practical cap: min(Quarter-Kelly, 2%) = 2%

Negative Kelly = DO NOT TRADE this strategy (negative expectancy)
```

**Kelly interpretation table:**

| Kelly Result | Action | Explanation |
|---|---|---|
| < 0% | DO NOT TRADE | Negative expectancy; strategy loses money long-term |
| 0-5% | Use 0.5-1.0% | Marginal edge; minimize exposure |
| 5-15% | Use 1.0-2.0% | Decent edge; quarter-Kelly practical |
| 15-30% | Use 1.5-2.0% | Strong edge; cap at 2% for gold volatility |
| > 30% | Use 2.0% max | Very strong edge; cap protects against model error |

**Critical warning:** Kelly assumes accurate win rate and R:R estimates. With fewer than 200 trades of history, reduce Kelly fraction by an additional 50%.

### Method 3: ATR-Based Dynamic Sizing

Adjusts position size dynamically based on current market volatility. **Preferred method for XAUUSD** due to gold's volatility regime shifts.

**Formula:**
```
SL_distance = ATR(H1, 14) * ATR_multiplier
Lot = (Equity * Risk%) / (SL_distance * 100)

ATR Multiplier by strategy:
- Scalping (M5-M15):  1.5x ATR -> tighter SL, larger lot (higher risk per pip)
- Day Trading (H1):   2.0x ATR -> balanced
- Swing (H4-D1):      2.5-3.0x ATR -> wider SL, smaller lot
- Position (W1):       3.0-4.0x ATR -> widest SL, smallest lot
```

**Volatility regime adjustments:**

| ATR(H1,14) | Regime | Lot Adjustment | Rationale |
|---|---|---|---|
| < $10 | Low volatility | +20% lot size | Tighter ranges, smaller SL |
| $10-$20 | Normal | Baseline (no adjustment) | Standard conditions |
| $20-$35 | Elevated | -25% lot size | Wider stops needed, news possible |
| $35-$60 | High (news/event) | -50% lot size | Crisis-level moves |
| > $60 | Extreme (black swan) | -75% lot size or PAUSE | Flash crash / war / pandemic |

**MQL5 Implementation:**
```mql5
double CalculateLotSize_ATR(double riskPercent, int atrPeriod=14,
                             double atrMultiplier=2.0) {
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = equity * riskPercent / 100.0;

    // Get current ATR
    int atrHandle = iATR(_Symbol, PERIOD_H1, atrPeriod);
    double atrBuffer[];
    CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
    double atr = atrBuffer[0];

    double slDistance = atr * atrMultiplier; // In price terms (e.g., $22.50)
    double lotSize = riskAmount / (slDistance * 100.0); // 100 oz per lot

    // Volatility regime adjustment
    if(atr > 60) lotSize *= 0.25;       // Extreme: -75%
    else if(atr > 35) lotSize *= 0.50;  // High: -50%
    else if(atr > 20) lotSize *= 0.75;  // Elevated: -25%
    else if(atr < 10) lotSize *= 1.20;  // Low: +20%

    return NormalizeLots(lotSize);
}

double NormalizeLots(double lots) {
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    lots = MathMax(minLot, MathMin(maxLot, lots));
    return NormalizeDouble(MathFloor(lots / lotStep) * lotStep, 2);
}
```

### Method 4: Volatility-Adjusted Sizing (Normalized Risk)

Normalizes risk across different volatility regimes so that each trade risks the same dollar amount regardless of market conditions.

**Formula:**
```
Volatility_ratio = Baseline_ATR / Current_ATR
Adjusted_lot = Base_lot * Volatility_ratio

Where:
- Baseline_ATR = 20-period median ATR(H1) = ~$10 (XAUUSD H1 normal range $8-$12)
- Current_ATR = live ATR(H1, 14)

Example:
- Base lot (at median vol): 0.10
- Current ATR: $25 (elevated)
- Ratio: $10 / $25 = 0.40
- Adjusted lot: 0.10 * 0.40 = 0.04 lots (reduced for high vol)

Example 2:
- Current ATR: $7 (low vol)
- Ratio: $10 / $7 = 1.43 -> cap at 1.25
- Adjusted lot: 0.10 * 1.25 = 0.13 lots (slightly increased, capped)
```

**Cap the upside multiplier at 1.25x** to prevent oversizing in deceptively calm markets (calm before news storm).

---

## Portfolio Heat Calculation

Portfolio heat measures the total risk exposure across ALL open positions at any moment. This is the single most important real-time risk metric.

### Total Portfolio Heat

**Formula:**
```
Portfolio_Heat% = SUM(Risk_per_position%) for all open positions

Where:
- Risk_per_position% = (Entry - SL) * Lot_size * 100 / Equity

Example:
- Position 1: BUY 0.05 lots, entry $2050, SL $2035 -> risk = $15 * 5 = $75
- Position 2: BUY 0.03 lots, entry $2060, SL $2040 -> risk = $20 * 3 = $60
- Position 3: SELL 0.04 lots, entry $2070, SL $2085 -> risk = $15 * 4 = $60
- Total risk = $195 on $10,000 equity = 1.95% portfolio heat
```

### Portfolio Heat Limits

| Heat Level | Value | Action |
|---|---|---|
| Green | 0-3% | Normal operation, can add positions |
| Yellow | 3-5% | Caution, reduce new position sizes by 50% |
| Orange | 5-6% | Warning, no new positions allowed |
| Red | > 6% | EMERGENCY: close weakest position(s) immediately |

### Max Simultaneous Positions

| Account Size | Max Positions | Max per EA | Rationale |
|---|---|---|---|
| < $5,000 | 2 | 1 | Avoid margin call on spike |
| $5,000 - $25,000 | 3 | 2 | Standard diversification |
| $25,000 - $100,000 | 4-5 | 2-3 | Room for multi-strategy |
| > $100,000 | 5-8 | 3 | Portfolio-level management |

### Correlation-Adjusted Risk

Raw portfolio heat assumes positions are independent. For correlated positions, adjust:

**Formula:**
```
Adjusted_Heat = Raw_Heat * Correlation_Factor

Correlation_Factor = sqrt(1 + (n-1) * avg_pairwise_correlation)
Where n = number of same-direction positions

Example:
- 3 BUY positions on XAUUSD (same EA, same direction)
- avg_pairwise_correlation = 0.95 (nearly identical exposure)
- Factor = sqrt(1 + 2 * 0.95) = sqrt(2.90) = 1.70
- Raw heat 3% -> Adjusted heat = 3% * 1.70 = 5.10% -> YELLOW zone
```

**Correlation adjustment rules:**
- Same symbol, same direction, same EA: correlation = 0.95 (nearly 1.0)
- Same symbol, same direction, different EA: correlation = 0.80-0.90
- Same symbol, opposite direction: correlation = -0.90 (hedging, reduces heat)
- XAUUSD + XAGUSD same direction: correlation = +0.85 (doubles exposure)
- XAUUSD long + DXY long: correlation = -0.45 to -0.70 (natural hedge)

---

## Risk Metrics

### VaR (Value at Risk) for Gold Portfolio

VaR answers: "What is the maximum loss over a given time period at a given confidence level?"

**Historical VaR Method:**
```
1. Collect daily returns for XAUUSD (minimum 252 trading days = 1 year)
2. Sort returns ascending
3. VaR(95%) = 5th percentile of daily returns * Portfolio_value
4. VaR(99%) = 1st percentile of daily returns * Portfolio_value

XAUUSD Historical Benchmarks (2020-2026):
- Daily VaR(95%): -1.8% to -2.5% of position value
- Daily VaR(99%): -3.0% to -4.2% of position value
- Weekly VaR(95%): -3.5% to -5.0%
- Monthly VaR(95%): -7.0% to -10.0%
```

**Parametric VaR (assumes normal distribution):**
```
VaR(95%) = Portfolio_value * Z_score * daily_volatility * sqrt(holding_period)

Where:
- Z_score(95%) = 1.645
- Z_score(99%) = 2.326
- daily_volatility(XAUUSD) ~ 1.1-1.5% (2024-2026 average)

Example:
- Portfolio: 0.10 lots XAUUSD = $10/point exposure at ~$2,900 = ~$29,000 notional
- Daily vol: 1.3%
- VaR(95%, 1-day) = $29,000 * 1.645 * 0.013 = $620
- This means: 95% confidence the portfolio won't lose more than $620 in one day
```

**IMPORTANT:** Parametric VaR underestimates tail risk for gold. Gold has fat tails (kurtosis > 3). Always prefer Historical VaR or CVaR for production risk management.

### CVaR (Conditional VaR / Expected Shortfall)

CVaR answers: "Given that the loss exceeds VaR, what is the expected loss?" This captures tail risk that VaR misses.

**Calculation:**
```
CVaR(95%) = Average of all returns below the 5th percentile

XAUUSD Historical Benchmarks:
- Daily CVaR(95%): -2.8% to -3.8% (vs VaR 95% of -1.8% to -2.5%)
- The gap between VaR and CVaR reveals tail risk severity
- Gold CVaR/VaR ratio typically 1.4-1.7x (significant tail risk)
```

**Why CVaR matters more than VaR for gold:**
- Gold experiences sudden spikes (geopolitical events, Fed surprises)
- Price can gap over stops (Sunday open, flash crash)
- VaR says "you won't lose more than X, 95% of the time"
- CVaR says "in that worst 5%, expect to lose Y" (Y is much larger)

### Maximum Drawdown Analysis

**Drawdown types:**
```
1. Peak-to-Trough Drawdown (absolute)
   DD% = (Peak_equity - Trough_equity) / Peak_equity * 100

2. Rolling Maximum Drawdown (time-windowed)
   Max DD over last N trades or T time period

3. Underwater Period
   Duration from peak to recovery (new peak)

XAUUSD EA Benchmarks:
- Acceptable max DD (backtest): < 20%
- Target max DD (live): < 15%
- Emergency shutdown DD: > 25%
- Recovery factor target: > 2.0 (net profit / max DD)
```

**Drawdown projection using Monte Carlo:**
```
1. Collect trade results (P&L per trade)
2. Randomly resample 1000+ sequences
3. Calculate max DD for each sequence
4. Report: median DD, 95th percentile DD, 99th percentile DD

If 95th percentile DD > 25%:
  -> Strategy has significant ruin risk
  -> REDUCE position sizes until 95th percentile DD < 20%
```

### Performance Ratios

| Ratio | Formula | Target (XAUUSD EA) | Interpretation |
|---|---|---|---|
| **Sharpe** | (Avg_return - Rf) / Std_return | > 1.0 (good), > 2.0 (excellent) | Risk-adjusted return; higher = better |
| **Sortino** | (Avg_return - Rf) / Downside_std | > 1.5 (good), > 3.0 (excellent) | Penalizes only downside volatility |
| **Calmar** | Annual_return / Max_DD | > 1.0 (good), > 2.0 (excellent) | Return relative to worst drawdown |
| **Profit Factor** | Gross_profit / Gross_loss | > 1.5 (minimum), > 2.0 (good) | How much profit per unit of loss |
| **Recovery Factor** | Net_profit / Max_DD | > 2.0 (minimum), > 3.0 (good) | Ability to recover from drawdowns |
| **Expectancy** | (W% * Avg_win) - (L% * Avg_loss) | > $0 per trade | Average expected outcome per trade |

---

## Correlation Analysis

### XAUUSD Cross-Asset Correlations

Understanding correlations prevents unintended portfolio concentration and enables natural hedging.

**XAUUSD vs DXY (US Dollar Index)**

| Period | Correlation | Notes |
|---|---|---|
| Historical average | -0.45 to -0.70 | Inverse: strong USD -> weak gold |
| 2022-2024 | -0.45 (weakening) | NHTW buying broke traditional correlation |
| News events | -0.70 to -0.90 | Correlation strengthens during macro events |
| Crisis | Variable | Both can rise simultaneously (safe haven overlap) |

**Trading implication:** If running EAs on both XAUUSD and DXY-correlated pairs, account for natural hedging. A long XAUUSD + long EURUSD doubles the anti-USD bet. A long XAUUSD + long USDCHF partially hedges.

**XAUUSD vs XAGUSD (Silver)**

| Period | Correlation | Notes |
|---|---|---|
| Historical average | +0.80 to +0.90 | Strong positive: gold and silver move together |
| Trending markets | +0.85 to +0.95 | Nearly identical movement |
| Divergence signal | < +0.70 | Divergence = potential reversal signal for both |

**Trading implication:** Running buy EAs on both XAUUSD and XAGUSD simultaneously nearly doubles directional risk. Treat combined exposure as a single risk unit and halve individual position sizes.

**XAUUSD vs S&P 500**

| Period | Correlation | Notes |
|---|---|---|
| Normal markets | -0.10 to -0.30 | Weak negative: mild diversification |
| Risk-off events | -0.50 to -0.70 | Stocks crash -> gold rallies (flight to safety) |
| Liquidity crisis | +0.30 to +0.60 | Both sell off in forced liquidation (2008, COVID March 2020) |

**Trading implication:** Do not rely on gold as a hedge during liquidity crises. Initial crash phase can hit both stocks and gold. Gold typically recovers first and rallies strongly in phase 2 (QE response).

**XAUUSD vs US 10-Year Bond Yields**

| Period | Correlation | Notes |
|---|---|---|
| Historical average | -0.76 | Strong inverse: yields up -> gold down |
| 2024-2026 | -0.40 (weakening) | NHTW buying partially decoupled this |
| Real yields (TIPS) | -0.82 | Strongest traditional driver of gold |
| Fed pivot events | -0.85 to -0.95 | Correlation spikes around rate decisions |

**Trading implication:** Monitor US 10Y yield and TIPS spread as leading indicators. Rapid yield spikes (> 15 bps in a day) warrant immediate risk reduction on long gold positions.

### Correlation Matrix for Portfolio Construction

```
              XAUUSD  DXY    XAGUSD  SPX    US10Y  Oil
XAUUSD        1.00   -0.55   +0.85  -0.20  -0.76  +0.15
DXY          -0.55    1.00   -0.50  +0.10  +0.60  -0.20
XAGUSD       +0.85   -0.50    1.00  -0.15  -0.65  +0.25
SPX          -0.20   +0.10   -0.15   1.00  +0.30  +0.35
US10Y        -0.76   +0.60   -0.65  +0.30   1.00  +0.10
Oil          +0.15   -0.20   +0.25  +0.35  +0.10   1.00
```

**Portfolio construction rules:**
1. If holding XAUUSD long, avoid XAGUSD long at full size (correlation +0.85)
2. XAUUSD long + mild DXY short = concentrated anti-USD bet (manage as one)
3. XAUUSD + SPX provides genuine diversification in normal markets
4. Monitor correlation regime shifts -- they signal structural market changes

---

## Regime Stress Testing

Every position sizing recommendation MUST be stress-tested across four market regimes before finalizing.

### Regime 1: Trending Market (Strong Directional Move)

**Characteristics:**
- ADX > 25, sustained for 5+ days
- Price consistently above/below EMA 20
- ATR normal to slightly elevated ($12-$25)
- Clear higher highs/higher lows (uptrend) or vice versa

**Stress test parameters:**
```
- Winning streak: 5-8 consecutive wins (risk of overconfidence)
- Trend exhaustion: sudden reversal after extended move
- Gap risk: weekend gap against position direction ($20-$50)
- Test: Can portfolio survive a 3-ATR adverse move?

Adjustment:
- Allow full position sizing (regimes where EAs perform best)
- Set trailing stops to lock in trend profits
- Max 3 same-direction positions (even in strong trend)
```

### Regime 2: Ranging / Consolidation

**Characteristics:**
- ADX < 20, price oscillating in channel
- ATR contracting ($8-$15)
- Multiple false breakouts (whipsaws)
- EMA 9/21 intertwined (no clear direction)

**Stress test parameters:**
```
- Whipsaw scenario: 5 consecutive SL hits at full size
- Cost: 5 * 1.5% risk = 7.5% drawdown in short period
- Spread impact: wider spreads in low-vol eat into small profits
- Test: Portfolio survival after 10 consecutive losses

Adjustment:
- REDUCE position size by 30-50%
- Increase SL multiplier to 2.5x ATR (wider stops for whipsaws)
- Reduce max simultaneous positions by 1
- Consider pausing trend-following EAs entirely
```

### Regime 3: High Volatility (News Events, Macro Releases)

**Characteristics:**
- ATR > $30 (2x+ normal)
- Rapid price swings ($30-$80 in minutes)
- Spread widening: 80-500+ points
- Slippage: 10-50+ points on market orders
- Events: NFP, FOMC, CPI, geopolitical shock

**Stress test parameters:**
```
- Spike scenario: $50 adverse move in 5 minutes
- Gap through SL: actual loss 2-3x intended risk
- Spread cost: $3-$5 per lot round-trip (vs normal $0.20-$0.40)
- Test: portfolio survives $80 flash move with slippage

Adjustment:
- REDUCE position size by 50-75%
- Widen SL to 3x ATR minimum
- Set max spread filter: disable trading when spread > 50 points
- Pause all EAs 30-120 min before/after high-impact news
- No new positions during active news window
```

### Regime 4: Crisis / Black Swan

**Characteristics:**
- ATR > $60 (4x+ normal)
- Limit moves, gaps, exchange halts possible
- Liquidity disappears: no fills, extreme slippage
- VIX > 35, correlations break down
- Events: war escalation, pandemic, financial crisis, sovereign default

**Stress test parameters:**
```
- Flash crash: $150-$300 adverse move
- Gap over stop: loss = 5-10x intended risk per position
- Forced liquidation: margin call if over-leveraged
- Broker outage: positions stuck for hours/days
- Test: portfolio survival if EVERY open position loses 3x intended risk

Adjustment:
- REDUCE to minimum position size (0.01 lots) or STOP trading
- If positions are open: manually set SL to worst-case tolerable level
- NEVER average down in a crisis
- Check margin level continuously (must stay > 200%)
- Phase 1 of crisis (0-2 weeks): gold may DECLINE (forced liquidation)
- Phase 2 (2+ weeks): gold typically rallies strongly (QE response)
```

### Regime Detection Heuristics

```mql5
enum MARKET_REGIME {
    REGIME_TRENDING,
    REGIME_RANGING,
    REGIME_HIGH_VOL,
    REGIME_CRISIS
};

// Handles created in OnInit():
// int g_atrHandle = iATR(_Symbol, PERIOD_H1, 14);
// int g_adxHandle = iADX(_Symbol, PERIOD_H1, 14);

MARKET_REGIME DetectRegime() {
    double atrBuf[], adxBuf[];
    ArraySetAsSeries(atrBuf, true);
    ArraySetAsSeries(adxBuf, true);
    if(CopyBuffer(g_atrHandle, 0, 0, 1, atrBuf) < 1) return REGIME_RANGING;
    if(CopyBuffer(g_adxHandle, 0, 0, 1, adxBuf) < 1) return REGIME_RANGING;
    double atr = atrBuf[0];
    double adx = adxBuf[0];
    double atrMedian = GetMedianATR(20); // 20-period median

    // Crisis: extreme volatility
    if(atr > atrMedian * 4.0) return REGIME_CRISIS;

    // High volatility: elevated but not extreme
    if(atr > atrMedian * 2.0) return REGIME_HIGH_VOL;

    // Trending: strong directional movement
    if(adx > 25) return REGIME_TRENDING;

    // Default: ranging/consolidation
    return REGIME_RANGING;
}

double GetRegimeMultiplier(MARKET_REGIME regime) {
    switch(regime) {
        case REGIME_TRENDING:  return 1.00; // Full size
        case REGIME_RANGING:   return 0.60; // -40%
        case REGIME_HIGH_VOL:  return 0.40; // -60%
        case REGIME_CRISIS:    return 0.15; // -85%
    }
    return 0.50; // Safe default
}
```

---

## Risk Rules (Hard Limits)

These rules are NON-NEGOTIABLE. They override all other calculations.

### Per-Trade Limits

| Rule | Limit | Action on Breach |
|---|---|---|
| Max risk per trade | 2.0% of equity | Reduce lot size, never exceed |
| Max lot size | Account-specific (see table) | Hard cap in EA code |
| Min R:R ratio | 1:1.5 | Do not enter trade below this |
| Max spread at entry | 50 points (scalp: 30) | Skip trade, wait for spread normalization |
| Max slippage tolerance | 20 points | Cancel order, re-evaluate |

### Per-EA Limits

| Rule | Limit | Action on Breach |
|---|---|---|
| Max positions per EA | 2-3 (account-dependent) | Queue new signals, do not open |
| Max daily trades per EA | 10 (scalp: 20) | Pause EA until next day |
| Max daily loss per EA | 3% of equity | Disable EA for remainder of day |
| Consecutive losses trigger | 5 losses in a row | Pause EA for 4 hours minimum |
| Win rate floor (rolling 50) | 35% | Review strategy; pause if below 30% |

### Portfolio-Level Limits

| Rule | Limit | Action on Breach |
|---|---|---|
| Max portfolio heat | 6% of equity | No new positions until heat drops |
| Max daily loss (all EAs) | 5% of equity | **SHUT DOWN ALL EAs for the day** |
| Max weekly drawdown | 8% of equity | Reduce all lot sizes by 50% next week |
| Max total drawdown | 15% from peak equity | **EMERGENCY: disable all EAs, manual review** |
| Max drawdown (hard stop) | 25% from peak equity | **STOP ALL TRADING. Full strategy review required** |
| Margin level floor | 300% | No new positions below this level |

### EA Shutdown Rules

```
Decision Matrix: When to Stop an EA

Performance Degradation:
├─ DD > 15% (from EA's equity allocation) -> STOP EA
├─ Profit Factor < 1.0 (rolling 50 trades) -> STOP EA
├─ Win rate < 30% (rolling 100 trades) -> STOP EA
├─ Recovery Factor < 1.0 -> STOP EA
└─ Sharpe < 0 (rolling 3 months) -> STOP EA

Behavioral Anomalies:
├─ Trades outside defined session -> STOP EA + investigate
├─ Lot size exceeds configured max -> STOP EA + investigate
├─ More positions than configured max -> STOP EA + investigate
├─ SL/TP not set on new position -> STOP EA + investigate
└─ Trade frequency 3x above baseline -> STOP EA + investigate

Market Regime Mismatch:
├─ Trend EA in ranging market (ADX < 15 for 5+ days) -> PAUSE EA
├─ Range EA in trending market (ADX > 30 for 5+ days) -> PAUSE EA
├─ Any EA during crisis regime -> REDUCE to minimum lot
└─ Sustained spread > 80 points for 30+ min -> PAUSE all EAs
```

### Emergency Stop Conditions

**Immediate full shutdown (all EAs, all positions reviewed):**
1. Account equity drops below 70% of last peak (30% drawdown)
2. Margin level falls below 150%
3. Broker connectivity lost for > 10 minutes with open positions
4. Unexpected position opened (not by any configured EA)
5. Daily loss exceeds 7% of equity
6. Multiple EAs simultaneously hitting loss limits

---

## 33-Metric Framework Integration

When full EA backtest/live data is available, evaluate using the comprehensive 33-metric framework. This provides the statistical foundation for all risk calculations.

### Tier 1: Core Performance (Must-Have)

| # | Metric | Formula / Source | Minimum | Target |
|---|---|---|---|---|
| 1 | Net Profit | Total P&L | > $0 | Positive with buffer |
| 2 | Profit Factor | Gross profit / Gross loss | > 1.3 | > 1.8 |
| 3 | Win Rate | Winning trades / Total trades | > 40% | > 55% |
| 4 | Avg Win/Loss Ratio | Average win / Average loss | > 1.2 | > 1.5 |
| 5 | Max Drawdown % | Peak-to-trough / Peak equity | < 25% | < 15% |
| 6 | Recovery Factor | Net profit / Max DD | > 1.5 | > 3.0 |
| 7 | Total Trades | Count of closed trades | > 200 | > 500 |
| 8 | Expectancy | (W% * AvgW) - (L% * AvgL) | > $0 | > $5/trade |

### Tier 2: Risk-Adjusted Performance

| # | Metric | Target |
|---|---|---|
| 9 | Sharpe Ratio | > 1.0 |
| 10 | Sortino Ratio | > 1.5 |
| 11 | Calmar Ratio | > 1.0 |
| 12 | Ulcer Index | < 10 |
| 13 | Max Consecutive Losses | < 8 |
| 14 | Max Consecutive Loss Amount | < 5% equity |
| 15 | Avg Trade Duration | Strategy-appropriate |
| 16 | Max Single Trade Loss | < 3% equity |

### Tier 3: Robustness & Consistency

| # | Metric | Target |
|---|---|---|
| 17 | Monthly Win Rate | > 65% of months profitable |
| 18 | Quarterly Consistency | < 30% std dev across quarters |
| 19 | Walk-Forward Efficiency | OOS PF > 70% of IS PF |
| 20 | Parameter Sensitivity | Profitable within +/-20% param change |
| 21 | Stagnation Period | < 90 days without new equity high |
| 22 | Monte Carlo 95th DD | < 25% |
| 23 | Regime Performance Split | Profitable in 3/4 regimes |
| 24 | Year-over-Year Stability | No single year > 50% of total profit |

### Tier 4: Execution Quality

| # | Metric | Target |
|---|---|---|
| 25 | Avg Slippage | < 5 points |
| 26 | Avg Spread Cost | < 30 points |
| 27 | Fill Rate | > 98% |
| 28 | Partial Fill Rate | < 2% |
| 29 | Requote Rate | < 1% |

### Tier 5: Portfolio Integration

| # | Metric | Target |
|---|---|---|
| 30 | Correlation with Other EAs | < 0.50 |
| 31 | Portfolio Contribution Ratio | 10-40% of total portfolio return |
| 32 | Marginal Risk Contribution | < 30% of portfolio VaR |
| 33 | Diversification Benefit | Portfolio DD < worst individual EA DD |

**Scoring:**
- Tier 1 all pass: EA approved for live at minimum size
- Tier 1 + Tier 2 pass: EA approved for standard sizing
- Tiers 1-3 pass: EA approved for full allocation
- Tiers 1-4 pass: EA approved for full allocation with quality confidence
- All 5 tiers pass: EA approved for portfolio integration at full allocation
- Any Tier 1 fail: DO NOT deploy live

---

## Output Contract

Every analysis MUST produce output in this structured format:

```json
{
  "analysis_timestamp": "2026-02-22T10:30:00Z",
  "account": {
    "equity": 10000.00,
    "balance": 10200.00,
    "margin_level_percent": 850.0
  },
  "position_sizing": {
    "method_used": "ATR-based dynamic (primary), Fixed Fraction (baseline)",
    "recommended_lot": 0.05,
    "max_lot_hard_cap": 0.10,
    "risk_per_trade_percent": 1.5,
    "risk_per_trade_dollars": 150.00,
    "sl_distance_dollars": 22.50,
    "sl_method": "2.0x ATR(H1,14)",
    "kelly_fraction_raw": 0.22,
    "kelly_applied": "quarter-Kelly capped at 2%"
  },
  "portfolio_heat": {
    "current_heat_percent": 3.2,
    "heat_zone": "YELLOW",
    "open_positions": 2,
    "max_positions": 3,
    "correlation_adjustment_factor": 1.35,
    "adjusted_heat_percent": 4.32,
    "can_add_position": true,
    "next_position_max_risk_percent": 0.68
  },
  "risk_metrics": {
    "var_95_daily_dollars": 425.00,
    "var_99_daily_dollars": 680.00,
    "cvar_95_daily_dollars": 595.00,
    "max_drawdown_projected_percent": 12.5,
    "monte_carlo_95th_dd_percent": 18.2,
    "sharpe_ratio": 1.45,
    "sortino_ratio": 2.10,
    "calmar_ratio": 1.80,
    "profit_factor": 1.85,
    "recovery_factor": 2.40
  },
  "regime_assessment": {
    "current_regime": "TRENDING",
    "atr_h1_14": 16.50,
    "adx_14": 28.5,
    "regime_multiplier": 1.00,
    "regime_adjusted_lot": 0.05
  },
  "shutdown_rules": [
    {"condition": "DD > 15%", "action": "STOP EA, manual review", "current_value": "4.2%", "status": "OK"},
    {"condition": "Daily loss > 5%", "action": "Shutdown all EAs", "current_value": "0.8%", "status": "OK"},
    {"condition": "Consecutive losses > 5", "action": "Pause 4 hours", "current_value": "2", "status": "OK"},
    {"condition": "Margin < 300%", "action": "No new positions", "current_value": "850%", "status": "OK"}
  ],
  "regime_adjustments": {
    "trending": {"lot_multiplier": 1.00, "max_positions": 3, "notes": "Full sizing, current regime"},
    "ranging": {"lot_multiplier": 0.60, "max_positions": 2, "notes": "Reduce for whipsaw risk"},
    "high_volatility": {"lot_multiplier": 0.40, "max_positions": 2, "notes": "Widen stops, reduce exposure"},
    "crisis": {"lot_multiplier": 0.15, "max_positions": 1, "notes": "Survival mode, minimum exposure"}
  },
  "recommendations": [
    "Current sizing is appropriate for trending regime",
    "Monitor ADX -- if drops below 20, switch to ranging regime adjustments",
    "Consider reducing silver exposure to avoid correlation-doubled risk",
    "Next FOMC in 5 days: pre-reduce positions 2 hours before announcement"
  ],
  "warnings": []
}
```

---

## Error Handling & Quality Standards

### Input Validation

```
Before ANY calculation:
├─ Equity > 0? -> CONTINUE (else: ABORT with "Invalid account data")
├─ Risk% between 0.1% and 5%? -> CONTINUE (else: WARN and cap at 2%)
├─ SL distance > 0? -> CONTINUE (else: ABORT with "Stop loss required")
├─ ATR available? -> CONTINUE (else: use default $10 with WARNING)
├─ Win rate between 0% and 100%? -> CONTINUE (else: REJECT input)
└─ Lot result >= min lot? -> CONTINUE (else: WARN "account too small for this SL")
```

### Calculation Verification

```
After EVERY calculation:
├─ Lot size within broker min/max? -> PASS
├─ Lot size step-normalized? -> PASS (floor to nearest 0.01)
├─ Risk amount < 3% of equity? -> PASS (else: OVERRIDE with 2% max)
├─ Portfolio heat after new position < 6%? -> PASS (else: reduce or block)
├─ VaR(95%) < 5% of equity? -> PASS (else: WARN about concentration)
└─ All metrics calculated without division by zero? -> PASS
```

### Common Error Scenarios

| Error | Cause | Resolution |
|---|---|---|
| Lot = 0.00 after calculation | SL too wide for account size | Reduce SL multiplier or increase risk% (max 2%) |
| Kelly negative | Losing strategy | DO NOT TRADE; report negative expectancy |
| Portfolio heat > 10% | Too many correlated positions | Immediately close worst-performing position |
| VaR exceeds daily loss limit | Concentration risk | Reduce total exposure across all positions |
| Monte Carlo DD > 30% | Strategy fragility | Reduce base lot by 40%, retest |
| Margin level < 200% | Over-leveraged | Close positions until margin > 300% |

### Quality Checklist (Execute Before Delivering Output)

```
[ ] All four position sizing methods calculated
[ ] Most conservative method selected as recommendation
[ ] Portfolio heat calculated with correlation adjustment
[ ] VaR and CVaR computed (or estimated from benchmarks)
[ ] All four regime stress tests applied
[ ] No hard limits violated in any scenario
[ ] Shutdown rules evaluated against current values
[ ] Output Contract JSON is valid and complete
[ ] Recommendations are specific and actionable
[ ] Warnings highlight any concerns found during analysis
```

---

## References

- MQL5 Documentation: https://www.mql5.com/en/docs
- Position Sizing: Van K. Tharp, "Trade Your Way to Financial Freedom"
- Kelly Criterion: Ed Thorp, "The Kelly Capital Growth Investment Criterion"
- VaR/CVaR: Philippe Jorion, "Value at Risk"
- Gold Market Data: World Gold Council (gold.org/goldhub)
- XAUUSD Correlations: FRED (fred.stlouisfed.org), CFTC COT Reports

---

---

## Inputs & Assumptions

### Required Inputs

| Input | Source | Fallback |
|---|---|---|
| Account equity/balance | User or MT5 report | $10,000 default |
| EA name(s) and strategy type | User | "Unknown EA" |
| Win rate (rolling 100+ trades) | Backtest report or live history | 50% (neutral assumption) |
| Avg win / avg loss ratio | Backtest report or live history | 1.0 (break-even assumption) |
| Max historical drawdown | Backtest report | 15% (conservative estimate, aligns with emergency threshold) |
| Current open positions | User or EA log | 0 (no open positions) |

### Optional Inputs (Improve Accuracy)

| Input | Impact | Default If Missing |
|---|---|---|
| Full trade history CSV | Enables Monte Carlo, regime analysis | Benchmark-based estimates |
| Current ATR(H1,14) | Precise volatility sizing | $10 (normal range $8-$12) |
| Active market regime | Regime multiplier selection | Auto-detect via ADX+ATR |
| Correlation data (multi-EA) | Portfolio heat adjustment | Same-direction = 0.95 |
| Broker spread/slippage stats | Execution cost modeling | ECN defaults (20-40 pts) |

### Standing Assumptions

- All calculations use XAUUSD contract specs: 1 lot = 100 oz, $100 per $1.00 move
- Swap costs are excluded from position sizing (accounted separately in P&L)
- Risk percentages are based on equity (not balance) to account for floating P&L
- ATR baseline median: $10 (XAUUSD H1, normal range $8-$12; above $15 = elevated volatility)
- Kelly criterion always capped at quarter-Kelly or 2%, whichever is lower
- VaR benchmarks assume 252 trading days per year
- Correlation values are approximate 2024-2026 averages; they shift in crisis regimes

<!-- STATIC CONTEXT BLOCK END -->

---

## Dynamic Execution Zone

<!-- Dynamic content below this line — market data, account snapshots, EA stats -->
<!-- This section is populated at runtime with live context -->

### Runtime Context (Populated Per Invocation)

```
Account snapshot:
- Equity: [from user/MT5]
- Open positions: [from user/EA log]
- Current margin level: [from user/MT5]

Market conditions:
- Current ATR(H1,14): [live or user-provided]
- Current ADX(14): [live or user-provided]
- Detected regime: [auto-detect or user override]
- Upcoming events: [from economic calendar]

EA performance:
- [EA_name]: win_rate, PF, max_DD, consecutive_losses, last_50_trades_summary
- [Repeat for each active EA]
```

### Regime Override Protocol

If the user explicitly states the current regime (e.g., "we're in a crisis"), use that override even if ATR/ADX heuristics suggest otherwise. Log the override in the output:
```json
{"regime_override": true, "user_regime": "CRISIS", "heuristic_regime": "HIGH_VOL", "note": "User override applied"}
```
