#include <Trade/Trade.mqh>
CTrade trade;

input int StartHour = 2;
input int StartMinute = 0;
input int EndHour = 6;
input int EndMinute = 0;
input int CloseTradesHour = 20;
input int CloseTradesMinute = 0;
input bool UseRiskManagement = true;
input double RiskInPercent = 1.0;
input double LotSize = 1.04;
input bool UseTakeProfit = true;
input double TPMultiplier = 1;
input double SLMultiplier = 1;
input bool PrintOnChart = true;

bool timeStart, timeEnd, timeClose;
double high = 0;
double low = 100000;
ulong buyPos, sellPos;
bool positionAlready;
double stopLossPoints;

void OnTick(){
   bool isTime = timeCheck();
   bool newCandle = detectNewCandle();
   bool isCloseTime = timeCloseCheck();
   if(isCloseTime){
      if(high != 0 && low != 100000){
         high = 0;
         low = 100000;
      }
      if(PositionSelectByTicket(buyPos)){
         trade.PositionClose(buyPos);
      }
      if(PositionSelectByTicket(sellPos)){
         trade.PositionClose(sellPos);
      }
      if(OrderSelect(buyPos)){
         trade.OrderDelete(buyPos);
      }
      if(OrderSelect(sellPos)){
         trade.OrderDelete(sellPos);
      }
   }
   if(newCandle && isTime){
      positionAlready = false;
      timeClose = false;
      if(iHigh(_Symbol,PERIOD_CURRENT,1) > high){
         high = iHigh(_Symbol,PERIOD_CURRENT,1);
      }
      if(iLow(_Symbol,PERIOD_CURRENT,1) < low){
         low = iLow(_Symbol,PERIOD_CURRENT,1);
      }
   }
   if(!isTime && !isCloseTime && high != 0 && low != 100000 && !positionAlready){
      executeBuy();
      executeSell();
      positionAlready = true;
   }
   if(newCandle){
      Print(stopLossPoints," ",high," ",low);
   }
}

void executeBuy(){
   double lots;
   double takeProfit;
   double stopLoss = high - SLMultiplier * (high - low);
   stopLossPoints = (high - stopLoss) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(UseRiskManagement){
      lots = calcLots();
   }
   else{
      lots = LotSize;
   }
   if(UseTakeProfit){
      takeProfit = high + TPMultiplier * (high - low);
   }
   else{
      takeProfit = 0;
   }
   trade.BuyStop(lots,high,_Symbol,stopLoss,takeProfit,ORDER_TIME_GTC);
   buyPos = trade.ResultOrder();
}

void executeSell(){
   double lots;
   double takeProfit;
   double stopLoss = low + SLMultiplier * (high - low);
   stopLossPoints = (stopLoss - low) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(UseRiskManagement){
      lots = calcLots();
   }
   else{
      lots = LotSize;
   }
   if(UseTakeProfit){
      takeProfit = low - TPMultiplier * (high - low);
   }
   else{
      takeProfit = 0;
   }
   trade.SellStop(lots,low,_Symbol,stopLoss,takeProfit,ORDER_TIME_GTC);
   sellPos = trade.ResultOrder();
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

bool timeCloseCheck(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour == CloseTradesHour && structTime.min >= CloseTradesMinute){
      timeClose = true;
   }
   if(timeClose){
      return true;
   }
   return false;
}

double calcLots(){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent/100;
   double moneyPerLotstep = stopLossPoints * tickvalue * lotstep;
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