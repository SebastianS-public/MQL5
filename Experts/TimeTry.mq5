#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
CTrade trade;
CPositionInfo posInfo;

input string Currency = "USD";
input string EventNames = "CPI m/m,Fed Interest Rate Decision";
input double EntryPoints = 500;
input double LotSize = 0.01;
input datetime testTime;

bool executed = false;
datetime nextNewsTime;
ulong buyPos;
ulong sellPos;
double lastSecEntryPoints;
double trailingBuySl;
double trailingSellSl;

void OnTick(){
   if(TimeCurrent() > testTime-1*60 && OrdersTotal() == 0 && PositionsTotal() == 0 && TimeCurrent() < testTime + 1*60){
      executeBuySellStop();
      lastSecEntryPoints = EntryPoints;
      trailingBuySl = 0;
      trailingSellSl = 0;
   }
   if(TimeCurrent() > testTime-1*60 && OrderSelect(buyPos) && OrderSelect(sellPos) && !PositionSelectByTicket(buyPos) && !PositionSelectByTicket(sellPos)){
      executeOrderManagement();
   }
   bool newCandleM5 = detectNewCandleM5();
   if(PositionSelectByTicket(buyPos)){
      executeBuyManagement();
      if(newCandleM5){
         trailingBuySl = iLow(_Symbol,PERIOD_M5,1);
         if(trailingBuySl > PositionGetDouble(POSITION_SL)){
            trade.PositionModify(buyPos,trailingBuySl,0);
         }
      }
   }
   if(PositionSelectByTicket(sellPos)){
      executeSellManagement();
      if(newCandleM5){
         trailingSellSl = iHigh(_Symbol,PERIOD_M5,1);
         if(trailingSellSl < PositionGetDouble(POSITION_SL)){
            trade.PositionModify(sellPos,trailingSellSl,0);
         }
      }
   }
   if(newCandleM5 && TimeCurrent() > testTime + 10*60){
      if(OrderSelect(buyPos)){
         trade.OrderDelete(buyPos);
      }
      if(OrderSelect(sellPos)){
         trade.OrderDelete(sellPos);
      }
   }
}

void executeBuyManagement(){
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double entryBuystop = ask + EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(ask + 50 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) > PositionGetDouble(POSITION_PRICE_OPEN) && PositionGetDouble(POSITION_PRICE_OPEN) > PositionGetDouble(POSITION_SL)){
      double slToZero = PositionGetDouble(POSITION_PRICE_OPEN);
      trade.PositionModify(buyPos,slToZero,0);
   }
}

void executeSellManagement(){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double entrySellstop = bid - EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(bid - 50 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) < PositionGetDouble(POSITION_PRICE_OPEN) && PositionGetDouble(POSITION_PRICE_OPEN) < PositionGetDouble(POSITION_SL)){
      double slToZero = PositionGetDouble(POSITION_PRICE_OPEN);
      trade.PositionModify(sellPos,slToZero,0);
   }
}

void executeOrderManagement(){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double entryBuystop = ask + EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double entrySellstop = bid - EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double slBuystop = ask + (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double slSellstop = bid - (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   datetime expiration = TimeCurrent() + 60*60;
   if(TimeCurrent() < testTime-10){
      if(ask > entryBuystop - (EntryPoints / 5) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)){
         double newEntryBuystop = ask + (EntryPoints / 2) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         double newSlBuystop = ask + (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         trade.OrderModify(buyPos,newEntryBuystop,newSlBuystop,0,ORDER_TIME_GTC,expiration);
      }
      if(bid < entrySellstop + (EntryPoints / 5) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)){
         double newEntrySellstop = bid - (EntryPoints / 2) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         double newSlSellstop = bid - (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         trade.OrderModify(sellPos,newEntrySellstop,newSlSellstop,0,ORDER_TIME_GTC,expiration);
      }
   }
   if(TimeCurrent() > testTime-10){
      double lastSecEntryBuystop = ask + lastSecEntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double lastSecSlBuystop = ask + (lastSecEntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(OrderSelect(buyPos)){
         if(lastSecEntryBuystop < OrderGetDouble(ORDER_PRICE_OPEN)){
            trade.OrderModify(buyPos,lastSecEntryBuystop,lastSecSlBuystop,0,ORDER_TIME_GTC,expiration);
         }
      }
      double lastSecEntrySellstop = bid - lastSecEntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double lastSecSlSellstop = bid - (lastSecEntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(OrderSelect(sellPos)){
         if(lastSecSlSellstop > OrderGetDouble(ORDER_PRICE_OPEN)){
            trade.OrderModify(sellPos,lastSecEntrySellstop,lastSecSlSellstop,0,ORDER_TIME_GTC,expiration);
         }
      }
      lastSecEntryPoints = lastSecEntryPoints * 0.95;
      if(lastSecEntryPoints < EntryPoints / 5){
         lastSecEntryPoints = EntryPoints / 5;
      }
   }
}

void executeBuySellStop(){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double entryBuystop = ask + EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double entrySellstop = bid - EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double slBuystop = ask + (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double slSellstop = bid - (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   trade.BuyStop(LotSize,entryBuystop,_Symbol,slBuystop,0,ORDER_TIME_GTC);
   buyPos = trade.ResultOrder();
   trade.SellStop(LotSize,entrySellstop,_Symbol,slSellstop,0,ORDER_TIME_GTC);
   sellPos = trade.ResultOrder();
}

bool detectNewCandleM5(){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,PERIOD_M5,0,3,priceData);
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