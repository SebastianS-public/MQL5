#include <Trade/Trade.mqh>
CTrade trade;

enum RiskManagementMode{
   RiskPercentage,
   RiskPercentageStartAccount,
   FixedLotSize,
   FixedRiskMoney
};

input group "Time Settings"
input int StartMinutesAfterMidnight = 120;
input int EndMinutesAfterStart = 240;
input int CloseTradesHour = 21;

input group "Lot Size Settings"
input RiskManagementMode UseRiskManagement = RiskPercentage;
input double RiskInPercent = 1.0;
input double RiskInPercentStartAccount = 1.0;
input double LotSizeFixed = 1.04;
input double RiskMoneyFixed = 500;

input group "Trade Settings"
input bool UseTakeProfit = true;
input double TPMultiplier = 1;
input double SLMultiplier = 1;
input bool BiDirectionalTrading = true;

input group "Additional Settings"
input string TradeComment = "Enter Comment";
input bool Logs = false;
input bool PrintOnChart = false;
input bool ExportBacktestHistory = false;
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;


int normalizeStep;
double high = 0, low = 0;
string currentSymbol;
double fixedRiskMoney;
datetime closeTime, startTime, endTime;
bool tradesToday = false;
bool firstTick = true;
string commentString;

int OnInit(){
   currentSymbol = Symbol();
   if(SymbolInfoDouble(currentSymbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if(SymbolInfoDouble(currentSymbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
   }
   if(UseRiskManagement == RiskPercentageStartAccount){
      fixedRiskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercentStartAccount / 100;
   }
   else if(UseRiskManagement == FixedRiskMoney){
      fixedRiskMoney = RiskMoneyFixed;
   }
   if(StartMinutesAfterMidnight + EndMinutesAfterStart > (CloseTradesHour - 1) * 60){
      return INIT_PARAMETERS_INCORRECT;
   }
   return INIT_SUCCEEDED;
}

void OnTick(){
   bool newCandle = detectNewCandle(Timeframe);
   
   if(newCandle){
      bool newDay = detectNewDayCandle(PERIOD_D1);
      ulong positionTicket = getOpenPositionTicket();
      bool openOrders = checkOrders();
      datetime currentTime = TimeCurrent();
      
      if(newDay){
         if(currentTime > closeTime && (positionTicket != 0 || openOrders)){
            if(positionTicket != 0){
               closePosition(positionTicket);
            }
            if(openOrders){
               deleteOrders();
            }
         }
         high = 0;
         low = 0;
         getTimes(StartMinutesAfterMidnight, EndMinutesAfterStart, CloseTradesHour, TimeCurrent());
         tradesToday = false;
      }
      
      if((positionTicket != 0 || openOrders) && currentTime >= closeTime){
         if(positionTicket != 0){
            closePosition(positionTicket);
         }
         if(openOrders){
            deleteOrders();
         }
      }
      
      if(currentTime >= endTime && currentTime <= closeTime && high == 0 && low == 0){
         int numberBars = Bars(currentSymbol, Timeframe, startTime, endTime);
         int offset = Bars(currentSymbol, Timeframe, TimeCurrent(), endTime) - 1;
         high = iHigh(currentSymbol, Timeframe, iHighest(currentSymbol, Timeframe, MODE_HIGH, numberBars, offset));
         low = iLow(currentSymbol, Timeframe, iLowest(currentSymbol, Timeframe, MODE_LOW, numberBars, offset));
         if(Logs){
            Print("High: ", high, " Low: ", low, " Offset: ", offset);
         }
      }
      
      if(high != 0 && low != 0 && !openOrders && !tradesToday){
         executeOrdersTrades();
         tradesToday = true;
      }
      if(PrintOnChart){
         commentString = "";
         checkTradeObjects();
         commentString = "\n\n\n" + TradeComment + "\nStart time today: " + TimeToString(startTime) + 
                         "\nEnd time today: " + TimeToString(endTime) + "\nHigh: " + (string)high + "\nLow: " + (string)low;
         Comment(commentString);
      }
   }
}

void OnTrade(){
   ulong positionTicket = getOpenPositionTicket();
   if(!BiDirectionalTrading && positionTicket != 0){
      deleteOrders();
   }
}

double OnTester(){
   if (ExportBacktestHistory) {
      exportBacktestHistory();
   }
   double metric = 0.0;
   metric = TesterStatistics(STAT_SHARPE_RATIO) * (TesterStatistics(STAT_PROFIT) / (TesterStatistics(STAT_EQUITY_DD) / 4500)) / 100000;
   return metric;
}

void exportBacktestHistory(){
   // File operations
   Print("executing backtest export");
   string filename = TradeComment + ".csv";
   int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   Print("Filename: ", filename, " Filehandle: ", fileHandle);
   if(fileHandle == INVALID_HANDLE) {
      Print("Error opening file ", filename, ". Error code: ", GetLastError());
      return;
   }
   
   // --- Write the CSV Header Row
   uint bytes = FileWrite(fileHandle,
             "Position ID", "Symbol", "Volume", "Direction",
             "Open Price", "Close Price", "Open Time", "Close Time",
             "Commission", "Swap", "Profit", "Comment");
   Print("header bytes written: ", bytes);
             
   // --- Select the entire trade history for the account
   if(!HistorySelect(0, TimeCurrent())) {
      Print("Failed to select history!");
      FileClose(fileHandle);
      return;
   }
      
   // --- Step 1: Collect all unique position IDs from the deal history
   ulong unique_position_ids[];
   int unique_ids_count = 0;
   uint totalDeals = HistoryDealsTotal();

   for(uint i = 0; i < totalDeals; i++) {
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0) continue;

      ulong positionID = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      if(positionID == 0) continue;

      // Check if the ID is already in our list
      bool found = false;
      for(int j = 0; j < unique_ids_count; j++) {
         if(unique_position_ids[j] == positionID) {
            found = true;
            break;
         }
      }

      // If not found, add it to the list
      if(!found) {
         ArrayResize(unique_position_ids, unique_ids_count + 1);
         unique_position_ids[unique_ids_count] = positionID;
         unique_ids_count++;
      }
   }

   // --- Step 2: Process each unique position
   for(int i = 0; i < unique_ids_count; i++) {
      ulong positionID = unique_position_ids[i];

      // --- Now, get all details for this position
      string     symbol          = "";
      double     volume          = 0;
      long       position_type   = 0;
      string     comment         = "";
      double     openPrice       = 0;
      datetime   openTime        = 0;
      double     closePrice      = 0;
      datetime   closingTime       = 0;
      double     totalCommission = 0;
      double     totalSwap       = 0;
      double     totalProfit     = 0;
      double     weighted_price_sum = 0;

      // Select all deals for the current position ID
      if(HistorySelectByPosition(positionID)) {
         uint deals_in_position = HistoryDealsTotal();
         for(uint j = 0; j < deals_in_position; j++) {
            ulong pos_deal_ticket = HistoryDealGetTicket(j);
            if(pos_deal_ticket == 0)
               continue;

            // --- On the first deal, get common information
            if (j == 0) {
                symbol = HistoryDealGetString(pos_deal_ticket, DEAL_SYMBOL);
                position_type = HistoryDealGetInteger(pos_deal_ticket, DEAL_TYPE);
                comment = HistoryDealGetString(pos_deal_ticket, DEAL_COMMENT);
            }

            long deal_entry = HistoryDealGetInteger(pos_deal_ticket, DEAL_ENTRY);
            double deal_volume = HistoryDealGetDouble(pos_deal_ticket, DEAL_VOLUME);
            double deal_price = HistoryDealGetDouble(pos_deal_ticket, DEAL_PRICE);
            datetime deal_time = (datetime)HistoryDealGetInteger(pos_deal_ticket, DEAL_TIME);

            totalCommission += HistoryDealGetDouble(pos_deal_ticket, DEAL_COMMISSION);
            totalSwap       += HistoryDealGetDouble(pos_deal_ticket, DEAL_SWAP);
            totalProfit     += HistoryDealGetDouble(pos_deal_ticket, DEAL_PROFIT);

            // Capture opening details from "IN" deals
            if(deal_entry == DEAL_ENTRY_IN) {
               if(openTime == 0 || deal_time < openTime) {
                  openTime = deal_time;
               }
               volume += deal_volume;
               weighted_price_sum += deal_price * deal_volume;
            }
            // Aggregate closing details from "OUT" deals
            else if(deal_entry == DEAL_ENTRY_OUT) {
               if(deal_time > closeTime) {
                  closingTime = deal_time;
                  closePrice = deal_price;
               }
            }
         }
      }

      if(volume > 0) {
          openPrice = weighted_price_sum / volume;
      }

      string direction = (position_type == DEAL_TYPE_BUY) ? "Long" : "Short";

      // --- Write the collected data for this position to the file
      FileWrite(fileHandle,
                (string)positionID,
                symbol,
                DoubleToString(volume, 2),
                direction,
                DoubleToString(openPrice, 5),
                DoubleToString(closePrice, 5),
                TimeToString(openTime, TIME_DATE | TIME_SECONDS),
                TimeToString(closingTime, TIME_DATE | TIME_SECONDS),
                DoubleToString(totalCommission, 2),
                DoubleToString(totalSwap, 2),
                DoubleToString(totalProfit, 2),
                comment);
   }

   // --- Close the file handle
   FileClose(fileHandle);
   MessageBox("Export Successful!");
}

void checkTradeObjects(){
   HistorySelect(TimeCurrent() - 60 * 60 * 24 * 7, TimeCurrent());
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++){
      HistorySelect(TimeCurrent() - 60 * 60 * 24 * 7, TimeCurrent());
      ulong dealTicket = HistoryDealGetTicket(i);
      if(HistoryDealGetString(dealTicket, DEAL_COMMENT) == TradeComment){
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         string dealTimeString = TimeToString(dealTime, TIME_DATE|TIME_MINUTES);
         double dealPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         ulong dealPositionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         if(HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_BUY){
            if(ObjectFind(0, "BuySign" + TradeComment + dealTimeString) < 0){
               ObjectCreate(0, "BuySign" + TradeComment + dealTimeString, OBJ_ARROW_BUY, 0, dealTime, dealPrice);
            }
            HistorySelectByPosition(dealPositionID);
            int positionDeals = HistoryDealsTotal();
            if(positionDeals == 2){
               for(int j = 0; j < positionDeals; j++){
                  ulong positionDealTicket = HistoryDealGetTicket(j);
                  if(   HistoryDealGetInteger(positionDealTicket, DEAL_TYPE) == DEAL_TYPE_SELL &&
                        ObjectFind(0, "EntryExitConnect" + TradeComment + dealTimeString) < 0){
                     datetime positionDealTime = (datetime)HistoryDealGetInteger(positionDealTicket, DEAL_TIME);
                     string positionDealTimeString = TimeToString(positionDealTime, TIME_DATE|TIME_MINUTES);
                     double positionDealPrice = HistoryDealGetDouble(positionDealTicket, DEAL_PRICE);
                     ObjectCreate(0, "SellSign" + TradeComment + positionDealTimeString, OBJ_ARROW_SELL, 0, positionDealTime, positionDealPrice);
                     ObjectCreate(0, "EntryExitConnect" + TradeComment + dealTimeString, OBJ_TREND, 0, dealTime, dealPrice, positionDealTime, positionDealPrice);
                     ObjectSetInteger(0, "EntryExitConnect" + TradeComment + dealTimeString, OBJPROP_STYLE, STYLE_DASH);
                     ObjectSetInteger(0, "EntryExitConnect" + TradeComment + dealTimeString, OBJPROP_COLOR, C'255,0,0');
                  }
               }
            }
         }
         if(HistoryDealGetInteger(dealTicket, DEAL_TYPE) == DEAL_TYPE_SELL){
            if(ObjectFind(0, "SellSign" + TradeComment + dealTimeString) < 0){
               ObjectCreate(0, "SellSign" + TradeComment + dealTimeString, OBJ_ARROW_SELL, 0, dealTime, dealPrice);
            }
            HistorySelectByPosition(dealPositionID);
            int positionDeals = HistoryDealsTotal();
            if(positionDeals == 2){
               for(int j = 0; j < positionDeals; j++){
                  ulong positionDealTicket = HistoryDealGetTicket(j);
                  if(   HistoryDealGetInteger(positionDealTicket, DEAL_TYPE) == DEAL_TYPE_BUY &&
                        ObjectFind(0, "EntryExitConnect" + TradeComment + dealTimeString) < 0){
                     datetime positionDealTime = (datetime)HistoryDealGetInteger(positionDealTicket, DEAL_TIME);
                     string positionDealTimeString = TimeToString(positionDealTime, TIME_DATE|TIME_MINUTES);
                     double positionDealPrice = HistoryDealGetDouble(positionDealTicket, DEAL_PRICE);
                     ObjectCreate(0, "BuySign" + TradeComment + positionDealTimeString, OBJ_ARROW_BUY, 0, positionDealTime, positionDealPrice);
                     ObjectCreate(0, "EntryExitConnect" + TradeComment + dealTimeString, OBJ_TREND, 0, dealTime, dealPrice, positionDealTime, positionDealPrice);
                     ObjectSetInteger(0, "EntryExitConnect" + TradeComment + dealTimeString, OBJPROP_STYLE, STYLE_DASH);
                     ObjectSetInteger(0, "EntryExitConnect" + TradeComment + dealTimeString, OBJPROP_COLOR, C'255,0,0');
                  }
               }
            }
         }
      }
   }
}

void deleteOrders(){
   int orders = OrdersTotal();
   for(int i = 0; i < orders; i++){
      ulong ticket = OrderGetTicket(i);
      if(OrderGetString(ORDER_COMMENT) == TradeComment){
         trade.OrderDelete(ticket);
         Sleep(500);
      }
   }
}

void closePosition(ulong ticket){
   trade.PositionClose(ticket);
}

void placeBuyStop(double price, double stopLoss, double takeProfit, double volume){
   volume = NormalizeDouble(volume, normalizeStep);
   trade.BuyStop(volume, price, currentSymbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, TradeComment);
}

void placeSellStop(double price, double stopLoss, double takeProfit, double volume){
   volume = NormalizeDouble(volume, normalizeStep);
   trade.SellStop(volume, price, currentSymbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, TradeComment);
}

void executeBuy(double stopLoss, double takeProfit, double volume){
   volume = NormalizeDouble(volume, normalizeStep);
   trade.Buy(volume, currentSymbol, 0, stopLoss, takeProfit, TradeComment);
}

void executeSell(double stopLoss, double takeProfit, double volume){
   volume = NormalizeDouble(volume, normalizeStep);
   trade.Sell(volume, currentSymbol, 0, stopLoss, takeProfit, TradeComment);
}

double getLotSize(double stopLossPoints){
   double volumeStep = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_STEP);
   double tickvalue = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE) * SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_CONTRACT_SIZE) / 
                      SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
   
   if(UseRiskManagement == FixedLotSize){
      if(LotSizeFixed < volumeStep){
         return volumeStep;
      }
      else{
         return LotSizeFixed;
      }
   }
   else if(UseRiskManagement == RiskPercentage){
      double volume = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent / 100) / (stopLossPoints * tickvalue * volumeStep) * volumeStep;
      return volume;
   }
   else{
      return fixedRiskMoney / (stopLossPoints * tickvalue);
   }
}

void executeOrdersTrades(){
   double range = high - low;
   double buySl = high - range * SLMultiplier;
   double sellSl = low + range * SLMultiplier;
   double buyTp = 0, sellTp = 0;
   if(UseTakeProfit){
      buyTp = high + range * TPMultiplier;
      sellTp = low - range * TPMultiplier;
   }
   double volume = getLotSize((high - buySl) / SymbolInfoDouble(currentSymbol,SYMBOL_TRADE_TICK_SIZE));
   
   if(SymbolInfoDouble(currentSymbol,SYMBOL_ASK) < high - 10 * SymbolInfoDouble(currentSymbol,SYMBOL_TRADE_TICK_SIZE)){
      placeBuyStop(high, buySl, buyTp, volume);
   }
   else{
      executeBuy(buySl, buyTp, volume);
   }
   if(SymbolInfoDouble(currentSymbol,SYMBOL_BID) > low + 10 * SymbolInfoDouble(currentSymbol,SYMBOL_TRADE_TICK_SIZE)){
      placeSellStop(low, sellSl, sellTp, volume);
   }
   else{
      executeSell(sellSl, sellTp, volume);
   }
   if(PrintOnChart){
      printRanges(buyTp, buySl, sellTp, sellSl);
   }
}

void printRanges(double position1TP, double position1SL, double position2TP, double position2SL){
   ObjectCreate(0, "RangeWindow" + TradeComment + TimeToString(startTime, TIME_DATE|TIME_MINUTES), OBJ_RECTANGLE, 0, startTime, high, endTime, low);
   ObjectSetInteger(0, "RangeWindow" + TradeComment + TimeToString(startTime, TIME_DATE|TIME_MINUTES), OBJPROP_BACK, true);
   ObjectSetInteger(0, "RangeWindow" + TradeComment + TimeToString(startTime, TIME_DATE|TIME_MINUTES), OBJPROP_FILL, true);
   ObjectSetInteger(0, "RangeWindow" + TradeComment + TimeToString(startTime, TIME_DATE|TIME_MINUTES), OBJPROP_COLOR, C'69,50,50');
   
   string endTimeString = TimeToString(endTime, TIME_DATE|TIME_MINUTES);
   if(UseTakeProfit){
      ObjectCreate(0, "TPLine1" + TradeComment + endTimeString, OBJ_TREND, 0, endTime, position1TP, closeTime, position1TP);
      ObjectSetInteger(0, "TPLine1" + TradeComment + endTimeString, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "TPLine1" + TradeComment + endTimeString, OBJPROP_COLOR, C'0,255,0');
      ObjectCreate(0, "TPLine2" + TradeComment + endTimeString, OBJ_TREND, 0, endTime, position2TP, closeTime, position2TP);
      ObjectSetInteger(0, "TPLine2" + TradeComment + endTimeString, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "TPLine2" + TradeComment + endTimeString, OBJPROP_COLOR, C'0,255,0');
   }
   ObjectCreate(0, "SLLine1" + TradeComment + endTimeString, OBJ_TREND, 0, endTime, position1SL, closeTime, position1SL);
   ObjectSetInteger(0, "SLLine1" + TradeComment + endTimeString, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "SLLine1" + TradeComment + endTimeString, OBJPROP_COLOR, C'255,0,0');
   ObjectCreate(0, "SLLine2" + TradeComment + endTimeString, OBJ_TREND, 0, endTime, position2SL, closeTime, position2SL);
   ObjectSetInteger(0, "SLLine2" + TradeComment + endTimeString, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "SLLine2" + TradeComment + endTimeString, OBJPROP_COLOR, C'255,0,0');
}

bool checkOrders(){
   int orders = OrdersTotal();
   if(orders == 0){
      return false;
   }
   else{
      for(int i = 0; i < orders; i++){
         ulong ticket = OrderGetTicket(i);
         if(OrderGetString(ORDER_COMMENT) == TradeComment){
            return true;
         }
      }
   }
   return false;
}

ulong getOpenPositionTicket(){
   int positions = PositionsTotal();
   if(positions == 0){
      return 0;
   }
   else{
      for(int i = 0; i < positions; i++){
         ulong ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_COMMENT) == TradeComment){
            return ticket;
         }
      }
      return 0;
   }
}

void getTimes(int startMinAfterMidnight, int endMinAfterStart, int closeTrades, datetime time){
   MqlDateTime structTime;
   TimeToStruct(time, structTime);
   
   string timeString, closeTimeString;

   StringConcatenate(timeString, structTime.year, ".", structTime.mon, ".", structTime.day, " 00:00");
   startTime = StringToTime(timeString) + startMinAfterMidnight * 60;
   endTime = startTime + endMinAfterStart * 60;
   StringConcatenate(closeTimeString, structTime.year, ".", structTime.mon, ".", structTime.day, " ", closeTrades, ":00");
   closeTime = StringToTime(closeTimeString);
   
   if(Logs){
      Print("Start Time Today: ", startTime, "\nEnd Time Today: ", endTime, "\nClose Time Today: ", closeTime);
   }
}

bool detectNewCandle(ENUM_TIMEFRAMES candleTimeframe){
   MqlRates priceData[1];
   CopyRates(currentSymbol,candleTimeframe,0,1,priceData);
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

bool detectNewDayCandle(ENUM_TIMEFRAMES candleTimeframe){
   MqlRates priceData[1];
   CopyRates(currentSymbol,candleTimeframe,0,1,priceData);
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