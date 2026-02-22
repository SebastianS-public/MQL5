#include <Trade/Trade.mqh>
CTrade trade;

input bool ReceiverSide = false;
input bool UseDrawdownPercent = true;
input double DrawdownPercent = 4.5;
input double DrawdownAbsolute = 500;

double maxDrawdownBalanceDay;
double maxDrawdownRelative;
string buttonName1 = "Button1";
string buttonName2 = "Button2";
bool shutdown;

void OnInit(){
   shutdown = false;
   if(!ReceiverSide){
      createButton(buttonName1,2,90,92,58,"Close all");
      createButton(buttonName2,2,150,92,58,"Close 50%");
   }
   if(UseDrawdownPercent){
      maxDrawdownRelative = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) * DrawdownPercent / 100,2);
      maxDrawdownBalanceDay = AccountInfoDouble(ACCOUNT_BALANCE) - NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE) * DrawdownPercent / 100,2);
   }
   else{
      maxDrawdownRelative = DrawdownAbsolute;
      maxDrawdownBalanceDay = AccountInfoDouble(ACCOUNT_BALANCE) - DrawdownAbsolute;
   }
}

void OnDeinit(const int reason){
   ObjectDelete(0,buttonName1);
   ObjectDelete(0,buttonName2);
   ObjectDelete(ChartFirst(),"shutdown");
}

void OnTick(){
   if((AccountInfoDouble(ACCOUNT_BALANCE) < maxDrawdownBalanceDay || AccountInfoDouble(ACCOUNT_EQUITY) < maxDrawdownBalanceDay) && PositionsTotal() != 0){
      executeCloseAll();
      shutdown = true;
      ObjectCreate(ChartFirst(),"shutdown",OBJ_ARROW_THUMB_DOWN,0,TimeCurrent(),SymbolInfoDouble(_Symbol,SYMBOL_ASK));
      ObjectSetInteger(ChartFirst(),"shutdown",OBJPROP_WIDTH,50);
   }
   Comment("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nLowest Balance/Equity: ",
            maxDrawdownBalanceDay,"\nEquity: ",AccountInfoDouble(ACCOUNT_EQUITY),"\nBalance: ",AccountInfoDouble(ACCOUNT_BALANCE));
            
   if(PositionsTotal() != 0 || OrdersTotal() != 0){
      double totalVolume = 0;
      double totalPrice = 0;
      double minVolume = 0;
      if(PositionsTotal() != 0){
         for(int i = PositionsTotal() - 1; i >= 0; i--){
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)){
               double volume = PositionGetDouble(POSITION_VOLUME);
               if(minVolume == 0){
                  minVolume = volume;
               }
               else if(minVolume > volume){
                  minVolume = volume;
               }
            }
         }
      }
      if(OrdersTotal() != 0){
         for(int i = OrdersTotal() - 1; i >= 0; i--){
            ulong ticket = OrderGetTicket(i);
            if(OrderSelect(ticket)){
               double volume = OrderGetDouble(ORDER_VOLUME_INITIAL);
               if(minVolume == 0){
                  minVolume = volume;
               }
               else if(minVolume > volume){
                  minVolume = volume;
               }
            }
         }
      }
      if(PositionsTotal() != 0){
         for(int i = PositionsTotal() - 1; i >= 0; i--){
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)){
               double volume = PositionGetDouble(POSITION_VOLUME);
               double price = PositionGetDouble(POSITION_PRICE_OPEN);
               totalPrice = totalPrice + price * (volume / minVolume);
               totalVolume = totalVolume + volume;
            }
         }
      }
      if(OrdersTotal() != 0){
         for(int i = OrdersTotal() - 1; i >= 0; i--){
            ulong ticket = OrderGetTicket(i);
            if(OrderSelect(ticket)){
               double volume = OrderGetDouble(ORDER_VOLUME_INITIAL);
               double price = OrderGetDouble(ORDER_PRICE_OPEN);
               totalPrice = totalPrice + price * (volume / minVolume);
               totalVolume = totalVolume + volume;
            }
         }
      }
      double averagePrice = totalPrice / (totalVolume / minVolume);
      double slPoints = (maxDrawdownRelative / (totalVolume * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE)));
      double slPrice = 0;
      if(PositionSelectByTicket(PositionGetTicket(0)) || OrderSelect(OrderGetTicket(0))){
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT){
            slPrice = averagePrice - slPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         }
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT){
            slPrice = averagePrice + slPoints * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         }
      }
      ObjectCreate(0,"Stop Loss Level",OBJ_HLINE,0,0,slPrice);
      ObjectSetInteger(0,"Stop Loss Level",OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,"Stop Loss Level",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(0,"Stop Loss Level",OBJPROP_WIDTH,3);
      
      ObjectCreate(0,"Average Price",OBJ_HLINE,0,0,averagePrice);
      ObjectSetInteger(0,"Average Price",OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,"Average Price",OBJPROP_COLOR,clrYellow);
      ObjectSetInteger(0,"Average Price",OBJPROP_WIDTH,1);
      
      ObjectCreate(ChartNext(ChartFirst()),"Stop Loss Level",OBJ_HLINE,0,0,slPrice);
      ObjectSetInteger(ChartNext(ChartFirst()),"Stop Loss Level",OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(ChartNext(ChartFirst()),"Stop Loss Level",OBJPROP_COLOR,clrBlue);
      ObjectSetInteger(ChartNext(ChartFirst()),"Stop Loss Level",OBJPROP_WIDTH,3);
      
      ObjectCreate(ChartNext(ChartFirst()),"Average Price",OBJ_HLINE,0,0,averagePrice);
      ObjectSetInteger(ChartNext(ChartFirst()),"Average Price",OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(ChartNext(ChartFirst()),"Average Price",OBJPROP_COLOR,clrYellow);
      ObjectSetInteger(ChartNext(ChartFirst()),"Average Price",OBJPROP_WIDTH,1);
   }
   else if(ObjectFind(0,"Average Price") == 0){
      ObjectDelete(0,"Average Price");
      ObjectDelete(ChartNext(ChartFirst()),"Average Price");
   }
   else if(ObjectFind(0,"Stop Loss Level") == 0){
      ObjectDelete(0,"Stop Loss Level");
      ObjectDelete(ChartNext(ChartFirst()),"Stop Loss Level");
   }
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam){
   if(id == CHARTEVENT_OBJECT_CLICK){
      if(ObjectGetString(0,sparam,OBJPROP_TEXT) == "Close all"){
         executeCloseAll();
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         Print("Close all was pressed");
      }
      if(ObjectGetString(0,sparam,OBJPROP_TEXT) == "Close 50%"){
         executeClose50();
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         Print("Close 50% was pressed");
      }
   }
}

void executeCloseAll(){
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)){
         trade.PositionClose(ticket);
      }
   }
}

void executeClose50(){
   double totalVolume = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)){
         double volume = PositionGetDouble(POSITION_VOLUME);
         totalVolume = totalVolume + volume;
      }
   }
   double volume50 = NormalizeDouble(totalVolume / 2,2);
   double closedVolume = 0;
   while(closedVolume != volume50){
      ulong ticket = PositionGetTicket(0);
      if(PositionSelectByTicket(ticket)){
         if(PositionGetDouble(POSITION_VOLUME) <= volume50 - closedVolume){
            Print("Close trade ",ticket," with volume ",PositionGetDouble(POSITION_VOLUME));
            trade.PositionClose(ticket);
            closedVolume = closedVolume + PositionGetDouble(POSITION_VOLUME);
            Print("Trade closed, closed Volume: ",closedVolume,"/",volume50);
         }
         else if(PositionGetDouble(POSITION_VOLUME) > volume50 - closedVolume){
            Print("Close partial trade ",ticket," closing volume ",NormalizeDouble(volume50 - closedVolume,2));
            trade.PositionClosePartial(ticket,NormalizeDouble(volume50 - closedVolume,2));
            closedVolume = volume50;
            Print("Partial closed, closed Volume: ",closedVolume,"/",volume50);
         }
      }
   }
}

void createButton(string buttonName, int xDist, int yDist, int xSize, int ySize, string buttonText){
   ObjectCreate(0,buttonName,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,buttonName,OBJPROP_XDISTANCE,xDist);
   ObjectSetInteger(0,buttonName,OBJPROP_YDISTANCE,yDist);
   ObjectSetInteger(0,buttonName,OBJPROP_XSIZE,xSize);
   ObjectSetInteger(0,buttonName,OBJPROP_YSIZE,ySize);
   ObjectSetString(0,buttonName,OBJPROP_TEXT,buttonText);
}