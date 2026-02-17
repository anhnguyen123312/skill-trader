//+------------------------------------------------------------------+
//|                                            SimpleMA_EA.mq5       |
//|                           Simple MA Crossover with High Frequency |
//|                                              EA-OAT-v2 Framework |
//+------------------------------------------------------------------+
#property copyright "EA-OAT-v2"
#property link      "https://github.com/ea-oat-v2"
#property version   "1.00"
#property strict

//--- Input parameters
input double LotSize = 0.01;              // Lot size
input int    StopLoss = 30;               // Stop Loss in points
input int    TakeProfit = 60;             // Take Profit in points (R:R = 1:2)
input int    FastMA_Period = 5;           // Fast MA Period (aggressive for more signals)
input int    SlowMA_Period = 20;          // Slow MA Period
input ENUM_MA_METHOD MA_Method = MODE_EMA; // MA Method (EMA faster response)
input int    MagicNumber = 789012;        // Magic Number

//--- Global variables
int handleFastMA;
int handleSlowMA;
double fastMABuffer[];
double slowMABuffer[];
int tradeCount = 0;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create MA indicators
   handleFastMA = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MA_Method, PRICE_CLOSE);
   handleSlowMA = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MA_Method, PRICE_CLOSE);

   if(handleFastMA == INVALID_HANDLE || handleSlowMA == INVALID_HANDLE)
   {
      Print("❌ ERROR: Failed to create MA indicators");
      return(INIT_FAILED);
   }

   ArraySetAsSeries(fastMABuffer, true);
   ArraySetAsSeries(slowMABuffer, true);

   Print("========================================");
   Print("✅ SimpleMA_EA v1.00 INITIALIZED");
   Print("========================================");
   Print("Symbol: ", _Symbol);
   Print("Period: ", EnumToString(Period()));
   Print("Fast MA: ", FastMA_Period, " ", EnumToString(MA_Method));
   Print("Slow MA: ", SlowMA_Period, " ", EnumToString(MA_Method));
   Print("Lot Size: ", LotSize);
   Print("SL: ", StopLoss, " pts | TP: ", TakeProfit, " pts");
   Print("Risk:Reward = 1:", DoubleToString((double)TakeProfit/StopLoss, 1));
   Print("========================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleFastMA != INVALID_HANDLE) IndicatorRelease(handleFastMA);
   if(handleSlowMA != INVALID_HANDLE) IndicatorRelease(handleSlowMA);

   Print("========================================");
   Print("SimpleMA_EA SHUTDOWN");
   Print("Total Trades Opened: ", tradeCount);
   Print("Reason: ", reason);
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar (to avoid multiple signals per bar)
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime)
      return; // Not a new bar yet

   lastBarTime = currentBarTime;

   // Check if we already have a position
   if(PositionSelect(_Symbol))
   {
      // Already in position, skip
      return;
   }

   // Copy MA values
   if(CopyBuffer(handleFastMA, 0, 0, 3, fastMABuffer) < 3)
   {
      Print("⚠️  Failed to copy Fast MA buffer");
      return;
   }

   if(CopyBuffer(handleSlowMA, 0, 0, 3, slowMABuffer) < 3)
   {
      Print("⚠️  Failed to copy Slow MA buffer");
      return;
   }

   // Get MA values
   double fastMA_current = fastMABuffer[0];
   double fastMA_prev = fastMABuffer[1];
   double slowMA_current = slowMABuffer[0];
   double slowMA_prev = slowMABuffer[1];

   // Get current price
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Log current state
   string logMsg = StringFormat("📊 Bar[%s] | FastMA: %.2f | SlowMA: %.2f | Price: %.2f",
                                 TimeToString(currentBarTime, TIME_DATE|TIME_MINUTES),
                                 fastMA_current, slowMA_current, bid);

   // BULLISH CROSSOVER: Fast MA crosses ABOVE Slow MA
   if(fastMA_prev <= slowMA_prev && fastMA_current > slowMA_current)
   {
      double sl = bid - StopLoss * point;
      double tp = bid + TakeProfit * point;

      Print("🟢 BULLISH CROSSOVER DETECTED!");
      Print(logMsg);
      Print("   FastMA[1]=", fastMA_prev, " <= SlowMA[1]=", slowMA_prev);
      Print("   FastMA[0]=", fastMA_current, " >  SlowMA[0]=", slowMA_current);
      Print("   → OPENING BUY ORDER");

      if(OpenPosition(ORDER_TYPE_BUY, LotSize, ask, sl, tp, "MA Bullish Cross"))
      {
         tradeCount++;
         Print("✅ BUY #", tradeCount, " opened at ", ask, " | SL:", sl, " | TP:", tp);
      }
   }

   // BEARISH CROSSOVER: Fast MA crosses BELOW Slow MA
   else if(fastMA_prev >= slowMA_prev && fastMA_current < slowMA_current)
   {
      double sl = ask + StopLoss * point;
      double tp = ask - TakeProfit * point;

      Print("🔴 BEARISH CROSSOVER DETECTED!");
      Print(logMsg);
      Print("   FastMA[1]=", fastMA_prev, " >= SlowMA[1]=", slowMA_prev);
      Print("   FastMA[0]=", fastMA_current, " <  SlowMA[0]=", slowMA_current);
      Print("   → OPENING SELL ORDER");

      if(OpenPosition(ORDER_TYPE_SELL, LotSize, bid, sl, tp, "MA Bearish Cross"))
      {
         tradeCount++;
         Print("✅ SELL #", tradeCount, " opened at ", bid, " | SL:", sl, " | TP:", tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Open position function                                           |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE orderType, double volume, double price, double sl, double tp, string comment)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = comment;

   if(!OrderSend(request, result))
   {
      Print("❌ OrderSend FAILED: ", GetLastError(), " | ", result.comment);
      return false;
   }

   if(result.retcode != TRADE_RETCODE_DONE)
   {
      Print("❌ Order REJECTED: Code=", result.retcode, " | ", result.comment);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| OnTester function - Export detailed CSV                          |
//+------------------------------------------------------------------+
double OnTester()
{
   Print("========================================");
   Print("📊 BACKTEST COMPLETED - Exporting Results");
   Print("========================================");

   // Get account info
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Get trade history
   HistorySelect(0, TimeCurrent());
   int totalDeals = HistoryDealsTotal();

   // Count trades and calculate metrics
   int wins = 0;
   int losses = 0;
   double totalProfit = 0;
   double totalLoss = 0;
   double maxDrawdown = 0;
   double peakBalance = balance;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

            if(profit > 0)
            {
               wins++;
               totalProfit += profit;
            }
            else if(profit < 0)
            {
               losses++;
               totalLoss += MathAbs(profit);
            }

            // Update drawdown
            if(balance > peakBalance) peakBalance = balance;
            double drawdown = (peakBalance - balance) / peakBalance * 100;
            if(drawdown > maxDrawdown) maxDrawdown = drawdown;
         }
      }
   }

   int totalTrades = wins + losses;
   double winRate = (totalTrades > 0) ? (wins * 100.0 / totalTrades) : 0;
   double avgWin = (wins > 0) ? (totalProfit / wins) : 0;
   double avgLoss = (losses > 0) ? (totalLoss / losses) : 0;
   double riskReward = (avgLoss > 0) ? (avgWin / avgLoss) : 0;
   double profitFactor = (totalLoss > 0) ? (totalProfit / totalLoss) : 0;
   double netProfit = totalProfit - totalLoss;

   // Calculate Sharpe Ratio (simplified)
   double sharpeRatio = (totalTrades > 10) ? (netProfit / totalTrades) / (avgLoss > 0 ? avgLoss : 1) : 0;

   // Log summary to terminal
   Print("Total Trades: ", totalTrades);
   Print("Wins: ", wins, " (", DoubleToString(winRate, 2), "%)");
   Print("Losses: ", losses);
   Print("Win Rate: ", DoubleToString(winRate, 2), "%");
   Print("Profit Factor: ", DoubleToString(profitFactor, 2));
   Print("Risk:Reward: 1:", DoubleToString(riskReward, 2));
   Print("Net Profit: $", DoubleToString(netProfit, 2));
   Print("Max Drawdown: ", DoubleToString(maxDrawdown, 2), "%");

   // Export to CSV
   string filename = "backtest_results.csv";
   int fileHandle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON, '\t');

   if(fileHandle != INVALID_HANDLE)
   {
      // Write summary metrics
      FileWrite(fileHandle, "Metric", "Value");
      FileWrite(fileHandle, "Win Rate %", DoubleToString(winRate, 2));
      FileWrite(fileHandle, "Risk Reward", DoubleToString(riskReward, 2));
      FileWrite(fileHandle, "Total Trades", IntegerToString(totalTrades));
      FileWrite(fileHandle, "Max DD %", DoubleToString(maxDrawdown, 2));
      FileWrite(fileHandle, "Profit Factor", DoubleToString(profitFactor, 2));
      FileWrite(fileHandle, "Net Profit", DoubleToString(netProfit, 2));
      FileWrite(fileHandle, "Sharpe Ratio", DoubleToString(sharpeRatio, 2));
      FileWrite(fileHandle, "");

      // Write detailed trade log header
      FileWrite(fileHandle, "Trade Details");
      FileWrite(fileHandle, "Ticket", "Type", "Open Time", "Close Time", "Open Price", "Close Price", "Profit", "Comment");

      // Export each trade
      for(int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
               long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
               string typeStr = (dealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
               datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
               double dealPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
               double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

               FileWrite(fileHandle,
                        IntegerToString(ticket),
                        typeStr,
                        TimeToString(dealTime),
                        TimeToString(TimeCurrent()),
                        DoubleToString(dealPrice, _Digits),
                        "",
                        DoubleToString(profit, 2),
                        comment);
            }
         }
      }

      FileClose(fileHandle);
      Print("✅ Results exported to: ", filename);
   }
   else
   {
      Print("❌ Failed to create CSV file: ", GetLastError());
   }

   Print("========================================");

   // Return profit factor for optimization
   return profitFactor;
}
