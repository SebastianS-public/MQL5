#include <Trade/Trade.mqh>
CTrade trade;

input group "Position Size Settings"
input double PositionSize = 0.01;
input double SizeIncreaseFactor = 2;

input group "Grid Settings"
input int BasePoints = 200;

input group "Technical Settings"
input int LookbackPeriod = 15;

double resistanceLevel, supportLevel;
double high, low = -1;
double highTrend, lowTrend = 0;
double lastFiveHigh, lastFiveLow;

void OnInit(){
   
}

void OnTick(){
   getHighLow();
}

void getHighLow(){
   int x = LookbackPeriod;
   while(high != highTrend || lastFiveHigh >= high){
      lastFiveHigh = iHigh(_Symbol,PERIOD_M15,iHighest(_Symbol,PERIOD_M15,MODE_HIGH,5,0));
      high = iHigh(_Symbol,PERIOD_M15,iHighest(_Symbol,PERIOD_M15,MODE_HIGH,x,5));
      highTrend = iHigh(_Symbol,PERIOD_M15,iHighest(_Symbol,PERIOD_M15,MODE_HIGH,x+5,5));
      x = x + 5;
   }
   if(high != resistanceLevel){
      resistanceLevel = high;
      ObjectDelete(0,"Resistance");
      ObjectCreate(0,"Resistance",OBJ_HLINE,0,0,resistanceLevel);
      ObjectSetInteger(0,"Resistance",OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,"Resistance",OBJPROP_COLOR,clrRed);
      ObjectSetInteger(0,"Resistance",OBJPROP_WIDTH,3);
   }
   highTrend = 0;
   
   while(low != lowTrend || lastFiveLow <= low){
      lastFiveLow = iLow(_Symbol,PERIOD_M15,iLowest(_Symbol,PERIOD_M15,MODE_LOW,5,0));
      low = iLow(_Symbol,PERIOD_M15,iLowest(_Symbol,PERIOD_M15,MODE_LOW,x,5));
      lowTrend = iLow(_Symbol,PERIOD_M15,iLowest(_Symbol,PERIOD_M15,MODE_LOW,x+5,5));
      x = x + 5;
   }
   if(low != supportLevel){
      supportLevel = low;
      ObjectDelete(0,"Support");
      ObjectCreate(0,"Support",OBJ_HLINE,0,0,supportLevel);
      ObjectSetInteger(0,"Support",OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,"Support",OBJPROP_COLOR,clrGreen);
      ObjectSetInteger(0,"Support",OBJPROP_WIDTH,3);
   }
   lowTrend = 0;
}