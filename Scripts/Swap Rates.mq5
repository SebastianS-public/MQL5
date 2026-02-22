void OnStart(){
   int totalSymbols = SymbolsTotal(true);
   string fileString;
   string messageString;
   
   for(int i = 0; i < totalSymbols; i++){
      string symbolName = SymbolName(i, true);
      string swapLong = DoubleToString(SymbolInfoDouble(symbolName,SYMBOL_SWAP_LONG),2);
      string swapShort = DoubleToString(SymbolInfoDouble(symbolName,SYMBOL_SWAP_SHORT),2);
      fileString = fileString + symbolName + " " + swapLong + " " + swapShort +  "\n";
   }
   
   if(FileIsExist("SwapNew.txt")){
      FileDelete("SwapNew.txt");
   }
   
   int swapNewHandle = FileOpen("SwapNew.txt",FILE_READ|FILE_WRITE|FILE_ANSI|FILE_TXT);
   
   FileWrite(swapNewHandle,fileString);
   FileClose(swapNewHandle);
   
   if(FileIsExist("SwapOld.txt")){
      swapNewHandle = FileOpen("SwapNew.txt",FILE_READ|FILE_ANSI|FILE_TXT);
      int swapOldHandle = FileOpen("SwapOld.txt",FILE_READ|FILE_ANSI|FILE_TXT);
      
      while(!FileIsEnding(swapNewHandle)){
         string lineXNew = FileReadString(swapNewHandle);
         string lineXOld = FileReadString(swapOldHandle);
         if(lineXNew != lineXOld){
            messageString = messageString + lineXOld + " " + lineXNew + "\n";
         }
      }
      FileClose(swapNewHandle);
      FileClose(swapOldHandle);
   }
   
   FileCopy("SwapNew.txt",0,"SwapOld.txt",FILE_REWRITE);
   MessageBox(messageString);
}