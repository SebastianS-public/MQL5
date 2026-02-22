#include <Trade/Trade.mqh>
CTrade trade;

input int TimeHour = 16;
input int TimeMinute = 30;
input ENUM_TIMEFRAMES Timeframe;
input int LookbackSensitivity = 5;

ulong buyPos, sellPos;
int lookbackPeriod;

void OnInit(){
   lookbackPeriod = LookbackSensitivity * 4;
}

void OnTick(){
   bool isTime = timeCheck();
   if(isTime){
      if(!OrderSelect(buyPos) && !PositionSelectByTicket(buyPos)){
         double high = findHigh();
      }
      if(!OrderSelect(sellPos) && !PositionSelectByTicket(sellPos)){
         double low = findLow();
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

bool timeCheck(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour == TimeHour && structTime.min == TimeMinute){
      return true;
   }
   return false;
}
