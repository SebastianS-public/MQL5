#include <Trade/Trade.mqh>
CTrade trade;

input group "General Settings"
input string ResetTime = "01:00";
input string MarketClose = "21:00";
input bool BuyTrades = true;
input bool SellTrades = true;

input group "Trade Settings"
input int PipDigit = 2;
input double RiskInPercent = 2.0;
input int LookbackSensitivity = 8;
input int StopLossPips = 10;
input int TakeProfitPips = 20;
input double TrailingStopTrigger = 6;
input double TrailingStopPoints = 2;

int lookbackPeriod;
double trailingStopTriggerTicks;
double trailingStopTicks;

void OnInit(){
   lookbackPeriod = LookbackSensitivity * 4;
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   trailingStopTriggerTicks = TrailingStopTrigger * pipSize;
   trailingStopTicks = TrailingStopPoints * pipSize;
}

bool timeStart = true;
bool timeEnd = false;
ulong buyPos, sellPos;
double entryHigh = 0;
double entryLow = 0;

double buyStopLoss;
double stopLossTicks;
double sellStopLoss;
double oldBuyStopLoss;
double newBuyStopLoss;
double oldSellStopLoss;
double newSellStopLoss;

void OnTick(){
   bool newCandle = detectNewCandle();
   bool isTime = timeCheck();
   executeOrderTradeManagement();
   
   if(PositionsTotal() > 0){
      executeTrailingStop();
   }

   if(newCandle && isTime && PositionsTotal() == 0){
      if(oldBuyStopLoss != 0 && !OrderSelect(buyPos)){
         oldBuyStopLoss = 0;
         newBuyStopLoss = 0;
      }
      if(oldSellStopLoss != 0 && !OrderSelect(sellPos)){
         oldSellStopLoss = 0;
         newSellStopLoss = 0;
      }
      
      double high = findHigh();
      if(high != 0 && high != entryHigh){
         if(OrderSelect(buyPos)){
            trade.OrderDelete(buyPos);
         }
         entryHigh = high;
      }
      double low = findLow();
      if(low != 0 && low != entryLow){
         if(OrderSelect(sellPos)){
            trade.OrderDelete(sellPos);
         }
         entryLow = low;
      }
      
      if(!OrderSelect(buyPos) && !PositionSelectByTicket(buyPos) && entryHigh != 0 && BuyTrades){
         double swingHigh = iHigh(_Symbol,PERIOD_CURRENT,iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackPeriod,0));
         if(entryHigh >= swingHigh){
            executeBuy(entryHigh);
         }
      }
      if(!OrderSelect(sellPos) && !PositionSelectByTicket(sellPos) && entryLow != 0 && SellTrades){
         double swingLow = iLow(_Symbol,PERIOD_CURRENT,iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookbackPeriod,0));
         if(entryLow <= swingLow){
            executeSell(entryLow);
         }
      }
   }
}

void executeTrailingStop(){
   if(PositionSelectByTicket(buyPos)){
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double slTriggerValue = buyStopLoss + stopLossTicks + trailingStopTriggerTicks;
      if(bid > slTriggerValue){
         newBuyStopLoss = bid - trailingStopTicks;
         if(newBuyStopLoss > oldBuyStopLoss && newBuyStopLoss < bid){
            trade.PositionModify(buyPos,newBuyStopLoss,0);
            oldBuyStopLoss = newBuyStopLoss;
         }
      }
   }
   if(PositionSelectByTicket(sellPos)){      
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double slTriggerValue = sellStopLoss - stopLossTicks - trailingStopTriggerTicks;
      if(ask < slTriggerValue){
         newSellStopLoss = ask + trailingStopTicks;
         if(newSellStopLoss < oldSellStopLoss && newSellStopLoss > ask){
            trade.PositionModify(sellPos,newSellStopLoss,0);
            oldSellStopLoss = newSellStopLoss;
         }
      }
   }
}

double findHigh(){
   int highest = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackPeriod,0);
   int highestBefore = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,highest+LookbackSensitivity,1);
   if(highest <= LookbackSensitivity || highest != highestBefore){
      return 0;
   }
   double high = iHigh(_Symbol,PERIOD_CURRENT,highest);
   return high;
}

double findLow(){
   int lowest = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookbackPeriod,0);
   int lowestBefore = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lowest+LookbackSensitivity,1);
   if(lowest <= LookbackSensitivity || lowest != lowestBefore){
      return 0;
   }
   double low = iLow(_Symbol,PERIOD_CURRENT,lowest);
   return low;
}

void executeBuy(double entry){
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double takeProfitTicks = TakeProfitPips * pipSize;
   double takeProfit = entry + takeProfitTicks;
   stopLossTicks = StopLossPips * pipSize;
   buyStopLoss =  entry - stopLossTicks;
   oldBuyStopLoss = buyStopLoss;
   trade.BuyStop(calcLots(),entry,_Symbol,buyStopLoss,takeProfit,ORDER_TIME_GTC);
   buyPos = trade.ResultOrder();
}

void executeSell(double entry){
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double takeProfitTicks = TakeProfitPips * pipSize;
   double takeProfit = entry - takeProfitTicks;
   stopLossTicks = StopLossPips * pipSize;
   sellStopLoss =  entry + stopLossTicks;
   oldSellStopLoss = sellStopLoss;
   trade.SellStop(calcLots(),entry,_Symbol,sellStopLoss,takeProfit,ORDER_TIME_GTC);
   sellPos = trade.ResultOrder();
}

void executeOrderTradeManagement(){
   bool isTime = timeCheck();
   if(!isTime && PositionsTotal() != 0){
      if(PositionSelectByTicket(buyPos)){
         trade.PositionClose(buyPos);
      }
      if(PositionSelectByTicket(sellPos)){
         trade.PositionClose(sellPos);
      }
   }
   if(!isTime && OrdersTotal() != 0){
      if(OrderSelect(buyPos)){
         trade.OrderDelete(buyPos);
      }
      if(OrderSelect(sellPos)){
         trade.OrderDelete(sellPos);
      }
   }
}

bool detectNewCandle(){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,PERIOD_CURRENT,0,3,priceData);
   datetime currentCandle;
   static datetime lastCandle;
   currentCandle = priceData[0].time;
   bool newCandle = false;
   if(currentCandle != lastCandle){
      lastCandle = currentCandle;
      newCandle = true;
   }
   return newCandle;
}

bool timeCheck(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   string stringHour;
   if(structTime.hour < 10){
      stringHour = "0" + IntegerToString(structTime.hour);
   }
   if(structTime.hour >= 10){
      stringHour = IntegerToString(structTime.hour);
   }
   
   string stringMinute;
   if(structTime.min < 10){
      stringMinute = "0" + IntegerToString(structTime.min);
   }
   if(structTime.min >= 10){
      stringMinute = IntegerToString(structTime.min);
   }
   string timeString = stringHour+":"+stringMinute;
   if(timeString == ResetTime){
      timeStart = true;
      timeEnd = false;
   }
   if(timeString == MarketClose){
      timeEnd = true;
      timeStart = false;
   }
   if(timeStart && !timeEnd){
      return true;
   }
   return false;
}

double calcLots(){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   stopLossTicks = StopLossPips * pipSize;
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent/100;
   double moneyPerLotstep = (stopLossTicks / ticksize) * tickvalue * lotstep;
   if(moneyPerLotstep == 0){
      return 0;
   }
   
   int normalizeStep = 0;
   
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if (SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
   }
   
   double tradeLots = NormalizeDouble(riskMoney / moneyPerLotstep * lotstep, normalizeStep);
   if(tradeLots < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)){
      tradeLots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   }
   return tradeLots;
}