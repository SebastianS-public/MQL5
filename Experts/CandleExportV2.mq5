input int TrainingDataSize = 10;
input datetime StartingTime;
input int LookbackDistance = 10;
input int TargetDistance = 10;
input ENUM_TIMEFRAMES Timeframe = PERIOD_M1;


struct CandleData{
   int size;
   int upperWickSize;
   int lowerWickSize;
   int tickVol;
   int lookbackVal;
   int targetVal;
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

// TODO: 
// Implement MACD Indicator: Check for Indicator Specs through EA
// Implement Support/Resistance Bands in either M1/M5/M15
int OnInit(){
   int filehandle = FileOpen("test.csv", FILE_WRITE | FILE_CSV | FILE_COMMON);
   if(filehandle == INVALID_HANDLE){
      MessageBox("Error opening file!");
      return(INIT_FAILED);
   }
   
   int shift = iBarShift(_Symbol, Timeframe, StartingTime, false);
   int startIndex = shift + TrainingDataSize;
   int bytes = int(FileWriteString(filehandle, "totalRows:       \n" + 
      TimeToString(StartingTime) + "," + TimeToString(iTime(_Symbol,Timeframe, startIndex)) + "\n" + 
      "bar_size,upper_wick_size,lower_wick_size,tick_volume,lookback_val,dist_to_ma_20_m1," +
      "prev_dist_to_prev_ma_20_m1,dist_to_ma_20_h1,cci_Value,rsi_Value,target_val\n"));
   int maHandle20M1 = iMA(_Symbol, Timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   int maHandle20H1 = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   int cciHandle25 = iCCI(_Symbol, Timeframe, 25, PRICE_TYPICAL);
   int rsiHandle14 = iRSI(_Symbol, Timeframe, 14, PRICE_CLOSE);
   CopyBuffer(maHandle20M1, 0, shift + 1, TrainingDataSize + 1, maArray20M1);
   CopyBuffer(cciHandle25, 0, shift + 1, TrainingDataSize, cciArray25);
   CopyBuffer(rsiHandle14, 0, shift + 1, TrainingDataSize, rsiArray14);
   
   int rowCounter = 0;
   int progCounter = 0;
   for(int i = startIndex; i > startIndex - TrainingDataSize; i--){
      MqlDateTime timestruct;
      TimeToStruct(iTime(_Symbol, Timeframe, i), timestruct);
      
      if(timestruct.hour < 22 && timestruct.hour > 1){
         CopyBuffer(maHandle20H1, 0, iTime(_Symbol, Timeframe, i), 2, maArray20H1);
         CandleData data = getCandleData(i, progCounter);
         
         if(data.targetVal < -50000){
            MessageBox("Error! Tried to access bars from the future!");
            return(INIT_PARAMETERS_INCORRECT);
         }
         
         string file_string = IntegerToString(data.size) + "," +
                              IntegerToString(data.upperWickSize) + "," +
                              IntegerToString(data.lowerWickSize) + "," +
                              IntegerToString(data.tickVol) + "," + 
                              IntegerToString(data.lookbackVal) + "," +
                              DoubleToString(data.distToMa20M1) + "," +
                              DoubleToString(data.prevDistToPrevMa20M1) + "," +
                              DoubleToString(data.distToMa20H1) + "," +
                              DoubleToString(data.cciValue) + "," +
                              DoubleToString(data.rsiValue) + "," +
                              IntegerToString(data.targetVal) + "\n";
         
         FileSeek(filehandle, 0, SEEK_END);
         bytes += int(FileWriteString(filehandle, file_string));
         rowCounter++;
      }
      if(progCounter % 10000 == 0){
            Print(NormalizeDouble(progCounter / float(TrainingDataSize), 2));
      }
      progCounter++;
   }
   FileSeek(filehandle, 2, SEEK_SET);
   FileWriteString(filehandle, "totalRows:" + IntegerToString(rowCounter));
   FileClose(filehandle);
   Print("File successfully saved! " + IntegerToString(bytes) + " Bytes Written!");
   MessageBox("File successfully saved, " + IntegerToString(bytes) + " Bytes written!");
   return(INIT_FAILED);
}

CandleData getCandleData(int i, int progCounter){
   CandleData data;
   double symbolTickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double open = iOpen(_Symbol, Timeframe, i);
   double high = iHigh(_Symbol, Timeframe, i);
   double low = iLow(_Symbol, Timeframe, i);
   double close = iClose(_Symbol, Timeframe, i);
   data.size = int(round((close - open) / symbolTickSize));
   data.tickVol = int(iTickVolume(_Symbol, Timeframe, i));
   data.lookbackVal = int((close - iClose(_Symbol, Timeframe, i + LookbackDistance)) / symbolTickSize);
   data.targetVal = int((iOpen(_Symbol, Timeframe, i - TargetDistance) - close) / symbolTickSize);
   data.distToMa20M1 = (close - maArray20M1[progCounter+1]) / symbolTickSize;
   data.prevDistToPrevMa20M1 = (iClose(_Symbol, Timeframe, i + 1) - maArray20M1[progCounter]) / symbolTickSize;
   data.distToMa20H1 = (close - maArray20H1[0]) / symbolTickSize;
   data.cciValue = cciArray25[progCounter];
   data.rsiValue = rsiArray14[progCounter];
   
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