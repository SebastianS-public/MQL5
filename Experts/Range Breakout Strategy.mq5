#include <Trade/Trade.mqh>
CTrade trade;

input double RiskInPercent = 1.0;
input double TargetPips = 20;
input double StopPips = 20;
input int pipDigit = 3;
input int lookback = 20;

double highFindHigh = 0;
int highestBar = 0;
int highestBarFinal;
double lowFindLow = 0;
int lowestBar = 0;
int lowestBarFinal;
int lookbackTotal = lookback;

ulong buyPos, sellPos;

void OnTick(){
   bool newCandle = detectNewCandle();
   if(newCandle){
      double high;
      double low;
      high = findHigh();
      low =findLow();
      
      double highArray[];
      double lowArray[];
      ArraySetAsSeries(highArray,true);
      ArraySetAsSeries(lowArray,true);
      ArrayResize(highArray,2,0);
      ArrayResize(lowArray,2,0);
      highArray[0] = high;
      lowArray[0] = low;
      
      if(buyPos <= 0 || (highArray[0] != highArray[1] && PositionsTotal() == 0)){
         if(high > 0){
            if(buyPos != 0){
               trade.OrderDelete(buyPos);
            }
            executeBuy(high);
         }
      }
      if(sellPos <= 0 || (lowArray[0] != lowArray[1] && PositionsTotal() == 0)){
         if(low > 0){
            if(sellPos != 0){
               trade.OrderDelete(sellPos);
            }
            executeSell(low);
         }
      }
      if(buyPos > 0 && !PositionSelectByTicket(buyPos) && !OrderSelect(buyPos)){
         buyPos = 0;
      }
      if(sellPos > 0 && !PositionSelectByTicket(sellPos) && !OrderSelect(sellPos)){
         sellPos = 0;
      }
      
      highArray[1] = highArray[0];
      lowArray[1] = lowArray[0];
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

double findHigh(){
   if(iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookback,0) >= 5){
      highestBar = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookback,0);
      highFindHigh = iHigh(_Symbol,PERIOD_CURRENT,highestBar);
      lookbackTotal = lookback;
      return highFindHigh;
   }
   else 
      while(iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackTotal,0) < 5){
         highestBar = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackTotal,0);
         highestBarFinal = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackTotal,highestBar+1);
         highFindHigh = iHigh(_Symbol,PERIOD_CURRENT,highestBarFinal);
         lookbackTotal = lookbackTotal + 1;
      }
   return highFindHigh;

}

double findLow(){
   if(iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookback,0) >= 5){
      lowestBar = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookback,0);
      lowFindLow = iLow(_Symbol,PERIOD_CURRENT,lowestBar);
      lookbackTotal = lookback;
      return lowFindLow;
   }
   else 
      while(iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookbackTotal,0) < 5){
         lowestBar = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookbackTotal,0);
         lowestBarFinal = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,lookbackTotal,lowestBar+1);
         lowFindLow = iLow(_Symbol,PERIOD_CURRENT,lowestBarFinal);
         lookbackTotal = lookbackTotal + 1;
      }
   Print(lookbackTotal," ",lowestBarFinal);
   return lowFindLow;

}

void executeBuy(double entry){
   entry = NormalizeDouble(entry,_Digits);
   
   double tp = entry + TargetPips;
   tp = NormalizeDouble(tp,_Digits);
   
   double sl = entry - StopPips;
   sl = NormalizeDouble(sl,_Digits);
   
   trade.BuyStop(calcLots(RiskInPercent),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   buyPos = trade.ResultOrder();
}

void executeSell(double entry){
   entry = NormalizeDouble(entry,_Digits);
   
   double tp = entry - TargetPips;
   tp = NormalizeDouble(tp,_Digits);
   
   double sl = entry + StopPips;
   sl = NormalizeDouble(sl,_Digits);
     
   trade.SellStop(calcLots(RiskInPercent),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   sellPos = trade.ResultOrder();
}

double calcLots(double riskPercent){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double customPipSize = pow(10,(pipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double stopLossTicks = StopPips / pipSize;
   
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent/100;
   double moneyPerLotstep = (stopLossTicks / ticksize) * tickvalue * lotstep;
   
   if(moneyPerLotstep == 0){
      return 0;
   }
   
   double tradeLots = NormalizeDouble(riskMoney / moneyPerLotstep * lotstep, 2);
   return tradeLots;
}