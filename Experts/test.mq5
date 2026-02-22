#include <Trade/Trade.mqh>
CTrade trade;

// --- STATE MACHINE ---
enum EAState {
   STATE_IDLE,
   STATE_PENDING_OPEN,
   STATE_PENDING_CLOSE
};

enum RiskManagementMode{
   RiskPercentage,
   FixedLotSize,
   FixedRiskMoney
};

// --- INPUTS ---
input int TakeProfitPoints = 100;
input int StopLossPoints = 100;
input int StartHour = 1;
input int StartMin = 0;
input int StopHour = 22;
input int StopMin = 0;
input int MaxSpreadPoints = 20;        // New: Max allowed spread
input int RetryDelaySeconds = 5;       // New: Wait time between retries
input string TradeComment = "";
input RiskManagementMode UseRiskManagement = RiskPercentage;
input double RiskInPercent = 1.0;
input double LotSizeFixed = 1.0;
input double RiskMoneyFixed = 500;
input int MagicNumber = 1;

// --- GLOBALS ---
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

// Trigger Times
datetime tradeTriggerDatetime = -1; // Default to -1 (Inactive)
datetime tradeStopDatetime = -1;    // Default to -1 (Inactive)

// State Management
EAState currentState = STATE_IDLE;
datetime lastRetryTime = 0;
ulong ticketToClose = 0; // Stores the ticket we are trying to close

// --- ON INIT ---
int OnInit() {
   Timeframe = Period();
   timeframeVal = PeriodSeconds(Timeframe) / 60;
   
   trade.SetExpertMagicNumber(MagicNumber);
   
   currentSymbol = _Symbol;
   tradeTickSize = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
   volumeStep = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_STEP);
   minVol = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN);
   maxVol = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MAX);
   
   initTradeTimes();
   
   // FIX: Check for parameters
   if(StartHour > StopHour || (UseRiskManagement != LotSizeFixed && StopLossPoints == 0)) {
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // FIX: Recover State on Restart
   ulong existingTicket = getOpenPositionTicket();
   if(existingTicket > 0) {
      Print("Restored state: Active Trade Found (Ticket: ", existingTicket, ")");
      // If we have a trade, ensure we aren't trying to open another one
      currentState = STATE_IDLE; 
   }

   return INIT_SUCCEEDED;
}

// --- ON TICK ---
void OnTick() {
   // 1. Recover Logic (Stateless Check)
   ulong existingTicket = getOpenPositionTicket();
   bool iHaveAPosition = (existingTicket > 0);

   // 2. Handle State Machine (Retries, Spreads, Execution)
   ProcessState(iHaveAPosition, existingTicket);

   // 3. Main Candle/Time Logic
   if(detectNewCandle(Timeframe, lastCandle)) {
      
      // New Day Logic
      if(detectNewCandle(PERIOD_D1, lastDayCandle)) {
         Print("NewDayCandle");
         initTradeTimes();
      }
      Print("NewCandle");
      
      // A. Check STOP Trigger
      if(detectTimeTrigger(tradeStopDatetime)) {
         Print("Time Trigger: STOP");
         tradeStopDatetime = -1; // Disable trigger
         
         if(iHaveAPosition) {
            // Instead of closing immediately, we request a Close State
            currentState = STATE_PENDING_CLOSE;
            ticketToClose = existingTicket;
            lastRetryTime = 0; // Reset timer to act immediately
         }
      }

      // B. Check START Trigger
      if(detectTimeTrigger(tradeTriggerDatetime)) {
         Print("Time Trigger: START");
         tradeTriggerDatetime = -1; // Disable trigger
         
         if(!iHaveAPosition) {
            // Instead of buying immediately, we request an Open State
            currentState = STATE_PENDING_OPEN;
            lastRetryTime = 0; // Reset timer to act immediately
         }
      }
   }
}

// --- STATE MACHINE ENGINE ---
void ProcessState(bool iHaveAPosition, ulong existingTicket) {
   // If IDLE, do nothing
   if(currentState == STATE_IDLE) return;

   // Throttling: Check if enough time passed since last attempt
   if(TimeCurrent() - lastRetryTime < RetryDelaySeconds) return;

   // UPDATE TIMESTAMP NOW (To prevent spamming if logic below fails)
   lastRetryTime = TimeCurrent();

   // --- HANDLING OPEN ---
   if(currentState == STATE_PENDING_OPEN) {
      
      // Safety: If a position appeared (maybe filled manually?), abort
      if(iHaveAPosition) {
         currentState = STATE_IDLE;
         return;
      }
      
      // Spread Check
      double currentSpread = (SymbolInfoDouble(currentSymbol, SYMBOL_ASK) - SymbolInfoDouble(currentSymbol, SYMBOL_BID)) / _Point;
      if(currentSpread > MaxSpreadPoints) {
         Print("High Spread: ", currentSpread, " > ", MaxSpreadPoints, ". Waiting...");
         return; // Retry next cycle
      }

      // Attempt Trade
      if(trade.Buy(calcVolume(), currentSymbol, 0, calcSL(), calcTP(), TradeComment)) {
         // Check "Did it actually work?" (Trade class usually handles RetCode internally for bool return, but let's be safe)
         if(trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED) {
             Print("Order Placed Successfully");
             currentState = STATE_IDLE;
             return;
         }
      }
      
      // If we are here, Trade Failed. Analyze Error.
      HandleTradeError(trade.ResultRetcode());
   }

   // --- HANDLING CLOSE ---
   if(currentState == STATE_PENDING_CLOSE) {
      // Safety: If position is already gone, abort
      if(!iHaveAPosition) {
         currentState = STATE_IDLE;
         ticketToClose = 0;
         return;
      }

      if(trade.PositionClose(ticketToClose)) {
         if(trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED) {
            Print("Position Closed Successfully");
            currentState = STATE_IDLE;
            ticketToClose = 0;
            return;
         }
      }
      
      HandleTradeError(trade.ResultRetcode());
   }
}

// --- ERROR HANDLER ---
void HandleTradeError(uint retCode) {
   // 1. Fatal Errors (Abort Immediately)
   if(retCode == TRADE_RETCODE_INVALID_VOLUME ||
      retCode == TRADE_RETCODE_NO_MONEY ||
      retCode == TRADE_RETCODE_INVALID_STOPS ||
      retCode == TRADE_RETCODE_CLIENT_DISABLES_AT ||
      retCode == TRADE_RETCODE_SERVER_DISABLES_AT) {
      
      Print("CRITICAL ERROR (Fatal): ", retCode, ". Aborting operation.");
      currentState = STATE_IDLE; // Give up
   }
   // 2. Retryable Errors (Do nothing, just print)
   else {
      Print("Temporary Error: ", retCode, ". Retrying in ", RetryDelaySeconds, " seconds...");
      // We do NOT change state. We stay in PENDING.
      // The 'lastRetryTime' check at the top of ProcessState handles the wait.
   }
}

// --- HELPER FUNCTIONS ---

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
   if(tickValue == 0 || volumeStep == 0) return 0;
   
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
   if(calculatedVolume < minVol) calculatedVolume = minVol;
   if(calculatedVolume > maxVol) calculatedVolume = maxVol;

   return calculatedVolume;
}

ulong getOpenPositionTicket() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         // Added Symbol Check for Safety
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol) {
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
   
   // 1. Calculate Today's Start Time
   timeStruct.hour = StartHour;
   timeStruct.min = StartMin;
   timeStruct.sec = 0;
   datetime potentialStartTime = StructToTime(timeStruct);
   
   // 2. Calculate Today's Stop Time
   timeStruct.hour = StopHour;
   timeStruct.min = StopMin;
   timeStruct.sec = 0;
   datetime potentialStopTime = StructToTime(timeStruct);
   
   // 3. Logic
   tradeStopDatetime = potentialStopTime;
   
   if(currentTime >= potentialStartTime) {
      tradeTriggerDatetime = -1; 
   } else {
      tradeTriggerDatetime = potentialStartTime;
   }
   
   if(currentTime >= tradeStopDatetime) {
      tradeStopDatetime = -1;
      tradeTriggerDatetime = -1;
   }
}

bool detectTimeTrigger(datetime triggerTime) {
   if(triggerTime == -1) return false;
   if(TimeCurrent() >= triggerTime) return true;
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