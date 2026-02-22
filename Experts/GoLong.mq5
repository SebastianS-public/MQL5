#include <Trade/Trade.mqh>
CTrade trade;

enum RiskManagementMode{
   RiskPercentage,
   FixedLotSize,
   FixedRiskMoney
};

input int TakeProfitPoints = 100;
input int StopLossPoints = 100;
input int StartHour = 1;
input int StartMin = 0;
input int StopHour = 22;
input int StopMin = 0;
input string TradeComment = "";
input RiskManagementMode UseRiskManagement = RiskPercentage;
input double RiskInPercent = 1.0;
input double LotSizeFixed = 1.0;
input double RiskMoneyFixed = 500;
input int MagicNumber = 1;

string currentSymbol;
double tradeTickSize;
double volumeStep;
double minVol;
double maxVol;
double tickValue;


datetime lastCandle;
datetime lastDayCandle;

int timeframeVal;
ENUM_TIMEFRAMES Timeframe;
datetime tradeTriggerDatetime = 0;
datetime tradeStopDatetime = 0;
bool isTradeTime = false;
bool initClosePosition = false;

int OnInit() {
   Timeframe = Period();
   timeframeVal = PeriodSeconds(Timeframe) / 60;
   initTradeTimes();
   trade.SetExpertMagicNumber(MagicNumber);
   
   currentSymbol = _Symbol;
   tradeTickSize = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
   volumeStep = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_STEP);
   minVol = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN);
   maxVol = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MAX);
   
   if(StartHour > StopHour ||
      (UseRiskManagement != LotSizeFixed && StopLossPoints == 0)) {
      return INIT_PARAMETERS_INCORRECT;
   }
   return INIT_SUCCEEDED;
}

void OnTick() {
   if(detectNewCandle(Timeframe, lastCandle)) {
      ulong existingTicket = getOpenPositionTicket();
      if(initClosePosition) {
         trade.PositionClose(existingTicket);
         initClosePosition = false;
      }
      if(detectNewCandle(PERIOD_D1, lastDayCandle)) {
         Print("NewDayCandle");
         initTradeTimes();
      }
      Print("NewCandle");
      
      if(detectTimeTrigger(tradeStopDatetime)) {
         tradeStopDatetime = -1;
         tradeTriggerDatetime = -1;
         Print("Trade Stop");
         if(existingTicket != 0) {
            trade.PositionClose(existingTicket);
         }
      }
      if(detectTimeTrigger(tradeTriggerDatetime)) {
         Print("Trade Start");
         if(existingTicket == 0) {
            trade.Buy(calcVolume(), currentSymbol, 0, calcSL(), calcTP(), TradeComment);
         }
         tradeTriggerDatetime = -1;
      }
   }
}

double calcSL() {
   if(StopLossPoints != 0) {
      return SymbolInfoDouble(currentSymbol, SYMBOL_ASK) - StopLossPoints * tradeTickSize;
   }
   return 0;
}

double calcTP() {
   if(TakeProfitPoints != 0) {
      return SymbolInfoDouble(currentSymbol, SYMBOL_ASK) + TakeProfitPoints * tradeTickSize;
   }
   return 0;
}

double calcVolume() {
   tickValue = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue == 0 || volumeStep == 0) {
      return 0;
   }
   
   double calculatedVolume = 0.0;
   double moneyRisk = 0.0;

   switch(UseRiskManagement) {
      case FixedLotSize:
         calculatedVolume = LotSizeFixed;
         break;
         
      case RiskPercentage:
         moneyRisk = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskInPercent / 100.0);
         break;
         
      case FixedRiskMoney:
         moneyRisk = RiskMoneyFixed;
         break;
   }
   
   if(UseRiskManagement != FixedLotSize) {
      calculatedVolume = moneyRisk / (StopLossPoints * tickValue);
   }
   
   calculatedVolume = MathFloor(calculatedVolume / volumeStep) * volumeStep;
   if(calculatedVolume < minVol) {
      calculatedVolume = minVol;
   }
   if(calculatedVolume > maxVol) {
      calculatedVolume = maxVol;
   }

   return calculatedVolume;
}

ulong getOpenPositionTicket() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            return ticket;
         }
      }
   }
   return 0;
}

void initTradeTimes() {
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   timeStruct.hour = StartHour;
   timeStruct.min = StartMin;
   timeStruct.sec = 0;
   tradeTriggerDatetime = StructToTime(timeStruct);
   timeStruct.hour = StopHour;
   timeStruct.min = StopMin;
   tradeStopDatetime = StructToTime(timeStruct);
   if(currentTime > tradeTriggerDatetime) {
      tradeTriggerDatetime = -1;
      if(currentTime > tradeStopDatetime) {
         tradeStopDatetime = -1;
         if(getOpenPositionTicket() != 0) {
            initClosePosition = true;
         }
      }
   }
}

bool detectTimeTrigger(datetime triggerTime) {
   if(triggerTime == -1) {
      return false;
   }
   if(TimeCurrent() >= triggerTime) {
      return true;
   }
   return false;
}

bool detectNewCandle(ENUM_TIMEFRAMES candleTimeframe, datetime &previousCandle){
   datetime currentCandle = iTime(currentSymbol, candleTimeframe, 0);
   if(currentCandle != previousCandle) {
      previousCandle = currentCandle;
      return true;
   }
   return false;
}