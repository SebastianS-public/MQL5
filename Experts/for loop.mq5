#include <Trade/Trade.mqh>
CTrade trade;

input bool PercentageRisk = true;
input double RiskInPercent = 1.0;
input double FixedLots = 10;
input int PipDistance = 1;
input int PipDigit = 3;
input int TargetPips = 15;
input int StopPips = 15;
input int openTimeHour = 16;
input int closeTimeHour = 23;

int bullishCandle = 0;
int bearishCandle = 0;

ulong buyPos, sellPos;

void OnTick(){
   bool newCandle = detectNewCandle();
   bool session = duringSession();
   double open = 0;
   double close = 0;
   if(newCandle && session){
      open = iOpen(_Symbol,PERIOD_CURRENT,1);
      close = iClose(_Symbol,PERIOD_CURRENT,1);
      
      if(open != 0 && close != 0){
         if(open < close){
            bearishCandle = 0;
            bullishCandle++;
         }
         if(open > close){
            bullishCandle = 0;
            bearishCandle++;
         }
      }
      if(bullishCandle == 3){
         executeBuy();
      }
      if(bearishCandle == 3){
         executeSell();
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

bool duringSession(){
   bool duringSession = false;
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour < closeTimeHour && structTime.hour >= openTimeHour){
      duringSession = true;
   }
   return duringSession;
}

void executeBuy(){
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * pow(10,(PipDigit-1));
   double high = NormalizeDouble(iHigh(_Symbol,PERIOD_CURRENT,1),_Digits);
   double ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double entry = high + (PipDistance * pipSize);
   entry = NormalizeDouble(entry,_Digits);
   double tp = entry + (TargetPips * pipSize);
   tp = NormalizeDouble(tp,_Digits);
   double sl = entry - (StopPips * pipSize);
   sl = NormalizeDouble(sl,_Digits);
   double lots = 0;
   
   if(PercentageRisk == true){
      lots = calcLots(RiskInPercent);
   }
   if(PercentageRisk == false){
      lots = FixedLots;
   }
   if(ask > high){
      trade.Buy(lots,_Symbol,ask,sl,tp);
   }
   if(ask < high){
      trade.BuyStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_DAY);
   }
   buyPos = trade.ResultOrder();
}

void executeSell(){
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * pow(10,(PipDigit-1));
   double low = NormalizeDouble(iLow(_Symbol,PERIOD_CURRENT,1),_Digits);
   double bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   double entry = low - (PipDistance * pipSize);
   entry = NormalizeDouble(entry,_Digits);
   double tp = entry - (TargetPips * pipSize);
   tp = NormalizeDouble(tp,_Digits);
   double sl = entry + (StopPips * pipSize);
   sl = NormalizeDouble(sl,_Digits);
   double lots = 0;
   
   if(PercentageRisk == true){
      lots = calcLots(RiskInPercent);
   }
   if(PercentageRisk == false){
      lots = FixedLots;
   }
   if(bid < low){
      trade.Buy(lots,_Symbol,bid,sl,tp);
   }
   if(bid > low){
      trade.SellStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_DAY);
   }
   sellPos = trade.ResultOrder();
}

double calcLots(double riskPercent){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double stopLossTicks = StopPips * pipSize;
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent/100;
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
   return tradeLots;
}