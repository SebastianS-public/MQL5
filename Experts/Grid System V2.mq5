#include <Trade/Trade.mqh>
CTrade trade;

input double Volume = 0.1;
input int RsiLength = 15;
input ENUM_TIMEFRAMES RsiPeriod;
input int RsiTopTrigger = 70;
int RsiBottomTrigger = 100 - RsiTopTrigger;
input int StochasticTopTrigger = 80;
int StochasticBottomTrigger = 100 - StochasticTopTrigger;
input int StochasticKLength = 14;
input ENUM_TIMEFRAMES Timeframe;

input group "lotsize double times"
input double start = 2;
input double power = 1.2;

double averagePrice = 100000;
double additionPrice;
int averagePriceCount = 0;
ulong buyPos, sellPos;
double maValue;
int positionSizeCount = 1;
int count = 0;
int mArr[20];

void OnInit(){
   double base = start;
   for(int i = 0;i < 20;i++){
      mArr[i] = (int)NormalizeDouble(base * power,0);
      base = base * power;
   }
}

void OnTick(){
   bool newCandle = detectNewCandle();
   if(newCandle){
      checkTrades();
      int rsiFilter = checkRsiFilter();
      int stochasticFilter = checkStochasticFilter();
      if(rsiFilter == 1 && stochasticFilter == 1 && iOpen(_Symbol,Timeframe,1) < iClose(_Symbol,Timeframe,1)){
         count++;
         if(count==mArr[0]||count==mArr[1]||count==mArr[2]||count==mArr[3]||count==mArr[4]||count==mArr[5]||count==mArr[6]||
            count==mArr[7]||count==mArr[8]||count==mArr[9]||count==mArr[10]||count==mArr[11]||count==mArr[12]||count==mArr[13]||
            count==mArr[14]||count==mArr[15]||count==mArr[16]||count==mArr[17]||count==mArr[18]||count==mArr[19]){
            positionSizeCount = positionSizeCount * 2;
         }
         double lots = getLots();
         trade.Sell(lots,_Symbol,0,0,0);
         if(PositionSelectByTicket(PositionGetTicket(PositionsTotal() - 1))){
            calculateAveragePrice(PositionGetDouble(POSITION_PRICE_OPEN) * positionSizeCount);
         }
      }
      if(rsiFilter == 2 && stochasticFilter == 2 && iOpen(_Symbol,Timeframe,1) > iClose(_Symbol,Timeframe,1)){
         count++;
         if(count==mArr[0]||count==mArr[1]||count==mArr[2]||count==mArr[3]||count==mArr[4]||count==mArr[5]||count==mArr[6]||
            count==mArr[7]||count==mArr[8]||count==mArr[9]||count==mArr[10]||count==mArr[11]||count==mArr[12]||count==mArr[13]||
            count==mArr[14]||count==mArr[15]||count==mArr[16]||count==mArr[17]||count==mArr[18]||count==mArr[19]){
            positionSizeCount = positionSizeCount * 2;
         }
         double lots = getLots();
         trade.Buy(lots,_Symbol,0,0,0);
         if(PositionSelectByTicket(PositionGetTicket(PositionsTotal() - 1))){
            calculateAveragePrice(PositionGetDouble(POSITION_PRICE_OPEN) * positionSizeCount);
         }
      }
   }
}

void calculateAveragePrice(double entryPrice){
   averagePriceCount = averagePriceCount + positionSizeCount;
   additionPrice = additionPrice + entryPrice;
   averagePrice = additionPrice / averagePriceCount;
   Print(additionPrice," ",entryPrice," ",averagePrice," ",averagePriceCount);
}

double getLots(){
   double lots = Volume * positionSizeCount;
   int normalizeStep = 0;
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if (SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
   }
   NormalizeDouble(lots,normalizeStep);
   if(lots > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)){
      lots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   }
   return lots;
}

int checkStochasticFilter(){
   int stochasticHandle = iStochastic(_Symbol,Timeframe,StochasticKLength,3,3,MODE_SMA,STO_LOWHIGH);
   double stochasticValue[2];
   CopyBuffer(stochasticHandle,0,0,2,stochasticValue);
   if(stochasticValue[0] >= StochasticTopTrigger){
      return 1;
   }
   else if(stochasticValue[0] <= StochasticBottomTrigger){
      return 2;
   }
   else return 0;
}

int checkRsiFilter(){
   int rsiHandle = iRSI(_Symbol,Timeframe,RsiLength,PRICE_CLOSE);
   double rsiValue[2];
   CopyBuffer(rsiHandle,0,0,2,rsiValue);
   if(rsiValue[0] >= RsiTopTrigger){
      return 1;
   }
   else if(rsiValue[0] <= RsiBottomTrigger){
      return 2;
   }
   else return 0;
}

void checkTrades(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour != 0){ 
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(PositionsTotal() != 0){
         ulong i = PositionGetTicket(PositionsTotal() - 1);
         if(PositionSelectByTicket(PositionGetTicket(PositionsTotal() - 1))){
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && bid > averagePrice){
               additionPrice = 0;
               averagePriceCount = 0;
               count = 0;
               averagePrice = 100000;
               positionSizeCount = 1;
               while(PositionsTotal() != 0){
                  trade.PositionClose(i);
                  i--;
               }
            }
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && ask < averagePrice){
               additionPrice = 0;
               averagePriceCount = 0;
               count = 0;
               averagePrice = 100000;
               positionSizeCount = 1;
               while(PositionsTotal() != 0){
                  trade.PositionClose(i);
                  i--;
               }
            }
         }
      }
   }
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