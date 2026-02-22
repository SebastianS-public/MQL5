input double trendFilter = 10;
void OnTick(){
   bool isTrend = isTrend();
}

bool isTrend(){
   double ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   double maArray[];
   int ma = iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_EMA,PRICE_CLOSE);
   ArraySetAsSeries(maArray,true);
   CopyBuffer(ma,0,0,10,maArray);
   double maTrendValue = maArray[0] - maArray[9];
   bool isTrend = false;
   if(maTrendValue > trendFilter || maTrendValue < 0 - trendFilter){
      isTrend = true;
   }
   return isTrend;
}