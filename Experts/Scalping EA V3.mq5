#include <Trade/Trade.mqh>
CTrade trade;

input group "General Settings"
input string ResetTime = "01:00";
input string MarketClose = "21:00";
input bool BuyTrades = true;
input bool SellTrades = true;
input ENUM_TIMEFRAMES Timeframe;

input group "Volume Settings"
input bool UseRiskInPercent = true;
input double RiskInPercent = 2.0;
input double Lots = 1.1;

input group "Trade Settings"
input int LookbackSensitivity = 8;
input int StopLossPoints = 100;
input int TakeProfitPoints = 200;
input double TrailingStopTrigger = 60;
input double TrailingStopPoints = 20;

int lookbackPeriod;

void OnInit(){
   lookbackPeriod = LookbackSensitivity * 4;
}

bool timeStart;
bool timeEnd;
ulong buyPos, sellPos;
double entryHigh = 0;
double entryLow = 0;

double buyStopLoss;
double sellStopLoss;
double oldBuyStopLoss;
double newBuyStopLoss;
double oldSellStopLoss;
double newSellStopLoss;

void OnTick(){
   bool newCandle = detectNewCandle();
   bool isTime = timeCheck();
   executeOrderTradeManagement();
   
   if(PositionSelectByTicket(buyPos) || PositionSelectByTicket(sellPos)){
      executeTrailingStop();
   }
   if(newCandle && isTime && !PositionSelectByTicket(buyPos) && !PositionSelectByTicket(sellPos)){
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
         double swingHigh = iHigh(_Symbol,Timeframe,iHighest(_Symbol,Timeframe,MODE_HIGH,lookbackPeriod,0));
         if(entryHigh >= swingHigh){
            executeBuy(entryHigh);
         }
      }
      if(!OrderSelect(sellPos) && !PositionSelectByTicket(sellPos) && entryLow != 0 && SellTrades){
         double swingLow = iLow(_Symbol,Timeframe,iLowest(_Symbol,Timeframe,MODE_LOW,lookbackPeriod,0));
         if(entryLow <= swingLow){
            executeSell(entryLow);
         }
      }
   }
}

void executeTrailingStop(){
   if(PositionSelectByTicket(buyPos)){
      if(buyStopLoss != PositionGetDouble(POSITION_PRICE_OPEN) - StopLossPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)){
         buyStopLoss = PositionGetDouble(POSITION_PRICE_OPEN) - StopLossPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         trade.PositionModify(buyPos,buyStopLoss,0);
      }
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double slTriggerValue = PositionGetDouble(POSITION_PRICE_OPEN) + TrailingStopTrigger * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(bid > slTriggerValue){
         newBuyStopLoss = bid - TrailingStopPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         if(newBuyStopLoss > oldBuyStopLoss && newBuyStopLoss < bid){
            trade.PositionModify(buyPos,newBuyStopLoss,0);
            oldBuyStopLoss = newBuyStopLoss;
         }
      }
   }
   if(PositionSelectByTicket(sellPos)){
      if(sellStopLoss != PositionGetDouble(POSITION_PRICE_OPEN) + StopLossPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)){
         sellStopLoss = PositionGetDouble(POSITION_PRICE_OPEN) + StopLossPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         trade.PositionModify(sellPos,sellStopLoss,0);
      }
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double slTriggerValue = PositionGetDouble(POSITION_PRICE_OPEN) - TrailingStopTrigger * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(ask < slTriggerValue){
         newSellStopLoss = ask + TrailingStopPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         if(newSellStopLoss < oldSellStopLoss && newSellStopLoss > ask){
            trade.PositionModify(sellPos,newSellStopLoss,0);
            oldSellStopLoss = newSellStopLoss;
         }
      }
   }
}

double findHigh(){
   int highest = iHighest(_Symbol,Timeframe,MODE_HIGH,lookbackPeriod,0);
   int highestBefore = iHighest(_Symbol,Timeframe,MODE_HIGH,highest+LookbackSensitivity,1);
   if(highest <= LookbackSensitivity || highest != highestBefore){
      return 0;
   }
   double high = iHigh(_Symbol,Timeframe,highest);
   return high;
}

double findLow(){
   int lowest = iLowest(_Symbol,Timeframe,MODE_LOW,lookbackPeriod,0);
   int lowestBefore = iLowest(_Symbol,Timeframe,MODE_LOW,lowest+LookbackSensitivity,1);
   if(lowest <= LookbackSensitivity || lowest != lowestBefore){
      return 0;
   }
   double low = iLow(_Symbol,Timeframe,lowest);
   return low;
}

void executeBuy(double entry){
   double takeProfit = entry + TakeProfitPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   buyStopLoss =  entry - StopLossPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   oldBuyStopLoss = buyStopLoss;
   double lots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(UseRiskInPercent){
      lots = calcLots();
   }
   else{
      lots = Lots;
   }
   trade.BuyStop(lots,entry,_Symbol,buyStopLoss,takeProfit,ORDER_TIME_GTC);
   buyPos = trade.ResultOrder();
}

void executeSell(double entry){
   double takeProfit = entry - TakeProfitPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   sellStopLoss =  entry + StopLossPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   oldSellStopLoss = sellStopLoss;
   double lots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(UseRiskInPercent){
      lots = calcLots();
   }
   else{
      lots = Lots;
   }
   trade.SellStop(lots,entry,_Symbol,sellStopLoss,takeProfit,ORDER_TIME_GTC);
   sellPos = trade.ResultOrder();
}

void executeOrderTradeManagement(){
   bool isTime = timeCheck();
   if(!isTime){
      if(PositionSelectByTicket(buyPos)){
         trade.PositionClose(buyPos);
      }
      if(PositionSelectByTicket(sellPos)){
         trade.PositionClose(sellPos);
      }
   }
   if(!isTime){
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
   CopyRates(_Symbol,Timeframe,0,3,priceData);
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
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent/100;
   double moneyPerLotstep = StopLossPoints * tickvalue * lotstep;
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
   if(tradeLots > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)){
      tradeLots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   }
   return tradeLots;
}