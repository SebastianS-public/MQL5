##property strict

#include <Trade/Trade.mqh>
#include "..\\Libraries\\OrderManager.mqh"

input group "Trade Settings"
input double         TakeProfit = 100;
input double         StopLoss = 50;
input string         TradeComment = "GoLong";
input int           MagicNumber = 12345;

input group "Risk Management"
input RiskManagementMode RiskMode = RiskPercentBalance;
input double         RiskInPercent = 2.0;
input double         LotSizeFixed = 0.1;
input double         RiskMoneyFixed = 100.0;

input group "Trading Hours"
input int            OpenHour = 9;
input int            OpenMinute = 30;
input int            CloseHour = 17;
input int            CloseMinute = 0;

COrderManager        manager;
bool                 positionOpenedToday = false;
int                  openRequestID = 0;
int                  closeRequestID = 0;
RequestStatus        lastOpenStatus = REQ_STATUS_SUCCESS;
RequestStatus        lastCloseStatus = REQ_STATUS_SUCCESS;
datetime             lastTickTime = 0;
bool                 recoveredFromHoliday = false;

void OnInit() {
   manager.Init(_Symbol, MagicNumber, 5, 0, 0, 100);
   manager.SetRiskSettings(RiskMode, getRiskValue());
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