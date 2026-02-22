#include <Trade/Trade.mqh>
CTrade trade;

input string ResetTime = "16:30";
input string MarketClose = "23:50";
input int PipDigit = 3;
input double RiskInPercent = 1.0;
input int slAdd = 50;
input int EntryConfirmationPeriod = 5;
input int LookbackPeriod = 25;
input bool TrailingStop = false;
input int TrailingStopLookback = 5;

bool timeStart;
bool timeEnd;
ulong buyPos, sellPos;
ulong sellStopPos, buyStopPos;
bool newHighLow;
bool positionAlready;
double slDistance;
double stopLoss;
double oldStopLoss = 0;
double newStopLoss = 0;

void OnTick(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.day_of_week != 6){
      bool newCandle = detectNewCandle();
      bool onTime = timeCheck();
      if(!onTime && OrdersTotal() > 0){
         if(OrderSelect(sellStopPos)){
            trade.OrderDelete(sellStopPos);
         }
         if(OrderSelect(buyStopPos)){
            trade.OrderDelete(buyStopPos);
         }
      }
      if(!onTime && PositionsTotal() > 0){
         if(PositionSelectByTicket(buyPos)){
            trade.PositionClose(buyPos);
         }
         if(PositionSelectByTicket(sellPos)){
            trade.PositionClose(sellPos);
         }
         if(PositionSelectByTicket(sellStopPos)){
            trade.PositionClose(sellStopPos);
         }
         if(PositionSelectByTicket(buyStopPos)){
            trade.PositionClose(buyStopPos);
         }
      }
      if((!onTime && newHighLow == true) || (!onTime && positionAlready == true)){
         newHighLow = false;
         positionAlready = false;
         oldStopLoss = 0;
         newStopLoss = 0;
      }
      if(onTime && PositionsTotal() == 0 && !positionAlready){
         if(newCandle){
            int highestCandle = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,LookbackPeriod,0);
            int lowestCandle = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,LookbackPeriod,0);
            if(highestCandle == 1 || lowestCandle == 1){
               newHighLow = true;
            }
            if(newHighLow == true && highestCandle == EntryConfirmationPeriod && lowestCandle > EntryConfirmationPeriod){
               executeSell();
            }
            if(newHighLow == true && lowestCandle == EntryConfirmationPeriod && highestCandle > EntryConfirmationPeriod){
               executeBuy();
            }
         }
      }
      if(TrailingStop && onTime && PositionsTotal() > 0 && newCandle){
         executeTrailingStop();
      }
   }
}

void executeTrailingStop(){
   if(PositionSelectByTicket(buyPos)){
      double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double slTriggerValue = stopLoss + slDistance + slDistance * 0.5;
      double close1 = iClose(_Symbol,PERIOD_CURRENT,1);
      double close2 = iClose(_Symbol,PERIOD_CURRENT,2);
      if(bid > slTriggerValue && close1 > close2){
         newStopLoss = iLow(_Symbol,PERIOD_CURRENT,iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,TrailingStopLookback,0));
         if(newStopLoss > oldStopLoss && newStopLoss < bid){
            trade.PositionModify(buyPos,newStopLoss,0);
         }
         oldStopLoss = newStopLoss;
      }
   }
   if(PositionSelectByTicket(sellPos)){
      double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double slTriggerValue = stopLoss + slDistance + slDistance * 0.5;
      double close1 = iClose(_Symbol,PERIOD_CURRENT,1);
      double close2 = iClose(_Symbol,PERIOD_CURRENT,2);
      if(ask < slTriggerValue && close1 < close2){
         newStopLoss = iHigh(_Symbol,PERIOD_CURRENT,iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,TrailingStopLookback,0));
         if(newStopLoss < oldStopLoss && newStopLoss > ask){
            trade.PositionModify(sellPos,newStopLoss,0);
         }
         oldStopLoss = newStopLoss;
      }
   }
}

void executeBuy(){
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double stopLossTicks = slAdd * pipSize;
   stopLoss = iLow(_Symbol,PERIOD_CURRENT,iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,LookbackPeriod,0)) - stopLossTicks;
   slDistance = SymbolInfoDouble(_Symbol,SYMBOL_ASK) - stopLoss;
   double tp = stopLoss + slDistance + slDistance * 2;
   double lots = calcLots();
   trade.Buy(lots,_Symbol,0,stopLoss,tp);
   buyPos = trade.ResultOrder();
   double sellStopSl = stopLoss + slDistance * 0.5;
   double sellStopTp = stopLoss - slDistance;
   //trade.SellStop(lots*2,stopLoss,_Symbol,sellStopSl,sellStopTp,ORDER_TIME_GTC);
   sellStopPos = trade.ResultOrder();
   positionAlready = true;
}

void executeSell(){
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double stopLossTicks = slAdd * pipSize;
   stopLoss = iHigh(_Symbol,PERIOD_CURRENT,iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,LookbackPeriod,0)) + stopLossTicks;
   slDistance = stopLoss - SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double tp = stopLoss - slDistance - slDistance * 2;
   double lots = calcLots();
   trade.Sell(lots,_Symbol,0,stopLoss,tp);
   sellPos = trade.ResultOrder();
   double buyStopSl = stopLoss - slDistance * 0.5;
   double buyStopTp = stopLoss + slDistance;
   //trade.BuyStop(lots*2,stopLoss,_Symbol,buyStopSl,buyStopTp,ORDER_TIME_GTC);
   sellStopPos = trade.ResultOrder();
   positionAlready = true;
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

bool timeCheck(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   string stringHour;
   if(structTime.hour < 10){
      stringHour = "0" + IntegerToString(structTime.hour);
   }
   if(structTime.hour >= 10){
      stringHour = IntegerToString(structTime.hour);
   }
   
   string stringMinute;
   if(structTime.min < 10){
      stringMinute = "0" + IntegerToString(structTime.min);
   }
   if(structTime.min >= 10){
      stringMinute = IntegerToString(structTime.min);
   }
   string timeString = stringHour+":"+stringMinute;
   if(timeString == ResetTime){
      timeStart = true;
      timeEnd = false;
   }
   if(timeString == MarketClose){
      timeEnd = true;
      timeStart = false;
   }
   if(timeStart && !timeEnd){
      return true;
   }
   return false;
}

double calcLots(){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double customPipSize = pow(10,(PipDigit-1));
   double pipSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * customPipSize;
   double stopLossTicks = slDistance;
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
   return tradeLots;
}