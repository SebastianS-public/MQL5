#include <Trade/Trade.mqh>

CTrade trade;

int lastBreakout;
int lotSize=1;


void OnTick(){

   double high = iHigh(NULL,PERIOD_CURRENT,1);
   high = NormalizeDouble(high,_Digits);
   double low = iLow(NULL,PERIOD_CURRENT,1);
   low = NormalizeDouble(low,_Digits);
   
//   ObjectCreate(_Symbol,"High", OBJ_HLINE,0,0,high);
//   ObjectSetInteger(0,"High",OBJPROP_COLOR,clrBlue);
//   ObjectSetInteger(0,"High",OBJPROP_WIDTH,2);
//   ObjectCreate(_Symbol,"Low", OBJ_HLINE,0,0,high);
//   ObjectSetInteger(0,"Low",OBJPROP_COLOR,clrBlue);
//   ObjectSetInteger(0,"Low",OBJPROP_WIDTH,2);
    
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
   if(bid > high && lastBreakout <= 0){
      lastBreakout = 1;
//      double stopLoss = sl - stopPips;
      trade.Buy(lotSize,_Symbol,0,low);
   }
   else if(bid < low && lastBreakout >= 0){
      lastBreakout = -1;
//      double stopLoss = sl + stopPips;
      trade.Sell(lotSize,_Symbol,0,high);
   }
   
   for(int i = PositionsTotal()-1; i >= 0; i--){
      ulong posTicket = PositionGetTicket(i);
      CPositionInfo pos;
      if(pos.SelectByTicket(posTicket)){
         if(pos.PositionType() == POSITION_TYPE_BUY){
            if(low > pos.StopLoss()){
            trade.PositionModify(pos.Ticket(),low,pos.TakeProfit());
            }
         }
         else if(pos.PositionType() == POSITION_TYPE_SELL){
            if(high < pos.StopLoss()){
            trade.PositionModify(pos.Ticket(),high,pos.TakeProfit());
            }
         }
      }
   }
}