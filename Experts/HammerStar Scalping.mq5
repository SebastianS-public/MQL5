#include <Trade/Trade.mqh>
CTrade trade;

input int entryPipsStar = 4;
input int entryPipsHammer = 4;
input double RiskInPercent = 1.0;
input int StopLossPips = 5;
input int profitPips = 15;
input int PipDigit = 3;

ulong buyPos,sellPos;
double stopLossTicks;

void OnTick(){
   if(detectNewCandle()){
      double high = iHigh(_Symbol,PERIOD_CURRENT,1);
      double low = iLow(_Symbol,PERIOD_CURRENT,1);    
      double starFib = (high-low) * 0.5 + low;
      double hammerFib = (low - high) * 0.5 + high;
      bool star = false;
      bool hammer = false;
      
      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      CopyRates(_Symbol,PERIOD_CURRENT,0,Bars(_Symbol,PERIOD_CURRENT),rates);
      double close1 = rates[1].close;
      double open1 = rates[1].open;
      if(close1 < starFib && open1 < starFib){
         star = true;
      }
      if(close1 > hammerFib && open1 > hammerFib){
         hammer = true;
      }
      
      double customPipSize = pow(10,(PipDigit-1));
      double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;

      if(star){
         if(OrderSelect(sellPos)){
            trade.OrderDelete(sellPos);
         }
         double entryStar = low - entryPipsStar*pipSize;
         double slStar = entryStar + StopLossPips*pipSize;
         double tpStar = entryStar - profitPips*pipSize;
         trade.SellStop(calcLots(),entryStar,_Symbol,slStar,tpStar,ORDER_TIME_GTC);
         sellPos = trade.ResultOrder();
      }
      if(hammer){
         if(OrderSelect(buyPos)){
            trade.OrderDelete(buyPos);
         }
         double entryHammer = high + entryPipsHammer*pipSize;
         double slHammer = entryHammer - StopLossPips*pipSize;
         double tpHammer = entryHammer + profitPips*pipSize;
         trade.BuyStop(calcLots(),entryHammer,_Symbol,slHammer,tpHammer,ORDER_TIME_GTC);
         buyPos = trade.ResultOrder();
      }
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

double calcLots(){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   stopLossTicks = StopLossPips * pipSize;
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent/100;
   double moneyPerLotstep = (stopLossTicks / ticksize) * tickvalue * lotstep;
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