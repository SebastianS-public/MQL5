#property copyright "OrderManager Example EA"
#property link      "Example"
#property version   "1.00"
#property strict

#include "../Include/OrderManager.mqh"

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
COrderManager om;
int requestCounter = 1000;  // Request ID counter
datetime lastBarTime = 0;   // Track bar changes
int fastMAHandle = INVALID_HANDLE;  // Handle for fast MA indicator
int slowMAHandle = INVALID_HANDLE;  // Handle for slow MA indicator

void OnInit()
{
   // Initialize OrderManager with the symbol
   om.Init(InpSymbol, Magic);
   
   // Set risk management: use percentage of balance
   om.SetRiskSettings(RiskPercentBalance, RiskPercent);
   
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
   // Process pending orders and position modifications
   om.Process();
   
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
      double sl = bid - (StopLossPips * point);
      double tp = ask + (TakeProfitPips * point);
      
      // Queue a BUY market order (volume = 0 for auto calculation based on risk)
      if(om.Trade(InpSymbol, ORDER_TYPE_BUY, 0, 0, sl, tp, "MA Crossover BUY", requestCounter++)) {
         Print("BUY signal: Golden Cross detected. FastMA: ", fastMA, " SlowMA: ", slowMA);
      }
   }
   
   // DEATH CROSS: Fast MA crosses below Slow MA - SELL SIGNAL
   if(!hasPosition && fastMA_Prev >= slowMA_Prev && fastMA < slowMA) {
      // Calculate stop loss and take profit
      double sl = ask + (StopLossPips * point);
      double tp = bid - (TakeProfitPips * point);
      
      // Queue a SELL market order (volume = 0 for auto calculation based on risk)
      if(om.Trade(InpSymbol, ORDER_TYPE_SELL, 0, 0, sl, tp, "MA Crossover SELL", requestCounter++)) {
         Print("SELL signal: Death Cross detected. FastMA: ", fastMA, " SlowMA: ", slowMA);
      }
   }
   
   // Positions are held indefinitely until stop loss or take profit is hit
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
