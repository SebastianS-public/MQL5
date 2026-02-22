#include <Trade/Trade.mqh>
CTrade trade;

input int MAshort = 20;
input int MAmid = 50;
input int MAlong = 100;
input double RiskInPercent = 1.0;
input ENUM_TIMEFRAMES timeframe;
input bool UseTimeCheck = false;
input int StartHour = 14;
input int StartMinute = 0;
input int EndHour = 20;
input int EndMinute = 0;

ulong buyPos, sellPos;
bool timeStart, timeEnd, timeClose;

void OnTick(){
   bool isTime = timeCheck();
   bool newCandle = detectNewCandle();
   if(newCandle){
      bool upFractal = getUpWilliamsFractal();
      bool downFractal = getDownWilliamsFractal();
      double maShortValue = getMAshort();
      double maMidValue = getMAmid();
      double maLongValue = getMAlong();
      if(upFractal && isTime && maLongValue > maMidValue && maMidValue > maShortValue && !PositionSelectByTicket(sellPos)){
         double high = iHigh(_Symbol,timeframe,3);
         if(high < maLongValue && (high > maShortValue || high > maMidValue)){
            double stopLossPoints = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
            double stopLoss = 0;
            if(high > maMidValue){
               stopLoss = maLongValue;
               stopLossPoints = (stopLoss - SymbolInfoDouble(_Symbol,SYMBOL_BID)) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
            }
            else if(high > maShortValue && high < maMidValue){
               stopLoss = maMidValue;
               stopLossPoints = (stopLoss - SymbolInfoDouble(_Symbol,SYMBOL_BID)) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
            }
            double lots = calcLots(stopLossPoints);
            double takeProfit = SymbolInfoDouble(_Symbol,SYMBOL_BID) - stopLossPoints * 2 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
            if(SymbolInfoDouble(_Symbol,SYMBOL_BID) < high){
               trade.Sell(lots,_Symbol,0,stopLoss,takeProfit,NULL);
               sellPos = trade.ResultOrder();
            }
         }
      }
      if(downFractal && isTime && maLongValue < maMidValue && maMidValue < maShortValue && !PositionSelectByTicket(buyPos)){
         double low = iLow(_Symbol,timeframe,3);
         if(low > maLongValue && (low < maShortValue || low < maMidValue)){
            double stopLossPoints = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
            double stopLoss = 0;
            if(low < maMidValue){
               stopLoss = maLongValue;
               stopLossPoints = (SymbolInfoDouble(_Symbol,SYMBOL_ASK) - stopLoss) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
            }
            else if(low < maShortValue && low > maMidValue){
               stopLoss = maMidValue;
               stopLossPoints = (SymbolInfoDouble(_Symbol,SYMBOL_ASK) - stopLoss) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
            }
            double lots = calcLots(stopLossPoints);
            double takeProfit = SymbolInfoDouble(_Symbol,SYMBOL_ASK) + stopLossPoints * 2 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
            if(SymbolInfoDouble(_Symbol,SYMBOL_ASK) > low){
               trade.Buy(lots,_Symbol,0,stopLoss,takeProfit,NULL);
               buyPos = trade.ResultOrder();
            }
         }
      }
   }
}

double getMAshort(){
   int maHandle = iMA(_Symbol,timeframe,MAshort,0,MODE_EMA,PRICE_CLOSE);
   double maValue[4];
   CopyBuffer(maHandle,0,0,4,maValue);
   return maValue[0];
}

double getMAmid(){
   int maHandle = iMA(_Symbol,timeframe,MAmid,0,MODE_EMA,PRICE_CLOSE);
   double maValue[4];
   CopyBuffer(maHandle,0,0,4,maValue);
   return maValue[0];
}

double getMAlong(){
   int maHandle = iMA(_Symbol,timeframe,MAlong,0,MODE_EMA,PRICE_CLOSE);
   double maValue[4];
   CopyBuffer(maHandle,0,0,4,maValue);
   return maValue[0];
}

bool getUpWilliamsFractal(){
      int highestBar = iHighest(_Symbol,timeframe,MODE_HIGH,5,1);
      if(highestBar == 3){
         datetime time = iTime(_Symbol,timeframe,3);
         ObjectCreate(0,"line",OBJ_VLINE,0,time,0);
         ObjectSetInteger(0,"line",OBJPROP_WIDTH,2);
         return true;
      }
      else return false;
}

bool getDownWilliamsFractal(){
      int lowestBar = iLowest(_Symbol,timeframe,MODE_LOW,5,1);
      if(lowestBar == 3){
         datetime time = iTime(_Symbol,timeframe,3);
         ObjectCreate(0,"line",OBJ_VLINE,0,time,0);
         ObjectSetInteger(0,"line",OBJPROP_WIDTH,2);
         return true;
      }
      else return false;
}

bool detectNewCandle(){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,timeframe,0,3,priceData);
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

double calcLots(double distancePoints){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent/100;
   double moneyPerLotstep = distancePoints * tickvalue * lotstep;
   if(moneyPerLotstep == 0){
      return 0;
   }
   
   int normalizeStep = 0;
   
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if (SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
   }
   
   double tradeLots = NormalizeDouble(riskMoney / moneyPerLotstep * lotstep, normalizeStep);
   if(tradeLots < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)){
      tradeLots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   }
   if(tradeLots > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)){
      tradeLots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   }
   return tradeLots;
}

bool timeCheck(){
   if(!UseTimeCheck){
      return true;
   }
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour == StartHour && structTime.min >= StartMinute){
      timeStart = true;
      timeEnd = false;
      if(timeClose){
         timeClose = false;
      }
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