---
name: strategy-spec-risk
description: Convert strategy hypotheses into formal, machine-readable specifications with precise entry/exit rules, filters, risk parameters, and regime definitions for EA code generation.
---

# Strategy Spec & Risk

<!-- STATIC CONTEXT BLOCK START - Optimized for prompt caching -->
<!-- All static instructions, methodology, and templates below this line -->
<!-- Dynamic content (strategy hypotheses, specs) added after this block -->

## Core System Instructions

**Purpose:** Transform Strategy Hypothesis documents (produced by strategy-researcher) into formal, machine-readable specifications that can be directly translated into MQL5 Expert Advisor code. Every output must be precise enough for an automated code generator or developer to implement without interpretation or guesswork.

**Context Strategy:** This skill uses context engineering best practices:
- Static instructions cached (this section)
- Progressive disclosure (load hypothesis details only when needed)
- Avoid "loss in the middle" (critical constraints at start/end)
- Explicit section markers for context navigation

**Core Principles:**
1. **Zero Ambiguity** -- Every rule must resolve to a single boolean outcome. No "approximately", "around", "roughly", or "generally".
2. **Machine-Readable** -- Output must be valid JSON that can be parsed programmatically. Every field has a defined type, range, and unit.
3. **1:1 MQL5 Mapping** -- Every parameter in the spec must map to exactly one MQL5 `input` variable or internal constant. No orphaned parameters.
4. **Defensive Risk Design** -- Risk rules are non-negotiable constraints, not suggestions. The EA must enforce them as hard limits.
5. **Regime-Aware** -- The spec must define behavior for every market regime. Undefined regime behavior defaults to "do not trade".
6. **XAUUSD Calibrated** -- All numerical values must be calibrated for gold's characteristics: high pip value, wide spreads, volatile sessions, macro sensitivity.

**What This Skill Does:**
- Validates strategy hypotheses for completeness and consistency
- Converts qualitative conditions into exact numerical thresholds
- Produces a formal JSON specification for EA code generation
- Defines all risk parameters as hard constraints
- Maps every parameter to MQL5 input variables
- Creates regime detection rules and filter logic

**What This Skill Does NOT Do:**
- Conduct market research (that is strategy-researcher's job)
- Write MQL5 code (that is the executor/coder agent's job)
- Run backtests (that is the backtest agent's job)
- Modify the trading strategy logic (only formalizes what the researcher defined)

---

## Decision Tree (Execute First)

```
Input Analysis
|-- No hypothesis provided? --> STOP: Request hypothesis from strategy-researcher first
|-- Hypothesis incomplete? --> PARTIAL: List missing fields, request completion
|-- Hypothesis has vague conditions? --> REFINE: Convert each to numerical threshold
+-- Hypothesis is complete and precise? --> CONTINUE to formalization

Validation Depth
|-- Simple strategy (3-5 conditions)? --> STANDARD validation
|-- Complex strategy (6+ conditions)? --> DEEP validation with contradiction check
+-- Multi-regime strategy? --> DEEP validation + regime transition matrix

Formalization Path
|-- Single-direction (long only or short only)? --> Single-side spec
|-- Bi-directional? --> Dual-side spec with independent conditions
+-- Adaptive (regime-dependent)? --> Multi-mode spec with mode switching logic

Output Gate
|-- Quality checklist passes? --> Output JSON spec
|-- Checklist has warnings? --> Output spec + warnings section
+-- Checklist has blockers? --> REJECT: Return to researcher with specific issues
```

---

## Workflow

### Phase 1: Receive Hypothesis

Accept a Strategy Hypothesis document from strategy-researcher. The hypothesis must contain at minimum:
- Premise (trading idea)
- Entry conditions with indicator names and approximate thresholds
- Exit conditions (TP and SL methods)
- Filters (at least news, session, spread)
- Risk model basics (risk per trade, max drawdown)
- Regime dependency statement

### Phase 2: Validate Hypothesis

Run the following validation checks:

**Check 1: Completeness Scan**

| Required Section | Status | Notes |
|-----------------|--------|-------|
| Premise | Present / Missing | Must be falsifiable |
| Entry conditions (at least 3) | Present / Missing | Each needs indicator + threshold |
| Exit conditions (SL + TP) | Present / Missing | Both methods required |
| Filters (at least 3) | Present / Missing | News + Session + Spread minimum |
| Risk model (6 parameters) | Present / Missing | All 6 must be defined |
| Regime dependency (4 regimes) | Present / Missing | All 4 must have an action |
| Expected performance targets | Present / Missing | At least 5 metrics |

**Check 2: Consistency Analysis**

| Rule | Test | Pass/Fail |
|------|------|-----------|
| Positive expectancy | WinRate * AvgWin > (1 - WinRate) * AvgLoss | Must pass |
| SL feasibility | SL distance > typical spread * 3 | Must pass |
| TP realism | TP distance achievable within avg trade duration given ATR | Must pass |
| Filter coverage | Filters do not eliminate > 70% of trading hours | Must pass |
| Risk coherence | risk_per_trade * max_positions <= max_daily_loss | Must pass |
| Max DD alignment | max_consecutive_losses * risk_per_trade < max_drawdown | Should pass |
| Entry mutex | Long and short conditions cannot fire simultaneously | Must pass |
| Regime coverage | At least 1 regime has action = "trade" | Must pass |

**Check 3: XAUUSD Calibration**

| Parameter | Valid Range for XAUUSD | Check |
|-----------|----------------------|-------|
| SL distance (H1 strategy) | $5 - $50 (typically 1-3x ATR) | In range? |
| TP distance (H1 strategy) | $8 - $100 (typically 1.5-5x ATR) | In range? |
| Max spread filter | $0.20 - $1.00 (20-100 points) | In range? |
| ATR(14) H1 reference | $5 - $25 (normal market) | In range? |
| Position size | 0.01 - 10.0 lots typical | In range? |
| Risk per trade | 0.5% - 2.0% (conservative to aggressive) | In range? |
| Max drawdown | 10% - 25% | In range? |
| Session hours (GMT+7) | At least London or NY covered | Covered? |

### Phase 3: Formalize Specification

Convert the validated hypothesis into the formal JSON specification format (see Output Contract below).

**Conversion Rules:**

| Hypothesis Element | Spec Element | Conversion |
|-------------------|-------------|------------|
| "Price above EMA 200" | `entry_conditions[n]` | `{"indicator": "ma", "params": {"period": 200, "applied_price": "close", "method": "MODE_EMA"}, "timeframe": "PERIOD_H1", "buffer_index": 0, "compare": "price_above"}` |
| "RSI > 50" | `entry_conditions[n]` | `{"indicator": "rsi", "params": {"period": 14, "applied_price": "close"}, "timeframe": "PERIOD_H1", "buffer_index": 0, "compare": ">", "value": 50}` |
| "ADX > 25" | `entry_conditions[n]` | `{"indicator": "adx", "params": {"period": 14}, "timeframe": "PERIOD_H1", "buffer_index": 0, "compare": ">", "value": 25}` |
| "Avoid news 30min" | `filters.news` | `{"avoid_before_minutes": 30, "avoid_after_minutes": 15, "impact": "high"}` |
| "London-NY overlap" | `filters.session` | `{"start_hour": 20, "end_hour": 23, "timezone": "GMT+7"}` |
| "Max spread $0.50" | `filters.spread` | `{"max_spread_points": 50}` |
| "1% risk per trade" | `risk_rules.risk_per_trade` | `1.0` |
| "ATR trailing stop" | `exit_conditions.trailing` | `{"method": "atr", "multiplier": 1.5, "period": 14}` |

**Indicator Standardization:**

Every indicator reference must include:

```json
{
  "indicator": "string (lowercase, MQL5 function name without 'i' prefix)",
  "params": {
    "period": "int",
    "applied_price": "string (close|open|high|low|median|typical|weighted)",
    "shift": "int (default 0, use 1 for confirmed/closed bar)"
  },
  "timeframe": "string (M1|M5|M15|M30|H1|H4|D1|W1|MN1)",
  "buffer_index": "int (for multi-buffer indicators like MACD, Bollinger)"
}
```

**Standard Indicator Map for XAUUSD EA:**

| Common Name | MQL5 Function | Key Params | Buffer Index |
|-------------|--------------|------------|-------------|
| SMA | `iMA` | period, MODE_SMA | 0 |
| EMA | `iMA` | period, MODE_EMA | 0 |
| RSI | `iRSI` | period, PRICE_CLOSE | 0 |
| MACD Signal | `iMACD` | fast=12, slow=26, signal=9 | 0=main, 1=signal |
| MACD Histogram | `iMACD` | fast=12, slow=26, signal=9 | Computed: main - signal |
| Bollinger Upper | `iBands` | period=20, deviation=2.0 | 1=upper |
| Bollinger Lower | `iBands` | period=20, deviation=2.0 | 2=lower |
| Bollinger Middle | `iBands` | period=20, deviation=2.0 | 0=middle |
| ATR | `iATR` | period=14 | 0 |
| ADX | `iADX` | period=14 | 0=main, 1=+DI, 2=-DI |
| Stochastic | `iStochastic` | K=14, D=3, slowing=3 | 0=main, 1=signal |
| Ichimoku Tenkan | `iIchimoku` | tenkan=9, kijun=26, senkou=52 | 0 |
| Ichimoku Kijun | `iIchimoku` | tenkan=9, kijun=26, senkou=52 | 1 |
| Ichimoku Senkou A | `iIchimoku` | tenkan=9, kijun=26, senkou=52 | 2 |
| Ichimoku Senkou B | `iIchimoku` | tenkan=9, kijun=26, senkou=52 | 3 |
| Williams %R | `iWPR` | period=14 | 0 |
| CCI | `iCCI` | period=14, PRICE_TYPICAL | 0 |
| Volume (tick) | `iVolumes` | VOLUME_TICK | 0 |

### Phase 4: Quality Check

Run the Quality Checklist (see section below) against the produced spec. All blockers must be resolved before output.

### Phase 5: Output Specification

Produce the final JSON spec and parameter mapping table.

---

## Output Contract: Strategy Specification

### Primary JSON Format

> **IMPORTANT -- Enum fields:** Values shown with pipe separators (e.g., `"trending | ranging"`, `"atr_multiple | fixed_points"`) represent enum options. The agent MUST select exactly ONE value when generating output -- do NOT include the pipe characters or multiple options in the final specification.

```json
{
  "spec_id": "SS-YYYYMMDD-NNN",
  "hypothesis_id": "SH-YYYYMMDD-NNN",
  "metadata": {
    "strategy_name": "string (PascalCase, max 32 chars)",
    "version": "1.0.0",
    "author": "strategy-spec-risk",
    "date": "YYYY-MM-DD",
    "status": "DRAFT | VALIDATED | APPROVED | REJECTED",
    "asset": "XAUUSD",
    "primary_timeframe": "H1",
    "style": "trend-follow | mean-reversion | breakout | grid | scalping | swing | news-trading",
    "direction": "long-only | short-only | bidirectional",
    "regime": "trending | ranging | volatile | all"
  },

  "entry_conditions": {
    "long": [
      {
        "id": "L1",
        "name": "Higher TF Trend Filter",
        "description": "Price must be above EMA 200 on H4 for bullish bias",
        "indicator": {
          "function": "iMA",
          "symbol": "_Symbol",
          "timeframe": "PERIOD_H4",
          "params": {
            "ma_period": 200,
            "ma_shift": 0,
            "ma_method": "MODE_EMA",
            "applied_price": "PRICE_CLOSE"
          },
          "buffer_index": 0,
          "shift": 1
        },
        "compare": "price_above",
        "value": null,
        "required": true,
        "weight": 30
      },
      {
        "id": "L2",
        "name": "Signal TF EMA Cross",
        "description": "EMA 9 crosses above EMA 21 on H1",
        "indicator": {
          "function": "iMA",
          "symbol": "_Symbol",
          "timeframe": "PERIOD_H1",
          "params": {
            "ma_period": [9, 21],
            "ma_shift": 0,
            "ma_method": "MODE_EMA",
            "applied_price": "PRICE_CLOSE"
          },
          "buffer_index": 0,
          "shift": 1
        },
        "compare": "cross_above",
        "value": null,
        "required": true,
        "weight": 25
      },
      {
        "id": "L3",
        "name": "Momentum Confirmation",
        "description": "RSI(14) must be above 50 on H1",
        "indicator": {
          "function": "iRSI",
          "symbol": "_Symbol",
          "timeframe": "PERIOD_H1",
          "params": {
            "ma_period": 14,
            "applied_price": "PRICE_CLOSE"
          },
          "buffer_index": 0,
          "shift": 1
        },
        "compare": "greater_than",
        "value": 50.0,
        "required": true,
        "weight": 15
      },
      {
        "id": "L4",
        "name": "Volatility Gate",
        "description": "ATR(14) on H1 must exceed minimum threshold",
        "indicator": {
          "function": "iATR",
          "symbol": "_Symbol",
          "timeframe": "PERIOD_H1",
          "params": {
            "ma_period": 14
          },
          "buffer_index": 0,
          "shift": 1
        },
        "compare": "greater_than",
        "value": 5.0,
        "required": true,
        "weight": 10
      },
      {
        "id": "L5",
        "name": "Trend Strength",
        "description": "ADX(14) must be above 25 for trend confirmation",
        "indicator": {
          "function": "iADX",
          "symbol": "_Symbol",
          "timeframe": "PERIOD_H1",
          "params": {
            "ma_period": 14
          },
          "buffer_index": 0,
          "shift": 1
        },
        "compare": "greater_than",
        "value": 25.0,
        "required": false,
        "weight": 20
      }
    ],
    "short": [],
    "logic": {
      "type": "weighted_score | all_required | any_n_of_m",
      "threshold": 70,
      "min_required_count": null,
      "note": "If type=weighted_score, sum weights of passing conditions. If type=all_required, all required=true conditions must pass. If type=any_n_of_m, at least min_required_count must pass."
    }
  },

  "exit_conditions": {
    "take_profit": {
      "primary": {
        "method": "atr_multiple | fixed_points | fixed_dollars | risk_multiple | fibonacci_extension",
        "value": 3.0,
        "unit": "atr_multiplier | points | dollars | risk_ratio | fib_level",
        "indicator": {
          "function": "iATR",
          "timeframe": "PERIOD_H1",
          "params": {"ma_period": 14},
          "buffer_index": 0,
          "shift": 1
        }
      },
      "partial_close": [
        {
          "percent_of_position": 50,
          "trigger": {
            "method": "risk_multiple",
            "value": 1.0,
            "description": "Close 50% when trade reaches 1:1 R:R"
          }
        },
        {
          "percent_of_position": 50,
          "trigger": {
            "method": "trailing",
            "value": null,
            "description": "Remaining 50% managed by trailing stop"
          }
        }
      ]
    },
    "stop_loss": {
      "initial": {
        "method": "atr_multiple | fixed_points | fixed_dollars | structure",
        "value": 2.0,
        "unit": "atr_multiplier | points | dollars",
        "indicator": {
          "function": "iATR",
          "timeframe": "PERIOD_H1",
          "params": {"ma_period": 14},
          "buffer_index": 0,
          "shift": 1
        },
        "placement": "below_swing_low | above_swing_high | fixed_distance",
        "buffer_points": 10,
        "min_sl_points": 50,
        "max_sl_points": 500
      },
      "breakeven": {
        "enabled": true,
        "trigger_profit_points": 100,
        "lock_profit_points": 10,
        "description": "Move SL to entry + 10 points when trade is 100 points in profit"
      },
      "trailing": {
        "enabled": true,
        "method": "atr | fixed_step | chandelier | parabolic_sar",
        "activation_profit_points": 150,
        "trail_distance": {
          "value": 1.5,
          "unit": "atr_multiplier | points"
        },
        "step_points": 10,
        "indicator": {
          "function": "iATR",
          "timeframe": "PERIOD_H1",
          "params": {"ma_period": 14},
          "buffer_index": 0,
          "shift": 1
        }
      }
    },
    "time_exit": {
      "enabled": true,
      "max_bars": 48,
      "max_hours": null,
      "condition": "if_not_in_profit | always | if_below_breakeven",
      "description": "Close position after 48 H1 bars if not in profit"
    },
    "signal_exit": {
      "enabled": true,
      "conditions": [
        {
          "name": "Reverse EMA Cross",
          "description": "Close long if EMA 9 crosses below EMA 21",
          "indicator": {
            "function": "iMA",
            "timeframe": "PERIOD_H1",
            "params": {"ma_period": [9, 21], "ma_method": "MODE_EMA"}
          },
          "compare": "cross_below"
        }
      ]
    },
    "session_exit": {
      "enabled": false,
      "close_at_session_end": false,
      "close_before_weekend": true,
      "friday_close_hour": 4,
      "friday_close_minute": 30,
      "timezone": "GMT+7"
    }
  },

  "filters": {
    "news": {
      "enabled": true,
      "avoid_before_minutes": 30,
      "avoid_after_minutes": 15,
      "impact_levels": ["high"],
      "close_positions_before_news": false,
      "widen_sl_during_news": false,
      "widen_sl_multiplier": null,
      "data_source": "mql5_calendar | forexfactory | custom_api",
      "events_to_track": [
        "FOMC", "NFP", "CPI", "GDP", "PPI", "PCE",
        "Fed_Chair_Speech", "FOMC_Minutes", "Jobless_Claims",
        "Retail_Sales", "ISM_PMI"
      ]
    },
    "session": {
      "enabled": true,
      "timezone": "GMT+7",
      "allowed_sessions": [
        {
          "name": "London",
          "start_hour": 14,
          "start_minute": 0,
          "end_hour": 23,
          "end_minute": 0
        },
        {
          "name": "NewYork",
          "start_hour": 20,
          "start_minute": 0,
          "end_hour": 5,
          "end_minute": 0
        },
        {
          "name": "LondonNYOverlap",
          "start_hour": 20,
          "start_minute": 0,
          "end_hour": 23,
          "end_minute": 0
        }
      ],
      "active_sessions": ["LondonNYOverlap"],
      "allow_trade_management_outside_session": true
    },
    "spread": {
      "enabled": true,
      "max_spread_points": 50,
      "max_spread_dollars": 0.50,
      "action_on_high_spread": "wait | skip | reduce_lot_size",
      "check_frequency": "every_tick | every_bar"
    },
    "volatility": {
      "enabled": true,
      "indicator": {
        "function": "iATR",
        "timeframe": "PERIOD_H1",
        "params": {"ma_period": 14}
      },
      "min_atr": 5.0,
      "max_atr": 25.0,
      "unit": "dollars",
      "action_on_low_volatility": "skip",
      "action_on_high_volatility": "reduce_lot_size | skip | widen_sl"
    },
    "trend_alignment": {
      "enabled": true,
      "higher_timeframe": "PERIOD_H4",
      "method": "price_vs_ema | ema_alignment | adx_direction",
      "indicator": {
        "function": "iMA",
        "timeframe": "PERIOD_H4",
        "params": {"ma_period": 200, "ma_method": "MODE_EMA"}
      },
      "long_condition": "price > ema_200_h4",
      "short_condition": "price < ema_200_h4"
    },
    "day_of_week": {
      "enabled": false,
      "allowed_days": [1, 2, 3, 4, 5],
      "excluded_days": [],
      "note": "1=Monday, 5=Friday. Most strategies trade all weekdays."
    },
    "cot_positioning": {
      "enabled": false,
      "net_long_threshold": null,
      "divergence_detection": false,
      "data_update_frequency": "weekly",
      "note": "Optional. Requires external data feed (CFTC COT report)."
    },
    "dxy_correlation": {
      "enabled": false,
      "symbol": "USDX",
      "condition": null,
      "note": "Optional. Use when DXY correlation is strong (> 0.6)."
    },
    "equity_curve": {
      "enabled": true,
      "method": "equity_above_ma",
      "ma_period": 20,
      "action": "pause_trading",
      "description": "Stop opening new trades when equity curve falls below its 20-trade moving average"
    }
  },

  "risk_rules": {
    "risk_per_trade_percent": 1.0,
    "max_risk_per_trade_percent": 2.0,
    "max_daily_loss_percent": 5.0,
    "max_weekly_loss_percent": 10.0,
    "max_drawdown_percent": 15.0,
    "max_drawdown_action": "stop_ea | reduce_lot | pause_24h",
    "max_concurrent_positions": 2,
    "max_positions_same_direction": 2,
    "max_correlation_exposure": 1,
    "emergency_stop": {
      "enabled": true,
      "trigger_drawdown_percent": 20.0,
      "action": "close_all_and_stop",
      "notification": true,
      "cooldown_hours": 24
    },
    "daily_trade_limit": {
      "enabled": true,
      "max_trades_per_day": 5,
      "max_losses_per_day": 3,
      "action_on_limit": "stop_trading_today"
    },
    "consecutive_loss_guard": {
      "enabled": true,
      "max_consecutive_losses": 5,
      "action": "pause_trading | reduce_lot_50 | stop_ea",
      "cooldown_bars": 24
    }
  },

  "position_sizing": {
    "method": "atr_risk | fixed_lot | percent_equity | kelly_criterion",
    "risk_per_trade_percent": 1.0,
    "calculation": {
      "formula": "lot_size = (equity * risk_percent) / (sl_points * tick_value_per_lot)",
      "variables": {
        "equity": "AccountInfoDouble(ACCOUNT_EQUITY)",
        "risk_percent": "input_risk_per_trade / 100.0",
        "sl_points": "calculated SL distance in points",
        "tick_value_per_lot": "SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)"
      }
    },
    "lot_constraints": {
      "min_lot": 0.01,
      "max_lot": 10.0,
      "lot_step": 0.01,
      "source": "SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN/MAX/STEP)"
    },
    "scaling": {
      "enabled": false,
      "method": "fixed | martingale | anti_martingale | grid",
      "scale_factor": 1.0,
      "max_scale_level": 1,
      "note": "Martingale is PROHIBITED for XAUUSD due to extreme volatility risk"
    }
  },

  "constraints": {
    "max_spread_points": 50,
    "max_slippage_points": 30,
    "min_free_margin_percent": 50.0,
    "magic_number": 20260222,
    "order_comment": "EA_OAT_v5",
    "order_type_filling": "ORDER_FILLING_FOK | ORDER_FILLING_IOC | ORDER_FILLING_RETURN",
    "max_retry_on_error": 3,
    "retry_delay_ms": 500,
    "time_windows": [
      {
        "name": "Primary Trading",
        "start": "20:00",
        "end": "23:00",
        "timezone": "GMT+7",
        "priority": 1
      },
      {
        "name": "Secondary Trading",
        "start": "14:00",
        "end": "20:00",
        "timezone": "GMT+7",
        "priority": 2
      }
    ],
    "broker_requirements": {
      "min_leverage": "1:100",
      "account_type": "hedging | netting",
      "execution_type": "market | instant",
      "swap_consideration": true
    }
  },

  "input_parameters": [
    {
      "name": "InpMagicNumber",
      "type": "int",
      "default": 20260222,
      "min": 1,
      "max": 2147483647,
      "description": "EA Magic Number for order identification",
      "group": "General",
      "mql5_declaration": "input int InpMagicNumber = 20260222; // Magic Number"
    },
    {
      "name": "InpRiskPercent",
      "type": "double",
      "default": 1.0,
      "min": 0.1,
      "max": 5.0,
      "step": 0.1,
      "description": "Risk per trade as percentage of equity",
      "group": "Risk Management",
      "mql5_declaration": "input double InpRiskPercent = 1.0; // Risk Per Trade (%)"
    },
    {
      "name": "InpMaxDailyLoss",
      "type": "double",
      "default": 5.0,
      "min": 1.0,
      "max": 15.0,
      "step": 0.5,
      "description": "Maximum daily loss as percentage of equity",
      "group": "Risk Management",
      "mql5_declaration": "input double InpMaxDailyLoss = 5.0; // Max Daily Loss (%)"
    },
    {
      "name": "InpMaxDrawdown",
      "type": "double",
      "default": 15.0,
      "min": 5.0,
      "max": 30.0,
      "step": 1.0,
      "description": "Maximum drawdown before EA stops",
      "group": "Risk Management",
      "mql5_declaration": "input double InpMaxDrawdown = 15.0; // Max Drawdown (%)"
    },
    {
      "name": "InpMaxPositions",
      "type": "int",
      "default": 2,
      "min": 1,
      "max": 5,
      "description": "Maximum concurrent positions",
      "group": "Risk Management",
      "mql5_declaration": "input int InpMaxPositions = 2; // Max Positions"
    },
    {
      "name": "InpEMA_Fast",
      "type": "int",
      "default": 9,
      "min": 3,
      "max": 50,
      "description": "Fast EMA period for signal",
      "group": "Signal",
      "mql5_declaration": "input int InpEMA_Fast = 9; // Fast EMA Period"
    },
    {
      "name": "InpEMA_Slow",
      "type": "int",
      "default": 21,
      "min": 10,
      "max": 100,
      "description": "Slow EMA period for signal",
      "group": "Signal",
      "mql5_declaration": "input int InpEMA_Slow = 21; // Slow EMA Period"
    },
    {
      "name": "InpEMA_Trend",
      "type": "int",
      "default": 200,
      "min": 100,
      "max": 500,
      "description": "Trend EMA period on higher timeframe",
      "group": "Signal",
      "mql5_declaration": "input int InpEMA_Trend = 200; // Trend EMA Period"
    },
    {
      "name": "InpRSI_Period",
      "type": "int",
      "default": 14,
      "min": 5,
      "max": 50,
      "description": "RSI period for momentum filter",
      "group": "Signal",
      "mql5_declaration": "input int InpRSI_Period = 14; // RSI Period"
    },
    {
      "name": "InpRSI_Level",
      "type": "double",
      "default": 50.0,
      "min": 30.0,
      "max": 70.0,
      "step": 5.0,
      "description": "RSI threshold for buy signal",
      "group": "Signal",
      "mql5_declaration": "input double InpRSI_Level = 50.0; // RSI Buy Level"
    },
    {
      "name": "InpATR_Period",
      "type": "int",
      "default": 14,
      "min": 5,
      "max": 50,
      "description": "ATR period for volatility and SL/TP calculation",
      "group": "Volatility",
      "mql5_declaration": "input int InpATR_Period = 14; // ATR Period"
    },
    {
      "name": "InpATR_SL_Multi",
      "type": "double",
      "default": 2.0,
      "min": 1.0,
      "max": 5.0,
      "step": 0.1,
      "description": "ATR multiplier for stop loss distance",
      "group": "Exit",
      "mql5_declaration": "input double InpATR_SL_Multi = 2.0; // SL ATR Multiplier"
    },
    {
      "name": "InpATR_TP_Multi",
      "type": "double",
      "default": 3.0,
      "min": 1.5,
      "max": 8.0,
      "step": 0.1,
      "description": "ATR multiplier for take profit distance",
      "group": "Exit",
      "mql5_declaration": "input double InpATR_TP_Multi = 3.0; // TP ATR Multiplier"
    },
    {
      "name": "InpTrailingATR_Multi",
      "type": "double",
      "default": 1.5,
      "min": 0.5,
      "max": 4.0,
      "step": 0.1,
      "description": "ATR multiplier for trailing stop distance",
      "group": "Exit",
      "mql5_declaration": "input double InpTrailingATR_Multi = 1.5; // Trailing ATR Multiplier"
    },
    {
      "name": "InpTrailingActivation",
      "type": "int",
      "default": 150,
      "min": 50,
      "max": 500,
      "step": 10,
      "description": "Profit in points before trailing activates",
      "group": "Exit",
      "mql5_declaration": "input int InpTrailingActivation = 150; // Trailing Activation (points)"
    },
    {
      "name": "InpBreakevenProfit",
      "type": "int",
      "default": 100,
      "min": 30,
      "max": 300,
      "step": 10,
      "description": "Profit in points to move SL to breakeven",
      "group": "Exit",
      "mql5_declaration": "input int InpBreakevenProfit = 100; // Breakeven Trigger (points)"
    },
    {
      "name": "InpPartialClosePercent",
      "type": "int",
      "default": 50,
      "min": 0,
      "max": 80,
      "step": 10,
      "description": "Percentage of position to close at first TP",
      "group": "Exit",
      "mql5_declaration": "input int InpPartialClosePercent = 50; // Partial Close (%)"
    },
    {
      "name": "InpMaxSpread",
      "type": "int",
      "default": 50,
      "min": 10,
      "max": 200,
      "description": "Maximum allowed spread in points",
      "group": "Filters",
      "mql5_declaration": "input int InpMaxSpread = 50; // Max Spread (points)"
    },
    {
      "name": "InpSessionStart",
      "type": "int",
      "default": 20,
      "min": 0,
      "max": 23,
      "description": "Trading session start hour (server time)",
      "group": "Filters",
      "mql5_declaration": "input int InpSessionStart = 20; // Session Start Hour"
    },
    {
      "name": "InpSessionEnd",
      "type": "int",
      "default": 23,
      "min": 0,
      "max": 23,
      "description": "Trading session end hour (server time)",
      "group": "Filters",
      "mql5_declaration": "input int InpSessionEnd = 23; // Session End Hour"
    },
    {
      "name": "InpNewsFilter",
      "type": "bool",
      "default": true,
      "description": "Enable news event filter",
      "group": "Filters",
      "mql5_declaration": "input bool InpNewsFilter = true; // Enable News Filter"
    },
    {
      "name": "InpNewsAvoidMinutes",
      "type": "int",
      "default": 30,
      "min": 5,
      "max": 120,
      "description": "Minutes to avoid trading before high-impact news",
      "group": "Filters",
      "mql5_declaration": "input int InpNewsAvoidMinutes = 30; // News Avoid Minutes"
    },
    {
      "name": "InpADX_Period",
      "type": "int",
      "default": 14,
      "min": 5,
      "max": 50,
      "description": "ADX period for trend strength filter",
      "group": "Signal",
      "mql5_declaration": "input int InpADX_Period = 14; // ADX Period"
    },
    {
      "name": "InpADX_Level",
      "type": "double",
      "default": 25.0,
      "min": 15.0,
      "max": 40.0,
      "step": 1.0,
      "description": "Minimum ADX level for trend confirmation",
      "group": "Signal",
      "mql5_declaration": "input double InpADX_Level = 25.0; // Min ADX Level"
    },
    {
      "name": "InpMinATR",
      "type": "double",
      "default": 5.0,
      "min": 1.0,
      "max": 15.0,
      "step": 0.5,
      "description": "Minimum ATR value in dollars for volatility filter",
      "group": "Volatility",
      "mql5_declaration": "input double InpMinATR = 5.0; // Min ATR ($)"
    },
    {
      "name": "InpMaxATR",
      "type": "double",
      "default": 25.0,
      "min": 10.0,
      "max": 50.0,
      "step": 1.0,
      "description": "Maximum ATR value in dollars for volatility filter",
      "group": "Volatility",
      "mql5_declaration": "input double InpMaxATR = 25.0; // Max ATR ($)"
    },
    {
      "name": "InpTimeExitBars",
      "type": "int",
      "default": 48,
      "min": 0,
      "max": 240,
      "step": 12,
      "description": "Close position after N bars if not in profit (0=disabled)",
      "group": "Exit",
      "mql5_declaration": "input int InpTimeExitBars = 48; // Time Exit Bars (0=off)"
    },
    {
      "name": "InpMaxTradesPerDay",
      "type": "int",
      "default": 5,
      "min": 1,
      "max": 20,
      "description": "Maximum trades allowed per day",
      "group": "Risk Management",
      "mql5_declaration": "input int InpMaxTradesPerDay = 5; // Max Trades Per Day"
    },
    {
      "name": "InpEquityCurveFilter",
      "type": "bool",
      "default": true,
      "description": "Enable equity curve trading filter",
      "group": "Risk Management",
      "mql5_declaration": "input bool InpEquityCurveFilter = true; // Equity Curve Filter"
    }
  ],

  "regime_definitions": {
    "detection_method": "indicator_based",
    "update_frequency": "every_bar",
    "timeframe": "PERIOD_H4",
    "regimes": {
      "trending": {
        "conditions": [
          {"indicator": "ADX", "period": 14, "compare": ">", "value": 25},
          {"indicator": "EMA_alignment", "fast": 20, "slow": 50, "compare": "aligned"}
        ],
        "logic": "ALL",
        "ea_behavior": {
          "action": "trade",
          "modifications": "none",
          "note": "Primary operating regime for trend-follow strategies"
        }
      },
      "ranging": {
        "conditions": [
          {"indicator": "ADX", "period": 14, "compare": "<", "value": 20},
          {"indicator": "BB_width", "period": 20, "deviation": 2.0, "compare": "<", "value": 0.005, "note": "BB width as fraction of price; ~$10 band on $2000 gold"}
        ],
        "logic": "ALL",
        "ea_behavior": {
          "action": "avoid",
          "modifications": "no_new_entries",
          "note": "Trend-follow strategies perform poorly in ranges. Manage existing positions only."
        }
      },
      "volatile": {
        "conditions": [
          {"indicator": "ATR", "period": 14, "compare": ">", "value": 12.75, "note": "1.5x typical 20-period ATR avg (~8.50); recalculate from live data"},
          {"indicator": "daily_range", "compare": ">", "value": 40.0, "note": "2x average daily range (~20); recalculate from live data"}
        ],
        "logic": "ANY",
        "ea_behavior": {
          "action": "modify",
          "modifications": {
            "sl_multiplier": 1.5,
            "lot_reduction": 0.5,
            "tp_multiplier": 1.5
          },
          "note": "Widen stops, reduce size, extend targets during high volatility"
        }
      },
      "news_driven": {
        "conditions": [
          {"trigger": "within_news_window", "minutes_before": 30, "minutes_after": 15},
          {"trigger": "spread_spike", "threshold": {"value": 100, "unit": "points", "note": "2x normal spread of ~50 points"}}
        ],
        "logic": "ANY",
        "ea_behavior": {
          "action": "avoid",
          "modifications": "no_new_entries",
          "note": "News-driven price action is unpredictable. Filter out entirely for non-news strategies."
        }
      }
    }
  }
}
```

---

## Quality Checklist

### Blocker-Level Issues (MUST fix before output)

| # | Check | Rule | Status |
|---|-------|------|--------|
| B1 | No contradictory logic | Long entry conditions cannot logically contradict each other (e.g., RSI > 70 AND RSI < 30) | -- |
| B2 | No vague terms | All conditions resolve to numerical comparisons. Prohibited words: "around", "approximately", "usually", "might", "sometimes", "strong", "weak" (without numerical definition) | -- |
| B3 | All rules are numerical thresholds | Every comparison must be: >, <, >=, <=, ==, cross_above, cross_below, in_range | -- |
| B4 | SL is always defined | Every entry must have a computable stop loss | -- |
| B5 | Risk per trade is bounded | risk_per_trade_percent must be in [0.1, 5.0] | -- |
| B6 | Max drawdown is defined | max_drawdown_percent must be set and enforced | -- |
| B7 | Position sizing formula is complete | All variables in the lot size formula are defined | -- |
| B8 | Entry logic type is specified | Must be one of: weighted_score, all_required, any_n_of_m | -- |
| B9 | At least 1 tradeable regime | At least one regime has action = "trade" | -- |
| B10 | No Martingale for XAUUSD | Position sizing scaling must not use martingale for gold | -- |

### Warning-Level Issues (Should fix, can proceed with warning)

| # | Check | Rule | Status |
|---|-------|------|--------|
| W1 | Parameter count | Total optimizable parameters should be <= 8 to avoid overfitting | -- |
| W2 | Filter coverage | Filters should not eliminate > 70% of potential trading time | -- |
| W3 | SL-to-spread ratio | SL distance should be >= 5x typical spread | -- |
| W4 | Win rate vs R:R consistency | Win rate target must produce positive expectancy with stated R:R | -- |
| W5 | Regime overlap | Regime conditions should not overlap (two regimes active simultaneously) | -- |
| W6 | Parameter ranges | Min/max ranges for input_parameters should allow meaningful optimization | -- |
| W7 | Indicator redundancy | Avoid using two indicators that measure the same thing (e.g., RSI + Stochastic) | -- |
| W8 | Correlated conditions | Flag conditions that are highly correlated (e.g., EMA alignment + ADX > 25) | -- |

### Information-Level Notes

| # | Note | Description |
|---|------|-------------|
| I1 | Spread at current price | At $5,100/oz, spread of 50 points = $0.50 = ~0.01% of price |
| I2 | Tick value for XAUUSD | 1 standard lot (100 oz): $1 per 1 point ($0.01) move = $100 per $1 move |
| I3 | Swap consideration | Long swaps are typically negative for XAUUSD; positions held overnight incur cost |
| I4 | Weekend gap risk | Gold can gap $20-50+ on Monday open; weekend holds carry additional risk |
| I5 | Broker differences | ECN vs STP vs Market Maker: spread, execution speed, and slippage vary |

---

## Parameter Mapping: Spec to MQL5

### Mapping Convention

Every parameter in the JSON spec maps 1:1 to an MQL5 `input` variable:

```
Naming Convention:
  JSON field                -> MQL5 input variable
  risk_per_trade_percent    -> InpRiskPercent
  max_daily_loss_percent    -> InpMaxDailyLoss
  max_drawdown_percent      -> InpMaxDrawdown
  max_concurrent_positions  -> InpMaxPositions
  ema.fast.period           -> InpEMA_Fast
  ema.slow.period           -> InpEMA_Slow
  rsi.period                -> InpRSI_Period
  atr.sl_multiplier         -> InpATR_SL_Multi
  trailing.activation       -> InpTrailingActivation
  session.start_hour        -> InpSessionStart
  max_spread.points         -> InpMaxSpread

Prefix rules:
  Inp = input parameter (user-configurable)
  g_  = global variable (internal state)
  m_  = class member variable
  e_  = enum value
```

### MQL5 Input Groups

```mql5
//--- General Settings
input int    InpMagicNumber        = 20260222;  // Magic Number
input string InpComment            = "EA_OAT";  // Order Comment

//--- Risk Management
input double InpRiskPercent        = 1.0;       // Risk Per Trade (%)
input double InpMaxDailyLoss       = 5.0;       // Max Daily Loss (%)
input double InpMaxDrawdown        = 15.0;      // Max Drawdown (%)
input int    InpMaxPositions       = 2;         // Max Positions
input int    InpMaxTradesPerDay    = 5;         // Max Trades/Day
input bool   InpEquityCurveFilter  = true;      // Equity Curve Filter

//--- Signal Parameters
input int    InpEMA_Fast           = 9;         // Fast EMA Period
input int    InpEMA_Slow           = 21;        // Slow EMA Period
input int    InpEMA_Trend          = 200;       // Trend EMA (H4)
input int    InpRSI_Period         = 14;        // RSI Period
input double InpRSI_Level          = 50.0;      // RSI Buy Level
input int    InpADX_Period         = 14;        // ADX Period
input double InpADX_Level          = 25.0;      // ADX Min Level

//--- Volatility
input int    InpATR_Period         = 14;        // ATR Period
input double InpMinATR             = 5.0;       // Min ATR ($)
input double InpMaxATR             = 25.0;      // Max ATR ($)

//--- Exit Rules
input double InpATR_SL_Multi       = 2.0;       // SL ATR Multiplier
input double InpATR_TP_Multi       = 3.0;       // TP ATR Multiplier
input double InpTrailingATR_Multi  = 1.5;       // Trail ATR Multiplier
input int    InpTrailingActivation = 150;       // Trail Activation (pts)
input int    InpBreakevenProfit    = 100;       // Breakeven Trigger (pts)
input int    InpPartialClosePercent= 50;        // Partial Close (%)
input int    InpTimeExitBars       = 48;        // Time Exit Bars (0=off)

//--- Filters
input int    InpMaxSpread          = 50;        // Max Spread (points)
input int    InpSessionStart       = 20;        // Session Start Hour
input int    InpSessionEnd         = 23;        // Session End Hour
input bool   InpNewsFilter         = true;      // News Filter
input int    InpNewsAvoidMinutes   = 30;        // News Avoid (min)
```

### Optimization Ranges (MT5 Strategy Tester)

| Parameter | Start | Step | Stop | Recommended |
|-----------|-------|------|------|-------------|
| InpEMA_Fast | 5 | 2 | 21 | 9 |
| InpEMA_Slow | 15 | 3 | 50 | 21 |
| InpRSI_Period | 7 | 1 | 21 | 14 |
| InpRSI_Level | 40 | 5 | 60 | 50 |
| InpATR_SL_Multi | 1.0 | 0.25 | 3.0 | 2.0 |
| InpATR_TP_Multi | 1.5 | 0.25 | 5.0 | 3.0 |
| InpTrailingATR_Multi | 0.5 | 0.25 | 3.0 | 1.5 |
| InpADX_Level | 18 | 2 | 35 | 25 |
| InpMinATR | 3.0 | 0.5 | 8.0 | 5.0 |

**Optimization Warning:** Keep total parameter combinations below 10,000 to avoid overfitting. Use genetic algorithm for initial scan, then grid search on top 3 parameter sets.

---

## Regime Definitions

### Regime Detection Implementation

Each regime is detected by evaluating indicator conditions on the higher timeframe (default H4):

**Regime 1: TRENDING**
```
Detection:
  ADX(14, H4) > 25 AND
  (
    (Uptrend: +DI > -DI AND Price > EMA(50, H4)) OR
    (Downtrend: -DI > +DI AND Price < EMA(50, H4))
  )

Characteristics:
  - Sustained directional movement
  - MAs aligned in trend direction
  - Pullbacks to EMA 20/50 are opportunities
  - Duration: typically 2-12 weeks for XAUUSD

EA Behavior:
  - Trade: YES (primary regime for trend-follow)
  - Entry: Standard conditions apply
  - SL: Standard ATR multiplier
  - TP: Extended (use higher ATR multiplier)
```

**Regime 2: RANGING**
```
Detection:
  ADX(14, H4) < 20 AND
  BollingerBandWidth(20, 2.0, H4) < 20-period average AND
  Price oscillating around EMA(50, H4) (within +/- 1 ATR)

Characteristics:
  - Sideways price action
  - Frequent false breakouts
  - Support/resistance boundaries visible
  - Duration: typically 1-4 weeks for XAUUSD

EA Behavior:
  - Trade: NO (for trend-follow strategies)
  - Action: Manage existing positions only
  - No new entries
  - Tighten existing trailing stops
```

**Regime 3: VOLATILE (Expansion)**
```
Detection:
  ATR(14, H4) > 1.5 * SMA(ATR(14, H4), 20) OR
  Daily range > 2 * average daily range (20-day) OR
  VIX equivalent conditions (if available)

Characteristics:
  - Large directional swings
  - Wide intraday ranges ($80-150+/day)
  - Increased spread and slippage
  - Often triggered by macro events
  - Duration: typically 1-5 days for XAUUSD

EA Behavior:
  - Trade: MODIFY (adjusted parameters)
  - SL multiplier: 1.5x normal (wider stops)
  - Lot size: 0.5x normal (reduced exposure)
  - TP multiplier: 1.5x normal (extended targets)
  - Spread filter: 2x normal threshold
```

**Regime 4: NEWS-DRIVEN (Event)**
```
Detection:
  Within news_avoid_minutes of high-impact event OR
  Spread > 2x normal average OR
  (Price moved > 1.5 ATR in last 5 minutes -- spike detection)

Characteristics:
  - Whipsaw price action
  - Extreme spread widening ($1-5+)
  - Slippage risk very high
  - Directional bias only clear after initial reaction
  - Duration: typically 15-60 minutes for XAUUSD

EA Behavior:
  - Trade: NO
  - Action: Filter out entirely
  - No new entries
  - Optionally: widen SL on existing positions (configurable)
  - Wait for spread normalization before resuming
```

### Regime Transition Matrix

| From / To | Trending | Ranging | Volatile | News-Driven |
|-----------|----------|---------|----------|-------------|
| **Trending** | -- | ADX drops < 20, price consolidates | ATR spike > 1.5x avg | News event window |
| **Ranging** | ADX rises > 25, breakout confirmed | -- | ATR spike > 1.5x avg | News event window |
| **Volatile** | ATR normalizes + ADX > 25 | ATR normalizes + ADX < 20 | -- | News event window |
| **News-Driven** | After news window + ADX > 25 | After news window + ADX < 20 | After news window + ATR still elevated | -- |

**Hysteresis:** To prevent regime flipping, require the new regime conditions to hold for 3 consecutive bars on H4 before switching (except news-driven, which activates immediately).

---

## Risk Profile Alignment with Performance Metrics

### Mapping Risk Parameters to 33-Metric Framework

Every risk parameter in the spec directly influences specific performance metrics:

| Risk Parameter | Directly Affects Metrics | Relationship |
|---------------|------------------------|-------------|
| risk_per_trade_percent | #9 Max DD, #12 Recovery Factor, #16 VaR | Lower risk = lower DD, higher RF |
| max_daily_loss_percent | #9 Max DD, #8 Monthly Consistency | Circuit breaker for drawdown |
| max_drawdown_percent | #12 Recovery Factor, #15 Calmar | Hard stop = bounded DD |
| max_concurrent_positions | #9 Max DD, #16 VaR | More positions = more exposure |
| sl_atr_multiplier | #19 Avg Loss, #20 Avg R:R, #17 Win Rate | Wider SL = higher win rate but lower R:R |
| tp_atr_multiplier | #18 Avg Win, #20 Avg R:R, #4 Profit Factor | Higher TP = lower win rate but higher R:R |
| partial_close_percent | #28 Partial Close Efficiency, #5 Expected Payoff | Locks profit but reduces average win |
| trailing_atr_multiplier | #29 Trailing Stop Efficiency, #18 Avg Win | Tighter trail = more exits but less profit per trade |
| max_trades_per_day | #24 Trade Frequency, #8 Monthly Consistency | Limits overtrading |
| equity_curve_filter | #33 Equity Curve Smoothness, #11 DD Duration | Pauses trading in drawdown periods |

### Risk Profile Presets for XAUUSD

**Conservative:**
```json
{
  "risk_per_trade_percent": 0.5,
  "max_daily_loss_percent": 3.0,
  "max_drawdown_percent": 10.0,
  "max_concurrent_positions": 1,
  "sl_atr_multiplier": 2.5,
  "tp_atr_multiplier": 3.5,
  "expected_monthly_return": "2-5%",
  "target_sharpe": "> 1.5"
}
```

**Standard (Default):**
```json
{
  "risk_per_trade_percent": 1.0,
  "max_daily_loss_percent": 5.0,
  "max_drawdown_percent": 15.0,
  "max_concurrent_positions": 2,
  "sl_atr_multiplier": 2.0,
  "tp_atr_multiplier": 3.0,
  "expected_monthly_return": "5-10%",
  "target_sharpe": "> 1.0"
}
```

**Aggressive:**
```json
{
  "risk_per_trade_percent": 2.0,
  "max_daily_loss_percent": 8.0,
  "max_drawdown_percent": 20.0,
  "max_concurrent_positions": 3,
  "sl_atr_multiplier": 1.5,
  "tp_atr_multiplier": 2.5,
  "expected_monthly_return": "10-20%",
  "target_sharpe": "> 0.8"
}
```

### Expectancy Validation

Before finalizing any spec, validate positive expectancy:

```
Expectancy = (WinRate * AvgWin) - (LossRate * AvgLoss)

Where:
  WinRate = target win rate (decimal)
  LossRate = 1 - WinRate
  AvgWin = TP distance (in $) * partial close adjustment
  AvgLoss = SL distance (in $)

Example (Standard profile, H1 ATR = $8.50):
  SL = 2.0 * $8.50 = $17.00
  TP = 3.0 * $8.50 = $25.50
  Partial: 50% at 1:1 ($17), 50% trailing (est. $25.50)
  Effective AvgWin = 0.5 * $17.00 + 0.5 * $25.50 = $21.25

  At 55% win rate:
  Expectancy = (0.55 * $21.25) - (0.45 * $17.00) = $11.69 - $7.65 = +$4.04/trade

  Spread cost: ~$0.50/trade
  Net expectancy: +$3.54/trade (POSITIVE -- viable strategy)

Minimum acceptable: Expectancy > 2x spread cost
```

---

## Error Handling

### Input Errors

| Error | Detection | Recovery |
|-------|-----------|---------|
| Missing hypothesis | No hypothesis_id provided | Return error: "Strategy hypothesis required. Run strategy-researcher first." |
| Incomplete hypothesis | Required fields missing | List missing fields, return to researcher |
| Invalid indicator params | Period <= 0 or > 500 | Clamp to valid range, log warning |
| Invalid risk params | Risk > 5% or DD > 30% | Clamp to max allowed, warn user |
| Conflicting conditions | Entry conditions that can never simultaneously be true | Reject spec, explain conflict |
| Invalid timeframe | Timeframe not in MT5 enum | Default to H1, warn user |

### Runtime Specification Errors

| Error | Detection | Recovery |
|-------|-----------|---------|
| SL too tight for spread | SL distance < 3x current spread | Increase SL to 5x spread minimum |
| TP unreachable | TP > 10x ATR for timeframe | Cap at 5x ATR, warn about hold time |
| Filter too restrictive | Filters eliminate > 80% of bars | Relax filters, warn user |
| Lot size underflow | Calculated lot < SYMBOL_VOLUME_MIN | Use minimum lot, log warning |
| Lot size overflow | Calculated lot > SYMBOL_VOLUME_MAX | Cap at max lot, log warning |
| Insufficient margin | Required margin > available * 1.5 | Skip trade, log "insufficient margin" |

### Specification Validation Errors

| Error | Severity | Action |
|-------|----------|--------|
| Negative expectancy | BLOCKER | Reject spec. Adjust SL/TP/WinRate targets |
| Contradictory regime rules | BLOCKER | Resolve overlap between regime conditions |
| Parameter out of MQL5 range | BLOCKER | Fix to valid MQL5 type range |
| Missing MQL5 mapping | BLOCKER | Add input_parameters entry for every configurable value |
| Redundant indicators | WARNING | Flag and suggest removal of one |
| Over-parameterized (> 8 optimizable) | WARNING | Suggest fixing least impactful parameters |
| Untested regime transition | WARNING | Add hysteresis rule for flagged transition |

---

## Reference: XAUUSD Specification Constants

**Instrument Properties:**
- Symbol: XAUUSD
- Digits: 2 (price quote: $5098.12)
- Point: 0.01
- Tick size: 0.01
- Tick value (1 lot): $1.00 (per 0.01 move) = $100 per $1.00 move
- Contract size: 100 oz per standard lot
- Min lot: 0.01 (broker dependent)
- Max lot: 100.0 (broker dependent)
- Lot step: 0.01

**Typical Spread Ranges:**
- ECN (off-peak): 15-30 points ($0.15-$0.30)
- ECN (peak hours): 20-50 points ($0.20-$0.50)
- Standard (off-peak): 30-60 points ($0.30-$0.60)
- Standard (news): 100-300+ points ($1.00-$3.00+)

**ATR Reference Values (as of 02/2026):**
- M5 ATR(14): $1.5-$3.0
- M15 ATR(14): $3.0-$5.0
- H1 ATR(14): $8.0-$12.0 (normal), $15-$25 (volatile)
- H4 ATR(14): $15-$25 (normal), $30-$50 (volatile)
- D1 ATR(14): $30-$60 (normal), $80-$150 (event day)

**Session Times (GMT+7 / Indochina Time):**
- Asian: 06:00-15:00 (low vol, range-bound)
- London: 14:00-23:00 (trend initiation)
- New York: 20:00-05:00 (continuation/reversal)
- London-NY Overlap: 20:00-23:00 (peak volume)
- LBMA AM Fix: 17:30 | LBMA PM Fix: 22:00

**Risk Calculation Constants:**
```
Lot Size = (Account_Equity * Risk_Percent / 100) / (SL_Points * Tick_Value)

Where for XAUUSD:
  Tick_Value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)  // $1.00 per 0.01 move per lot
  Point = SymbolInfoDouble(_Symbol, SYMBOL_POINT)                  // 0.01

Example:
  Equity = $10,000
  Risk = 1% = $100
  SL = $17.00 = 1700 points
  Tick_Value = $1.00 per point per lot
  Lot_Size = $100 / (1700 * $1.00) = 0.0588 -> rounds to 0.05 lots
```

## Inputs & Assumptions

| Input | Source | Required | Default |
|-------|--------|----------|---------|
| Strategy hypothesis document | strategy-researcher output | YES | None |
| Risk tolerance profile | User/orchestrator | NO | Standard (1% risk, 15% max DD) |
| Account size | User/orchestrator | NO | $10,000 |
| Broker type | User/orchestrator | NO | ECN |
| Existing portfolio context | trading-risk-portfolio | NO | Single EA |

**Standing Assumptions:**
- XAUUSD on MT5, 5-digit pricing (0.01 = 1 point)
- Point value: $1.00 per point per standard lot (100 oz)
- H1 primary timeframe unless hypothesis specifies otherwise
- All enum fields in JSON template use pipe separators for documentation; agent selects exactly ONE value

## Dynamic Execution Zone
<!-- Orchestrator injects strategy hypothesis and user context below this line -->
