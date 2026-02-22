#include <Trade/Trade.mqh>

input int StructureLength = 10;
input int LookbackDistance = 1000;
input int EnableDebugInfo = 0;
input ENUM_TIMEFRAMES timeframe = PERIOD_M1;
input string PositionComment = "StructureFinder";
input int TopScoreRelevancy = 50;
input bool CandleFractionsScoreCalculation = true;
input int TradeLength = 10;
input int TradeThreshold = 50;

CTrade trade;


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



struct Candles{
   datetime timestamp;
   double open;
   double high;
   double low;
   double close;
};

struct CandleFractions{
   datetime timestamp;
   double bodySize;
   double upperWickSize;
   double lowerWickSize;
   double absoluteRangeFractions;
};

struct posArrStruct{
   datetime timeout;
   ulong ticket;
   int scoreIndex;
};

enum openclose{
   open = 0,
   close = 1
};

enum posDir{
   buy = 0,
   sell = 1
};

struct candleFractionArray{
   CandleFractions CandleFractions[];
};

double scores[][2];
posArrStruct posArr[];
candleFractionArray fractionHistory[];

double tradeTickSize;
int timeframeVal;

void OnInit(){
   Print("frHist size before: ", ArraySize(fractionHistory));
   ArrayResize(fractionHistory, LookbackDistance - StructureLength, 0);
   Print("frHist size after: ", ArraySize(fractionHistory));
   ArrayResize(scores, LookbackDistance - StructureLength, 0);
   tradeTickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
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
   for(int i = StructureLength; i < LookbackDistance; i++){
      //init candle history
      Candles candleHistory[];
      CandleFractions fractions[];
      ArrayResize(candleHistory, StructureLength, 0);
      ArrayResize(fractions, StructureLength, 0);
      ArrayResize(fractionHistory[i - StructureLength].CandleFractions, StructureLength, 0);
      getCandleHistory(i, candleHistory);
      getFractions(candleHistory, fractions);
      ArrayCopy(fractionHistory[i - StructureLength].CandleFractions, fractions, 0, 0, WHOLE_ARRAY);
   }
}

void OnTick(){
   bool newCandle = detectNewCandle(timeframe);
   
   if(newCandle){
      if(EnableDebugInfo > 0){
         Print("\n\n!New Print!\n");
      }
      
      checkPositions();
      
      datetime time = TimeCurrent();
      MqlDateTime timeStruct;
      TimeToStruct(time, timeStruct);
      
      if(timeStruct.hour < 22 && timeStruct.hour > 0){
         Candles structureCandleData[];
         CandleFractions structureFractions[];
         ArrayResize(structureFractions, StructureLength, 0);
         ArrayResize(structureCandleData, StructureLength, 0);
         
         getCandleHistory(0, structureCandleData);
         getFractions(structureCandleData, structureFractions);
         
         for(int i = StructureLength; i < LookbackDistance; i++){
            //4.990.000 Aufrufe
            scores[i - StructureLength][0] = getScores(i - StructureLength, structureFractions);
            scores[i - StructureLength][1] = i;
         }
         ArraySort(scores);
         
         if(EnableDebugInfo > 0){
            Print("Array lenghths:\n",
                  "CurrentHistory: ", ArraySize(structureCandleData), "\n"
                  "CandleFractions: ", ArraySize(fractionHistory), "\n"
                  "CurrentCandleFractions: ", ArraySize(structureFractions), "\n",
                  "Scores: ", ArraySize(scores), "\n",
                  "PosArray: ", ArraySize(posArr));
            
            Print("Lowest score: ", scores[0][0], " at position: ", TimeToString(iTime(_Symbol,timeframe, (int)scores[0][1])), "\n",
                  "Second lowest score: ", scores[1][0], " at position: ", TimeToString(iTime(_Symbol,timeframe, (int)scores[1][1])), "\n",
                  "Third lowest score: ", scores[2][0], " at position: ", TimeToString(iTime(_Symbol,timeframe, (int)scores[2][1])), "\n",
                  "Fourth lowest score: ", scores[3][0], " at position: ", TimeToString(iTime(_Symbol,timeframe, (int)scores[3][1])), "\n",
                  "Fifth lowest score: ", scores[4][0], " at position: ", TimeToString(iTime(_Symbol,timeframe, (int)scores[4][1])), "\n");
         }
         
         double topScoreCloseVal = iClose(_Symbol, timeframe, (int)scores[0][1]);
         double topScorePlusXCloseVal = iClose(_Symbol, timeframe, (int)scores[0][1] - TradeLength);
         
         if(EnableDebugInfo > 0){
            Print("TopScoreCloseVal: ", topScoreCloseVal, "\nTopScorePlusXCloseVal: ", topScorePlusXCloseVal);
            Print("Buy Price Threshold: ", topScoreCloseVal + TradeThreshold * tradeTickSize, "\n",
                  "Sell Price Threshold: ", topScoreCloseVal - TradeThreshold * tradeTickSize);
         }
         
         if(topScorePlusXCloseVal > topScoreCloseVal + TradeThreshold * tradeTickSize){
            if(EnableDebugInfo > 1){
               Print("PosArr before: ");
               ArrayPrint(posArr);
            }
            
            posArrStruct positionData;
            positionData.scoreIndex = (int)scores[0][1];
            positionData.timeout = getTimeout(iTime(_Symbol, timeframe, 0) + TradeLength * timeframeVal * 60);
            positionHandler(open, positionData, buy);
         }
         else if(topScorePlusXCloseVal < topScoreCloseVal - TradeThreshold * tradeTickSize){
            if(EnableDebugInfo > 1){
               Print("PosArr before: ");
               ArrayPrint(posArr);
            }
            
            posArrStruct positionData;
            positionData.scoreIndex = (int)scores[0][1];
            positionData.timeout = getTimeout(iTime(_Symbol, timeframe, 0) + TradeLength * timeframeVal * 60);
            positionHandler(open, positionData, sell);
         }
         
         for(int i = 0; i < LookbackDistance - StructureLength - 1; i++){
            fractionHistory[i + 1] = fractionHistory[i];
         }
         ArrayCopy(fractionHistory[0].CandleFractions, structureFractions, 0, 0, WHOLE_ARRAY);
      }
   }
}

datetime getTimeout(datetime timeout){
   Print("Original Timeout: ", timeout);
   MqlDateTime timeoutStruct, currentTimeStruct;
   TimeToStruct(timeout, timeoutStruct);
   TimeToStruct(TimeCurrent(), currentTimeStruct);
      
   while(timeoutStruct.hour >= 22 || timeoutStruct.hour <= 0){
      timeout -= 60 * timeframeVal;
      TimeToStruct(timeout, timeoutStruct);
      Print("Rolling back\nCURRENT TIMEOUT: ", TimeToString(StructToTime(timeoutStruct)));
   }
   
   if(timeoutStruct.day_of_week == SATURDAY || timeoutStruct.day_of_week == SUNDAY){
      TimeToStruct(timeout + 60 * 2880, timeoutStruct);
      Print("Rolling forward\nCURRENT TIMOUT: ", TimeToString(StructToTime(timeoutStruct)));
   }

   return StructToTime(timeoutStruct);
}

double getScores(int idx, CandleFractions& currentCandleFractions[]){
   double cumScore = 0;
   
   for(int i = 0; i < StructureLength; i++){
      double totalScore = 0;
      
      if(CandleFractionsScoreCalculation){
         double bodySizeDiff = MathAbs(fractionHistory[idx].CandleFractions[i].bodySize - currentCandleFractions[i].bodySize);
         double lowerWickDiff = MathAbs(fractionHistory[idx].CandleFractions[i].lowerWickSize - currentCandleFractions[i].lowerWickSize);
         double upperWickDiff = MathAbs(fractionHistory[idx].CandleFractions[i].upperWickSize - currentCandleFractions[i].upperWickSize);
         totalScore = (bodySizeDiff + lowerWickDiff + upperWickDiff) / 3;
         
         if(EnableDebugInfo > 1){
            Print("Comparing Bar at Time: ", fractionHistory[idx].CandleFractions[i].timestamp, "\nwith\n",
               "Body: ", fractionHistory[idx].CandleFractions[i].bodySize, "\n",
               "Upper: ", fractionHistory[idx].CandleFractions[i].upperWickSize, "\n",
               "Lower: ", fractionHistory[idx].CandleFractions[i].lowerWickSize, "\n",
               "To: ", currentCandleFractions[i].timestamp, "\nwith\n",
               "Body: ", currentCandleFractions[i].bodySize, "\n",
               "Upper: ", currentCandleFractions[i].upperWickSize, "\n",
               "Lower: ", currentCandleFractions[i].lowerWickSize, "\n",
               "\nScore: ", totalScore, "\n");
         }
      }
      else{
         totalScore = MathAbs(fractionHistory[idx].CandleFractions[i].absoluteRangeFractions - currentCandleFractions[i].absoluteRangeFractions);
         
         if(EnableDebugInfo > 1){
            Print("Comparing Bar at Time: ", fractionHistory[idx].CandleFractions[i].timestamp, "\nwith\n",
               "AbsoluteRangeFraction: ", fractionHistory[idx].CandleFractions[i].absoluteRangeFractions, "\n",
               "To: ", currentCandleFractions[i].timestamp, "\nwith\n",
               "AbsoluteRangeFraction: ", currentCandleFractions[i].absoluteRangeFractions, "\n",
               "\nScore: ", totalScore, "\n");
         }
      }
      cumScore += totalScore;
   }
   return cumScore / StructureLength;
}

void getFractions(Candles& array[], CandleFractions& resArray[]){
   double max = 0;
   double min = DBL_MAX;
   
   for(int i = 0; i < StructureLength; i++){
      if(array[i].high > max) max = array[i].high;
      if(array[i].low < min) min = array[i].low;
   }
   double rangeSize = max - min;
   
   for(int i = 0; i < StructureLength; i++){
      resArray[i].timestamp = array[i].timestamp;
      
      if(CandleFractionsScoreCalculation){
         double bodySize = (array[i].close - array[i].open) / rangeSize;
         resArray[i].bodySize = bodySize;
         if(bodySize >= 0){
            resArray[i].upperWickSize = (array[i].high - array[i].close) / rangeSize;
            resArray[i].lowerWickSize = (array[i].low - array[i].open) / rangeSize;
         }
         else{
            resArray[i].upperWickSize = (array[i].high - array[i].open) / rangeSize;
            resArray[i].lowerWickSize = (array[i].low - array[i].close) / rangeSize;
         }
      }
      else {
         resArray[i].absoluteRangeFractions = (array[i].close + min) / rangeSize;
      }
   }
}

void getCandleHistory(int startIndex, Candles& candleHistory[]){
   for(int i = 1; i <= StructureLength; i++){
      candleHistory[i - 1].timestamp = iTime(_Symbol, timeframe, startIndex + i);
      candleHistory[i - 1].open = iOpen(_Symbol, timeframe, startIndex + i);
      candleHistory[i - 1].high = iHigh(_Symbol, timeframe, startIndex + i);
      candleHistory[i - 1].low = iLow(_Symbol, timeframe, startIndex + i);
      candleHistory[i - 1].close = iClose(_Symbol, timeframe, startIndex + i);
   }
}

void checkPositions(){
   checkIfOpenPositionsAreValid();
   checkForClosingConditions();
}

void checkForClosingConditions(){
   datetime time = iTime(_Symbol, timeframe, 0);
   for(int i = 0; i < ArraySize(posArr); i++){
      if(time >= posArr[i].timeout || !checkForScoreInTopScores(posArr[i])){
         if(EnableDebugInfo > 0){
            Print("Either position timed out or Position wasn't found at top relevant scores, closing position!");
         }
         positionHandler(close, posArr[i]);
         i--;
      }
   }
}

bool checkForScoreInTopScores(posArrStruct& position){
   for(int i = 0; i < TopScoreRelevancy; i++){
      if(scores[i][1] == position.scoreIndex){
         return true;
      }
   }
   
   if(EnableDebugInfo > 0){
      Print("Position with ticket ", position.ticket, " couldn't be found in relevant top Scores!");
      for(int i = 0; i < ArraySize(scores); i++){
         if(scores[i][1] == position.scoreIndex){
            Print("Position Index was found at index ", i, " of scores!");
            break;
         }
      }
   }
   return false;
}

void checkIfOpenPositionsAreValid(){
   int posArrIDX = 0;
   
   for(int i = 0; i < PositionsTotal(); i++){
      ulong ticket = PositionGetTicket(i);
      
      if(PositionGetString(POSITION_COMMENT) == PositionComment){
         posArrStruct position = posArr[posArrIDX];
         if(EnableDebugInfo > 0){
            Print("Found position at index ", i, " corresponding to position in array:\n",
                  "Ticket: ", position.ticket, "\n",
                  "Score Index: ", position.scoreIndex, "\n",
                  "Timeout: ", position.timeout);
         }
         
         if(ticket != position.ticket){
            if(EnableDebugInfo > 0){
               Print("Position isn't valid, ticket not matching posArr.ticket, closing position!");
            }
            positionHandler(close, position);
            i--;
         }
         else{
            if(EnableDebugInfo > 0){
               Print("Position is valid!");
            }
         }
         posArrIDX++;
      }
   }
}

void positionHandler(openclose openClose, posArrStruct& position, int direction = buy){
   if(openClose == open){
      if(direction == sell){
         trade.Sell(0.1, _Symbol, 0, 0, 0, PositionComment);
      }
      else if(direction == buy){
         trade.Buy(0.1, _Symbol, 0, 0, 0, PositionComment);
      }
      
      uint retcode = trade.ResultRetcode();
      Print(retcode);
      if(retcode == 10009){
         int size = ArraySize(posArr);
         
         if(EnableDebugInfo > 0){
            Print("RETCODE: ", retcode);
            Print("Old posArr size: ", size);
         }
         
         ArrayResize(posArr, size + 1, 0);
         position.ticket = trade.ResultOrder();
         posArr[size] = position;
         
         if(EnableDebugInfo > 0){
            Print("New posArr size: ", ArraySize(posArr));
            Print("New posArr entry:\n", 
                  "Ticket: ", posArr[size].ticket, "\n",
                  "Score Index: ", posArr[size].scoreIndex, "\n",
                  "Translates to Timestamp: ", TimeToString(iTime(_Symbol, timeframe, position.scoreIndex)), "\n",
                  "Timout: ", TimeToString(posArr[size].timeout));
         }
      }
   }
   else if(openClose == close){
      if(PositionSelectByTicket(position.ticket)){
         trade.PositionClose(position.ticket);
         int size = ArraySize(posArr);
         
         uint retcode = trade.ResultRetcode();
         Print(retcode);
         if(retcode == 10009){
            if(EnableDebugInfo > 0){
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
            
            if(EnableDebugInfo > 0){
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

bool detectNewCandle(ENUM_TIMEFRAMES candleTimeframe){
   MqlRates priceData[1];
   CopyRates(_Symbol, candleTimeframe, 0, 1, priceData);
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