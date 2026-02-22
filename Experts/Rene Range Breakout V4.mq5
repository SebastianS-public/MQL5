#include <Trade/Trade.mqh>
CTrade trade;

enum TrailingStopModeList{
   TrailingStopMode1,
   TrailingStopMode2,
   TrailingStopMode3
};

input group "Time Settings"
input int StartHour = 2;
input int StartMinute = 0;
input int EndHour = 6;
input int EndMinute = 0;
input int CloseTradesHour = 20;
input int CloseTradesMinute = 0;

input group "Lot Size Settings"
input bool UseRiskManagement = true;
input double RiskInPercent = 1.0;
input double LotSize = 1.04;

input group "Trade Settings"
input bool UseTakeProfit = true;
input double TPMultiplier = 1;
input double SLMultiplier = 1;
input bool UseSlToZero = false;
input double SlToZeroTriggerMultiplier = 1.0;
input bool UseRsiFilter = false;
input int RsiLength = 15;
input double RsiTrigger = 50;

input group "Trailing Stop Modes"
input bool UseTrailingStop = false;
input TrailingStopModeList TrailingStopMode = TrailingStopMode1;
input int TrailingStopMode1Value = 5;
input int TrailingStopMode2Value = 200;

input group "Additional Settings"
input string TradeComment = "Enter Comment";
input bool PrintOnChart = true;

bool timeStart, timeEnd, timeClose;
double high = 0;
double low = 100000;
ulong buyPos, sellPos;
double buyTakeProfit, sellTakeProfit;
bool positionAlready;
double stopLossPoints;
double buyStopLoss, sellStopLoss;
double buyTrailingStopPrice, sellTrailingStopPrice;

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
   if(isTime){
      positionAlready = false;
      timeClose = false;
      if(SymbolInfoDouble(_Symbol,SYMBOL_BID) > high){
         high = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      }
      if(SymbolInfoDouble(_Symbol,SYMBOL_BID) < low){
         low = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      }
   }
   if(!isTime && !isCloseTime && high != 0 && low != 100000 && !positionAlready){
      executeBuy();
      executeSell();
      positionAlready = true;
      buyTrailingStopPrice = buyStopLoss;
      sellTrailingStopPrice = sellStopLoss;
   }
   if((isTime || isCloseTime) && (PositionsTotal() != 0 || OrdersTotal()) != 0){
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
   bool slToZeroCondition = false;
   if(PositionsTotal() != 0){
      slToZeroCondition = checkSlToZeroCondition();
   }
   if(UseSlToZero && PositionsTotal() != 0 && slToZeroCondition){
      if(PositionSelectByTicket(buyPos)){
         if(PositionGetDouble(POSITION_SL) != PositionGetDouble(POSITION_PRICE_OPEN)){
            trade.PositionModify(buyPos,PositionGetDouble(POSITION_PRICE_OPEN),buyTakeProfit);
         }
      }
      if(PositionSelectByTicket(sellPos)){
         if(PositionGetDouble(POSITION_SL) != PositionGetDouble(POSITION_PRICE_OPEN)){
            trade.PositionModify(sellPos,PositionGetDouble(POSITION_PRICE_OPEN),sellTakeProfit);
         }
      }
   }
   if(UseTrailingStop && PositionsTotal() != 0){
      if(PositionSelectByTicket(buyPos)){
         executeBuyTrailingStop();
      }
      if(PositionSelectByTicket(sellPos)){
         executeSellTrailingStop();
      }
   }
}

void executeBuyTrailingStop(){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(TrailingStopMode == TrailingStopMode1){
      buyTrailingStopPrice = iLow(_Symbol,PERIOD_CURRENT,iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,TrailingStopMode1Value,0));
      if(PositionGetDouble(POSITION_SL) < buyTrailingStopPrice){
         trade.PositionModify(buyPos,buyTrailingStopPrice,buyTakeProfit);
      }
   }
   if(TrailingStopMode == TrailingStopMode2){
      buyTrailingStopPrice = bid - TrailingStopMode2Value * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(PositionGetDouble(POSITION_SL) < buyTrailingStopPrice){
         trade.PositionModify(buyPos,buyTrailingStopPrice,buyTakeProfit);
      }
   }
   if(TrailingStopMode == TrailingStopMode3){
   
   }
}

void executeSellTrailingStop(){
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(TrailingStopMode == TrailingStopMode1){
      sellTrailingStopPrice = iHigh(_Symbol,PERIOD_CURRENT,iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,TrailingStopMode1Value,0));
      if(PositionGetDouble(POSITION_SL) < sellTrailingStopPrice){
         trade.PositionModify(sellPos,sellTrailingStopPrice,sellTakeProfit);
      }
   }
   if(TrailingStopMode == TrailingStopMode2){
      sellTrailingStopPrice = ask + TrailingStopMode2Value * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(PositionGetDouble(POSITION_SL) < sellTrailingStopPrice){
         trade.PositionModify(sellPos,sellTrailingStopPrice,sellTakeProfit);
      }
   }
   if(TrailingStopMode == TrailingStopMode3){
   
   }
}

bool checkSlToZeroCondition(){
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(PositionSelectByTicket(buyPos) && bid > high + (SlToZeroTriggerMultiplier * (high-low))){
      return true;
   }
   else if(PositionSelectByTicket(sellPos) && ask < low - (SlToZeroTriggerMultiplier * (high - low))){
      return true;
   }
   else{
      return false;
   }
}

void executeBuy(){
   double lots;
   buyStopLoss = high - SLMultiplier * (high - low);
   stopLossPoints = (high - buyStopLoss) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(UseRiskManagement){
      lots = calcLots();
   }
   else{
      lots = LotSize;
   }
   if(UseTakeProfit){
      buyTakeProfit = high + TPMultiplier * (high - low);
   }
   else{
      buyTakeProfit = 0;
   }
   bool rsiLongCheck = true;
   if(UseRsiFilter){
      rsiLongCheck = checkRsiLongFilter();
   }
   if(rsiLongCheck){
      if(SymbolInfoDouble(_Symbol,SYMBOL_ASK) < high - 5 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)){
         trade.BuyStop(lots,high,_Symbol,buyStopLoss,buyTakeProfit,ORDER_TIME_GTC,0,TradeComment);
         buyPos = trade.ResultOrder();
      }
      else{
         trade.Buy(lots,_Symbol,0,buyStopLoss,buyTakeProfit,TradeComment);
         buyPos = trade.ResultOrder();
      }
   }
}

void executeSell(){
   double lots;
   sellStopLoss = low + SLMultiplier * (high - low);
   stopLossPoints = (sellStopLoss - low) / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(UseRiskManagement){
      lots = calcLots();
   }
   else{
      lots = LotSize;
   }
   if(UseTakeProfit){
      sellTakeProfit = low - TPMultiplier * (high - low);
   }
   else{
      sellTakeProfit = 0;
   }
   bool rsiShortCheck = true;
   if(UseRsiFilter){
      rsiShortCheck = checkRsiShortFilter();
   }
   if(rsiShortCheck){
      if(SymbolInfoDouble(_Symbol,SYMBOL_BID) > low + 5 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)){
         trade.SellStop(lots,low,_Symbol,sellStopLoss,sellTakeProfit,ORDER_TIME_GTC,0,TradeComment);
         sellPos = trade.ResultOrder();
      }
      else{
         trade.Sell(lots,_Symbol,0,sellStopLoss,sellTakeProfit,TradeComment);
         sellPos = trade.ResultOrder();
      }
   }
}

bool checkRsiShortFilter(){
   int rsiHandle = iRSI(_Symbol,PERIOD_CURRENT,RsiLength,PRICE_CLOSE);
   double rsiValue[2];
   CopyBuffer(rsiHandle,0,0,2,rsiValue);
   double rsiShortTrigger = 0 + RsiTrigger;
   if(rsiValue[0] < rsiShortTrigger){
      return true;
   }
   else return false;
}

bool checkRsiLongFilter(){
   int rsiHandle = iRSI(_Symbol,PERIOD_CURRENT,RsiLength,PRICE_CLOSE);
   double rsiValue[2];
   CopyBuffer(rsiHandle,0,0,2,rsiValue);
   double rsiLongTrigger = 100 - RsiTrigger;
   if(rsiValue[0] > rsiLongTrigger){
      return true;
   }
   else return false;
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