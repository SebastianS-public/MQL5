#include <Trade/Trade.mqh>
CTrade trade;

input group "Technical Settings"
input double MartingaleFactor = 2.0;
input bool PositionSizePer100kMode = false;
input double PositionSizePer100k = 1.0;
input double PositionSizeAbsolute = 0.01;
input int CCITriggerLevel = 100;
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
input int CCIPeriod = 14;
input int ATRPeriod = 200;
input int MaxStopLoss = 4500;

input group "Visuals"
input bool PrintOnChart = false;

int normalizeStep;
double averagePosition;
int CCIHandle, ATRHandle;
double baseLot;

void OnInit(){
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
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
   CCIHandle = iCCI(_Symbol,Timeframe,CCIPeriod,PRICE_TYPICAL);
   ATRHandle = iATR(_Symbol,Timeframe,ATRPeriod);
}

void OnTick(){
   bool newCandle = detectNewCandle();
   
   if(PositionsTotal() != 0){
      if(PrintOnChart){
         averagePosition = getAveragePosition();
      }
      if(AccountInfoDouble(ACCOUNT_EQUITY) < AccountInfoDouble(ACCOUNT_BALANCE) - MaxStopLoss){
         closePositions();
      }
   }
   else if(ObjectFind(0, "Average Price")){
      ObjectDelete(0, "Average Price");
   }
   
   if(newCandle){
      bool ATRCondition = getATRCondition();
      
      switch(getCCICase()){
         case 0:
            if(PrintOnChart){
               Print("CCI Case 0");
            }
            break;
         case 1:
            if(ATRCondition){
               if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                  Print("Case1 Close Positions/Sell");
                  closePositions();
               }else{
                  Print("Case1 Sell");
               }
               executeSell();
            }
            else if(!ATRCondition && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE) && PositionsTotal() != 0 
                    && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               closePositions();
            }
            break;
         case 2:
            if(ATRCondition){
               if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  Print("Case2 Close Positions/Buy");
                  closePositions();
               }else{
                  Print("Case2 Buy");
               }
               executeBuy();
            }
            else if(!ATRCondition && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE) && PositionsTotal() != 0 
                    && PositionSelectByTicket(PositionGetTicket(0)) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               closePositions();
            }
            break;
         case 3:
            if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0))){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1)){
                  Print("Case3 Close Buys");
               }
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1)){
                  Print("Case3 Close Sells");
               }
               closePositions();
            }
            break;
         case 4:
            if(PositionsTotal() != 0 && PositionSelectByTicket(PositionGetTicket(0))){
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1)){
                  Print("Case4 Close Buys");
               }
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1)){
                  Print("Case4 Close Sells");
               }
               closePositions();
            }
            break;
      }
   }
}

double OnTester(){
   double metric = 0.0;
   metric = TesterStatistics(STAT_SHARPE_RATIO) * (TesterStatistics(STAT_PROFIT) / (TesterStatistics(STAT_EQUITY_DD) / 4500)) / 100000;
   return metric;
}

double calcLots(){
   double maxLots = 0;
   for(int i = 0; i < PositionsTotal(); i++){
      if(PositionSelectByTicket(PositionGetTicket(i))){
         if(PositionGetDouble(POSITION_VOLUME) > maxLots){
            maxLots = PositionGetDouble(POSITION_VOLUME);
         }
      }
   }
   return NormalizeDouble(NormalizeDouble(maxLots, normalizeStep) * MartingaleFactor, 2);
}

void executeBuy(){
   double lots = calcLots();
   if(lots < baseLot){
      lots = baseLot;
   }
   trade.Buy(lots,_Symbol,0,0,0,NULL);
}

void executeSell(){
   double lots = calcLots();
   if(lots < baseLot){
      lots = baseLot;
   }
   trade.Sell(lots,_Symbol,0,0,0,NULL);
}

bool getATRCondition(){
   double atrArray[];
   ArraySetAsSeries(atrArray,true);
   CopyBuffer(ATRHandle,0,0,2,atrArray);
   if(MathAbs(iOpen(_Symbol,Timeframe,1) - iClose(_Symbol,Timeframe,1)) > atrArray[1]){
      return true;
   }
   return false;
}

int getCCICase(){
   double CCIArray[];
   ArraySetAsSeries(CCIArray,true);
   CopyBuffer(CCIHandle,0,0,3,CCIArray);
   if(iClose(_Symbol,Timeframe,1) > iOpen(_Symbol,Timeframe,1) && CCIArray[1] > CCITriggerLevel && CCIArray[1] > CCIArray[2]){
      return 1;
   }
   else if(iClose(_Symbol,Timeframe,1) < iOpen(_Symbol,Timeframe,1) && CCIArray[1] < -CCITriggerLevel && CCIArray[1] < CCIArray[2]){
      return 2;
   }
   else if(CCIArray[1] > -CCITriggerLevel && CCIArray[1] > CCIArray[2] && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
      return 3;
   }
   else if(CCIArray[1] < CCITriggerLevel && CCIArray[1] < CCIArray[2] && AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE)){
      return 4;
   }
   else return 0;
}

void closePositions(){
   while(PositionsTotal() != 0){
      ulong ticket = PositionGetTicket(0);
      if(PositionSelectByTicket(ticket)){
         trade.PositionClose(ticket);
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
         else if(volume < minVolume){
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

bool detectNewCandle(){
   MqlRates priceData[1];
   CopyRates(_Symbol,Timeframe,0,1,priceData);
   datetime currentCandle;
   static datetime lastCandle;
   currentCandle = priceData[0].time;
   if(currentCandle != lastCandle){
      lastCandle = currentCandle;
      return true;
   }else{
      return false;
   }
}