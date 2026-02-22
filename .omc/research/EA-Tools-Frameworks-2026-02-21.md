# NGHIEN CUU: CONG CU, FRAMEWORK VA TINH NANG NANG CAO CHO EA XAUUSD

> Ngay: 2026-02-21 | Nguon: Perplexity Deep Research

---

## 1. CONG CU PHAT TRIEN

### 1.1 MetaEditor - IDE Chinh

- **MQL5 Wizard**: Tao template EA tu dong
- **Debugging nang cao**: Breakpoints, step into/over, watch window, profiling
- **Git tich hop**: MQL5 Algo Forge tu build 5100+
- **ONNX support**: Float16/Float8, GPU acceleration voi CUDA

### 1.2 MQL5 Standard Library

| Module | Chuc nang | Vi du cho Gold |
|--------|-----------|---------------|
| Signal Classes | Tao tin hieu | MA + RSI cho XAUUSD |
| Trailing Classes | Trailing stop | ATR trailing cho vang |
| Money Management | Khoi luong lenh | Position sizing theo volatility |
| CTrade | Thuc thi lenh | Mo/dong voi slippage control |
| Indicator Classes | Truy cap indicator | iATR, iRSI, iMACD |

### 1.3 Third-party & Tools

- **jason.mqh**: Xu ly JSON (Telegram/Discord notifications)
- **MQL5 Algo Forge** (forge.mql5.io): Git branching, collaboration
- **VS Code + MQL Tools Extension**: Syntax highlighting, Git workflow
- **Unit Testing**: MQLUnit, MTUnit, mql5-unit-test-library

### 1.4 Version Control

- MQL5 Algo Forge (Git-based tu build 5100+)
- `.gitignore` loai bo `.ex5`, logs, file tam
- Short-lived branches cho tung tinh nang

---

## 2. DU LIEU VA PHAN TICH

### 2.1 Nguon Du Lieu Lich Su

| Nguon | Loai | Chat luong | Chi phi |
|-------|------|-----------|---------|
| Dukascopy (TDS) | Tick data | 99.9% | Mien phi |
| Tick Data LLC | Tick data institutional | Cap institutional | Tra phi |
| MetaQuotes Server | M1 data | Phu thuoc broker | Co san MT5 |
| Kaggle | Lich su XAUUSD | TB-Cao | Mien phi |

### 2.2 Tick Data Suite (TDS)

- Real tick data tu Dukascopy (99% modeling quality)
- Mo phong slippage thuc te va variable spread
- Ho tro Renko, Range bars
- Workflow: Download qua Tick Data Manager -> Bat TDS trong Tester -> Chay "Every tick"

### 2.3 QuantAnalyzer

- **Monte Carlo Simulation**: Do ben cua chien luoc
- **What-If Scenarios**: Gio giao dich, ngay trong tuan
- **Portfolio Master**: To hop chien luoc voi tuong quan thap (<0.3)
- **Metrics**: Sharpe ratio, max DD, stagnation period, profit factor

### 2.4 Python Integration

```python
import MetaTrader5 as mt5
import pandas as pd

mt5.initialize()
rates = mt5.copy_rates_range("XAUUSD", mt5.TIMEFRAME_H1, start, end)
df = pd.DataFrame(rates)

# Feature engineering, ML training, ONNX export
```

### 2.5 R Integration

- Qua `reticulate` package (Python bridge)
- Hoac `mt5R` package (WebSocket truc tiep)
- Su dung `quantmod` cho RSI, SMA, ATR

---

## 3. TINH NANG NANG CAO CHO EA VANG

### 3.1 News Filter (BAT BUOC)

**Tin can tranh:**
- NFP: Pause 60 min truoc/sau
- FOMC: Pause 120 min truoc/sau
- CPI: Pause 30 min truoc/sau
- GDP, Fed Chair Speech: Pause 30 min truoc/sau

**Implementation:** Su dung MQL5 Calendar API `CalendarValueHistory()` hoac file CSV tu Forex Factory.

### 3.2 Session Filter

| Phien | Gio GMT | Dac diem | Chien luoc |
|-------|---------|---------|-----------|
| Asia | 00:00-08:00 | Range, spread cao | Tranh giao dich |
| London | 08:00-16:00 | Xu huong ro | Breakout, Trend |
| New York | 13:00-21:00 | Volatility cao | News, Momentum |
| London Close | 15:00-17:00 | Reversal | Mean reversion |

### 3.3 Spread Filter

- Binh thuong ECN: 10-25 points
- Tin tuc: 80-200+ points
- Asia: 30-50 points
- MaxSpread scalping: 30-40 points
- MaxSpread swing: 50-60 points

### 3.4 Multi-Timeframe Analysis

```
H4 -> Xu huong chinh (EMA50, EMA200)
H1 -> Vung gioi han (EMA20)
M15 -> Diem vao (RSI pullback)
```

### 3.5 Correlation Filter (DXY, Silver)

- DXY RSI > 70: Khong buy vang (DXY qua manh)
- DXY RSI < 30: Khong sell vang (DXY qua yeu)
- Gold va Silver phai di cung huong de xac nhan

### 3.6 Volatility Position Sizing

- ATR cao -> SL rong -> lot nho -> bao ve tai khoan
- ATR thap -> SL hep -> lot lon -> tan dung co hoi
- Luon giu risk co dinh (1-2% tai khoan)

### 3.7 ONNX Machine Learning

**Workflow:**
1. Train model Python (GradientBoosting/LSTM)
2. Export ONNX (`skl2onnx`)
3. Load trong EA (`OnnxCreate`, `OnnxRun`)
4. Predict: Buy/Sell/Hold voi probability threshold > 0.7

---

## 4. TRIEN KHAI VA GIAM SAT

### 4.1 VPS cho EA Trading

| Provider | Gia/thang | Latency | Phu hop |
|----------|-----------|---------|---------|
| TradingFXVPS | $15-20 | 0.3-0.78ms | Scalping gold |
| ForexVPS.net | $29+ | ~1ms | General EA |
| MetaQuotes VPS | $15 | Thap | Tich hop MT5 |
| ForexBox | $7.99 | Thap | Budget |

**Yeu cau**: RAM 1-2GB, NVMe SSD, Latency <5ms den broker

### 4.2 Notifications

- **Telegram**: WebRequest API, HTML formatting
- **Discord**: Webhook POST, JSON payload
- Phai bat WebRequest URL trong MT5 Options

### 4.3 Monitoring

- **Myfxbook**: Auto-tracking, monthly reports
- **FXBlue**: Real-time dashboard, TradeTalk alerts
- **Heartbeat system**: Phat hien EA bi treo, canh bao mat ket noi

### 4.4 Recovery

- Kiem tra lenh mo tu phien truoc khi OnInit()
- Heartbeat moi 60s qua OnTimer()
- Canh bao lenh mo qua lau (>48h)

---

## 5. BAY VA SAI LAM THUONG GAP

### 5.1 Spread Widening
- Spread tang 80-200+ points khi tin tuc
- **Giai phap**: Spread filter, broker ECN, tranh tin

### 5.2 Requotes & Slippage
- Retry logic 3 lan voi 500ms delay
- SetDeviation 5-10 points
- VPS latency <1ms

### 5.3 Overnight Swap
- Long swap: -$14 den -$46/lot/dem
- Triple swap Thu Tu (x3)
- **Giai phap**: Uu tien intraday, tinh swap trong backtest

### 5.4 Broker Issues
- Symbol khac nhau: XAUUSD, Gold, XAUUSDm
- Lot value khac nhau tuy broker
- Platform outage khi volatility cao
- **Giai phap**: Tu dong detect symbol params

### 5.5 Over-optimization (NGUY HIEM NHAT)
- Gioi han 5-8 tham so chinh
- Walk-Forward Analysis bat buoc
- Monte Carlo 1000+ simulations
- Forward test demo 3 thang
- Thay doi params +-20% van phai loi nhuan

---

## CHECKLIST XAY DUNG EA XAUUSD

**Phase 1 - Phat trien:**
- [ ] MetaEditor + Git setup
- [ ] Kien truc voi Standard Library
- [ ] Unit tests
- [ ] Filters: News, Session, Spread
- [ ] MTF analysis, Correlation filter
- [ ] ATR position sizing

**Phase 2 - Backtest:**
- [ ] Tick data 3-5 nam (TDS)
- [ ] Spread/slippage thuc te
- [ ] Walk-Forward Analysis
- [ ] Monte Carlo (QuantAnalyzer)
- [ ] Robustness check (params +-20%)

**Phase 3 - Advanced:**
- [ ] Python integration
- [ ] ONNX ML model
- [ ] Custom indicators

**Phase 4 - Deploy:**
- [ ] VPS low-latency
- [ ] Telegram/Discord alerts
- [ ] Myfxbook monitoring
- [ ] Heartbeat + recovery
- [ ] Demo forward test 3 thang

**Phase 5 - Live:**
- [ ] Bat dau 0.01 lot
- [ ] Tang dan sau 1-2 thang
- [ ] Review hang tuan
- [ ] Cap nhat khi thi truong thay doi

---

## CONG NGHE KHUYEN NGHI 2025

| Thanh phan | Cong nghe | Ly do |
|-----------|-----------|-------|
| IDE | MetaEditor + VS Code | Git, code intelligence |
| Backtest | TDS + QuantAnalyzer | 99% quality + Monte Carlo |
| Phan tich | Python + MT5 package | ML, data science |
| ML | ONNX (GBM/LSTM) | Chay truc tiep MT5 |
| VPS | TradingFXVPS | Latency <1ms |
| Monitor | Myfxbook + Telegram | Tracking + alerts |
| Broker | ECN (IC Markets, Exness) | Spread thap, khong requote |
| VCS | Git (Algo Forge) | Branching, collaboration |

---

*Nguon: MetaQuotes, MQL5.com, Dukascopy, QuantAnalyzer, TDS*
