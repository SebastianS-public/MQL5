#include <WinINet.mqh>
#include <Trade/Trade.mqh>

input int TargetDistance = 10;
input int LookbackDistance = 10;
input int TradeThreshold = 30;
input ENUM_TIMEFRAMES Timeframe = PERIOD_M1;

CTrade trade;

struct posItem{
   ulong order;
   int val;
};

struct CandleData{
   int size;
   int upperWickSize;
   int lowerWickSize;
   int tickVol;
   int lookbackVal;
   double distToMa20M1;
   double prevDistToPrevMa20M1;
   double distToMa20H1;
   double cciValue;
   double rsiValue;
};

double maArray20M1[];
double maArray20H1[];
double cciArray25[];
double rsiArray14[];
int maHandle20M1;
int maHandle20H1;
int cciHandle25;
int rsiHandle14;

ulong resOrder;
posItem posArray[];

int OnInit(){
   ArrayResize(posArray, TargetDistance);
   for(int i = 0; i < ArraySize(posArray); i++){
      posArray[i].order = 0;
      posArray[i].val = 0;
   }
   maHandle20M1 = iMA(_Symbol, Timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   maHandle20H1 = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   cciHandle25 = iCCI(_Symbol, Timeframe, 25, PRICE_TYPICAL);
   rsiHandle14 = iRSI(_Symbol, Timeframe, 14, PRICE_CLOSE);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   bool newCandle = detectNewCandle(Timeframe);
   if(newCandle){
      checkToClosePositions();
      rotatePositionArray();
      
      MqlDateTime timestruct;
      TimeToStruct(iTime(_Symbol, Timeframe, 1), timestruct);
      if(timestruct.hour < 22 && timestruct.hour > 1){
         CopyBuffer(maHandle20M1, 0, 1, 2, maArray20M1);
         CopyBuffer(cciHandle25, 0, 1, 1, cciArray25);
         CopyBuffer(rsiHandle14, 0, 1, 1, rsiArray14);
         CopyBuffer(maHandle20H1, 0, 0, 1, maArray20H1);
         
         CandleData data = getCandleData();
         WininetRequest req;
         WininetResponse res;
            
         req.host = "127.0.0.1";
         req.port = 8080;
         req.method = "POST";
         req.data_str = IntegerToString(data.size) + "/" +
                        IntegerToString(data.upperWickSize) + "/" +
                        IntegerToString(data.lowerWickSize) + "/" +
                        IntegerToString(data.tickVol) + "/" + 
                        IntegerToString(data.lookbackVal) + "/" +
                        DoubleToString(data.distToMa20M1) + "/" +
                        DoubleToString(data.prevDistToPrevMa20M1) + "/" +
                        DoubleToString(data.distToMa20H1) + "/" +
                        DoubleToString(data.cciValue) + "/" +
                        DoubleToString(data.rsiValue);
         Print(req.data_str);
         WebReq(req, res);
         int tradeCommand = getTradeCommand(res);
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

CandleData getCandleData(){
   CandleData data;
   double symbolTickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double open = iOpen(_Symbol, Timeframe, 1);
   double high = iHigh(_Symbol, Timeframe, 1);
   double low = iLow(_Symbol, Timeframe, 1);
   double close = iClose(_Symbol, Timeframe, 1);
   data.size = int(round((close - open) / symbolTickSize));
   data.tickVol = int(iTickVolume(_Symbol, Timeframe, 1));
   data.lookbackVal = int((close - iClose(_Symbol, Timeframe, 1 + LookbackDistance)) / symbolTickSize);
   data.distToMa20M1 = (close - maArray20M1[1]) / symbolTickSize;
   data.prevDistToPrevMa20M1 = (iClose(_Symbol, Timeframe, 2) - maArray20M1[0]) / symbolTickSize;
   data.distToMa20H1 = (close - maArray20H1[0]) / symbolTickSize;
   data.cciValue = cciArray25[0];
   data.rsiValue = rsiArray14[0];
   
   if(open < close){
      data.upperWickSize = int(round((high - close) / symbolTickSize));
      data.lowerWickSize = int(round((open - low) / symbolTickSize));
   }
   else{
      data.upperWickSize = int(round((high - open) / symbolTickSize));
      data.lowerWickSize = int(round((close - low) / symbolTickSize));
   }
   return data;
}

int getTradeCommand(WininetResponse &res){
   string strRes = getPostResponse(res);
   double result = double(StringToDouble(strRes));
   Print("Double: ", result);
   if(result > TradeThreshold) return 1;
   else if(result < -TradeThreshold) return 2;
   else return 0;
}

string getPostResponse(WininetResponse &res){
   string result = res.GetDataStr();
   Print("status: ", res.status);
   Print(result);
   
   string resultArray[];
   StringSplit(result,StringGetCharacter(" ", 0), resultArray);
   result = resultArray[0];
   StringReplace(result, "[", "");
   StringReplace(result, "]", "");
   return result;
}

void checkToClosePositions(){
   if(PositionsTotal() != 0){
      for(int i = 0; i < PositionsTotal(); i++){
         ulong ticket = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_TIME) < TimeCurrent() - 1 * 60 * TargetDistance){ // timeframe * seconds/min * openDuration
            trade.PositionClose(ticket);
         }
      }
   }
}

void rotatePositionArray(){
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