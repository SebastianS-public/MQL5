#include <Trade/Trade.mqh>
CTrade trade;

input double Volume = 0.1;
input int RsiLength = 15;
input ENUM_TIMEFRAMES RsiPeriod;
input int RsiTrigger = 70;
input int MaPeriod = 15;
input int LookbackPeriod = 50;

double averagePrice = 100000;
double additionPrice;
int averagePriceCount = 0;
ulong buyPos, sellPos;
double maValue;
int count = 1;

void OnTick(){
   bool newCandle = detectNewCandle();
   if(newCandle){
      bool rsiLongFilter = checkRsiLongFilter();
      bool rsiShortFilter = checkRsiShortFilter();
      bool buyCondition = false;
      bool sellCondition = false;
      double open = iOpen(_Symbol,PERIOD_CURRENT,1);
      double close = iClose(_Symbol,PERIOD_CURRENT,1);
      int MaHandle = iMA(_Symbol,PERIOD_CURRENT,MaPeriod,0,MODE_EMA,PRICE_CLOSE);
      double maValueArray[2];
      CopyBuffer(MaHandle,0,0,2,maValueArray);
      maValue = maValueArray[0];
      if(rsiLongFilter && close < maValue){
         buyCondition = true;
      }
      if(rsiShortFilter && close > maValue){
         sellCondition = true;
      }
      if(PositionSelectByTicket(sellPos) && close <= averagePrice){
         additionPrice = 0;
         averagePriceCount = 0;
         count = 1;
         averagePrice = 100000;
         ulong i = sellPos;
         while(PositionsTotal() != 0){
            trade.PositionClose(i);
            i--;
         }
      }
      if(PositionSelectByTicket(buyPos) && close >= averagePrice){
         additionPrice = 0;
         averagePriceCount = 0;
         count = 1;
         averagePrice = 100000;
         ulong i = buyPos;
         while(PositionsTotal() != 0){
            trade.PositionClose(i);
            i--;
         }
      }
      if(buyCondition && open > close && rsiLongFilter){
         if(averagePrice == 100000){
            averagePrice = close;
         }
         if(close <= averagePrice){
            double lots = Volume * count;
            if(lots < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)){
               lots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
            }
            if(lots > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)){
               lots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
               count = count / 2;
            }
            trade.Buy(lots,_Symbol,0,0,0,NULL);
            buyPos = trade.ResultOrder();
            if(PositionSelectByTicket(buyPos)){
               calculateAveragePrice(PositionGetDouble(POSITION_PRICE_OPEN));
               count = count * 2;
            }
         }
      }
      if(sellCondition && open < close && rsiShortFilter){
         if(averagePrice == 100000){
            averagePrice = close;
         }
         if(close >= averagePrice){
            double lots = Volume * count;
            if(lots < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)){
               lots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
            }
            if(lots > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)){
               lots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
               count = count / 2;
            }
            trade.Sell(lots,_Symbol,0,0,0,NULL);
            sellPos = trade.ResultOrder();
            if(PositionSelectByTicket(sellPos)){
               calculateAveragePrice(PositionGetDouble(POSITION_PRICE_OPEN));
               count = count * 2;
            }
         }
      }
      Print(averagePrice);
   }
}

void calculateAveragePrice(double entryPrice){
   averagePriceCount = averagePriceCount + count;
   additionPrice += entryPrice * count;
   Print(additionPrice," ",entryPrice);
   averagePrice = additionPrice / averagePriceCount;
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

bool checkRsiShortFilter(){
   int rsiHandle = iRSI(_Symbol,PERIOD_CURRENT,RsiLength,PRICE_CLOSE);
   double rsiValue[2];
   CopyBuffer(rsiHandle,0,0,2,rsiValue);
   if(rsiValue[0] > RsiTrigger){
      return true;
   }
   else return false;
}

bool checkRsiLongFilter(){
   int rsiHandle = iRSI(_Symbol,PERIOD_CURRENT,RsiLength,PRICE_CLOSE);
   double rsiValue[2];
   CopyBuffer(rsiHandle,0,0,2,rsiValue);
   if(rsiValue[0] < RsiTrigger){
      return true;
   }
   else return false;
}