#include <Trade/Trade.mqh>

input int BarsN = 3;
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
input double lotSize = 1;
input int ExpirationHours = 50;

input int targetPips = 20;
input int stopPips = 20;
input int trailingStop = 20;

CTrade trade;

ulong buyPos, sellPos;

int totalBars;

void OnTick(){
   
   processPos(buyPos);
   processPos(sellPos);
   int bars = iBars(_Symbol,Timeframe);
   if(totalBars != bars){
      totalBars = bars;
      
      if(buyPos <= 0){
         double high = findHigh();
         if(high > 0){
            executeBuy(high);
         }
      }
      if(sellPos <= 0){
         double low = findLow();
         if(low > 0){
            executeSell(low);
         }
      }
   }
}

void processPos(ulong &posTicket){
   if(posTicket <= 0) return;
   if(OrderSelect(posTicket)) return;
   CPositionInfo pos;
   if(!pos.SelectByTicket(posTicket)){
      posTicket = 0;
      return;
   }
   else{
      if(pos.PositionType() == POSITION_TYPE_BUY){
         double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         
         if(bid > pos.PriceOpen() + trailingStop){
            double sl = bid - trailingStop;
            sl = NormalizeDouble(sl,_Digits);
            
            if(sl > pos.StopLoss()){
               trade.PositionModify(pos.Ticket(),sl,pos.TakeProfit());
            }
         }
      }
      else if(pos.PositionType() == POSITION_TYPE_SELL){
         double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         
         if(ask < pos.PriceOpen() - trailingStop){
            double sl = ask + trailingStop;
            sl = NormalizeDouble(sl,_Digits);
            
            if(sl < pos.StopLoss() || pos.StopLoss() == 0){
               trade.PositionModify(pos.Ticket(),sl,pos.TakeProfit());
            }
         }
      }
   }
}

void executeBuy(double entry){
   entry = NormalizeDouble(entry,_Digits);
   
   double tp = entry + targetPips;
   tp = NormalizeDouble(tp,_Digits);
   
   double sl = entry - stopPips;
   sl = NormalizeDouble(sl,_Digits);
            
   datetime expiration = iTime(_Symbol,Timeframe,0) + ExpirationHours * PeriodSeconds(PERIOD_H1);
   
   trade.BuyStop(lotSize,entry,_Symbol,sl,0,ORDER_TIME_SPECIFIED,expiration);
   buyPos = trade.ResultOrder();
}

void executeSell(double entry){
   entry = NormalizeDouble(entry,_Digits);
   
   double tp = entry - targetPips;
   tp = NormalizeDouble(tp,_Digits);
   
   double sl = entry + stopPips;
   sl = NormalizeDouble(sl,_Digits);
            
   datetime expiration = iTime(_Symbol,Timeframe,0) + ExpirationHours * PeriodSeconds(PERIOD_H1);
   
   trade.SellStop(lotSize,entry,_Symbol,sl,0,ORDER_TIME_SPECIFIED,expiration);
   sellPos = trade.ResultOrder();
}


double findHigh(){
   double highestHigh = 0;
   for(int i = 0; i < 200; i++){
      double high = iHigh(_Symbol,Timeframe,i);
      if(i > BarsN && iHighest(_Symbol,Timeframe,MODE_HIGH,BarsN*2+1,i-BarsN) == i){
         if(high > highestHigh){
            return high;
         }
      }
      highestHigh = MathMax(high,highestHigh);
   }
   return -1;
}

double findLow(){
   double lowestLow = DBL_MAX;
   for(int i = 0; i < 200; i++){      
      double low = iLow(_Symbol,Timeframe,i);
      if(i > BarsN && iLowest(_Symbol,Timeframe,MODE_LOW,BarsN*2+1,i-BarsN) == i){
         if(low < lowestLow){
            return low;
         }
      }
      lowestLow = MathMin(low,lowestLow);
   }
   return -1;
}