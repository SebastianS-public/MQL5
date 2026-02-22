input int TrainingDataSize = 10;
input datetime StartingTime;
input int Lookback = 10;
input int TargetDistance = 10;


// TODO: 
// Implement Moving Average Indicators:
// 1: MA Min1 Period 20, Distance Price to MA Value
// 2: MA Min1 Period 20, Distance Price previous to MA Value
// 3: MA Hour1 Period 20, Distance Price to MA Value
// Implement CCI Indicator: Check for Indicator Specs through CCI Grid or another EA
// Implement RSI Indicator: Check for Indicator Specs through EA
// Implement MACD Indicator: Check for Indicator Specs through EA
// Implement Support/Resistance Bands in either M1/M5/M15
int OnInit(){
   int filehandle = FileOpen("test.csv", FILE_WRITE | FILE_CSV | FILE_COMMON);
   if(filehandle == INVALID_HANDLE){
      MessageBox("Error opening file!");
      return(INIT_FAILED);
   }
   
   int shift = iBarShift(_Symbol, PERIOD_CURRENT, StartingTime, false);
   int startIndex = shift + TrainingDataSize;
   int bytes = int(FileWriteString(filehandle, "totalRows:       \n" + 
      TimeToString(StartingTime) + "," + TimeToString(iTime(_Symbol,PERIOD_CURRENT, startIndex)) + "\n" + 
      "bar_size,upper_wick_size,lower_wick_size,tick_volume,lookback_val,target_val\n"));
   
   int rowCounter = 2;
   double symbolTickSize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   for(int i = startIndex; i > startIndex - TrainingDataSize; i--){
      MqlDateTime timestruct;
      TimeToStruct(iTime(_Symbol, PERIOD_CURRENT, i), timestruct);
      if(timestruct.hour < 22 && timestruct.hour > 1){
         double open = iOpen(_Symbol, PERIOD_CURRENT, i);
         double high = iHigh(_Symbol, PERIOD_CURRENT, i);
         double low = iLow(_Symbol, PERIOD_CURRENT, i);
         double close = iClose(_Symbol, PERIOD_CURRENT, i);
         int size = int(round((close - open) / symbolTickSize));
         int tick_vol = int(iTickVolume(_Symbol, PERIOD_CURRENT, i));
         int lookback_val = int((iClose(_Symbol, PERIOD_CURRENT, i + Lookback) - close) / symbolTickSize);
         int target_val = int((iOpen(_Symbol, PERIOD_CURRENT, i - TargetDistance) - close) / symbolTickSize);
         if(target_val < -50000){
            MessageBox("Error! Tried to access bars from the future!");
            return(INIT_PARAMETERS_INCORRECT);
         }
         
         int upperWickSize, lowerWickSize;
         if(open < close){
            upperWickSize = int(round((high - close) / symbolTickSize));
            lowerWickSize = int(round((open - low) / symbolTickSize));
         }
         else{
            upperWickSize = int(round((high - open) / symbolTickSize));
            lowerWickSize = int(round((close - low) / symbolTickSize));
         }
         
         if(target_val > -30 && target_val < 30){
            target_val = 0;
         }
         else if(target_val > 30){
            target_val = 1;
         }
         else{
            target_val = 2;
         }
         
         string file_string = IntegerToString(size) + "," +
                              IntegerToString(upperWickSize) + "," +
                              IntegerToString(lowerWickSize) + "," +
                              IntegerToString(tick_vol) + "," + 
                              IntegerToString(lookback_val) + "," +
                              IntegerToString(target_val) + "\n";
         
         FileSeek(filehandle, 0, SEEK_END);
         bytes += int(FileWriteString(filehandle, file_string));
         rowCounter++;
         if(i % 10000 == 0){
            Print(NormalizeDouble(MathAbs((i - TrainingDataSize - shift) / float(TrainingDataSize)), 2));
         }
      }
   }
   FileSeek(filehandle, 2, SEEK_SET);
   FileWriteString(filehandle, "totalRows:" + IntegerToString(rowCounter));
   FileClose(filehandle);
   Print("File successfully saved! " + IntegerToString(bytes) + " Bytes Written!");
   MessageBox("File successfully saved, " + IntegerToString(bytes) + " Bytes written!");
   return(INIT_FAILED);
}