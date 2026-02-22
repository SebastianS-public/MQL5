void OnStart(){
   double swapValueShort;
   double swapValueLong;
   string message;
   double totalDailySwaps = 0;
   double totalSwaps = 0;
   for(int x=0;x<PositionsTotal();x++){
      string symbol = PositionGetSymbol(x);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
         swapValueLong = SymbolInfoDouble(symbol,SYMBOL_SWAP_LONG) * SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE) * PositionGetDouble(POSITION_VOLUME);
         totalDailySwaps = totalDailySwaps + swapValueLong;
         message = message + symbol + ": " + DoubleToString(swapValueLong,2) + "\n";
         totalSwaps = totalSwaps + PositionGetDouble(POSITION_SWAP);
      }
      else{
         swapValueShort = SymbolInfoDouble(symbol,SYMBOL_SWAP_SHORT) * SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE) * PositionGetDouble(POSITION_VOLUME);
         totalDailySwaps = totalDailySwaps + swapValueShort;
         message = message + symbol + ": " + DoubleToString(swapValueShort,2) + "\n";
         totalSwaps = totalSwaps + PositionGetDouble(POSITION_SWAP);
      }
   }
   MessageBox(message + "\n\n" + "Total Swaps per Day: " + DoubleToString(totalDailySwaps,2));
}