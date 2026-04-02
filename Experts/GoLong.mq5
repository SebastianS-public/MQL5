#property strict

#include "..\\Libraries\\OrderManagerManual.mqh"

input group "Trade Settings"
input double TakeProfit = 100;
input double StopLoss = 50;
input string TradeComment = "GoLong";
input int MagicNumber = 12345;

input group "Risk Management"
input RiskManagementMode RiskMode = RiskPercentBalance;
input double RiskInPercent = 2.0;
input double LotSizeFixed = 0.1;
input double RiskMoneyFixed = 100.0;

input group "Trading Hours"
input int OpenHour = 9;
input int OpenMinute = 30;
input int CloseHour = 17;
input int CloseMinute = 0;


struct DailyTimes {
   datetime openTime;
   datetime closeTime;
};

DailyTimes dailyTimes;
COrderManager manager;
datetime lastTickTime = 0;
bool positionOpenedToday = false;


int openRequestID = 0;
int closeRequestID = 0;
RequestStatus lastOpenStatus = REQ_STATUS_SUCCESS;
RequestStatus lastCloseStatus = REQ_STATUS_SUCCESS;

bool recoveredFromHoliday = false;

void OnInit() {
   manager.Init(5, 100);
   manager.AddStrategy(MagicNumber, _Symbol, 0, 0, 0, RiskMode, getRiskValue());
}

void OnDeinit(const int reason) {
   Print("GoLong EA deinitializing. Reason: ", reason);
}

// TODO: Currently it is set to reset on new day, might be better to reset at specified time
// to be able to deal with summer/winter time changes and other edge cases
void OnTick() {
   manager.Process();

   datetime currentTime = TimeCurrent();
   if(lastTickTime > 0) {
      long timeSinceLastTick = currentTime - lastTickTime;
      if(timeSinceLastTick > 24 * 3600) {
         Print("Detected a gap of ", timeSinceLastTick / 3600, " hours since last tick.");
      }
   }
   lastTickTime = currentTime;

   if(IsNewCalenderDay(currentTime)) {
      ResetDailyState();
      CheckAndCloseExistingPositions();
      CalcEntryExitTimes(currentTime);
   }
}

bool CheckAndCloseExistingPositions() {
   for(int i = PositionsTotal() -1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
   }
}

void CalcEntryExitTimes(datetime currentTime) {
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   timeStruct.hour = OpenHour;
   timeStruct.min = OpenMinute;
   timeStruct.sec = 0;
   datetime targetOpenTime = StructToTime(timeStruct);
   timeStruct.hour = CloseHour;
   timeStruct.min = CloseMinute;
   datetime targetCloseTime = StructToTime(timeStruct);

   if(currentTime >= targetOpenTime && currentTime < targetCloseTime) {
      targetOpenTime = currentTime;
   }
   dailyTimes.openTime = targetOpenTime;
   dailyTimes.closeTime = targetCloseTime;
}

void ResetDailyState() {
   positionOpenedToday = false;
   openRequestID = 0;
   closeRequestID = 0;
   lastOpenStatus = REQ_STATUS_SUCCESS;
   lastCloseStatus = REQ_STATUS_SUCCESS;
   Print("=== Daily state reset ===");
}

bool IsNewCalenderDay(datetime currentTime) {
   static datetime lastKnownTime = 0;

   // Treat first tick as new day
   if(lastKnownTime == 0) {
      lastKnownTime = currentTime;
      return true;
   }
   MqlDateTime currentTimeStruct, lastTimeStruct;
   TimeToStruct(currentTime, currentTimeStruct);
   TimeToStruct(lastKnownTime, lastTimeStruct);

   // Check if date changed
   if(currentTimeStruct.year != lastTimeStruct.year || 
      currentTimeStruct.mon != lastTimeStruct.mon || 
      currentTimeStruct.day != lastTimeStruct.day) {
      lastKnownTime = currentTime;
      return true;
   }
   lastKnownTime = currentTime;
   return false;
}

double getRiskValue() {
   if(RiskMode == RiskFixedLot) {
      return LotSizeFixed;
   }
   else if(RiskMode == RiskPercentBalance) {
      return RiskInPercent;
   }
   else {
      return RiskMoneyFixed;
   }
}