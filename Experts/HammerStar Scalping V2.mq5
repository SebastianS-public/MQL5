#include <Trade/Trade.mqh>
CTrade trade;

input string ResetTime = "01:00";
input string MarketClose = "23:00";
input bool UseRiskPercent = false;
input double RiskInPercent = 1.0;
input double LotSize = 1.04;
input double FibPercentage = 50;
input double TrailingStopPoints = 50;
input double TSDistanceFactor = 0.05;

bool timeStart = true;
bool timeEnd = false;
ulong buyPos,sellPos;

double buyStopLoss;
double stopLossTicks;
double sellStopLoss;
double oldBuyStopLoss;
double newBuyStopLoss;
double oldSellStopLoss;
double newSellStopLoss;
int trailingStopCount;
double trailingStopTicks = TrailingStopPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
double trailingStopDistance;

void OnTick(){
   bool isTime = timeCheck();
   bool newCandle = detectNewCandle();
   if((!isTime && OrdersTotal() != 0) || (!isTime && PositionsTotal() != 0)){
      executeOrderTradeManagement();
   }
   if(PositionsTotal() != 0){
      executeTrailingStop();
   }
   if(newCandle && isTime){
      double high = iHigh(_Symbol,PERIOD_CURRENT,1);
      double low = iLow(_Symbol,PERIOD_CURRENT,1);
      double close1 = iClose(_Symbol,PERIOD_CURRENT,1);
      double open1 = iOpen(_Symbol,PERIOD_CURRENT,1);
      double starFibLevel = high - (high - low) * (FibPercentage / 100);
      double hammerFibLevel = (high - low) * (FibPercentage / 100) + low;
      bool star = false;
      bool hammer = false;
      double entry = 0;
      double relativeClose = 0;
      double distanceToClose = 0;
      if(close1 < starFibLevel && open1 < starFibLevel){
         star = true;
      }
      if(close1 > hammerFibLevel && open1 > hammerFibLevel){
         hammer = true;
      }
      if(OrderSelect(buyPos)){
         trade.OrderDelete(buyPos);
      }
      if(OrderSelect(sellPos)){
         trade.OrderDelete(sellPos);
      }
      if(hammer && !OrderSelect(buyPos)){
         relativeClose = (close1 - low) / (high - low);
         distanceToClose = (high - close1) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      }
      if(star && !OrderSelect(sellPos)){
         relativeClose = (high - close1) / (high -low);
         distanceToClose = (close1 - low) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      }
      if(hammer && PositionsTotal() == 0){
         if(relativeClose > 0.9 || distanceToClose < 10){
            entry = NormalizeDouble(high + 10 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Digits);
         }
         else{
            entry = high;
         }
         buyStopLoss = entry - trailingStopTicks;
         oldBuyStopLoss = buyStopLoss;
         double lots = LotSize;
         if(UseRiskPercent){
            lots = calcLots();
         }
         trade.BuyStop(lots,entry,_Symbol,buyStopLoss,0,ORDER_TIME_GTC);
         buyPos = trade.ResultOrder();
         trailingStopCount = 0;
         trailingStopDistance = 0;
      }
      if(star && PositionsTotal() == 0){
         if(relativeClose > 0.9 || distanceToClose < 10){
            entry = NormalizeDouble(low - 10 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Digits);
         }
         else{
            entry = low;
         }
         sellStopLoss = entry + trailingStopTicks;
         oldSellStopLoss = sellStopLoss;
         double lots = LotSize;
         if(UseRiskPercent){
            lots = calcLots();
         }
         trade.SellStop(lots,entry,_Symbol,sellStopLoss,0,ORDER_TIME_GTC);
         sellPos = trade.ResultOrder();
         trailingStopCount = 0;
         trailingStopDistance = 0;
      }
   }
}

void executeOrderTradeManagement(){
   if(PositionSelectByTicket(buyPos)){
      trade.PositionClose(buyPos);
   }
   if(PositionSelectByTicket(sellPos)){
      trade.PositionClose(sellPos);
   }
   if(OrderSelect(buyPos)){
      trade.OrderDelete(buyPos);
   }
   if(OrderSelect(sellPos)){
      trade.OrderDelete(sellPos);
   }
}

void executeTrailingStop(){
   if(PositionSelectByTicket(buyPos)){
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      newBuyStopLoss = bid - trailingStopTicks;
      if(newBuyStopLoss > oldBuyStopLoss && newBuyStopLoss < bid){
         trade.PositionModify(buyPos,newBuyStopLoss + trailingStopDistance,0);
         oldBuyStopLoss = newBuyStopLoss;
         trailingStopDistance = trailingStopDistance + TSDistanceFactor * trailingStopTicks;
      }
   }
   if(PositionSelectByTicket(sellPos)){      
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      newSellStopLoss = ask + trailingStopTicks;
      if(newSellStopLoss < oldSellStopLoss && newSellStopLoss > ask){
         trade.PositionModify(sellPos,newSellStopLoss - trailingStopDistance,0);
         oldSellStopLoss = newSellStopLoss;
         trailingStopDistance = trailingStopDistance + TSDistanceFactor * trailingStopTicks;
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
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent/100;
   double moneyPerLotstep = (TrailingStopPoints / ticksize) * tickvalue * lotstep;
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