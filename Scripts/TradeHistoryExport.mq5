#property script_show_inputs

input datetime StartDate;
input datetime EndDate;

void OnStart() {
   
   // File operations
   string filename = "TradeHistory_Export.csv";
   int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV, ',');
   if(fileHandle == INVALID_HANDLE) {
      Print("Error opening file ", filename, ". Error code: ", GetLastError());
      return;
   }
   
   // --- Write the CSV Header Row
   FileWrite(fileHandle,
             "Position ID", "Symbol", "Volume", "Direction",
             "Open Price", "Close Price", "Open Time", "Close Time",
             "Commission", "Swap", "Profit", "Comment");
             
   // --- Select the entire trade history for the account
   if(!HistorySelect(StartDate, EndDate)) {
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
      datetime   closeTime       = 0;
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
                  closeTime = deal_time;
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
                TimeToString(closeTime, TIME_DATE | TIME_SECONDS),
                DoubleToString(totalCommission, 2),
                DoubleToString(totalSwap, 2),
                DoubleToString(totalProfit, 2),
                comment);
   }

   // --- Close the file handle
   FileClose(fileHandle);
   MessageBox("Export Successful!");
}