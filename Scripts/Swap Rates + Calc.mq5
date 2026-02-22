void OnStart(){
   int totalSymbols = SymbolsTotal(true);
   string fileString;
   string messageString;
   double swapValueShort;
   double swapValueLong;
   string calcMessage;
   double totalDailySwaps = 0;
   double totalSwaps = 0;
   
   for(int i = 0; i < totalSymbols; i++){
      string symbolName = SymbolName(i, true);
      string swapLong = DoubleToString(SymbolInfoDouble(symbolName,SYMBOL_SWAP_LONG),2);
      string swapShort = DoubleToString(SymbolInfoDouble(symbolName,SYMBOL_SWAP_SHORT),2);
      fileString = fileString + symbolName + " " + swapLong + " " + swapShort +  "\n";
   }
   
   for(int x=0;x<PositionsTotal();x++){
      string symbol = PositionGetSymbol(x);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
         swapValueLong = SymbolInfoDouble(symbol,SYMBOL_SWAP_LONG) * SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE) * PositionGetDouble(POSITION_VOLUME);
         totalDailySwaps = totalDailySwaps + swapValueLong;
         calcMessage = calcMessage + symbol + ": " + DoubleToString(swapValueLong,2) + "\n";
         totalSwaps = totalSwaps + PositionGetDouble(POSITION_SWAP);
      }
      else{
         swapValueShort = SymbolInfoDouble(symbol,SYMBOL_SWAP_SHORT) * SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE) * PositionGetDouble(POSITION_VOLUME);
         totalDailySwaps = totalDailySwaps + swapValueShort;
         calcMessage = calcMessage + symbol + ": " + DoubleToString(swapValueShort,2) + "\n";
         totalSwaps = totalSwaps + PositionGetDouble(POSITION_SWAP);
      }
   }
   calcMessage = calcMessage + "\nTotal Swaps per Day: " + DoubleToString(totalDailySwaps,2);
   messageString = calcMessage + "\nTotal swaps: " + DoubleToString(totalSwaps,2) + "\n\n";
   
   fileString = fileString + calcMessage;
   
   if(FileIsExist("SwapNewCalc.txt")){
      FileDelete("SwapNewCalc.txt");
   }
   
   int swapNewHandle = FileOpen("SwapNewCalc.txt",FILE_READ|FILE_WRITE|FILE_ANSI|FILE_TXT);
   
   FileWrite(swapNewHandle,fileString);
   FileClose(swapNewHandle);
   
   if(FileIsExist("SwapOldCalc.txt")){
      swapNewHandle = FileOpen("SwapNewCalc.txt",FILE_READ|FILE_ANSI|FILE_TXT);
      int swapOldHandle = FileOpen("SwapOldCalc.txt",FILE_READ|FILE_ANSI|FILE_TXT);
      
      while(!FileIsEnding(swapNewHandle)){
         string lineXNew = FileReadString(swapNewHandle);
         string lineXOld = FileReadString(swapOldHandle);
         if(lineXNew != lineXOld){
            messageString = messageString + "Old: " + lineXOld + " New: " + lineXNew + "\n";
         }
      }
      FileClose(swapNewHandle);
      FileClose(swapOldHandle);
   }
   
   FileCopy("SwapNewCalc.txt",0,"SwapOldCalc.txt",FILE_REWRITE);
   MessageBox(messageString);
}