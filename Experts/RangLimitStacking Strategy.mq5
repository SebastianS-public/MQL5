#include <Trade/Trade.mqh>
CTrade trade;

input int PipDigit = 3;
input double RiskInPercent = 1.0;
input int lookback = 10;
input int LookbackOffset = 3;
input int openTimeHour = 9;
input int closeTimeHour = 17;
input double trendFilter = 8;

ulong buyPos1,buyPos2,buyPos3;
ulong sellPos1,sellPos2,sellPos3;

void OnTick(){
   bool session = duringSession();
   bool isTrend = isTrend();
   double high = 0;
   double low = 0;
   bool newCandle = detectNewCandle();
   if(newCandle && session && !isTrend){
      high = findHigh();
      low = findLow();
   }
   NormalizeDouble(high,_Digits);
   NormalizeDouble(low,_Digits);
   Print(buyPos1," ",buyPos2," ",buyPos3," ",sellPos1," ",sellPos2," ",sellPos3);
   
   double highArray[];
   double lowArray[];
   ArraySetAsSeries(highArray,true);
   ArraySetAsSeries(lowArray,true);
   ArrayResize(highArray,2,0);
   ArrayResize(lowArray,2,0);
   highArray[0] = high;
   lowArray[0] = low;
   
   if(high > 0 && low > 0){
      double rangeTotal = high-low;
      double buyStopLoss = low - 0.5 * rangeTotal;
      double sellStopLoss = high + 0.5 * rangeTotal;
      double buyTakeProfit = low + 0.8 * rangeTotal;
      double sellTakeProfit = high - 0.8 * rangeTotal;
      
      double buyEntry1 = high - 0.8 * rangeTotal;
      double buyEntry2 = high - rangeTotal;
      double buyEntry3 = high - 1.2 * rangeTotal;

      double sellEntry1 = low + 0.8 * rangeTotal;
      double sellEntry2 = low + rangeTotal;
      double sellEntry3 = low + 1.2 * rangeTotal;
      if(rangeTotal < 100){
         if((buyPos1 <= 0 && buyPos2 <= 0 && buyPos3 <= 0 && PositionsTotal() == 0) ||
            ((highArray[0] != highArray[1] || lowArray[0] != lowArray[1]) && PositionsTotal() == 0)){
            executeBuy1(buyEntry1,buyStopLoss,buyTakeProfit);
            executeBuy2(buyEntry2,buyStopLoss,buyTakeProfit);
            executeBuy3(buyEntry3,buyStopLoss,buyTakeProfit);
         }
   
         if((sellPos1 <= 0 && sellPos2 <= 0 && sellPos3 <= 0 && PositionsTotal() == 0) ||
            ((highArray[0] != highArray[1] || lowArray[0] != lowArray[1]) && PositionsTotal() == 0)){
            executeSell1(sellEntry1,sellStopLoss,sellTakeProfit);
            executeSell2(sellEntry2,sellStopLoss,sellTakeProfit);
            executeSell3(sellEntry3,sellStopLoss,sellTakeProfit);
         }
         
         if(PositionsTotal() == 0 && buyPos1 <= 0 && buyPos2 > 0 && buyPos3 > 0){
            executeBuy1(buyEntry1,buyStopLoss,buyTakeProfit);
         }
         
         if(PositionsTotal() == 0 && sellPos1 <= 0 && sellPos2 > 0 && sellPos3 > 0){
            executeSell1(sellEntry1,sellStopLoss,sellTakeProfit);
         }
      }
   }
      
   if((buyPos1 > 0 && !PositionSelectByTicket(buyPos1) && !OrderSelect(buyPos1)) ||
      (buyPos2 > 0 && !PositionSelectByTicket(buyPos2) && !OrderSelect(buyPos2)) ||
      (buyPos3 > 0 && !PositionSelectByTicket(buyPos3) && !OrderSelect(buyPos3))){

         trade.OrderDelete(buyPos1);
         trade.OrderDelete(buyPos2);
         trade.OrderDelete(buyPos3);

         buyPos1 = 0;
         buyPos2 = 0;
         buyPos3 = 0;
   }
   
   if((sellPos1 > 0 && !PositionSelectByTicket(sellPos1) && !OrderSelect(sellPos1)) ||
      (sellPos2 > 0 && !PositionSelectByTicket(sellPos2) && !OrderSelect(sellPos2)) ||
      (sellPos3 > 0 && !PositionSelectByTicket(sellPos3) && !OrderSelect(sellPos3))){
         
         trade.OrderDelete(sellPos1);
         trade.OrderDelete(sellPos2);
         trade.OrderDelete(sellPos3);
         
         sellPos1 = 0;
         sellPos2 = 0;
         sellPos3 = 0;
   }
   if(PositionsTotal() > 0){
      ulong openPosTicket = PositionGetTicket(0);
      if((openPosTicket == buyPos1 || openPosTicket == buyPos2 || openPosTicket == buyPos3) &&
        (OrderSelect(sellPos1) || OrderSelect(sellPos2) || OrderSelect(sellPos3))){
         trade.OrderDelete(sellPos1);
         trade.OrderDelete(sellPos2);
         trade.OrderDelete(sellPos3);
      }
      else if((openPosTicket == sellPos1 || openPosTicket == sellPos2 || openPosTicket == sellPos3) &&
             (OrderSelect(buyPos1) || OrderSelect(buyPos2) || OrderSelect(buyPos3))){
         trade.OrderDelete(buyPos1);
         trade.OrderDelete(buyPos2);
         trade.OrderDelete(buyPos3);
      }
   }
   highArray[1] = highArray[0];
   lowArray[1] = lowArray[0];
}

bool isTrend(){
   double ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   double maArray[];
   int ma = iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_EMA,PRICE_CLOSE);
   ArraySetAsSeries(maArray,true);
   CopyBuffer(ma,0,0,10,maArray);
   double maTrendValue = maArray[0] - maArray[9];
   bool isTrend = false;
   if(maTrendValue > trendFilter || maTrendValue < 0 - trendFilter){
      isTrend = true;
   }
   return isTrend;
}

bool duringSession(){
   bool duringSession = false;
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour < closeTimeHour && structTime.hour >= openTimeHour){
      duringSession = true;
   }
   return duringSession;
}

double findHigh(){
   int highestBar;
   double highFindHigh;
   if(iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookback,0) >= LookbackOffset){
      highestBar = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookback,0);
      highFindHigh = iHigh(_Symbol,PERIOD_CURRENT,highestBar);
      return highFindHigh;
   }
   return -1;
}

double findLow(){
   int lowestBar;
   double lowFindLow;
   if(iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookback,0) >= LookbackOffset){
      lowestBar = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookback,0);
      lowFindLow = iLow(_Symbol,PERIOD_CURRENT,lowestBar);
      return lowFindLow;
   }
   return -1;
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

double calcLots(double StopLossPips){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double stopLossTicks = StopLossPips;
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
   if(tradeLots > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)){
      tradeLots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   }
   return tradeLots;
}

void executeBuy1(double entry, double sl, double tp){
   
   trade.OrderDelete(buyPos1);
   entry = NormalizeDouble(entry,_Digits);
   tp = NormalizeDouble(tp,_Digits);
   sl = NormalizeDouble(sl,_Digits);
   double StopPips = entry - sl;
   StopPips = NormalizeDouble(StopPips,1);
   
   trade.BuyLimit(calcLots(StopPips),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   buyPos1 = trade.ResultOrder();
}

void executeBuy2(double entry, double sl, double tp){
   
   trade.OrderDelete(buyPos2);
   entry = NormalizeDouble(entry,_Digits);
   tp = NormalizeDouble(tp,_Digits);
   sl = NormalizeDouble(sl,_Digits);
   double StopPips = entry - sl;
   StopPips = NormalizeDouble(StopPips,1);
   
   trade.BuyLimit(calcLots(StopPips),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   buyPos2 = trade.ResultOrder();
}

void executeBuy3(double entry, double sl, double tp){

   trade.OrderDelete(buyPos3);
   entry = NormalizeDouble(entry,_Digits);
   tp = NormalizeDouble(tp,_Digits);
   sl = NormalizeDouble(sl,_Digits);
   double StopPips = entry - sl;
   StopPips = NormalizeDouble(StopPips,1);
   
   trade.BuyLimit(calcLots(StopPips),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   buyPos3 = trade.ResultOrder();
}

void executeSell1(double entry, double sl, double tp){

   trade.OrderDelete(sellPos1);
   entry = NormalizeDouble(entry,_Digits);
   tp = NormalizeDouble(tp,_Digits);
   sl = NormalizeDouble(sl,_Digits);
   double StopPips = sl - entry;
   StopPips = NormalizeDouble(StopPips,1);
   
   trade.SellLimit(calcLots(StopPips),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   sellPos1 = trade.ResultOrder();
}

void executeSell2(double entry, double sl, double tp){

   trade.OrderDelete(sellPos2);
   entry = NormalizeDouble(entry,_Digits);
   tp = NormalizeDouble(tp,_Digits);
   sl = NormalizeDouble(sl,_Digits);
   double StopPips = sl - entry;
   StopPips = NormalizeDouble(StopPips,1);
   
   trade.SellLimit(calcLots(StopPips),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   sellPos2 = trade.ResultOrder();
}

void executeSell3(double entry, double sl, double tp){

   trade.OrderDelete(sellPos3);
   entry = NormalizeDouble(entry,_Digits);
   tp = NormalizeDouble(tp,_Digits);
   sl = NormalizeDouble(sl,_Digits);
   double StopPips = sl - entry;
   StopPips = NormalizeDouble(StopPips,1);
   
   trade.SellLimit(calcLots(StopPips),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   sellPos3 = trade.ResultOrder();
}