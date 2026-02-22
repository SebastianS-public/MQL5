#include <Trade/Trade.mqh>
CTrade trade;

input group "Time Settings"
input string SetRangeTime = "08:00:00";
input string CloseTradesTime = "20:00:00";

input group "Distance Settings"
input int EntryDistance = 100;
input int TakeProfit = 100;
input int StopLoss = 100;

input group "Additional Settings"
input bool FixedLots = false;
input double Lots = 1.00;
input double RiskPercentage = 1.0;

bool timeStart;
bool timeEnd;
ulong buyPos,sellPos;
ushort stringChar;
string SetRangeTimeResult[];
string CloseTradesTimeResult[];
bool positionAlready;

void OnInit(){
   stringChar = StringGetCharacter(":",0);
   StringSplit(SetRangeTime,stringChar,SetRangeTimeResult);
   StringSplit(CloseTradesTime,stringChar,CloseTradesTimeResult);
}

void OnTick(){
   bool isTime = timeCheck();
   if(!isTime && positionAlready){
      positionAlready = false;
   }
   if(!isTime && OrdersTotal() != 0){
      if(OrderSelect(buyPos)){
         trade.OrderDelete(buyPos);
      }
      if(OrderSelect(sellPos)){
         trade.OrderDelete(sellPos);
      }
   }
   if(!isTime && PositionsTotal() != 0){
      if(PositionSelectByTicket(buyPos)){
         trade.PositionClose(buyPos);
      }
      if(PositionSelectByTicket(sellPos)){
         trade.PositionClose(sellPos);
      }
   }
   
   if(isTime && OrdersTotal() == 0 && !positionAlready){
      executeBuyOrder();
      executeSellOrder();
      positionAlready = true;
   }
}

void executeBuyOrder(){
   double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID) + EntryDistance * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double sl = entry - StopLoss * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tp = entry + TakeProfit * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(FixedLots){
      trade.BuyStop(Lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC);
      buyPos = trade.ResultOrder();
   }
   if(!FixedLots){
      trade.BuyStop(calcLots(),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
      buyPos = trade.ResultOrder();
   }
}

void executeSellOrder(){
   double entry = SymbolInfoDouble(_Symbol,SYMBOL_BID) - EntryDistance * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double sl = entry + StopLoss * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tp = entry - TakeProfit * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(FixedLots){
      trade.SellStop(Lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC);
      sellPos = trade.ResultOrder();
   }
   if(!FixedLots){
      trade.SellStop(calcLots(),entry,_Symbol,sl,tp,ORDER_TIME_GTC);
      sellPos = trade.ResultOrder();
   }
}

bool timeCheck(){
   MqlDateTime structTime;
   TimeCurrent(structTime);
   string stringHour;
   string stringMinute;
   string stringSecond;
   if(structTime.hour < 10){
      stringHour = "0" + IntegerToString(structTime.hour);
   }
   if(structTime.hour >= 10){
      stringHour = IntegerToString(structTime.hour);
   }
   if(structTime.min < 10){
      stringMinute = "0" + IntegerToString(structTime.min);
   }
   if(structTime.min >= 10){
      stringMinute = IntegerToString(structTime.min);
   }
   if(structTime.sec < 10){
      stringSecond = "0" + IntegerToString(structTime.sec);
   }
   if(structTime.sec >= 10){
      stringSecond = IntegerToString(structTime.sec);
   }
   
   if(!timeStart && ((stringHour > SetRangeTimeResult[0] && stringHour < CloseTradesTimeResult[0]) ||
     (stringHour >= SetRangeTimeResult[0] && stringMinute > SetRangeTimeResult[1] && stringHour < CloseTradesTimeResult[0]) ||
     (stringHour >= SetRangeTimeResult[0] && stringMinute >= SetRangeTimeResult[1] && stringSecond >= SetRangeTimeResult[2] && stringHour < CloseTradesTimeResult[0]))){
         timeStart = true;
         timeEnd = false;
   }
   if(timeStart && ((stringHour > CloseTradesTimeResult[0]) ||
     (stringHour >= CloseTradesTimeResult[0] && stringMinute > CloseTradesTimeResult[1]) || 
     (stringHour >= CloseTradesTimeResult[0] && stringMinute >= CloseTradesTimeResult [1]) ||
     (stringHour >= CloseTradesTimeResult[0] && stringMinute >=  CloseTradesTimeResult[1] && stringSecond >= CloseTradesTimeResult[2]) ||
     (stringHour < SetRangeTimeResult[0]))){
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
   double stopLossTicks = StopLoss * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercentage/100;
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