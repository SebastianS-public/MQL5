#include <Trade/Trade.mqh>
CTrade trade;

input int ResetHour = 2;
input int StopPoints = 150;
input int TargetPoints = 150;
input int PointDistance = 0;
input bool UseRiskPercent = false;
input double RiskInPercent = 1.0;
input double LotSize = 1.04;

int currentDay;
int lookbackDay;
datetime currentHighTime;
datetime lookbackHighTime;
datetime currentLowTime;
datetime lookbackLowTime;
bool newDay;

ulong buyPos, sellPos;

void OnTick(){
   
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour == 23 && structTime.min == 45 && PositionsTotal() > 0){
      trade.PositionClose(buyPos);
      trade.PositionClose(sellPos);
   }
   
   if(!newDay){
      newDay = detectNewDay();      
   }
   
   int intHour = structTime.hour;
   if(newDay && intHour == ResetHour){
      if(OrderSelect(buyPos)){
         trade.OrderDelete(buyPos);
      }
      if(OrderSelect(sellPos)){
         trade.OrderDelete(sellPos);
      }
      
      double high = findHigh();
      double low = findLow();
      if(high != 0 && low != 0){
         executeBuy(high);
         executeSell(low);
      }
      newDay = false;
   }

   lookbackDay = currentDay;
}


bool detectNewDay(){
   MqlDateTime structTime;
   TimeCurrent(structTime);

   currentDay = structTime.day;
   if(currentDay != lookbackDay){
      return true;
   }
   return false;
}

double findHigh(){
   double high = 0;
   currentHighTime = detectCurrentTime();

   if(currentHighTime != D'1970.01.01 00:00' && lookbackHighTime != D'1970.01.01 00:00'){
      int amountBars = Bars(_Symbol,PERIOD_CURRENT,lookbackHighTime,currentHighTime);
      int highestBar = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,amountBars,0);
      high = iHigh(_Symbol,PERIOD_CURRENT,highestBar);
      high = NormalizeDouble(high,_Digits);
   }
   lookbackHighTime = currentHighTime;
   return high;
}

double findLow(){
   double low = 0;
   currentLowTime = detectCurrentTime();

   if(currentLowTime != D'1970.01.01 00:00' && lookbackLowTime != D'1970.01.01 00:00'){
      int amountBars = Bars(_Symbol,PERIOD_CURRENT,lookbackLowTime,currentLowTime);
      int lowestBar = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,amountBars,0);
      low = iLow(_Symbol,PERIOD_CURRENT,lowestBar);
      low = NormalizeDouble(low,_Digits);
   }
   lookbackLowTime = currentLowTime;
   return low;
}

datetime detectCurrentTime(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   
   int intMonth = structTime.mon;
   string stringMonth;
   if(structTime.mon < 10){
      stringMonth = "0" + IntegerToString(intMonth);
   }
   if(structTime.mon >= 10){
      stringMonth = IntegerToString(intMonth);
   }
   
   int intDay = structTime.day;
   string stringDay;
   if(structTime.day < 10){
      stringDay = "0" + IntegerToString(intDay);
   }
   if(structTime.day >= 10){
      stringDay = IntegerToString(intDay);
   }
   
   int intHour = structTime.hour;
   string stringHour;
   if(structTime.hour < 10){
      stringHour = "0" + IntegerToString(intHour);
   }
   if(structTime.hour >= 10){
      stringHour = IntegerToString(intHour);
   }
   
   int intMinute = structTime.min;
   string stringMinute;
   if(structTime.min < 10){
      stringMinute = "0" + IntegerToString(intMinute);
   }
   if(structTime.min >= 10){
      stringMinute = IntegerToString(intMinute);
   }
   
   string currentStringTime = IntegerToString(structTime.year)+"."+stringMonth+"."+stringDay+" "+stringHour+":"+stringMinute+"";
   return StringToTime(currentStringTime);
}

void executeBuy(double high){
   double entry = NormalizeDouble(high + (PointDistance * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)),_Digits);
   double tp = NormalizeDouble(entry + (TargetPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)),_Digits);
   double sl = NormalizeDouble(entry - (StopPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)),_Digits);
   double lots;
   if(!UseRiskPercent){
      lots = LotSize;
   }else{
      lots = calcLots();
   }
   trade.BuyStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   buyPos = trade.ResultOrder();
}

void executeSell(double low){
   double entry = NormalizeDouble(low - (PointDistance * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)),_Digits);
   double tp = NormalizeDouble(entry - (TargetPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)),_Digits);
   double sl = NormalizeDouble(entry + (StopPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)),_Digits);
   double lots;
   if(!UseRiskPercent){
      lots = LotSize;
   }else{
      lots = calcLots();
   }
   trade.SellStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC);
   sellPos = trade.ResultOrder();
}

double calcLots(){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent/100;
   double moneyPerLotstep = (StopPoints / ticksize) * tickvalue * lotstep;
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