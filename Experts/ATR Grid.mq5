#include <Trade/Trade.mqh>
CTrade trade;

input group "General Settings"
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
input bool PositionSizePer100kMode = false;
input double PositionSizePer100k = 1.0;
input double PositionSizeAbsolute = 0.01;
input double MartingaleFactor = 1.0;
input int ATRPeriod = 15;
input double ATRTriggerConstant = 1.0;
input bool UseATRSwitch = false;
input double ATRSwitchConstant = 2.0;
input bool DebugMode = false;
input bool UseComments = false;
input double CommissionPerLot = 3.50;

int normalizeStep;

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
   if(newCandle){
      if(PositionsTotal() != 0){
         if(AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE) + CommissionPerLot){
            closePositions();
         }
      }
      double candleSize = getCandleSize();
      double ATRValue = getATRValue();
      int ATRCase = getATRCase(ATRValue, MathAbs(candleSize));
      getAveragePosition();
      if(ATRCase == 2){
         if(candleSize < 0){
            if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0))){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                  closePositions();
                  executeSell();
               }
               else executeSell();
            }
            else executeSell();
         }
         else{
            if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0))){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  closePositions();
                  executeBuy();
               }
               else executeBuy();
            }
            else executeBuy();
         }
      }
      else if(ATRCase == 1){
         if(candleSize < 0){
            if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0))){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  closePositions();
                  executeBuy();
               }
               else executeBuy();
            }
            else executeBuy();
         }
         else{
            if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0))){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                  closePositions();
                  executeSell();
               }
               else executeSell();
            }
            else executeSell();
         }
      }
   }
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

double getATRValue(){
   int ATRHandle = iATR(_Symbol,Timeframe,ATRPeriod);
   double ATRArray[];
   ArraySetAsSeries(ATRArray,true);
   CopyBuffer(ATRHandle,0,0,2,ATRArray);
   if(DebugMode){
      Print("ATR Value: ",ATRArray[1]);
   }
   if(UseComments){
      Comment("ATR Value: ",ATRArray[1],"\n");
   }
   return ATRArray[1];
}

double getCandleSize(){
   double candleSize = iClose(_Symbol,Timeframe,1) - iOpen(_Symbol,Timeframe,1);
   if(DebugMode){
      Print("Candle Size: ",candleSize);
   }
   if(UseComments){
      Comment("Candle Size: ",candleSize,"\n");
   }
   return candleSize;
}

int getATRCase(double ATRValue, double candleSize){
   int ATRCase = 0;
   if(candleSize > ATRValue * ATRSwitchConstant && UseATRSwitch){
      ATRCase = 2;
   }
   else if(candleSize > ATRValue * ATRTriggerConstant){
      ATRCase = 1;
   }
   else ATRCase = 0;
   if(DebugMode){
      Print("ATR Case: ",ATRCase);
   }
   if(UseComments){
      Comment("ATR Case: ",ATRCase,"\n");
   }
   return ATRCase;
}

void getAveragePosition(){
   if(PositionsTotal() != 0){
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
      if(UseComments){
         ObjectCreate(0,"Average Price",OBJ_HLINE,0,0,averagePrice);
         ObjectSetInteger(0,"Average Price",OBJPROP_STYLE,STYLE_SOLID);
         ObjectSetInteger(0,"Average Price",OBJPROP_COLOR,clrYellow);
         ObjectSetInteger(0,"Average Price",OBJPROP_WIDTH,3);
      }
      else if(!UseComments && ObjectFind(0,"Average Price")){
         ObjectDelete(0,"Average Price");
      }
   }
   else if(ObjectFind(0,"Average Price")){
      ObjectDelete(0,"Average Price");
   }
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
