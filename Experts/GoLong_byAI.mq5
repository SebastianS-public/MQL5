#property strict
#property version   "1.0"
#property description "Daily Long Position EA - Opens at specified time, closes at specified time"

#include <Trade/Trade.mqh>
#include "..\\Libraries\\OrderManager.mqh"

// ==================== INPUT PARAMETERS ====================
input double         TakeProfit = 100;                   // Take Profit (points, not pips)
input double         StopLoss = 50;                      // Stop Loss (points, not pips)
input string         TradeComment = "GoLong";            // Trade comment

// Risk Management Settings
input RiskManagementMode RiskMode = RiskPercentBalance;  // Risk management mode
input double         RiskInPercent = 2.0;                // Risk as % of balance (if RiskPercentBalance)
input double         LotSizeFixed = 0.1;                 // Fixed lot size (if RiskFixedLot)
input double         RiskMoneyFixed = 100.0;             // Risk fixed money (if RiskFixedMoney)

// Trading Hours (Server Time)
input int            OpenHour = 9;                       // Market open hour (server time, 0-23)
input int            OpenMinute = 30;                    // Market open minute (0-59)
input int            CloseHour = 17;                     // Market close hour (server time, 0-23)
input int            CloseMinute = 0;                    // Market close minute (0-59)

// EA Configuration
input int            MagicNumber = 12345;                // Magic number for this EA

// ==================== GLOBAL VARIABLES ====================
COrderManager        manager;
bool                 positionOpenedToday = false;        // Track if position opened today
int                  openRequestID = 0;                  // Request ID for open order
int                  closeRequestID = 0;                 // Request ID for close order
RequestStatus        lastOpenStatus = REQ_STATUS_SUCCESS; // Status of last open request
RequestStatus        lastCloseStatus = REQ_STATUS_SUCCESS; // Status of last close request
datetime             lastTickTime = 0;                   // Track time of last OnTick for holiday detection
bool                 recoveredFromHoliday = false;       // Flag: we just had a 24+ hour gap (likely holiday)

// ==================== INITIALIZATION ====================
void OnInit() {
   manager.Init(_Symbol, MagicNumber, 5, 500, 10, 200);
   
   // Set risk management mode and value
   manager.SetRiskSettings(RiskMode, GetRiskValue());
   
   Print("=== GoLong EA Initialized ===");
   Print("Symbol: ", _Symbol);
   Print("Open Time: ", OpenHour, ":", FormatMinute(OpenMinute), " | Close Time: ", CloseHour, ":", FormatMinute(CloseMinute));
   Print("Risk Mode: ", EnumToString(RiskMode));
   Print("Magic Number: ", MagicNumber);
}

void OnDeinit(const int reason) {
   Print("GoLong EA deinitializing. Reason: ", reason);
}

// ==================== MAIN TRADING LOGIC ====================
void OnTick() {
   manager.Process();
   
   datetime currentTime = TimeCurrent();
   
   // ===== DETECT HOLIDAY / MARKET CLOSURE =====
   // If gap since last tick > 24 hours, we likely had a market closure (holiday, weekend skip, etc)
   if(lastTickTime > 0) {
      long timeSinceLastTick = currentTime - lastTickTime;
      // 86400 = 24 hours in seconds. Use 24 hours as threshold.
      // This catches holidays but not normal overnight gaps (which are ~16 hours in forex, ~16 hours in stocks)
      if(timeSinceLastTick > 86400) {
         recoveredFromHoliday = true;
         Print("⚠ Market closure detected (gap of ", timeSinceLastTick / 3600, " hours). ");
      }
   }
   lastTickTime = currentTime;
   
   // Check if it's a new calendar day
   if(IsNewCalendarDay(currentTime)) {
      ResetDailyState();
      // Don't reset recoveredFromHoliday flag - we want to apply special logic TODAY
   }
   
   // ===== LOGIC: Close previous day's position if still open (critical for new day) =====
   // If we're at the opening time and have existing positions, force close them first
   // This handles the edge case where market closed before yesterday's close time
   if(IsNearOpenTime(currentTime)) {
      bool hasExistingPosition = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            (int)PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            hasExistingPosition = true;
            
            // Close the existing position if no close request is pending
            if(closeRequestID == 0) {
               closeRequestID = GenerateRequestID();
               manager.ClosePosition(_Symbol, ticket, closeRequestID);
               Print("⚠ WARNING: Existing position found at open time. Closing ticket: ", ticket);
            }
            break;
         }
      }
      
      // Don't open new position if we're trying to close an old one
      if(hasExistingPosition && closeRequestID != 0) {
         // Wait for old close to complete before opening new position
         lastCloseStatus = manager.GetRequestStatus(closeRequestID);
         
         if(lastCloseStatus == REQ_STATUS_SUCCESS) {
            Print("✓ Old position closed successfully");
            positionOpenedToday = false;
            closeRequestID = 0;
         } else if(lastCloseStatus == REQ_STATUS_ERROR) {
            Print("✗ Old position close failed, retrying...");
            closeRequestID = 0;
         }
         // If still pending, wait and don't open yet
         if(lastCloseStatus != REQ_STATUS_SUCCESS) {
            return;  // Exit OnTick early, try again next tick
         }
      }
   }
   
   // ===== LOGIC: Open position =====
   // Only attempt to open if we haven't done so successfully today
   if(!positionOpenedToday) {
      datetime targetOpenTime = CalculateTargetOpenTime(currentTime);
      
      // HOLIDAY HANDLING: After market closure, be strict about opening time
      // Only open at or near the specified opening time, not arbitrarily late if we're past it
      bool shouldAttemptOpen = false;
      
      if(currentTime >= targetOpenTime) {
         if(recoveredFromHoliday) {
            // After holiday recovery: only open within 60 seconds of the exact opening time
            if(currentTime < targetOpenTime + 60) {
               shouldAttemptOpen = true;
               recoveredFromHoliday = false; // Consume the flag after the critical window
            }
         } else {
            // Normal day: open immediately if past the opening time (handles delayed market opens)
            shouldAttemptOpen = true;
         }
      }
      
      if(shouldAttemptOpen) {
         // Check if there's a pending open request
         if(openRequestID == 0) {
            // No pending request, attempt to open
            AttemptOpenPosition(currentTime);
         } else {
            // Check status of pending open request
            lastOpenStatus = manager.GetRequestStatus(openRequestID);
            
            if(lastOpenStatus == REQ_STATUS_SUCCESS) {
               // Previous open succeeded, mark position as opened
               positionOpenedToday = true;
               openRequestID = 0;
               Print("✓ Position opened successfully (confirmed by request status)");
            } else if(lastOpenStatus == REQ_STATUS_ERROR) {
               // Previous open failed fatally, reset and try again
               Print("✗ Open request failed with fatal error, retrying...");
               openRequestID = 0;
               AttemptOpenPosition(currentTime);
            }
            // If REQ_STATUS_PENDING, wait for completion
         }
      }
   }
   
   // ===== LOGIC: Close position =====
   datetime targetCloseTime = CalculateTargetCloseTime(currentTime);
   
   // Only attempt to close if we're at or past the target close time
   if(currentTime >= targetCloseTime && positionOpenedToday) {
      // Check if there's a pending close request
      if(closeRequestID == 0) {
         // No pending request, attempt to close
         AttemptClosePosition(currentTime);
      } else {
         // Check status of pending close request
         lastCloseStatus = manager.GetRequestStatus(closeRequestID);
         
         if(lastCloseStatus == REQ_STATUS_SUCCESS) {
            // Previous close succeeded
            positionOpenedToday = false;
            closeRequestID = 0;
            Print("✓ Position closed successfully (confirmed by request status)");
         } else if(lastCloseStatus == REQ_STATUS_ERROR) {
            // Previous close failed, reset and try again
            Print("✗ Close request failed with fatal error, retrying...");
            closeRequestID = 0;
            AttemptClosePosition(currentTime);
         }
         // If REQ_STATUS_PENDING, wait for completion
      }
   }
}

// ==================== POSITION MANAGEMENT ====================
bool AttemptOpenPosition(datetime currentTime) {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(ask <= 0 || bid <= 0) {
      Print("✗ Invalid prices: Ask=", ask, " Bid=", bid);
      return false;
   }
   
   // Calculate stop loss and take profit (in points)
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double sl = (StopLoss > 0) ? ask - (StopLoss * point) : 0;
   double tp = (TakeProfit > 0) ? ask + (TakeProfit * point) : 0;
   
   openRequestID = GenerateRequestID();
   
   // Use 0 for volume to trigger automatic risk-based calculation
   bool success = manager.Trade(_Symbol, ORDER_TYPE_BUY, 0, ask, sl, tp, TradeComment, openRequestID);
   
   if(success) {
      Print("✓ Open order queued | RequestID: ", openRequestID, " | Time: ", TimeToString(currentTime), 
            " | Entry: ", ask, " | SL: ", sl, " | TP: ", tp);
      return true;
   } else {
      Print("✗ Failed to queue open order | RequestID: ", openRequestID);
      openRequestID = 0;  // Reset so we can retry next tick
      return false;
   }
}

bool AttemptClosePosition(datetime currentTime) {
   // Find position by symbol and magic number
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      closeRequestID = GenerateRequestID();
      bool success = manager.ClosePosition(_Symbol, ticket, closeRequestID);
      
      if(success) {
         Print("✓ Close order queued | RequestID: ", closeRequestID, " | Ticket: ", ticket, 
               " | Time: ", TimeToString(currentTime));
         return true;
      } else {
         Print("✗ Failed to queue close order | RequestID: ", closeRequestID, " | Ticket: ", ticket);
         closeRequestID = 0;  // Reset so we can retry next tick
         return false;
      }
   }
   
   // No position found - market order may have already closed or never opened
   Print("⚠ No open position found for closing. Position may have already closed.");
   positionOpenedToday = false;
   closeRequestID = 0;
   return false;
}



// ==================== TIME CALCULATION ====================
datetime CalculateTargetOpenTime(datetime currentTime) {
   MqlDateTime mdt;
   TimeToStruct(currentTime, mdt);
   
   // Set time to open hour and minute today
   mdt.hour = OpenHour;
   mdt.min = OpenMinute;
   mdt.sec = 0;
   datetime todayOpenTime = StructToTime(mdt);
   
   // Set time to close hour and minute today
   MqlDateTime closeMdt = mdt;
   closeMdt.hour = CloseHour;
   closeMdt.min = CloseMinute;
   closeMdt.sec = 0;
   datetime todayCloseTime = StructToTime(closeMdt);
   
   // If we're still before today's close time, keep returning today's open time
   // This allows re-attempts throughout the trading day (not just at exact open time)
   if(currentTime < todayCloseTime) {
      return todayOpenTime;
   }
   
   // We've passed today's close time, calculate next trading day
   // Start with tomorrow
   mdt.day++;
   
   // Month boundary adjustment
   if(mdt.day > DaysInMonth(mdt.mon, mdt.year)) {
      mdt.day = 1;
      mdt.mon++;
      if(mdt.mon > 12) {
         mdt.mon = 1;
         mdt.year++;
      }
   }
   
   // Skip weekends (Saturday = 6, Sunday = 0)
   // Note: StructToTime recalculates day_of_week, so we need to check after conversion
   while(true) {
      datetime checkTime = StructToTime(mdt);
      MqlDateTime checkMdt;
      TimeToStruct(checkTime, checkMdt);  // Recalculate day_of_week
      
      if(checkMdt.day_of_week != 0 && checkMdt.day_of_week != 6) {
         break;  // Found a weekday
      }
      
      // Move to next day
      mdt.day++;
      if(mdt.day > DaysInMonth(mdt.mon, mdt.year)) {
         mdt.day = 1;
         mdt.mon++;
         if(mdt.mon > 12) {
            mdt.mon = 1;
            mdt.year++;
         }
      }
   }
   
   mdt.hour = OpenHour;
   mdt.min = OpenMinute;
   mdt.sec = 0;
   
   return StructToTime(mdt);
}

datetime CalculateTargetCloseTime(datetime currentTime) {
   MqlDateTime mdt;
   TimeToStruct(currentTime, mdt);
   
   // Set time to open hour and minute today
   MqlDateTime openMdt = mdt;
   openMdt.hour = OpenHour;
   openMdt.min = OpenMinute;
   openMdt.sec = 0;
   datetime todayOpenTime = StructToTime(openMdt);
   
   // Set time to close hour and minute today
   mdt.hour = CloseHour;
   mdt.min = CloseMinute;
   mdt.sec = 0;
   datetime todayCloseTime = StructToTime(mdt);
   
   // If we're still within today's trading hours (after open, before close), use today's close time
   if(currentTime >= todayOpenTime && currentTime < todayCloseTime) {
      return todayCloseTime;
   }
   
   // If we're before today's open, still use today's close time
   if(currentTime < todayOpenTime) {
      return todayCloseTime;
   }
   
   // We've passed today's close time, calculate next trading day's close time
   // Start with tomorrow
   mdt.day++;
   
   // Month boundary adjustment
   if(mdt.day > DaysInMonth(mdt.mon, mdt.year)) {
      mdt.day = 1;
      mdt.mon++;
      if(mdt.mon > 12) {
         mdt.mon = 1;
         mdt.year++;
      }
   }
   
   // Skip weekends
   while(true) {
      datetime checkTime = StructToTime(mdt);
      MqlDateTime checkMdt;
      TimeToStruct(checkTime, checkMdt);  // Recalculate day_of_week
      
      if(checkMdt.day_of_week != 0 && checkMdt.day_of_week != 6) {
         break;  // Found a weekday
      }
      
      // Move to next day
      mdt.day++;
      if(mdt.day > DaysInMonth(mdt.mon, mdt.year)) {
         mdt.day = 1;
         mdt.mon++;
         if(mdt.mon > 12) {
            mdt.mon = 1;
            mdt.year++;
         }
      }
   }
   
   mdt.hour = CloseHour;
   mdt.min = CloseMinute;
   mdt.sec = 0;
   
   return StructToTime(mdt);
}





// ==================== UTILITY FUNCTIONS ====================
bool IsNewCalendarDay(datetime currentTime) {
   static datetime lastKnownTime = 0;
   
   if(lastKnownTime == 0) {
      lastKnownTime = currentTime;
      return false;
   }
   
   MqlDateTime lastMdt, currentMdt;
   TimeToStruct(lastKnownTime, lastMdt);
   TimeToStruct(currentTime, currentMdt);
   
   // Check if date changed
   if(currentMdt.year != lastMdt.year || 
      currentMdt.mon != lastMdt.mon || 
      currentMdt.day != lastMdt.day) {
      lastKnownTime = currentTime;
      return true;
   }
   
   lastKnownTime = currentTime;
   return false;
}

void ResetDailyState() {
   positionOpenedToday = false;
   openRequestID = 0;
   closeRequestID = 0;
   lastOpenStatus = REQ_STATUS_SUCCESS;
   lastCloseStatus = REQ_STATUS_SUCCESS;
   Print("=== Daily state reset ===");
}

double GetRiskValue() {
   // Return the appropriate risk value based on selected risk mode
   if(RiskMode == RiskFixedLot) {
      return LotSizeFixed;
   } else if(RiskMode == RiskPercentBalance) {
      return RiskInPercent;
   } else {
      return RiskMoneyFixed;
   }
}

int GenerateRequestID() {
   static int requestCounter = 1;
   return requestCounter++;
}

string FormatMinute(int minute) {
   if(minute < 10) {
      return "0" + IntegerToString(minute);
   }
   return IntegerToString(minute);
}

int DaysInMonth(int month, int year) {
   if(month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
      return 31;
   } else if(month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
   } else { // February
      if((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
         return 29; // Leap year
      } else {
         return 28;
      }
   }
}

bool IsNearOpenTime(datetime currentTime) {
   // Check if current time is within 60 seconds of the target open time
   // Used to detect when we should close previous day's positions
   MqlDateTime mdt;
   TimeToStruct(currentTime, mdt);
   
   mdt.hour = OpenHour;
   mdt.min = OpenMinute;
   mdt.sec = 0;
   datetime openTime = StructToTime(mdt);
   
   // Return true if within 60 seconds after open time
   return (currentTime >= openTime && currentTime < openTime + 60);
}
