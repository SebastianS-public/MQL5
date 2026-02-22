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
double entryBuystop;
double entrySellstop;

void OnTick(){
   bool newCandle = detectNewCandle();
   if(newCandle || !executed || TimeCurrent() > nextNewsTime){
      if(ObjectsTotal(0,-1,OBJ_VLINE) != 0){
         ObjectsDeleteAll(0,-1,OBJ_VLINE);
      }
      string eventName[];
      ushort stringChar = StringGetCharacter(",",0);
      StringSplit(EventNames,stringChar,eventName);
      int x = ArraySize(eventName);
      datetime newsTime[];
      ArrayResize(newsTime,x,0);
      for(int i = 0;i < x;i++){
         newsTime[i] = GetNextEvent(eventName[i]);
      }
      nextNewsTime = newsTime[ArrayMinimum(newsTime,0,x)];
      ObjectCreate(0,"line",OBJ_VLINE,0,nextNewsTime,0);
      ObjectSetInteger(0,"line",OBJPROP_WIDTH,2);
      executed = true;
   }
   
   if(TimeCurrent() > testTime-1*60 && !OrderSelect(buyPos) && !OrderSelect(sellPos) && 
     !PositionSelectByTicket(buyPos) && !PositionSelectByTicket(sellPos) && TimeCurrent() < testTime + 1*60){
      trailingBuySl = 0;
      trailingSellSl = 0;
      entryBuystop = 0;
      entrySellstop = 0;
      executeBuySellStop();
      lastSecEntryPoints = EntryPoints;
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
   if(ask + 50 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) > PositionGetDouble(POSITION_PRICE_OPEN) && PositionGetDouble(POSITION_PRICE_OPEN) > PositionGetDouble(POSITION_SL)){
      double slToZero = PositionGetDouble(POSITION_PRICE_OPEN);
      trade.PositionModify(buyPos,slToZero,0);
   }
   datetime expiration = TimeCurrent() + 60*60;
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double slSellstop = iOpen(_Symbol,PERIOD_M5,0) + (EntryPoints / 2) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(OrderSelect(sellPos) && TimeCurrent() < testTime + 5*60){
      if(OrderGetDouble(ORDER_PRICE_OPEN) != iOpen(_Symbol,PERIOD_M5,0)){
         trade.OrderModify(sellPos,iOpen(_Symbol,PERIOD_M5,0),slSellstop,0,ORDER_TIME_GTC,expiration);
      }
   }
}

void executeSellManagement(){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid - 50 * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) < PositionGetDouble(POSITION_PRICE_OPEN) && PositionGetDouble(POSITION_PRICE_OPEN) < PositionGetDouble(POSITION_SL)){
      double slToZero = PositionGetDouble(POSITION_PRICE_OPEN);
      trade.PositionModify(sellPos,slToZero,0);
   }
   datetime expiration = TimeCurrent() + 60*60;
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double slBuystop = iOpen(_Symbol,PERIOD_M5,0) - (EntryPoints / 2) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(OrderSelect(buyPos) && TimeCurrent() < testTime + 5*60){
      if(OrderGetDouble(ORDER_PRICE_OPEN) != iOpen(_Symbol,PERIOD_M5,0)){
         trade.OrderModify(buyPos,iOpen(_Symbol,PERIOD_M5,0),slBuystop,0,ORDER_TIME_GTC,expiration);
      }
   }
}

void executeOrderManagement(){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double slBuystop = ask + (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double slSellstop = bid - (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   datetime expiration = TimeCurrent() + 60*60;
   if(TimeCurrent() < testTime-5){
      if(ask > entryBuystop - (EntryPoints / 2) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)){
         double newEntryBuystop = ask + EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         double newSlBuystop = ask + (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         trade.OrderModify(buyPos,newEntryBuystop,newSlBuystop,0,ORDER_TIME_GTC,expiration);
      }
      if(bid < entrySellstop + (EntryPoints / 2) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)){
         double newEntrySellstop = bid - EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         double newSlSellstop = bid - (EntryPoints / 10) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         trade.OrderModify(sellPos,newEntrySellstop,newSlSellstop,0,ORDER_TIME_GTC,expiration);
      }
   }
   if(TimeCurrent() > testTime-5){
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
      lastSecEntryPoints = lastSecEntryPoints * 0.80;
      if(lastSecEntryPoints < EntryPoints / 5){
         lastSecEntryPoints = EntryPoints / 5;
      }
   }
}

void executeBuySellStop(){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   entryBuystop = ask + EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   entrySellstop = bid - EntryPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
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

bool detectNewCandle(){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,PERIOD_D1,0,3,priceData);
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

datetime GetNextEvent(string eventNameString){ 
   MqlCalendarValue values[];
   ArraySetAsSeries(values,true);
   datetime dateFrom=TimeCurrent();
   datetime dateTo=0;
   if(CalendarValueHistory(values,dateFrom,dateTo,NULL,Currency)){ 
      int idx = ArraySize(values)-1;
      while (idx>=0){
         MqlCalendarEvent event;
         ulong eventId=values[idx].event_id;
         datetime eventTime = values[idx].time;
         string eventTimeString = TimeToString(eventTime);
         if(CalendarEventById(eventId,event)){
            if(event.name == eventNameString){
               Print(eventTimeString," ",eventId," ",event.name," (",event.importance,")");
               return eventTime;
            }
         }
         idx--;
      }
   }
   return 0;
}