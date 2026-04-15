#property script_show_inputs

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // Timeframe
input datetime InpStartDate = D'2023.01.01 00:00';  // Start Date
input datetime InpEndDate = D'2024.01.01 00:00';    // End Date

void OnStart() {
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, InpTimeframe, InpStartDate, InpEndDate, rates);
   if (copied <= 0) {
      Print("Error copying price data. Please ensure data is available. Error code: ", GetLastError());
      return;
   }

   if (copied < 2) {
      Print("Not enough candles found in the selected date range. Found: ", copied);
      return;
   }

   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if (pointSize == 0.0) {
      Print("Error retrieving the point size for the symbol.");
      return;
   }

   long cumulativeGapPoints = 0;
   for (int i = 1; i < copied; i++) {
      double rawGap = rates[i].open - rates[i - 1].close;
      long gapInPoints = (long)MathRound(rawGap / pointSize);
      cumulativeGapPoints += gapInPoints;
   }

   PrintFormat("--- Gap Calculation Report ---");
   PrintFormat("Symbol: %s | Timeframe: %s", _Symbol, EnumToString(InpTimeframe));
   PrintFormat("Period: %s to %s", TimeToString(InpStartDate), TimeToString(InpEndDate));
   PrintFormat("Candles Processed: %d", copied);
   PrintFormat("Cumulative Gap: %d points", cumulativeGapPoints);
   PrintFormat("------------------------------");
}