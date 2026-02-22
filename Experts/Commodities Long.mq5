#include <Trade/Trade.mqh>
CTrade trade;

input double ratio = 0.80;
input double tradeVolume = 0.01;
input double stopLossPoints = 1000;
input int StartHour = 23;
input int StartMinute = 45;


bool isPosition = false;
bool wickSetup = false;
ulong posTicket;
bool newDay = false;

void OnTick(){
   bool closeTime = timeCheck();
   bool setup = false;
   if(!isPosition){
      setup = getSetup();
   }else{
      if(closeTime){
         closePosition();
      }
   }
   
   if(setup){
      newDay = detectNewCandle();
      if(newDay){
         placePosition();
      }
   }
}

bool getSetup(){
   double lastCandleSize = iHigh(_Symbol,PERIOD_CURRENT,1) - iLow(_Symbol,PERIOD_CURRENT,1);
   if(iOpen(_Symbol,PERIOD_CURRENT,0) - iLow(_Symbol,PERIOD_CURRENT,0) > ratio * lastCandleSize){
      wickSetup = true;
   }else{
      wickSetup =  false;
   }
   if(wickSetup && SymbolInfoDouble(_Symbol,SYMBOL_ASK) > iOpen(_Symbol,PERIOD_CURRENT,0)){
      return true;
   }else{
      return false;
   }
}

void placePosition(){
   double stopLoss = SymbolInfoDouble(_Symbol,SYMBOL_ASK) - SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * stopLossPoints;
   trade.Buy(tradeVolume,_Symbol,0,stopLoss,0,NULL);
   posTicket = trade.ResultOrder();
   isPosition = true;
   Print(posTicket);
}

void closePosition(){
   trade.PositionClose(posTicket);
   isPosition = false;
}

bool timeCheck(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour == StartHour && structTime.min >= StartMinute){
      return true;
   }
   return false;
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