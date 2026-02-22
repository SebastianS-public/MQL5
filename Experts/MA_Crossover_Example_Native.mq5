#property copyright "MA Crossover Example with Native Trade"
#property link      "Example"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

// Input parameters
input string   InpSymbol              = "EURUSD";       // Symbol to trade
input ENUM_TIMEFRAMES InpPeriod       = PERIOD_H1;      // Timeframe
input int      FastMA_Period          = 10;             // Fast Moving Average Period
input int      SlowMA_Period          = 20;             // Slow Moving Average Period
input double   RiskPercent            = 2.0;            // Risk percentage per trade
input int      StopLossPips           = 30;             // Stop Loss in pips
input int      TakeProfitPips         = 60;             // Take Profit in pips
input int      Magic                  = 20250128;       // Magic Number

// Global variables
CTrade trade;
datetime lastBarTime = 0;   // Track bar changes
int fastMAHandle = INVALID_HANDLE;  // Handle for fast MA indicator
int slowMAHandle = INVALID_HANDLE;  // Handle for slow MA indicator
double g_minLot = 0;
double g_maxLot = 0;
double g_stepLot = 0;

void OnInit()
{
   // Initialize trade object with magic number
   trade.SetExpertMagicNumber(Magic);
   
   // Cache symbol volume info (like OrderManager does)
   g_minLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
   g_maxLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
   g_stepLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);
   
   // Create indicator handles for Moving Averages
   fastMAHandle = iMA(InpSymbol, InpPeriod, FastMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   slowMAHandle = iMA(InpSymbol, InpPeriod, SlowMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   
   if(fastMAHandle == INVALID_HANDLE || slowMAHandle == INVALID_HANDLE) {
      Print("Error: Failed to create indicator handles");
      return;
   }
   
   Print("MA Crossover EA initialized");
   Print("Symbol: ", InpSymbol, " | Period: ", InpPeriod);
   Print("Fast MA: ", FastMA_Period, " | Slow MA: ", SlowMA_Period);
   Print("Risk: ", RiskPercent, "% | SL: ", StopLossPips, "pips | TP: ", TakeProfitPips, "pips");
}

void OnTick()
{
   // Check for new bar
   datetime currentBarTime = iTime(InpSymbol, InpPeriod, 0);
   if(currentBarTime == lastBarTime) {
      return;  // No new bar, skip analysis
   }
   lastBarTime = currentBarTime;
   
   // Get current market prices
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   
   // Get Moving Average values from indicator buffers
   double fastMA_Buffer[2], slowMA_Buffer[2];
   
   if(CopyBuffer(fastMAHandle, 0, 0, 2, fastMA_Buffer) < 2 || 
      CopyBuffer(slowMAHandle, 0, 0, 2, slowMA_Buffer) < 2) {
      return;  // Not enough data yet
   }
   
   // Array indices: [0] = current bar, [1] = previous bar
   double fastMA = fastMA_Buffer[0];
   double slowMA = slowMA_Buffer[0];
   double fastMA_Prev = fastMA_Buffer[1];
   double slowMA_Prev = slowMA_Buffer[1];
   
   // Check for existing positions
   bool hasPosition = false;
   ENUM_POSITION_TYPE positionType = POSITION_TYPE_BUY;
   ulong positionTicket = 0;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         if(PositionGetString(POSITION_SYMBOL) == InpSymbol && 
            PositionGetInteger(POSITION_MAGIC) == Magic) {
            hasPosition = true;
            positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            positionTicket = ticket;
            break;
         }
      }
   }
   
   // GOLDEN CROSS: Fast MA crosses above Slow MA - BUY SIGNAL
   if(!hasPosition && fastMA_Prev <= slowMA_Prev && fastMA > slowMA) {
      // Calculate stop loss and take profit
      double sl = NormalizeDouble(bid - (StopLossPips * point), digits);
      double tp = NormalizeDouble(ask + (TakeProfitPips * point), digits);
      
      // Calculate volume based on risk percentage using entry and stop loss prices
      double volume = CalculateVolume(ask, sl, RiskPercent);
      // Normalize volume before trading (matches OrderManager's pattern)
      volume = NormalizeVolume(volume);
      
      // Place BUY market order
      if(trade.Buy(volume, InpSymbol, ask, sl, tp, "MA Crossover BUY")) {
         Print("BUY signal: Golden Cross detected. FastMA: ", fastMA, " SlowMA: ", slowMA);
      } else {
         Print("BUY order failed. Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   // DEATH CROSS: Fast MA crosses below Slow MA - SELL SIGNAL
   if(!hasPosition && fastMA_Prev >= slowMA_Prev && fastMA < slowMA) {
      // Calculate stop loss and take profit
      double sl = NormalizeDouble(ask + (StopLossPips * point), digits);
      double tp = NormalizeDouble(bid - (TakeProfitPips * point), digits);
      
      // Calculate volume based on risk percentage using entry and stop loss prices
      double volume = CalculateVolume(bid, sl, RiskPercent);
      // Normalize volume before trading (matches OrderManager's pattern)
      volume = NormalizeVolume(volume);
      
      // Place SELL market order
      if(trade.Sell(volume, InpSymbol, bid, sl, tp, "MA Crossover SELL")) {
         Print("SELL signal: Death Cross detected. FastMA: ", fastMA, " SlowMA: ", slowMA);
      } else {
         Print("SELL order failed. Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Normalize volume for specific symbol (matches OrderManager)        |
//+------------------------------------------------------------------+
double NormalizeVolume(double v)
{
   double vol = MathFloor(v / g_stepLot) * g_stepLot;
   if(vol < g_minLot) vol = g_minLot;
   if(vol > g_maxLot) vol = g_maxLot;
   return NormalizeDouble(vol, 2);
}

//+------------------------------------------------------------------+
//| Calculate volume based on risk percentage using OrderCalcProfit  |
//+------------------------------------------------------------------+
double CalculateVolume(double entryPrice, double slPrice, double riskPercent)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = (balance * riskPercent) / 100.0;
   
   // Validate inputs
   if(riskMoney <= 0) {
      return g_minLot;
   }
   
   // Use OrderCalcProfit to calculate loss for 1 lot (handles currency conversion)
   ENUM_ORDER_TYPE tempType = (entryPrice > slPrice) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double potentialProfit = 0.0;
   
   if(!OrderCalcProfit(tempType, InpSymbol, 1.0, entryPrice, slPrice, potentialProfit)) {
      Print("Error: OrderCalcProfit failed for symbol ", InpSymbol, ". Using minimum volume.");
      return g_minLot;
   }
   
   double lossPerLot = MathAbs(potentialProfit);
   double calculatedVol = g_minLot;
   
   if(lossPerLot > 0) {
      calculatedVol = riskMoney / lossPerLot;
   }
   
   // Apply the exact same normalization as OrderManager's NormalizeVolSymbol
   return NormalizeVolume(calculatedVol);
}

void OnDeinit(const int reason)
{
   // Release indicator handles
   if(fastMAHandle != INVALID_HANDLE) {
      IndicatorRelease(fastMAHandle);
   }
   if(slowMAHandle != INVALID_HANDLE) {
      IndicatorRelease(slowMAHandle);
   }
   
   Print("EA deinitialized");
}
