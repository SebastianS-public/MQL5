#include <Trade/Trade.mqh>
CTrade trade;

input int PipDistance = 5;
input int PipDigit = 2;

ulong buyPos, sellPos;

void OnTick(){
   bool newCandle = detectNewCandle();
   if(newCandle){
      double entry = getEntry();
      double close = NormalizeDouble(iClose(_Symbol,PERIOD_CURRENT,1),_Digits);
      if(OrderSelect(buyPos)){
         trade.OrderDelete(buyPos);
      }
      if(OrderSelect(sellPos)){
         trade.OrderDelete(sellPos);
      }
      if(OrdersTotal() == 0 && entry != 0){
         if(!PositionSelectByTicket(buyPos)){
            if(entry > close){
               executeBuy();
            }
         }
         if(!PositionSelectByTicket(sellPos)){
            if(entry < close){
               executeSell();
            }
         }
      }
      if(PositionsTotal() > 0){
         executeTrailingStop();
      }
   }
}

void executeTrailingStop(){
   Print("TRAILING STOP IS WORKING");
   CPositionInfo pos;      
   double close = NormalizeDouble(iClose(_Symbol,PERIOD_CURRENT,1),_Digits);
   double entry = getEntry();
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;

   double slBuy = entry - PipDistance * pipSize;
   double slSell = entry + PipDistance * pipSize;
   if(PositionSelectByTicket(buyPos)){
      if(close > entry){
         trade.PositionModify(buyPos,slBuy,0);
      }
   }
   if(PositionSelectByTicket(sellPos)){
      if(close < entry){
         trade.PositionModify(sellPos,slSell,0);
         Print("TRAILING STOP IS WORKING");
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

double getEntry(){
   int movingAverageHandle = iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_EMA,PRICE_CLOSE);
   double movingAverageArray[];
   CopyBuffer(movingAverageHandle,0,0,1,movingAverageArray);
   double movingAverage = NormalizeDouble(movingAverageArray[0],_Digits);
   Print(movingAverage);
   return movingAverage;
}

void executeBuy(){
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double entry = getEntry() + PipDistance * pipSize;
   double sl = NormalizeDouble(iLow(_Symbol,PERIOD_CURRENT,1),_Digits);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);


   if(entry - 1 * pipSize > ask){
      trade.BuyStop(1,entry,_Symbol,sl,0,ORDER_TIME_GTC);
   }
   if(entry - 1 * pipSize <= ask){
      trade.Buy(1,_Symbol,0,sl,0);
   }
   buyPos = trade.ResultOrder();
}

void executeSell(){
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double entry = getEntry() + PipDistance * pipSize;
   double sl = NormalizeDouble(iHigh(_Symbol,PERIOD_CURRENT,1),_Digits);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);


   if(entry + 1 * pipSize < bid){
      trade.SellStop(1,entry,_Symbol,sl,0,ORDER_TIME_GTC);
   }
   if(entry + 1 * pipSize >= bid){
      trade.Sell(1,_Symbol,0,sl,0);
   }
   sellPos = trade.ResultOrder();
}

/*double calcLots(double riskPercent){
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
}*/