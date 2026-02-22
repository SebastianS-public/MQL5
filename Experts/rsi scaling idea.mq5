#include <Trade/Trade.mqh>
CTrade trade;

input int rsiShortTrigger = 50;
input int rsiLongTrigger = 50;
input int rsiLength = 14;
input double LotSize = 0.1;
input string ResetTime = "01:00";
input string MarketClose = "23:00";


ulong buyPos,sellPos;
bool buySetup;
bool sellSetup;
bool timeStart = true;
bool timeEnd = false;

void OnTick(){
   bool isTime = timeCheck();
   bool newCandle = detectNewCandle();
   /*if(!isTime && PositionsTotal() != 0){
      if(PositionSelectByTicket(buyPos)){
         ulong j = buyPos;
         while(PositionsTotal() != 0){
            trade.PositionClose(j);
            j--;
         }
      }
      if(PositionSelectByTicket(sellPos)){
         ulong j = sellPos;
         while(PositionsTotal() != 0){
            trade.PositionClose(j);
            j--;
         }
      }
   }*/
   if(newCandle && isTime){
      double currentRsiValue = getCurrentRsiValue();
      double HtfRsiValue = getCurrentRsiValue();
      Print(currentRsiValue," ",HtfRsiValue);
      if(HtfRsiValue > rsiShortTrigger){
         sellSetup = true;
         buySetup = false;
      }
      if(HtfRsiValue < rsiLongTrigger){
         buySetup = true;
         sellSetup = false;
      }
      if(PositionSelectByTicket(buyPos) && !buySetup){
         ulong i = buyPos;
         while(PositionsTotal() != 0){
            trade.PositionClose(i);
            i--;
         }
      }
      if(PositionSelectByTicket(sellPos) && !sellSetup){
         ulong i = sellPos;
         while(PositionsTotal() != 0){
            trade.PositionClose(i);
            i--;
         }
      }
      double lastCandleOpen = iOpen(_Symbol,PERIOD_CURRENT,1);
      double lastCandleClose = iClose(_Symbol,PERIOD_CURRENT,1);
      if(lastCandleClose > lastCandleOpen && currentRsiValue > rsiShortTrigger && sellSetup){
         trade.Sell(LotSize,_Symbol);
         sellPos = trade.ResultOrder();
      }
      if(lastCandleClose < lastCandleOpen && currentRsiValue < rsiLongTrigger && buySetup){
         trade.Buy(LotSize,_Symbol);
         buyPos = trade.ResultOrder();
      }
   }
}

double getCurrentRsiValue(){
   double rsiArray[];
   int rsiHandle = iRSI(_Symbol,PERIOD_CURRENT,rsiLength,PRICE_CLOSE);
   ArraySetAsSeries(rsiArray,true);
   CopyBuffer(rsiHandle,0,0,3,rsiArray);
   double rsiValue = NormalizeDouble(rsiArray[0],2);
   return rsiValue;
}

double getHtfRsiValue(){
   double rsiArray[];
   int rsiHandle = iRSI(_Symbol,PERIOD_H1,rsiLength,PRICE_CLOSE);
   ArraySetAsSeries(rsiArray,true);
   CopyBuffer(rsiHandle,0,0,3,rsiArray);
   double rsiValue = NormalizeDouble(rsiArray[0],2);
   return rsiValue;
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