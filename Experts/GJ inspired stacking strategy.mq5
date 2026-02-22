#include <Trade/Trade.mqh>
CTrade trade;

input group "Time Check"
input string NighttimeStart = "20:00";
input string NighttimeEnd = "02:00";
input string SessiontimeStart = "06:00";
input string SessiontimeEnd = "14:00";

bool NightTimeStart;
bool NightTimeEnd;
bool SessionTimeStart;
bool SessionTimeEnd;
double totalPrice = 0;
int o = 0;
int a = 0;
double averagePrice = 0;
bool sellSetup;
bool buySetup;
int setupCount;
ulong buyPos, sellPos;

void OnTick(){
   bool newCandle = detectNewCandle();
   bool isNightTime = NightTimeCheck();
   bool isSessionTime = SessionTimeCheck();
   if(!isSessionTime && PositionsTotal() != 0){
      if(PositionSelectByTicket(buyPos)){
         ulong positionNumber = buyPos;
         while (PositionsTotal() != 0){
            trade.PositionClose(positionNumber);
            positionNumber--;
         }
      }
      if(PositionSelectByTicket(sellPos)){
         ulong positionNumber = sellPos;
         while (PositionsTotal() != 0){
            trade.PositionClose(positionNumber);
            positionNumber--;
         }
      }
   }
   if(!isSessionTime && sellSetup){
      sellSetup = false;
   }
   if(!isSessionTime && buySetup){
      buySetup = false;
   }
   if(isNightTime && newCandle){
      a = 0;
      totalPrice = totalPrice + iClose(_Symbol,PERIOD_CURRENT,1);
      o++;
   }
   if(a == 0 && !isNightTime && newCandle){
      averagePrice = totalPrice / o;
      a++;
      o = 0;
      totalPrice = 0;
      setupCount = 0;
   }
   if(isSessionTime && setupCount == 0){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(ask < averagePrice){
         sellSetup = true;
         setupCount = 1;
      }
      if(ask > averagePrice){
         buySetup = true;
         setupCount = 1;
      }
   }
   if(newCandle && buySetup && iClose(_Symbol,PERIOD_CURRENT,1) < iOpen(_Symbol,PERIOD_CURRENT,1)){
      trade.Buy(1,_Symbol,0,0,0);
      buyPos = trade.ResultOrder();
   }
   if(newCandle && sellSetup && iClose(_Symbol,PERIOD_CURRENT,1) > iOpen(_Symbol,PERIOD_CURRENT,1)){
      trade.Sell(1,_Symbol,0,0,0);
      sellPos = trade.ResultOrder();
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

bool NightTimeCheck(){
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
   if(timeString == NighttimeStart){
      NightTimeStart = true;
      NightTimeEnd = false;
   }
   if(timeString == NighttimeEnd){
      NightTimeEnd = true;
      NightTimeStart = false;
   }
   if(NightTimeStart && !NightTimeEnd){
      return true;
   }
   return false;
}

bool SessionTimeCheck(){
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
   if(timeString == SessiontimeStart){
      SessionTimeStart = true;
      SessionTimeEnd = false;
   }
   if(timeString == SessiontimeEnd){
      SessionTimeEnd = true;
      SessionTimeStart = false;
   }
   if(SessionTimeStart && !SessionTimeEnd){
      return true;
   }
   return false;
}