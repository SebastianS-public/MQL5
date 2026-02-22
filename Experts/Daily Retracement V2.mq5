#include <Trade/Trade.mqh>
CTrade trade;

input group "Trading Hours"
input string ResetTime = "16:30";
input string MarketClose = "23:50";

input group "Trade Settings"
input int PipDigit = 3;
input double RiskInPercent = 1.0;
input int slAdd = 50;
input int EntryConfirmationPeriod = 5;
input int LookbackPeriod = 15;

input group "Additional Filters"
input bool WithEntryRatio = false;
input double EntryRatio = 0.5;
input bool TrailingStop = false;
input int TrailingStopLookback = 5;
input bool WeekdayFilter = false;
input int FromWeekday = 1;
input int ToWeekday = 7;
input bool WithTp = false;
input double R_R = 2.0;

bool timeStart;
bool timeEnd;
ulong buyPos, sellPos;
bool newHighLow;
bool positionAlready;
bool setupAlready;
double slDistance;
double stopLoss;
double oldStopLoss = 0;
double newStopLoss = 0;
bool executeBuyAllowed;
bool executeSellAllowed;
int highestCandle;
int lowestCandle;
double high;
double low;

void OnTick(){
   bool isWeekday = checkWeekday();
   bool newCandle = detectNewCandle();
   bool isTime = timeCheck();
   if(!isTime){
      newHighLow = false;
      positionAlready = false;
      setupAlready = false;
      oldStopLoss = 0;
      newStopLoss = 0;
      executeBuyAllowed = false;
      executeSellAllowed = false;
      high = 0;
      low = 0;
   }
   if(!isTime && PositionsTotal() > 0){
      if(PositionSelectByTicket(buyPos)){
         trade.PositionClose(buyPos);
         
      }
      if(PositionSelectByTicket(sellPos)){
         trade.PositionClose(sellPos);
      }
   }
   double takeEntryRatio;
   if(WithEntryRatio){
      takeEntryRatio = EntryRatio;
   }
   else takeEntryRatio = 0;
   if(executeBuyAllowed){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(high - ask > takeEntryRatio * (high - low)){
         executeBuy();
      }
   }
   if(executeSellAllowed){
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(bid - low > takeEntryRatio * (high - low)){
         executeSell();
      }
   }
   if(isTime && isWeekday && PositionsTotal() == 0 && !positionAlready && newCandle && !setupAlready){
      highestCandle = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,LookbackPeriod,0);
      lowestCandle = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,LookbackPeriod,0);
      if(highestCandle == 1 || lowestCandle == 1){
         newHighLow = true;
      }
      if(newHighLow == true && highestCandle == EntryConfirmationPeriod && lowestCandle > EntryConfirmationPeriod){
         executeSellAllowed = true;
         setupAlready = true;
         high = iHigh(_Symbol,PERIOD_CURRENT,highestCandle);
         low = iLow(_Symbol,PERIOD_CURRENT,lowestCandle);
      }
      if(newHighLow == true && lowestCandle == EntryConfirmationPeriod && highestCandle > EntryConfirmationPeriod){
         executeBuyAllowed = true;
         setupAlready = true;
         high = iHigh(_Symbol,PERIOD_CURRENT,highestCandle);
         low = iLow(_Symbol,PERIOD_CURRENT,lowestCandle);
      }
   }
   if(TrailingStop && isTime && PositionsTotal() > 0 && newCandle){
      executeTrailingStop();
   }
}

void executeBuy(){
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double stopLossTicks = slAdd * pipSize;
   stopLoss = low - stopLossTicks;
   slDistance = SymbolInfoDouble(_Symbol,SYMBOL_ASK) - stopLoss;
   double tp = 0;
   if(WithTp){
      tp = stopLoss + slDistance + slDistance * R_R;
   }
   double lots = calcLots();
   trade.Buy(lots,_Symbol,0,stopLoss,tp);
   buyPos = trade.ResultOrder();
   positionAlready = true;
   executeBuyAllowed = false;
   executeSellAllowed = false;
}

void executeSell(){
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double stopLossTicks = slAdd * pipSize;
   stopLoss = high
    + stopLossTicks;
   slDistance = stopLoss - SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tp = 0;
   if(WithTp){
      tp = stopLoss - slDistance - slDistance * R_R;
   }
   double lots = calcLots();
   trade.Sell(lots,_Symbol,0,stopLoss,tp);
   sellPos = trade.ResultOrder();
   positionAlready = true;
   executeBuyAllowed = false;
   executeSellAllowed = false;
}

void executeTrailingStop(){
   if(PositionSelectByTicket(buyPos)){
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double slTriggerValue = stopLoss + slDistance + slDistance * 0.5;
      double close1 = iClose(_Symbol,PERIOD_CURRENT,1);
      double close2 = iClose(_Symbol,PERIOD_CURRENT,2);
      if(bid > slTriggerValue && close1 > close2){
         newStopLoss = iLow(_Symbol,PERIOD_CURRENT,iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,TrailingStopLookback,0));
         if(newStopLoss > oldStopLoss && newStopLoss < bid){
            trade.PositionModify(buyPos,newStopLoss,0);
         }
         oldStopLoss = newStopLoss;
      }
   }
   if(PositionSelectByTicket(sellPos)){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double slTriggerValue = stopLoss + slDistance + slDistance * 0.5;
      double close1 = iClose(_Symbol,PERIOD_CURRENT,1);
      double close2 = iClose(_Symbol,PERIOD_CURRENT,2);
      if(ask < slTriggerValue && close1 < close2){
         newStopLoss = iHigh(_Symbol,PERIOD_CURRENT,iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,TrailingStopLookback,0));
         if(newStopLoss < oldStopLoss && newStopLoss > ask){
            trade.PositionModify(sellPos,newStopLoss,0);
         }
         oldStopLoss = newStopLoss;
      }
   }
}

bool checkWeekday(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(WeekdayFilter){
      if(structTime.day_of_week >= FromWeekday && structTime.day_of_week <= ToWeekday){
         return true;
      }
      return false;
   }
   return true;
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
   double stopLossTicks = slDistance;
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
   if(tradeLots < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)){
      tradeLots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   }
   return tradeLots;
}