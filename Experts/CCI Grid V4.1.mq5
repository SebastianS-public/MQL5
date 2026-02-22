#include <Trade/Trade.mqh>
CTrade trade;

input group "General Settings"
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
input bool PositionSizePer100kMode = false;
input double PositionSizePer100k = 1.0;
input double PositionSizeAbsolute = 0.01;
input double MartingaleFactor = 1.0;
input bool UseGridDistance = true;
input int GridDistance = 200;
input bool UseComments = false;

input group "Indicator Settings"
input int CCITriggerLevelStart = 100;
input int CCIPeriod = 14;
input ENUM_APPLIED_PRICE CCIAppliedPrice = PRICE_TYPICAL;
input int ATRPeriod = 200;
input int ATRPeriodShort = 10;
input double ATRTrendModeMulti = 2.0;

int normalizeStep;
double averagePosition;
double CCITriggerLevel;
double atrValueShort,atrValueLong;
double atrValue;
double atrCoefficient;
double lotSizeMulti;


void OnInit(){
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
   }
   CCITriggerLevel = CCITriggerLevelStart;
}


void OnTick(){
   bool newCandle = detectNewCandle();
   if(PositionsTotal() != 0){
      averagePosition = getAveragePosition();
      if(AccountInfoDouble(ACCOUNT_EQUITY) < AccountInfoDouble(ACCOUNT_BALANCE) - 4500){
         closePositions();
         averagePosition = 0;
         ObjectDelete(0,"Average Price");
      }
   }
   if(newCandle){
      atrValue = calcATRValue();
      bool atrCondition = getATRCondition();
      if(atrValue < 0){
         CCITriggerLevel = CCITriggerLevelStart * (1 / lotSizeMulti);
      }
      if(atrValue > 0){
         CCITriggerLevel = CCITriggerLevelStart * (1 / lotSizeMulti);
      }
      int CCICase = getCCICase();
      if(CCICase == 1 && atrCondition){
         if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            Print("Case1 Close Positions/Sell");
            while(PositionsTotal() != 0){
               closePositions();
               averagePosition = 0;
               ObjectDelete(0,"Average Price");
            }
            executeSell();
         }
         else{
            Print("Case1 Sell");
            executeSell();
         }
      }
      else if(CCICase == 2 && atrCondition){
         if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
            Print("Case2 Close Positions/Buy");
            while(PositionsTotal() != 0){
               closePositions();
               averagePosition = 0;
               ObjectDelete(0,"Average Price");
            }
            executeBuy();
         }
         else{
            Print("Case2 Buy");
            executeBuy();
         }
      }
      else if(PositionsTotal() != 0){
         if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && 
            iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            Print("Case3 Close Buys");
            closePositions();
            averagePosition = 0;
            ObjectDelete(0,"Average Price");
         }
         if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && 
            iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1) && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
            Print("Case3 Close Sells");
            closePositions();
            averagePosition = 0;
            ObjectDelete(0,"Average Price");
         }
         if(UseGridDistance){
            if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&
               (SymbolInfoDouble(_Symbol,SYMBOL_BID) - averagePosition) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) > GridDistance){
               Print("Case3 Sell");
               executeSell();
            }
            if(PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY &&
               (averagePosition - SymbolInfoDouble(_Symbol,SYMBOL_ASK)) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) > GridDistance){
               Print("Case4 Buy");
               executeBuy();
            }
         }
      }
      if(UseComments){
         Comment("\n\natrValue: ",(atrValue / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)),"\nCCITriggerLevel: ",CCITriggerLevel,
                 "\ncandlesize: ",MathAbs(iOpen(_Symbol,Timeframe,1) - iClose(_Symbol,Timeframe,1)) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),
                 "\natrcondition: ", atrCondition,
                 "\nlotsizemulti: ",lotSizeMulti,"\nconditioncoefficient: ",(1 / lotSizeMulti),"\natrvaluelong: ",atrValueLong,"\nposnumtotal: ",posNumTotal);
      }
   }
}

bool getATRCondition(){
   double conditionCoefficient = 1 / lotSizeMulti;
   if(MathAbs(iOpen(_Symbol,Timeframe,1) - iClose(_Symbol,Timeframe,1)) > conditionCoefficient * atrValueLong){
      return true;
   }
   return false;
}

double calcATRValue(){
   int atrHandleShort = iATR(_Symbol,Timeframe,ATRPeriodShort);
   int atrHandleLong = iATR(_Symbol,Timeframe,ATRPeriod);
   double atrArrayShort[];
   ArraySetAsSeries(atrArrayShort,true);
   CopyBuffer(atrHandleShort,0,0,2,atrArrayShort);
   double atrArrayLong[];
   ArraySetAsSeries(atrArrayShort,true);
   CopyBuffer(atrHandleLong,0,0,2,atrArrayLong);
   double keyATRValue = atrArrayShort[1] - atrArrayLong[1];
   atrCoefficient = atrArrayShort[1] / atrArrayLong[1];
   if(atrCoefficient > 0 && atrCoefficient <= 1){
      lotSizeMulti = -3 * atrCoefficient + 4;
   }
   else if(atrCoefficient > 1){
      lotSizeMulti = MathPow(2,1 / MathPow(atrCoefficient,2) - 1);
   }
   atrValueLong = atrArrayLong[1];
   atrValueShort = atrArrayShort[1];
   return keyATRValue;
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
   if(atrValue > 0){
      if(atrValueShort > ATRTrendModeMulti * atrValueLong && posNumTotal != 0){
         posNumTotal = posNumTotal - 1;
      }
   }
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
   double lots = NormalizeDouble((baseLot * MathPow(2, posNumTotal) * lotSizeMulti), normalizeStep);
   trade.Buy(lots,_Symbol,0,0,0,NULL);
   posNumTotal = posNumTotal + MartingaleFactor;
}

void executeSell(){
   double baseLot = 0;
   if(atrValue > 0){
      if(atrValueShort > ATRTrendModeMulti * atrValueLong && posNumTotal != 0){
         posNumTotal = posNumTotal - 1;
      }
   }
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
   double lots = NormalizeDouble((baseLot * MathPow(2, posNumTotal) * lotSizeMulti), normalizeStep);
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

