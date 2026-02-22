#include <Trade/Trade.mqh>
CTrade trade;

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
input int ATRPeriod = 200;

int normalizeStep;
double averagePosition;

void OnInit(){
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
   }
}

void OnTick(){
   bool newCandle = detectNewCandle();
   if(PositionsTotal() != 0){
      averagePosition = getAveragePosition();
      if(AccountInfoDouble(ACCOUNT_EQUITY) < AccountInfoDouble(ACCOUNT_BALANCE) - 4500){
         closePositions();
         averagePosition = 0;
      }
   }
   if(newCandle){
      bool ATRCondition = getATRCondition();
      int CCICase = getCCICase();
      if(CCICase == 1 && ATRCondition){
         if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            Print("Case1 Close Positions/Sell");
            while(PositionsTotal() != 0){
               closePositions();
               averagePosition = 0;
            }
            executeSell();
         }
         else{
            Print("Case1 Sell");
            executeSell();
         }
      }
      else if(CCICase == 2 && ATRCondition){
         if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
            Print("Case2 Close Positions/Buy");
            while(PositionsTotal() != 0){
               closePositions();
               averagePosition = 0;
            }
            executeBuy();
         }
         else{
            Print("Case2 Buy");
            executeBuy();
         }
      }
      else if(PositionsTotal() != 0 && CCICase == 3){
         if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
            iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            Print("Case3 Close Buys");
            closePositions();
            averagePosition = 0;
         }
         else if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
            iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            Print("Case3 Close Sells");
            closePositions();
            averagePosition = 0;
         }
         else if((SymbolInfoDouble(_Symbol,SYMBOL_BID) - averagePosition) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) > GridDistance){
            Print("Case3 Sell");
            executeSell();
         }
      }
      else if(PositionsTotal() != 0 && CCICase == 4){
         if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
            iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            Print("Case4 Close Buys");
            closePositions();
            averagePosition = 0;
         }
         else if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
            iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            Print("Case4 Close Sells");
            closePositions();
            averagePosition = 0;
         }
         else if((averagePosition - SymbolInfoDouble(_Symbol,SYMBOL_ASK)) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) > GridDistance){
            Print("Case4 Buy");
            executeBuy();
         }
      }
   }
}

bool getATRCondition(){
   int atrHandle = iATR(_Symbol,Timeframe,ATRPeriod);
   double atrArray[];
   ArraySetAsSeries(atrArray,true);
   CopyBuffer(atrHandle,0,0,2,atrArray);
   if(MathAbs(iOpen(_Symbol,Timeframe,1) - iClose(_Symbol,Timeframe,1)) > atrArray[1]){
      return true;
   }
   return false;
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
   if(iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1) && CCIArray[1] > CCITriggerLevel && CCIArray[1] > CCIArray[2]){
      return 1;
   }
   else if(iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1) && CCIArray[1] < -CCITriggerLevel && CCIArray[1] < CCIArray[2]){
      return 2;
   }
   else if(CCIArray[1] > CCIArray[2] && CCIArray[1] < CCITriggerLevel){
      return 3;
   }
   else if(CCIArray[1] < CCIArray[2] && CCIArray[1] > -CCITriggerLevel){
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