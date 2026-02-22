#include <Trade/Trade.mqh>

input ENUM_TIMEFRAMES timeframe = PERIOD_M15;
input double tradeTriggerAtrRate = 1;
input double stopLossAtrRate = 1;
input double takeProfitAtrRate = 1;
input int atrPeriod = 14;
input string tradeComment = "Daily Continuation Trade";

CTrade trade;

struct NewCandleStruct{
   bool newDay;
   bool newCandle;
};

struct OrderStruct{
   string orderType;
   double volume;
   double price;
   string symbol;
   double stopLoss;
   double takeProfit;
   ENUM_ORDER_TYPE_TIME typeTime;
   datetime expiration;
   string comment;
   ulong resOrder;
   void print(string printString){
      Print("\n", printString, "\norderType: ", orderType, "\nvolume: ", volume, "\nprice: ", price, "\nsymbol: ", symbol, "\nstopLoss: ", stopLoss,
            "\ntakeProfit: ", takeProfit, "\ntypeTime: ", typeTime, "\nexpiration: ", expiration, "\ncomment: ", comment, "\nresOrder: ", resOrder, "\n");
   }
   void null(){
      orderType = ""; volume = 0; price = 0; symbol = ""; stopLoss = 0; takeProfit = 0; expiration = 0; comment = ""; resOrder = -1;
   }
};

NewCandleStruct isNewCandle;
int timeframeVal;
datetime dayTriggerDatetime = 0;
datetime candleTriggerDatetime = 0;
int tradeDir; // 1 = buy, 0 = sell;
int atrHandle;
double atrVal[1];
OrderStruct orderArray[];

void OnInit(){
   switch(timeframe){
      case PERIOD_M1: timeframeVal = 1; break;
      case PERIOD_M2: timeframeVal = 2; break;
      case PERIOD_M3: timeframeVal = 3; break;
      case PERIOD_M4: timeframeVal = 4; break;
      case PERIOD_M5: timeframeVal = 5; break;
      case PERIOD_M6: timeframeVal = 6; break;
      case PERIOD_M10: timeframeVal = 10; break;
      case PERIOD_M12: timeframeVal = 12; break;
      case PERIOD_M15: timeframeVal = 15; break;
      case PERIOD_M20: timeframeVal = 20; break;
      case PERIOD_M30: timeframeVal = 30; break;
      case PERIOD_H1: timeframeVal = 60; break;
      case PERIOD_H2: timeframeVal = 120; break;
      case PERIOD_H3: timeframeVal = 180; break;
      case PERIOD_H4: timeframeVal = 240; break;
      case PERIOD_H6: timeframeVal = 360; break;
      case PERIOD_H8: timeframeVal = 480; break;
      case PERIOD_H12: timeframeVal = 720; break;
      case PERIOD_D1: timeframeVal = 1440; break;
      case PERIOD_W1: timeframeVal = 10080; break;
   }
   atrHandle = iATR(_Symbol, PERIOD_D1, atrPeriod);
}

void OnTick(){
   detectNewCandle(TimeCurrent());
   if(isNewCandle.newDay){
      Print("New Day");
      closeOpenOrders();
      double close = iClose(_Symbol, PERIOD_D1, 1);
      getTradeDir(close);
      double currentAtrVal = getAtr();
      placeOrders(close, currentAtrVal);
   }
   if(isNewCandle.newCandle){
      Print("New Candle");
      handleOrderArray();
   }
}

void handleOrderArray(){
   Print("Handle Order Array:");
   Print("Checking Open Orders, OrdersTotal: ", OrdersTotal());
   //iterate through all orders
   for(int i = 0; i < OrdersTotal(); i++){
      //get tickets for all orders and select them
      ulong ticket = OrderGetTicket(i);
      //check if order from this ea
      if(OrderGetString(ORDER_COMMENT) == tradeComment){
         Print("Found an open Order from this ea: ", ticket);
         //check if order in order array, if not, close
         if(!isOrderInOrderArray(ticket)){
            Print("Order was not found in order array, closing order!");
            trade.OrderDelete(ticket);
         }
      }
   }
   //repeat for positions, remove for testing with letting all positons run into stop loss/take profit
   for(int i = 0; i < PositionsTotal(); i++){
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_COMMENT) == tradeComment){
         Print("Found an open Position from this ea: ", ticket);
         if(!isOrderInOrderArray(ticket)){
            Print("Position was not found in order array, closing Position!");
            trade.PositionClose(ticket);
         }
      }
   }
   Print("Checking Order Array, ArraySize: ", ArraySize(orderArray));
   //iterate through order array
   for(int i = 0; i < ArraySize(orderArray); i++){
      Print("Checking if following Order is open: ", orderArray[i].resOrder);
      //check if order is open, if not, open
      if(!isOrderFromOrderArrayOpen(orderArray[i].resOrder)){
         Print("Order was not found in open orders, opening order!");
         openOrder(orderArray[i]);
      }
   }
}

void openOrder(OrderStruct& order){
   order.print("Opening Order: ");
   if(order.orderType == "BuyLimit" && order.resOrder >= 0){
      trade.BuyLimit(order.volume, order.price, order.symbol, order.stopLoss, order.takeProfit, order.typeTime, order.expiration, order.comment);
      if(trade.ResultRetcode() == 10009 || trade.ResultRetcode() == 10008){
         order.resOrder = trade.ResultOrder();
      }
   }
   else if(order.orderType == "SellLimit" && order.resOrder >= 0){
      trade.SellLimit(order.volume, order.price, order.symbol, order.stopLoss, order.takeProfit, order.typeTime, order.expiration, order.comment);
      if(trade.ResultRetcode() == 10009 || trade.ResultRetcode() == 10008){
         order.resOrder = trade.ResultOrder();
      }
   }
}

bool isOrderFromOrderArrayOpen(ulong ticket){
   for(int i = 0; i < OrdersTotal(); i++){
      ulong openTicket = OrderGetTicket(i);
      if(openTicket == ticket) return true;
   }
   for(int i = 0; i < PositionsTotal(); i++){
      ulong openTicket = PositionGetTicket(i);
      if(openTicket == ticket) return true;
   }
   return false;
}

bool isOrderInOrderArray(ulong ticket){
   for(int i = 0; i < ArraySize(orderArray); i++){
      if(orderArray[i].resOrder == ticket) return true;
   }
   return false;
}

void closeOpenOrders(){
   Print("Closing all Open orders, emptying OrderArray");
   for(int i = 0; i < ArraySize(orderArray); i++){
      orderArray[i].null();
   }
   ArrayResize(orderArray, 0, 0);
   /*for(int i = 0; i < OrdersTotal(); i++){
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_COMMENT) == tradeComment){
         for(int j = 0; j < ArraySize(orderArray); j++){
            //find order in order array
            if(orderArray[j].resOrder == ticket){
               //delete order from order array, shift and resize order array
               for(int k = j; j < ArraySize(orderArray) - 1; k++){
                  orderArray[k] = orderArray[k + 1];
               }
               ArrayResize(orderArray, ArraySize(orderArray) - 1, 0);
            }
         }
      }
   }*/
}

void getTradeDir(double close){
   if(iOpen(_Symbol, PERIOD_D1, 1) < close) tradeDir = 1;
   else tradeDir = 0;
   Print("Get tradeDir: ", tradeDir);
}

double getAtr(){
   CopyBuffer(atrHandle, 0, 0, 1, atrVal);
   Print("Get AtrVal: ", atrVal[0]);
   return atrVal[0];
}

void placeOrders(double close, double currentAtrVal){
   Print("Placing Orders into OrderArray, ArraySize before: ", ArraySize(orderArray));
   int size = ArraySize(orderArray);
   ArrayResize(orderArray, size + 1, 0);
   Print("ArraySize after: ", ArraySize(orderArray));
   
   if(tradeDir == 1){
      double triggerPrice = close - currentAtrVal * tradeTriggerAtrRate;
      orderArray[size].orderType = "BuyLimit";
      orderArray[size].volume = 0.1;
      orderArray[size].price = triggerPrice;
      orderArray[size].symbol = _Symbol;
      orderArray[size].stopLoss = triggerPrice - currentAtrVal * stopLossAtrRate;
      orderArray[size].takeProfit = triggerPrice + currentAtrVal * takeProfitAtrRate;
      orderArray[size].typeTime = ORDER_TIME_GTC;
      orderArray[size].expiration = 0;
      orderArray[size].comment = tradeComment;
      orderArray[size].resOrder = 0;
   }
   else if(tradeDir == 0){
      double triggerPrice = close + currentAtrVal * tradeTriggerAtrRate;
      orderArray[size].orderType = "SellLimit";
      orderArray[size].volume = 0.1;
      orderArray[size].price = triggerPrice;
      orderArray[size].symbol = _Symbol;
      orderArray[size].stopLoss = triggerPrice + currentAtrVal * stopLossAtrRate;
      orderArray[size].takeProfit = triggerPrice - currentAtrVal * takeProfitAtrRate;
      orderArray[size].typeTime = ORDER_TIME_GTC;
      orderArray[size].expiration = 0;
      orderArray[size].comment = tradeComment;
      orderArray[size].resOrder = 0;
   }
   Print("OrderArray full Print:");
   ArrayPrint(orderArray);
}

void detectNewCandle(datetime currentTime){
   isNewCandle.newCandle = false;
   isNewCandle.newDay = false;
   if(currentTime >= dayTriggerDatetime){
      dayTriggerDatetime = iTime(_Symbol, PERIOD_D1, 0) + 1440 * 60;
      isNewCandle.newDay = true;
   }
   if(currentTime >= candleTriggerDatetime){
      candleTriggerDatetime = iTime(_Symbol, timeframe, 0) + timeframeVal * 60;
      isNewCandle.newCandle = true;
   }
}