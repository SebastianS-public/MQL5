#include <Trade/Trade.mqh>

enum openclose{
   open = 0,
   close = 1
};

enum posDir{
   buy = 0,
   sell = 1
};

enum debugInfo {
   none = 0,
   basic = 1,
   full = 2
};

input int StructureLength = 10;
input int LookbackDistance = 1000;
input debugInfo EnableDebugInfo = none;
input ENUM_TIMEFRAMES timeframe = PERIOD_M1;
input string PositionComment = "StructureFinder";
input int TopScoreRelevancy = 50;
input bool CandleFractionsScoreCalculation = true;
input int TradeLength = 10;
input int TradeThreshold = 50;
input int StartHour = 2;
input int StartMin = 0;
input int EndHour = 21;
input int EndMin = 0;

CTrade trade;


//TODO: Rewrite structs and combine them into a single struct that tracks everything
//TODO: Further optimize calculations
//TODO: After trying to make the calculations more efficient, the starting index of the history seems to be off 
//TODO: Build Time Constraint, only run program between 2am in the morning and 9pm, close all positions at 9:55
//TODO: Build basic trade Logic:
//    - debug trade logic: array out of range error
//    - print more debug statements within the trade logic to be able to follow whats happening
//TODO: Build a visualization to show the ranges and sequences of the best scores
//TODO: Build a visualization to overlay the range in the past with the current range
//TODO: Build a visualization to overlay top X score future candles at present chart
//TODO: Build UI to toggle normalization of the ranges, past range is different in absolute Values to the current one, with the toggle
//      it would be possible to compare the relative similarities between these market situations
//TODO: Build a UI Component to Show the current top X(20?) scores and timestamps of the Structures
//TODO: Try Calculating the similarities between the X top score Structure future X(10) candles as a Structure and get a single score from it =>
//      This might be an actual indicator, how often and how similar did the current chart Structure play out in the past?



struct CandleStruct {
   datetime timestamp;
   double close;
   double rangeFractions;
};

struct scores {
   datetime timestamp;
   double score;
};

struct PositionStruct{
   string positionType;
   double volume;
   string symbol;
   double price;
   double stopLoss;
   double takeProfit;
   datetime expiration;
   string comment;
   ulong ticket;
   datetime structureStartTime;
   void print(string printString){
      Print("\n", printString, "\norderType: ", positionType, "\nvolume: ", volume, "\nsymbol: ", symbol, "\nprice: ", price, "\nstopLoss: ", stopLoss,
            "\ntakeProfit: ", takeProfit, "\nexpiration: ", expiration, "\ncomment: ", comment, "\nticket: ", ticket, "\n");
   }
   void nullOrder(){
      positionType = ""; volume = 0; symbol = ""; price = 0; stopLoss = 0; takeProfit = 0; expiration = 0; comment = ""; ticket = -1; structureStartTime = 0;
   }
   PositionStruct(){
      positionType = ""; volume = 0; symbol = ""; price = 0; stopLoss = 0; takeProfit = 0; expiration = 0; comment = ""; ticket = -1; structureStartTime = 0;
   }
   PositionStruct(const PositionStruct& structIn){
      positionType = structIn.positionType;
      volume = structIn.volume;
      symbol = structIn.symbol;
      price = structIn.price;
      stopLoss = structIn.stopLoss;
      takeProfit = structIn.takeProfit;
      expiration = structIn.expiration;
      comment = structIn.comment;
      ticket = structIn.ticket;
      structureStartTime = structIn.structureStartTime;
   }
};

PositionStruct posArr[];
scores scoreArr[];

double tradeTickSize;
int timeframeVal;
datetime candleTriggerDatetime = 0;
datetime currentTime = 0;


void OnInit(){
   tradeTickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   ArrayResize(scoreArr, LookbackDistance - StructureLength, 0);
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
}

void OnTick(){
   if(detectNewCandle(TimeCurrent())){
      if(EnableDebugInfo < 0){
         Print("\n\n\nNEW CANDLE\n");
      }
      
      checkPositions();
   }
}

void checkPositions(){
   int posArrIDX = 0;
   
   for(int i = 0; i < PositionsTotal(); i++){
      ulong ticket = PositionGetTicket(i);
      
      if(PositionGetString(POSITION_COMMENT) == PositionComment){
         PositionStruct position = posArr[posArrIDX];
         if(EnableDebugInfo == basic || EnableDebugInfo == full){
            Print("Found position at index ", i, " corresponding to position in array: ", posArrIDX, "\n",
                  "Ticket: ", position.ticket, "\n",
                  "Structure Start Time: ", position.structureStartTime, "\n",
                  "Timeout: ", position.expiration);
         }
         
         if(currentTime >= position.expiration){
            if(EnableDebugInfo == basic || EnableDebugInfo == full){
               Print("Position isn't valid, position expired, closing position!");
            }
            positionHandler(close, position);
            i--;
         }
         else if(!isScoreInTopScores(position.structureStartTime)){
            if(EnableDebugInfo == basic || EnableDebugInfo == full){
               Print("Position isn't valid, position not found in top scores, closing position!");
            }
            positionHandler(close, position);
            i--;
         }
         else{
            if(EnableDebugInfo == basic || EnableDebugInfo == full){
               Print("Position is valid!");
            }
         }
         posArrIDX++;
      }
   }
}

bool isScoreInTopScores(datetime structureStartTime){
   for(int i = 0; i < TopScoreRelevancy; i++){
      if(scoreArr[i].timestamp == structureStartTime){
         return true;
      }
   }
   
   if(EnableDebugInfo == basic ||EnableDebugInfo == full){
      for(int i = 0; i < ArraySize(scoreArr); i++){
         if(scoreArr[i].timestamp == structureStartTime){
            Print("Position Index was found at index ", i, " of scores!");
            break;
         }
      }
   }
   return false;
}

void positionHandler(openclose openClose, PositionStruct& position, int direction = buy){
   if(openClose == open){
      switch(direction){
         case buy: trade.Buy(position.volume, position.symbol, position.price, position.stopLoss, position.takeProfit, position.comment); break;
         case sell: trade.Sell(position.volume, position.symbol, position.price, position.stopLoss, position.takeProfit, position.comment); break;
      }
      
      uint retcode = trade.ResultRetcode();
      Print("Trade ResultRetcode: ", retcode);
      if(retcode == 10009){
         int size = ArraySize(posArr);
         
         if(EnableDebugInfo == basic || EnableDebugInfo == full){
            Print("RETCODE: ", retcode);
            Print("Old posArr size: ", size);
         }
         
         ArrayResize(posArr, size + 1, 0);
         position.ticket = trade.ResultOrder();
         posArr[size] = position;
         
         if(EnableDebugInfo == basic || EnableDebugInfo == full){
            Print("New posArr size: ", ArraySize(posArr));
            Print("New posArr entry:\n", 
                  "Ticket: ", posArr[size].ticket, "\n",
                  "Structure Start Time: ", posArr[size].structureStartTime, "\n",
                  "Timeout: ", TimeToString(posArr[size].expiration));
         }
      }
   }
   else if(openClose == close){
      if(PositionSelectByTicket(position.ticket)){
         trade.PositionClose(position.ticket);
         int size = ArraySize(posArr);
         
         uint retcode = trade.ResultRetcode();
         Print("Trade ResultRetcode: ", retcode);
         if(retcode == 10009){
            if(EnableDebugInfo == basic || EnableDebugInfo == full){
               Print("RETCODE: ", retcode);
               Print("Position Array before:");
               ArrayPrint(posArr);
            }
            
            for(int i = 0; i < size; i++){
               if(posArr[i].ticket == position.ticket){
                  for(int j = i; j < size - 1; j++){
                     posArr[j] = posArr[j + 1];
                  }
                  ArrayResize(posArr, size - 1, 0);
                  break;
               }
            }
            
            if(EnableDebugInfo == basic || EnableDebugInfo == full){
               Print("Position Array after:");
               ArrayPrint(posArr);
            }
         }
      }
      else{
         Print("Could not find position ticket ", position.ticket, "!");
      }
   }
}

bool detectNewCandle(datetime time){
   if(time >= candleTriggerDatetime){
      candleTriggerDatetime = iTime(_Symbol, timeframe, 0) + timeframeVal * 60;
      currentTime = time;
      return true;
   }
   return false;
}