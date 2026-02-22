#include <WinINet.mqh>
#include <Trade/Trade.mqh>

input int TargetDistance = 10;
input int LookbackDistance = 10;

CTrade trade;

struct posItem{
   ulong order;
   int val;
};

ulong resOrder;
posItem posArray[];

int OnInit(){
   ArrayResize(posArray, TargetDistance);
   for(int i = 0; i < ArraySize(posArray); i++){
      posArray[i].order = 0;
      posArray[i].val = 0;
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   bool newCandle = detectNewCandle(PERIOD_CURRENT);
   if(newCandle){
      if(PositionsTotal() != 0){
         for(int i = 0; i < PositionsTotal(); i++){
            ulong ticket = PositionGetTicket(i);
            if(PositionGetInteger(POSITION_TIME) < TimeCurrent() - 1 * 60 * TargetDistance){ // timeframe * seconds/min * openDuration
               trade.PositionClose(ticket);
            }
         }
      }
      for(int i=ArraySize(posArray)-1; i>=0; i--){
         if(posArray[i].order != 0 && i == TargetDistance-1){
            trade.PositionClose(posArray[i].order);
         }
         else if(i < TargetDistance-1){
            if(posArray[i].order != 0){
               posArray[i].val += 1;
            }
            posArray[i+1] = posArray[i];
         }
      }
      posArray[0].order = 0;
      posArray[0].val = 0;
      
      MqlDateTime timestruct;
      TimeToStruct(iTime(_Symbol, PERIOD_CURRENT, 1), timestruct);
      if(timestruct.hour < 22 && timestruct.hour > 1){
         double symbolTickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         double open = iOpen(_Symbol, PERIOD_CURRENT, 1);
         double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
         double low = iLow(_Symbol, PERIOD_CURRENT, 1);
         double close = iClose(_Symbol, PERIOD_CURRENT, 1);
         int size = int(round((close - open) / symbolTickSize));
         int tick_vol = int(iTickVolume(_Symbol, PERIOD_CURRENT, 1));
         int lookback_val = int((iClose(_Symbol, PERIOD_CURRENT, 1 + LookbackDistance) - close) / symbolTickSize);
         
         int upperWickSize, lowerWickSize;
         if(open < close){
            upperWickSize = int(round((high - close) / symbolTickSize));
            lowerWickSize = int(round((open - low) / symbolTickSize));
         }
         else{
            upperWickSize = int(round((high - open) / symbolTickSize));
            lowerWickSize = int(round((close - low) / symbolTickSize));
         }
         
         
         WininetRequest req;
         WininetResponse res;
            
         req.host = "127.0.0.1";
         req.port = 8080;
         req.method = "POST";
         req.data_str = IntegerToString(size) + "/" +
                        IntegerToString(upperWickSize) + "/" +
                        IntegerToString(lowerWickSize) + "/" +
                        IntegerToString(tick_vol) + "/" + 
                        IntegerToString(lookback_val);
         WebReq(req, res);
         Print("status: ", res.status);
         string result = res.GetDataStr();
         string resultArray[];
         StringSplit(result,StringGetCharacter(" ", 0), resultArray);
         result = resultArray[0];
         StringReplace(result, "[", "");
         StringReplace(result, "]", "");
         long tradeCommand = StringToInteger(result);
         Print(res.GetDataStr());
         Print(tradeCommand);
         if(tradeCommand == 1){
            trade.Buy(0.1, _Symbol, 0, 0, 0, NULL);
            posArray[0].order = trade.ResultOrder();
         }
         else if(tradeCommand == 2){
            trade.Sell(0.1, _Symbol, 0, 0, 0, NULL);
            posArray[0].order = trade.ResultOrder();
         }
      }
   }
}

bool detectNewCandle(ENUM_TIMEFRAMES candleTimeframe){
   MqlRates priceData[1];
   CopyRates(_Symbol,candleTimeframe,0,1,priceData);
   datetime currentCandle;
   static datetime lastCandle;
   currentCandle = priceData[0].time;
   if(currentCandle != lastCandle){
      lastCandle = currentCandle;
      return true;
   }else{
      return false;
   }
}