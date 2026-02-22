#include <Trade/Trade.mqh>
CTrade trade;

input group "Time Settings"
input int StartHour = 6;
input int StartMinute = 0;
input int EndHour = 22;
input int EndMinute = 0;

input group "Other Settings"
input double MartingaleFactor = 1.0;
input bool PositionSizePer100kMode = false;
input double PositionSizePer100k = 1.0;
input double PositionSizeAbsolute = 0.01;
input int CCITriggerLevel = 100;
input int GridDistance = 200;
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
input int CCIPeriod = 14;
input ENUM_APPLIED_PRICE CCIAppliedPrice = PRICE_TYPICAL;

int normalizeStep;
double averagePosition;
bool timeStart, timeEnd;

void OnInit(){
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
   }
}

void OnTick(){
   bool isTime = timeCheck();
   if(!isTime && PositionsTotal() != 0){
      closePositions();
      averagePosition = 0;
      ObjectDelete(0,"Average Price");
   }
   bool newCandle = detectNewCandle();
   if(PositionsTotal() != 0){
      averagePosition = getAveragePosition();
   }
   if(newCandle && isTime){
      int CCICase = getCCICase();
      if(CCICase == 1){
         if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            while(PositionsTotal() != 0){
               closePositions();
               averagePosition = 0;
               ObjectDelete(0,"Average Price");
            }
            executeSell();
         }
         else{
            executeSell();
         }
      }
      else if(CCICase == 2){
         if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
            while(PositionsTotal() != 0){
               closePositions();
               averagePosition = 0;
               ObjectDelete(0,"Average Price");
            }
            executeBuy();
         }
         else{
            executeBuy();
         }
      }
      else if(PositionsTotal() != 0 && CCICase == 3){
         if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
            iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            closePositions();
            averagePosition = 0;
            ObjectDelete(0,"Average Price");
            Print("close long");
         }
         if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
            iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            closePositions();
            averagePosition = 0;
            ObjectDelete(0,"Average Price");
            Print("close short");
         }
         if((SymbolInfoDouble(_Symbol,SYMBOL_BID) - averagePosition) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) > GridDistance){
            executeSell();
         }
      }
      else if(PositionsTotal() != 0 && CCICase == 4){
         if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
            iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            closePositions();
            averagePosition = 0;
            ObjectDelete(0,"Average Price");
            Print("close long");
         }
         if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
            iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            closePositions();
            averagePosition = 0;
            ObjectDelete(0,"Average Price");
            Print("close short");
         }
         if((averagePosition - SymbolInfoDouble(_Symbol,SYMBOL_ASK)) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) > GridDistance){
            executeBuy();
         }
      }
   }
}

double getAveragePosition(){
   double totalVolume = 0;
   double totalPrice = 0;
   double minVolume = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)){
         double volume = PositionGetDouble(POSITION_VOLUME);
         if(minVolume == 0){
            minVolume = volume;
         }
         else if(minVolume > volume){
            minVolume = volume;
         }
      }
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)){
         double volume = PositionGetDouble(POSITION_VOLUME);
         double price = PositionGetDouble(POSITION_PRICE_OPEN);
         totalPrice = totalPrice + price * (volume / minVolume);
         totalVolume = totalVolume + volume;
      }
   }
   double averagePrice = totalPrice / (totalVolume / minVolume);
   ObjectCreate(0,"Average Price",OBJ_HLINE,0,0,averagePrice);
   ObjectSetInteger(0,"Average Price",OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,"Average Price",OBJPROP_COLOR,clrYellow);
   ObjectSetInteger(0,"Average Price",OBJPROP_WIDTH,3);
   return averagePrice;
}

double posNumTotal = 0;

void executeBuy(){
   double baseLot = 0;
   if(PositionSizePer100kMode){
      baseLot = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) / 100000 * PositionSizePer100k, normalizeStep);
      if(baseLot < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)){
         baseLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      }
   }
   else if(!PositionSizePer100kMode){
      baseLot = PositionSizeAbsolute;
      if(baseLot < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)){
         baseLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      }
   }
   double lots = NormalizeDouble(baseLot * MathPow(2, posNumTotal), normalizeStep);
   trade.Buy(lots,_Symbol,0,0,0,NULL);
   posNumTotal = posNumTotal + MartingaleFactor;
}

void executeSell(){
   double baseLot = 0;
   if(PositionSizePer100kMode){
      baseLot = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) / 100000 * PositionSizePer100k, normalizeStep);
      if(baseLot < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)){
         baseLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      }
   }
   else if(!PositionSizePer100kMode){
      baseLot = PositionSizeAbsolute;
      if(baseLot < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)){
         baseLot = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      }
   }
   double lots = NormalizeDouble(baseLot * MathPow(2, posNumTotal), normalizeStep);
   trade.Sell(lots,_Symbol,0,0,0,NULL);
   posNumTotal = posNumTotal + MartingaleFactor;
}

void closePositions(){
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)){
         trade.PositionClose(ticket);
      }
   }
   posNumTotal = 0;
}

int getCCICase(){
   int CCIHandle = iCCI(_Symbol,Timeframe,CCIPeriod,CCIAppliedPrice);
   double CCIArray[];
   ArraySetAsSeries(CCIArray,true);
   CopyBuffer(CCIHandle,0,0,3,CCIArray);
   Print(CCIArray[1]);
   if(iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1) && CCIArray[1] > CCITriggerLevel && CCIArray[1] > CCIArray[2]){
      Print("sell");
      return 1;
   }
   else if(iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1) && CCIArray[1] < -CCITriggerLevel && CCIArray[1] < CCIArray[2]){
      Print("buy");
      return 2;
   }
   else if(CCIArray[1] > CCIArray[2] && CCIArray[1] < CCITriggerLevel){
      Print("higher");
      return 3;
   }
   else if(CCIArray[1] < CCIArray[2] && CCIArray[1] > -CCITriggerLevel){
      Print("lower");
      return 4;
   }
   else return 0;
}

bool detectNewCandle(){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,Timeframe,0,3,priceData);
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
   if(structTime.hour == StartHour && structTime.min >= StartMinute){
      timeStart = true;
      timeEnd = false;
   }
   if(structTime.hour == EndHour && structTime.min >= EndMinute){
      timeStart = false;
      timeEnd = true;
   }
   if(timeStart && !timeEnd){
      return true;
   }
   return false;
}