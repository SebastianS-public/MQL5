#include <Trade/Trade.mqh>
CTrade trade;

input int SetupTriggerPoints = 1000;
input int stopLossPoints = 1000;
input int takeProfitPoints = 1000;
input double PositionSize = 0.1;
input int CloseTradesHour = 20;
input int CloseTradesMinute = 0;
input ENUM_TIMEFRAMES NewCandlePeriod = PERIOD_M15;

bool tradingTime = false;
bool setupCheck = false;
bool tradeSetupCheck = false;
ulong pos;

void OnTick(){
   bool newCandle = detectNewCandle(NewCandlePeriod);
   bool newCurrentCandle = detectNewCurrentCandle(PERIOD_CURRENT);
   if(newCandle){
      if(timeCloseCheck()){
         tradingTime = false;
         setupCheck = false;
         tradeSetupCheck = false;
         closePositions();
      }
   }
   if(newCurrentCandle){
      tradingTime = true;
   }
   if(tradingTime){
      if(!setupCheck){
         setupCheck = checkSetup();
      }
      else{
         if(!tradeSetupCheck && tradeSetup()){
            double sl = SymbolInfoDouble(_Symbol,SYMBOL_ASK) - stopLossPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
            double tp = SymbolInfoDouble(_Symbol,SYMBOL_ASK) + takeProfitPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
            trade.Buy(PositionSize,_Symbol,0,sl,tp,NULL);
            pos = trade.ResultOrder();
            tradeSetupCheck = true;
         }
      }
   }
}

bool tradeSetup(){
   if(SymbolInfoDouble(_Symbol,SYMBOL_ASK) > iOpen(_Symbol,PERIOD_CURRENT,0)){
      return true;
   }
   return false;
}

bool checkSetup(){
   if(SymbolInfoDouble(_Symbol,SYMBOL_ASK) + SetupTriggerPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) < iOpen(_Symbol,PERIOD_CURRENT,0)){
      return true;
   }
   return false;
}

void closePositions(){
   trade.PositionClose(pos);
}

bool timeCloseCheck(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour == CloseTradesHour && structTime.min >= CloseTradesMinute){
      return true;
   }
   return false;
}

bool detectNewCandle(ENUM_TIMEFRAMES period){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,period,0,3,priceData);
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

bool detectNewCurrentCandle(ENUM_TIMEFRAMES period){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,period,0,3,priceData);
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