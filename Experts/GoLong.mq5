#property strict

#include "..\\Libraries\\OrderManagerManual.mqh"

enum ExtRiskManagementMode {
   ExtRiskFixedLot,
   ExtRiskPercentBalance,
   ExtRiskFixedMoney,
   RiskScalingByContractAccountBalance
};


input group "Trade Settings"
input int TakeProfit = 100;
input int StopLoss = 50;
input string TradeComment = "GoLong";
input int MagicNumber = 12345;

input group "Risk Management"
input ExtRiskManagementMode RiskMode = ExtRiskPercentBalance;
input double RiskInPercent = 2.0;
input double LotSizeFixed = 0.1;
input double RiskMoneyFixed = 100.0;
input double RiskAccountBalanceInPercentPerContract = 50.0;

input group "Trading Hours"
input int OpenHour = 9;
input int OpenMinute = 30;
input int CloseHour = 17;
input int CloseMinute = 0;


struct DailyTimes {
   datetime openTime;
   datetime closeTime;
};

struct RequestStatusBufferStruct {
   int requestID;
   RequestStatus status;
   bool isTimerSet;
};

DailyTimes dailyTimes;
COrderManager manager;
bool positionOpenedToday = false;
bool positionClosedToday = false;
RequestStatusBufferStruct requestStatusBuffer[10] = {};
int openRequestCount = 0;
int counter = 0;

int OnInit() {
   if(
      (RiskMode == ExtRiskFixedMoney && StopLoss == 0) ||
      (RiskMode == RiskScalingByContractAccountBalance && RiskAccountBalanceInPercentPerContract == 0) ||
      (RiskMode == ExtRiskPercentBalance && StopLoss == 0)) {
         return INIT_PARAMETERS_INCORRECT;
   }
   manager.Init(5, 100);
   RiskManagementMode managerRiskMode = -1;
   switch (RiskMode) {
      case ExtRiskFixedLot:
         managerRiskMode = RiskFixedLot;
         break;
      case ExtRiskPercentBalance:
         managerRiskMode = RiskPercentBalance;
         break;
      case ExtRiskFixedMoney:
         managerRiskMode = RiskFixedMoney;
         break;
      case RiskScalingByContractAccountBalance:
         managerRiskMode = RiskFixedMoney;
         break;
   }
   if(!manager.AddStrategy(MagicNumber, _Symbol, 0, 0, 0, managerRiskMode, getRiskValue())) {
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   Print("Counter: ", counter);
   Print("GoLong EA deinitializing. Reason: ", reason);
}

void OnTick() {
   datetime currentTime = TimeCurrent();

   if(IsNewCalenderDay(currentTime)) {
      if(CheckAndCloseExistingPositions()) {
         counter++;
      }
      ResetDailyState();
      CalcEntryExitTimes(currentTime);
   }
   
   if(currentTime >= dailyTimes.openTime && currentTime < dailyTimes.closeTime && !positionOpenedToday) {
      OpenPosition();
   }
   if(currentTime >= dailyTimes.closeTime && positionOpenedToday && !positionClosedToday) {
      CheckAndCloseExistingPositions();
      positionClosedToday = true;
   }
   manager.Process();
}

void OnTimer() {
   if(openRequestCount == 0) {
      EventKillTimer();
      return;
   }
   for(int i = 0; i < 10; i++) {
      if(requestStatusBuffer[i].requestID == 0) break;
      else if(requestStatusBuffer[i].isTimerSet) {
         RequestStatus status = manager.GetRequestStatus(requestStatusBuffer[i].requestID);
         Print("Timer Check - Request ID ", requestStatusBuffer[i].requestID, " status: ", status);
         if(status == REQ_STATUS_SUCCESS || status == REQ_STATUS_ERROR) {
            ZeroMemory(requestStatusBuffer[i]);
            openRequestCount--;
         }
      }
   }
}

void OpenPosition() {
   Print("OpenPosition - Attempting to open position");
   double tp = 0;
   double sl = 0;
   double vol = 0;
   if(TakeProfit != 0) {
      tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + TakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   if(StopLoss != 0) {
      sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - StopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   if(RiskMode == RiskScalingByContractAccountBalance) {
      vol = CalcVolumeBasedOnAccountBalance();
   }
   int requestID = GenerateRequestID();
   bool success = manager.Trade(MagicNumber, ORDER_TYPE_BUY, vol, 0, sl, tp, TradeComment, requestID);
   if(success) {
      Print("OpenPosition - Opening position successfull");
      positionOpenedToday = true;
      CheckRequestStatus(requestID);
   }
   else {
      Print("OpenPosition - Failed to open position");
   }
}

double CalcVolumeBasedOnAccountBalance() {
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskInMoney = accountBalance * (RiskAccountBalanceInPercentPerContract / 100.0);
   double ticksToZero = SymbolInfoDouble(_Symbol, SYMBOL_ASK) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lossPerLot = ticksToZero * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   return riskInMoney / lossPerLot;
}

bool CheckAndCloseExistingPositions() {
   Print("CheckAndCloseExistingPositions - Checking for existing positions to close");
   for(int i = PositionsTotal() -1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      else {
         Print("CheckAndCloseExistingPositions - Closing ticket: ", ticket);
         int requestID = GenerateRequestID();
         bool success = manager.ClosePosition(MagicNumber, ticket, requestID);
         if(success) {
            CheckRequestStatus(requestID);
            return true;
         }
      }
   }
   Print("CheckAndCloseExistingPositions - Done checking for existing positions");
   return false;
}

void CheckRequestStatus(int requestID) {
   RequestStatus status = manager.GetRequestStatus(requestID);
   Print("Check Request Status - Request ID ", requestID, " status: ", status);
   if(status == REQ_STATUS_PENDING) {
      for(int i = 0; i < 10; i++) {
         if(requestStatusBuffer[i].requestID == requestID) {
            break;
         }
         if(requestStatusBuffer[i].requestID == 0) {
            requestStatusBuffer[i].requestID = requestID;
            requestStatusBuffer[i].status = REQ_STATUS_PENDING;
            requestStatusBuffer[i].isTimerSet = true;
            EventSetTimer(1);
            openRequestCount++;
            break;
         }
      }
   }
   else if(status == REQ_STATUS_SUCCESS || status == REQ_STATUS_ERROR) {
      for(int i = 0; i < 10; i++) {
         if(requestStatusBuffer[i].requestID == requestID) {
            ZeroMemory(requestStatusBuffer[i]);
            openRequestCount--;
            break;
         }
         else if (requestStatusBuffer[i].requestID == 0) {
            break;
         }
      }
   }
}

int GenerateRequestID() {
   static int requestCounter = 1;
   return requestCounter++;
}

void CalcEntryExitTimes(datetime currentTime) {
   Print("CalcEntryExitTimes - Calculating target entry and exit times for the day");
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   timeStruct.hour = OpenHour;
   timeStruct.min = OpenMinute;
   timeStruct.sec = 0;
   datetime targetOpenTime = StructToTime(timeStruct);
   Print("CalcEntryExitTimes - Open Time: ", TimeToString(targetOpenTime, TIME_DATE | TIME_SECONDS));
   timeStruct.hour = CloseHour;
   timeStruct.min = CloseMinute;
   datetime targetCloseTime = StructToTime(timeStruct);
   Print("CalcEntryExitTimes - Close Time: ", TimeToString(targetCloseTime, TIME_DATE | TIME_SECONDS));

   if(currentTime >= targetOpenTime && currentTime < targetCloseTime) {
      targetOpenTime = currentTime;
   }
   dailyTimes.openTime = targetOpenTime;
   dailyTimes.closeTime = targetCloseTime;
}

void ResetDailyState() {
   positionOpenedToday = false;
   positionClosedToday = false;
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
   if(RiskMode == ExtRiskFixedLot || RiskMode == RiskScalingByContractAccountBalance) {
      return LotSizeFixed;
   }
   else if(RiskMode == ExtRiskPercentBalance) {
      return RiskInPercent;
   }
   else {
      return RiskMoneyFixed;
   }
}