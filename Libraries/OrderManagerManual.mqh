#property strict

#include <Trade/Trade.mqh>

// Constants for static array initializations
#define MAX_QUEUE_SIZE 1024
#define FATAL_BUFFER_SIZE 256
#define MAX_STRATEGIES 32

// EA Processing States
enum EAState {
   STATE_PROCESSING_CLOSE,
   STATE_PROCESSING_DELETE,
   STATE_PROCESSING_MODIFY 
};

// Risk Management Modes
enum RiskManagementMode {
   RiskFixedLot,
   RiskPercentBalance,
   RiskFixedMoney
};

// Request Status for tracking (per symbol)
enum RequestStatus {
   REQ_STATUS_SUCCESS,
   REQ_STATUS_PENDING,
   REQ_STATUS_ERROR
};

// Trade Request Structure
struct TradeRequest {
   ENUM_ORDER_TYPE type;
   double volume;
   double price;
   double sl;
   double tp;
   datetime expiration;
   string comment;
   datetime retryAt; 
   int requestID;
};

// Ticket Request Structure
struct TicketRequest {
   ulong ticket;
   EAState action;
   double sl;
   double tp;
   datetime retryAt;
   int requestID;
};

// Strategy Structure
struct StrategyStruct {
   // Trade and Ticket Circular Buffers
   TradeRequest tradeQueue[MAX_QUEUE_SIZE];
   int tradeQueueHead;
   int tradeQueueTail;
   int tradeQueueCount;
   TicketRequest ticketQueue[MAX_QUEUE_SIZE];
   int ticketQueueHead;
   int ticketQueueTail;
   int ticketQueueCount;

   // Symbol specific market info
   double tickSize;
   double point;
   double volStep;
   double volMin;
   double volMax;
   int digits;
   long stopLevel;
   ENUM_ORDER_TYPE_FILLING fillingType;

   // strategy specific settings
   CTrade trade;
   string symbolName;
   int magicNumber;
   int stopLevelOverride;
   int maxSpread;
   int slippage;
   RiskManagementMode riskMode;
   double riskValue;
   
   // refresh timer
   ulong lastRefreshTime;
};

// COrderManager Class Definition
class COrderManager {
private:
   
   // Multi-symbol infrastructure
   StrategyStruct m_strategies[MAX_STRATEGIES];
   int m_symbolCount;
   
   // Circular buffer for fatal request IDs
   int m_fatalIDBuffer[FATAL_BUFFER_SIZE];
   int m_fatalIDCount;
   int m_fatalIDIndex;

   // General settings and state variables
   int m_retryDelay;
   ulong m_processingBudgetMs;
   bool m_isTester;

   // Helper: Find symbol index, return -1 if not found
   int GetSymbolIndex(int symbolMagic) {
      for(int i = 0; i < m_symbolCount; i++) {
         if(m_strategies[i].magicNumber == symbolMagic) return i;
      }
      return -1;
   }

   // Helper: Is Equal check for doubles with epsilon tolerance
   bool DoubleComparison(double a, string operation, double b) {
      double epsilon = 1e-8;
      bool equal = MathAbs(a - b) <= epsilon;
      if(operation == "EQUAL") {
         return equal;
      }
      if(operation == "LESS OR EQUAL") {
         return (a < b || equal);
      }
      if(operation == "GREATER OR EQUAL") {
         return (a > b || equal);
      }
      return false;
   }

   // Helper: Get filling type for symbol
   ENUM_ORDER_TYPE_FILLING GetFillingType(string symbol) {
      long filling = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
      if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
      if((filling & SYMBOL_FILLING_BOC) == SYMBOL_FILLING_BOC) return ORDER_FILLING_BOC;
      return ORDER_FILLING_RETURN;
   }

   // Normalize price for specific symbol
   double NormalizePriceSymbol(int symbolMagic, double p) {
      int idx = GetSymbolIndex(symbolMagic);
      if(idx < 0) {
         Print("Error: NormalizePriceSymbol - Symbol with magic ", symbolMagic, " not found. Returning 0.");
         return 0;
      }
      return NormalizeDouble(MathRound(p / m_strategies[idx].tickSize) * m_strategies[idx].tickSize, m_strategies[idx].digits);
   }

   // Normalize volume for specific symbol
   double NormalizeVolSymbol(int symbolMagic, double v) {
      int idx = GetSymbolIndex(symbolMagic);
      if(idx < 0) {
         Print("Error: NormalizeVolSymbol - Symbol with magic ", symbolMagic, " not found. Returning 0.");
         return 0;
      }
      double vol = MathFloor(v / m_strategies[idx].volStep) * m_strategies[idx].volStep;
      if(DoubleComparison(vol, "EQUAL", m_strategies[idx].volMin)) {
         vol = m_strategies[idx].volMin;
      }
      if(DoubleComparison(vol, "EQUAL", m_strategies[idx].volMax)) {
         vol = m_strategies[idx].volMax;
      }
      return NormalizeDouble(vol, 2);
   }

   // Check stop level for pending order types per symbol
   bool CheckStopLevelSymbol(int symbolMagic, ENUM_ORDER_TYPE type, double reqPrice, double curAsk, double curBid) {
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL) return true;
      
      int idx = GetSymbolIndex(symbolMagic);
      double minDist = m_strategies[idx].stopLevel * m_strategies[idx].point;

      // BUY_STOP must be above current ask by minimum distance
      if(type == ORDER_TYPE_BUY_STOP) {
         if(reqPrice - curAsk < minDist) {
            Print("Error: BUY_STOP too close to Ask. Symbol: ", symbolMagic, " Price: ", reqPrice, " Ask: ", curAsk, " MinDist: ", minDist);
            return false;
         }
      }
      // SELL_LIMIT must be above current bid by minimum distance
      if(type == ORDER_TYPE_SELL_LIMIT) {
         if(reqPrice - curBid < minDist) {
            Print("Error: SELL_LIMIT too close to Bid. Symbol: ", m_strategies[idx].symbolName, " Price: ", reqPrice, " Bid: ", curBid, " MinDist: ", minDist);
            return false;
         }
      }
      // SELL_STOP must be below current bid by minimum distance
      if(type == ORDER_TYPE_SELL_STOP) {
         if(curBid - reqPrice < minDist) {
            Print("Error: SELL_STOP too close to Bid. Symbol: ", m_strategies[idx].symbolName, " Price: ", reqPrice, " Bid: ", curBid, " MinDist: ", minDist);
            return false;
         }
      }
      // BUY_LIMIT must be below current ask by minimum distance
      if(type == ORDER_TYPE_BUY_LIMIT) {
         if(curAsk - reqPrice < minDist) {
            Print("Error: BUY_LIMIT too close to Ask. Symbol: ", m_strategies[idx].symbolName, " Price: ", reqPrice, " Ask: ", curAsk, " MinDist: ", minDist);
            return false;
         }
      }
      Print("Unexpected error when checking stop level for symbol ", m_strategies[idx].symbolName, " with type ", type);
      return false;
   }

   // O(1) circular buffer write - overwrites oldest fatal ID when buffer full
   void AddToFatalBuffer(int id) {
      // Always insert, overwrite oldest if full
      m_fatalIDBuffer[m_fatalIDIndex] = id;
      m_fatalIDIndex = (m_fatalIDIndex + 1) % FATAL_BUFFER_SIZE;
      
      // Track count until we hit capacity
      if(m_fatalIDCount < FATAL_BUFFER_SIZE) {
         m_fatalIDCount++;
      }
   }
   
   // O(n) linear buffer search
   bool IsIDInFatalBuffer(int id) {
      if(id <= 0) return false;
      for(int i = 0; i < m_fatalIDCount; i++) {
         if(m_fatalIDBuffer[i] == id) return true;
      }
      return false;
   }

   //Public methods
public:
   COrderManager() { 
      m_strategyCount = 0;
      m_fatalIDCount = 0;
      m_fatalIDIndex = 0;
      
      // Initialize all symbol arrays
      for(int s = 0; s < MAX_STRATEGIES; s++) {
         TradeRequest tradeQueue[MAX_QUEUE_SIZE] = {};
         int tradeQueueHead = 0;
         int tradeQueueTail = 0;
         int tradeQueueCount = 0;
         TicketRequest ticketQueue[MAX_QUEUE_SIZE] = {};
         int ticketQueueHead = 0;
         int ticketQueueTail = 0;
         int ticketQueueCount = 0;

         double tickSize = 0.0;
         double point = 0.0;
         double volStep = 0.0;
         double volMin = 0.0;
         double volMax = 0.0;
         int digits = 0;
         long stopLevel = 0;
         ENUM_ORDER_TYPE_FILLING fillingType = 0;

         string symbolName = NULL;
         int magicNumber = 0;
         int stopLevelOverride = 0;
         int maxSpread = 0;
         int slippage = 0;
         RiskManagementMode riskMode = {};
         double riskValue = 0.0;
         
         ulong lastRefreshTime = 0;
      }
      
      // Initialize fatal ID buffer
      for(int i = 0; i < FATAL_BUFFER_SIZE; i++) {
         m_fatalIDBuffer[i] = 0;
      }
   }

   // Initialize base settings
   void Init(int retryDelay=5, uint timeBudgetMs=200) {
      m_retryDelay = retryDelay;
      m_isTester = MQLInfoInteger(MQL_TESTER);

      if(m_isTester) {
         m_processingBudgetMs = ULONG_MAX; // Remove timing constraints in tester
      }
      else {
         m_processingBudgetMs = timeBudgetMs;
      }
   }

   // Add a symbol to the manager and init symbol specific settings
   bool AddStrategy(int magic, string symbol, int maxSpread=100, int slippage=10, int stopLevelOverride=0, RiskManagementMode riskMode=RiskPercentBalance, double riskValue=2.0) {
      int idx = m_strategyCount;

      if(idx >= MAX_STRATEGIES - 1) {
         Print("Error: Maximum ", MAX_STRATEGIES, " strategies per instance");
         return false;
      }

      // Check if symbol already added
      if(GetSymbolIndex(magic) >= 0) {
         Print("Strategy with magic number ", magic, " already registered");
         return false;
      }

      m_strategies[idx].symbolName = symbol;
      m_strategies[idx].magicNumber = magic;
      m_strategies[idx].stopLevelOverride = stopLevelOverride;
      m_strategies[idx].maxSpread = maxSpread;
      m_strategies[idx].slippage = slippage;
      m_strategies[idx].trade.SetDeviationInPoints(slippage);
      m_strategies[idx].trade.SetExpertMagicNumber(magic);
      m_strategies[idx].trade.SetAsyncMode(false);
      m_strategies[idx].riskMode = riskMode;
      m_strategies[idx].riskValue = riskValue;
      
      // Fetch symbol info
      if (!RefreshSymbolInfo(idx)) {
         Print("Error: Failed to refresh symbol info for ", symbol);
         return false;
      }
      m_strategyCount++;
      Print("Added strategy with symbol ", symbol, " with magic ", magic, " at index ", idx);
      return true;
   }

   // Refresh symbol info for all symbols
   void RefreshSymbolInfo() {
      for(int i = 0; i < m_symbolCount; i++) {
         RefreshSymbolInfo(i);
      }
   }

   // Refresh symbol info for specific symbol
   bool RefreshSymbolInfo(int symbolIdx) {
      if(symbolIdx < 0 || symbolIdx >= m_strategyCount) return false;
      
      string symbol = m_strategies[symbolIdx].symbolName;
      m_strategies[symbolIdx].tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      m_strategies[symbolIdx].point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_strategies[symbolIdx].volStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      m_strategies[symbolIdx].volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      m_strategies[symbolIdx].volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      long symbol_fetched_stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if (symbol_fetched_stop_level > m_strategies[symbolIdx].stopLevelOverride) {
         m_strategies[symbolIdx].stopLevel = symbol_fetched_stop_level;
      }
      else {
         m_strategies[symbolIdx].stopLevel = m_strategies[symbolIdx].stopLevelOverride;
      }
      m_strategies[symbolIdx].fillingType = GetFillingType(symbol);
      m_strategies[symbolIdx].lastRefreshTime = GetTickCount64();
      return true;
   }

   // Calculate volume for specific strategy (returns unnormalized value)
   double CalcRiskVolumeSymbol(int magic, double entryPrice, double slPrice) {
      int idx = GetSymbolIndex(magic);
      if(idx < 0) {
         Print("Error: CalcRiskVolumeSymbol - Invalid symbol index for magic number ", magic);
         return 0;
      }

      // If fixed Lot return immediately
      if(m_strategies[idx].riskMode == RiskFixedLot) {
         return m_strategies[idx].riskValue;
      }

      // If RiskPercentBalance, calculate risk money based on account balance, otherwise use fixed money value
      double riskMoney = 0.0;
      if(m_strategies[idx].riskMode == RiskPercentBalance) {
         riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (m_strategies[idx].riskValue / 100.0);
      }
      else {
         riskMoney = m_strategies[idx].riskValue;
      }

      ENUM_ORDER_TYPE tempType = (entryPrice > slPrice) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      
      double lossPerLot = 0.0;
      if(!OrderCalcProfit(tempType, m_strategies[idx].symbolName, 1.0, entryPrice, slPrice, lossPerLot)) {
         Print("Error: CalcRiskVolumeSymbol - OrderCalcProfit failed for symbol ", m_strategies[idx].symbolName, ".");
         return 0;
      }

      lossPerLot = MathAbs(lossPerLot);
      if(lossPerLot > 0) {
         double calculatedVol = riskMoney / lossPerLot;
         return calculatedVol;
      }
      Print("Error: CalcRiskVolumeSymbol - Loss per lot is zero for symbol ", m_strategies[idx].symbolName, ". Cannot calculate volume.");
      return 0;
   }

   // O(1) circular buffer enqueue with bounds checking
   bool Trade(int magic, ENUM_ORDER_TYPE type, double vol, double price, double sl, double tp, string comment, int requestID, datetime expiration=0) {
      int idx = GetSymbolIndex(magic);
      if(idx < 0 || m_strategies[idx].tradeQueueCount >= MAX_QUEUE_SIZE) {
         if (idx < 0) {
            Print("Error: Trade - Invalid symbol index for magic number ", magic);
         }
         else {
            Print("Error: Trade - Trade queue full for symbol ", m_strategies[idx].symbolName);
         }
         return false;
      }

      // Handle automatic volume calculation based on risk mode
      if(vol == 0.0) {
         if(m_strategies[idx].riskMode == RiskFixedLot) {
            // RiskFixedLot: use the fixed lot value directly
            vol = m_strategies[idx].riskValue;
         }
         else if(m_strategies[idx].riskMode == RiskPercentBalance || m_strategies[idx].riskMode == RiskFixedMoney) {
            // RiskPercentBalance and RiskFixedMoney: calculate based on stop loss
            if(sl == 0) {
               Print("Error: Trade - Cannot auto-calculate volume without SL. Volume=0, SL=0 for symbol ", m_strategies[idx].symbolName);
               return false;
            }
            
            // Determine entry price for calculation
            double entryPrice = price;
            if(DoubleComparison(entryPrice, "LESS OR EQUAL", 0.0)) {
               // Market order: use current bid/ask
               double curAsk = SymbolInfoDouble(m_strategies[idx].symbolName, SYMBOL_ASK);
               double curBid = SymbolInfoDouble(m_strategies[idx].symbolName, SYMBOL_BID);
               
               if(type == ORDER_TYPE_BUY) {
                  entryPrice = curAsk;
               }
               else if(type == ORDER_TYPE_SELL) {
                  entryPrice = curBid;
               }
            }
            
            vol = CalcRiskVolumeSymbol(magic, entryPrice, sl);
         }
      }

      if(DoubleComparison(vol, "LESS OR EQUAL", 0.0)) {
         Print("Error: Trade - Calculated volume is zero or negative for symbol ", m_strategies[idx].symbolName, ". Volume: ", vol);
         return false;
      }

      //TODO: Check if correct
      TradeRequest req = {};
      req.type = type;
      req.volume = NormalizeVolSymbol(magic, vol);
      req.price = NormalizePriceSymbol(magic, price);
      req.sl = NormalizePriceSymbol(magic, sl);
      req.tp = NormalizePriceSymbol(magic, tp);
      req.expiration = expiration;
      req.comment = comment;
      req.retryAt = 0;
      req.requestID = requestID;

      m_strategies[idx].tradeQueue[m_strategies[idx].tradeQueueTail] = req;

      m_strategies[idx].tradeQueueTail = (m_strategies[idx].tradeQueueTail + 1) % MAX_QUEUE_SIZE;
      m_strategies[idx].tradeQueueCount++;
      return true;
   }

   // O(1) circular buffer enqueue with bounds checking
   bool ClosePosition(int magic, ulong ticket, int requestID) {
      int idx = GetSymbolIndex(magic);
      if(idx < 0 || ticket <= 0 || m_ticketQueueCounts[idx] >= MAX_QUEUE_SIZE) {
         if(idx < 0) {
            Print("Error: ClosePosition - Invalid symbol index for magic number ", magic);
         }
         else if (ticket <= 0) {
            Print("Error: ClosePosition - Invalid ticket: ", ticket);
         }
         else {
            Print("Error: ClosePosition - Trade queue full for symbol ", m_strategies[idx].symbolName);
         }
         return false;
      }

      TicketRequest req = {};
      req.ticket = ticket;
      req.action = STATE_PROCESSING_CLOSE;
      req.sl = 0;
      req.tp = 0;
      req.retryAt = 0;
      req.requestID = requestID;

      m_strategies[idx].ticketQueue[m_strategies[idx].ticketQueueTail] = req;
      
      m_strategies[idx].ticketQueueTail = (m_strategies[idx].ticketQueueTail + 1) % MAX_QUEUE_SIZE;
      m_strategies[idx].ticketQueueCount++;
      return true;
   }

   // O(1) circular buffer enqueue with bounds checking
   bool DeletePendingOrder(int magic, ulong ticket, int requestID) {
      int idx = GetSymbolIndex(magic);
      if(idx < 0 || ticket <= 0 || m_ticketQueueCounts[idx] >= MAX_QUEUE_SIZE) {
         if(idx < 0) {
            Print("Error: DeletePendingOrder - Invalid symbol index for magic number ", magic);
         }
         else if (ticket <= 0) {
            Print("Error: DeletePendingOrder - Invalid ticket: ", ticket);
         }
         else {
            Print("Error: DeletePendingOrder - Trade queue full for symbol ", m_strategies[idx].symbolName);
         }
         return false;
      }

      TicketRequest req = {};
      req.ticket = ticket;
      req.action = STATE_PROCESSING_DELETE;
      req.sl = 0;
      req.tp = 0;
      req.retryAt = 0;
      req.requestID = requestID;

      m_strategies[idx].ticketQueue[m_strategies[idx].ticketQueueTail] = req;
      
      m_strategies[idx].ticketQueueTail = (m_strategies[idx].ticketQueueTail + 1) % MAX_QUEUE_SIZE;
      m_strategies[idx].ticketQueueCount++;
      return true;
   }

   // O(1) circular buffer enqueue with bounds checking
   bool ModifyPosition(int magic, ulong ticket, double sl, double tp, int requestID) {
      int idx = GetSymbolIndex(symbol);
      if(idx < 0 || ticket <= 0 || m_ticketQueueCounts[idx] >= MAX_QUEUE_SIZE) {
         if(idx < 0) {
            Print("Error: ModifyPosition - Invalid symbol index for magic number ", magic);
         }
         else if (ticket <= 0) {
            Print("Error: ModifyPosition - Invalid ticket: ", ticket);
         }
         else {
            Print("Error: ModifyPosition - Trade queue full for symbol ", m_strategies[idx].symbolName);
         }
         return false;
      }

      TicketRequest req = {};
      req.ticket = ticket;
      req.action = STATE_PROCESSING_MODIFY;
      req.sl = NormalizePriceSymbol(symbol, sl);
      req.tp = NormalizePriceSymbol(symbol, tp);
      req.retryAt = 0;
      req.requestID = requestID;

      m_strategies[idx].ticketQueue[m_strategies[idx].ticketQueueTail] = req;
      
      m_strategies[idx].ticketQueueTail = (m_strategies[idx].ticketQueueTail + 1) % MAX_QUEUE_SIZE;
      m_strategies[idx].ticketQueueCount++;
      return true;
   }
   
   // O(n*m) request status lookup where n = strategies, m = average queue size
   // Searches all symbols' trade and ticket queues linearly
   RequestStatus GetRequestStatus(int id) {
      if(IsIDInFatalBuffer(id)) {
         return REQ_STATUS_ERROR;
      }
      
      // 2. Check all Trade Queues
      for(int s = 0; s < m_strategyCount; s++) {
         for(int i = 0; i < m_strategies[s].tradeQueueCount; i++) {
            int idx = (m_strategies[s].tradeQueueHead + i) % MAX_QUEUE_SIZE;
            if(m_strategies[s].tradeQueue[idx].requestID == id) {
               return REQ_STATUS_PENDING;
            }
         }
      }
      
      // 3. Check all Ticket Queues
      for(int s = 0; s < m_strategyCount; s++) {
         for(int i = 0; i < m_strategies[s].ticketQueueCount; i++) {
            int idx = (m_strategies[s].ticketQueueHead + i) % MAX_QUEUE_SIZE;
            if(m_strategies[s].ticketQueue[idx].requestID == id) {
               return REQ_STATUS_PENDING;
            }
         }
      }

      // 4. Not found in any queue or error buffer = success
      return REQ_STATUS_SUCCESS;
   }

   bool IsBusy() { 
      for(int s = 0; s < m_strategyCount; s++) {
         if(m_strategies[s].tradeQueueCount > 0 || m_strategies[s].ticketQueueCount > 0) {
            return true;
         }
      }
      return false;
   }

   // TODO:
   void Process() {
      if(!m_isTester && !TerminalInfoInteger(TERMINAL_CONNECTED)) return;
      
      // In tester, skip timer checks; in live trading, enforce budget
      ulong startTime = m_isTester ? 0 : GetTickCount64();
      
      // Process all symbols
      for(int s = 0; s < m_symbolCount; s++) {
         // Optimize symbol refresh: use iTime() for bar detection in tester (cached, not a terminal call)
         // iTime() is ~1000x faster than SeriesInfoInteger() per tick
         if(!m_isTester) {
            if(GetTickCount64() - m_lastSymbolRefresh[s] > 10000) {
               RefreshSymbolInfo(s);
            }
         }
         
         // Process ticket queue (closes, deletes, modifies)
         while(m_ticketQueueCounts[s] > 0 && (m_isTester || (GetTickCount64() - startTime < m_processingBudgetMs))) {
            if(!ProcessTicketItem(s)) {
               break; // Retry delay active, stop processing this symbol
            }
         }

         // Process trade queue (opens)
         while(m_tradeQueueCounts[s] > 0 && (m_isTester || (GetTickCount64() - startTime < m_processingBudgetMs))) {
            if(!m_isTester && SymbolInfoInteger(m_strategies[s], SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL) break;
            if(!ProcessTradeItem(s)) {
               break; // Retry delay active, stop processing this symbol
            }
         }
      }
   }

private:
   bool ProcessTicketItem(int symbolIdx) {
      string symbol = m_strategies[symbolIdx];
      
      // Head points to next item to process; if empty queue, return false
      if(m_ticketQueueCounts[symbolIdx] <= 0) return false;
      
      TicketRequest req = m_ticketQueues[symbolIdx][m_ticketQueueHeads[symbolIdx]];
      
      // Check retry delay (enabled in both live trading and backtesting)
      if(TimeCurrent() < req.retryAt) return false;

      bool res = false;
      bool fatal = false;

      if(req.action == STATE_PROCESSING_CLOSE) {
         if(!PositionSelectByTicket(req.ticket)) fatal = true; 
         else res = m_trade.PositionClose(req.ticket);
      }
      else if(req.action == STATE_PROCESSING_DELETE) {
         if(!OrderSelect(req.ticket)) fatal = true; 
         else res = m_trade.OrderDelete(req.ticket);
      }
      else if(req.action == STATE_PROCESSING_MODIFY) {
         if(!PositionSelectByTicket(req.ticket)) fatal = true;
         else res = m_trade.PositionModify(req.ticket, req.sl, req.tp);
      }

      uint ret = m_trade.ResultRetcode();

      // Success, fatal error, or tester rejection = dequeue
      if(fatal || (res && (ret == TRADE_RETCODE_DONE || ret == TRADE_RETCODE_PLACED)) || (m_isTester && !res)) {
         if(fatal) {
            Print("ERROR: Fatal Ticket Error - RequestID: ", req.requestID, " | Retcode: ", ret, " | Ticket: ", req.ticket, " | Action: ", req.action);
            AddToFatalBuffer(req.requestID);
         }
         
         // Dequeue from head (O(1) circular buffer operation)
         m_ticketQueueHeads[symbolIdx] = (m_ticketQueueHeads[symbolIdx] + 1) % 512;
         m_ticketQueueCounts[symbolIdx]--;
         return true; 
      } 
      else {
         Print("Error: Ticket Retry - RequestID: ", req.requestID, " | Retcode: ", ret, " | Ticket: ", req.ticket, " | NextRetryAt: ", TimeCurrent() + m_retryDelay);
         m_ticketQueues[symbolIdx][m_ticketQueueHeads[symbolIdx]].retryAt = TimeCurrent() + m_retryDelay;
         return false; // Don't dequeue; retry later
      }
   }

   bool ProcessTradeItem(int symbolIdx) {
      string symbol = m_strategies[symbolIdx];
      int idx = symbolIdx;  // idx is already passed as parameter, avoid O(n) lookup
      
      // Head points to next item to process
      if(m_tradeQueueCounts[symbolIdx] <= 0) return false;
      
      TradeRequest req = m_tradeQueues[symbolIdx][m_tradeQueueHeads[symbolIdx]];
      
      // Check retry delay (enabled in both live trading and backtesting to handle market-closed errors)
      if(TimeCurrent() < req.retryAt) return false;

      // Cache market data (single call is more efficient than multiple)
      double curAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double curBid = SymbolInfoDouble(symbol, SYMBOL_BID);
      
      bool res = false;
      bool fatal = false;
      
      if(!CheckStopLevelSymbol(symbol, req.type, req.price, curAsk, curBid)) {
         Print("Trade Cancelled: StopLevel Violation.");
         AddToFatalBuffer(req.requestID);
         m_tradeQueueHeads[symbolIdx] = (m_tradeQueueHeads[symbolIdx] + 1) % 512;
         m_tradeQueueCounts[symbolIdx]--;
         RefreshSymbolInfo(idx); 
         return true;
      }

      double executionPrice = req.price;

      if(req.type == ORDER_TYPE_BUY || req.type == ORDER_TYPE_SELL) {
         double spread = (curAsk - curBid) / m_points[idx];
         if(spread > m_maxSpread) {
             Print("Spread High (", spread, "). Waiting.");
             m_tradeQueues[symbolIdx][m_tradeQueueHeads[symbolIdx]].retryAt = TimeCurrent() + m_retryDelay;
             return false;
         }
         
         if(req.type == ORDER_TYPE_BUY) {
            executionPrice = (executionPrice <= 0) ? curAsk : req.price;
         }
         if(req.type == ORDER_TYPE_SELL) {
            executionPrice = (executionPrice <= 0) ? curBid : req.price;
         }
      }

      // Execute trade
      if(req.type == ORDER_TYPE_BUY) {
         res = m_trade.Buy(req.volume, symbol, executionPrice, req.sl, req.tp, req.comment);
      }
      else if(req.type == ORDER_TYPE_SELL) {
         res = m_trade.Sell(req.volume, symbol, executionPrice, req.sl, req.tp, req.comment);
      }
      else {
         ENUM_ORDER_TYPE_TIME timeMode = (req.expiration > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC;
         res = m_trade.OrderOpen(symbol, req.type, req.volume, 0.0, req.price, req.sl, req.tp, timeMode, req.expiration, req.comment);
      }

      uint ret = m_trade.ResultRetcode();
      
      // Detect fatal errors
      if(ret == TRADE_RETCODE_INVALID_VOLUME || ret == TRADE_RETCODE_NO_MONEY || 
         ret == TRADE_RETCODE_INVALID_STOPS || ret == TRADE_RETCODE_REJECT ||
         ret == TRADE_RETCODE_INVALID_EXPIRATION) fatal = true;

      if(ret == TRADE_RETCODE_INVALID_STOPS) RefreshSymbolInfo(idx);

      // Dequeue on success or fatal error only; allow temporary errors to retry
      if((res && (ret == TRADE_RETCODE_DONE || ret == TRADE_RETCODE_PLACED)) || fatal) {
         if(fatal) {
            Print("ERROR: Fatal Trade Error - RequestID: ", req.requestID, " | Retcode: ", ret, " | Symbol: ", symbol, " | Type: ", req.type, " | Volume: ", req.volume);
            AddToFatalBuffer(req.requestID);
         }
         m_tradeQueueHeads[symbolIdx] = (m_tradeQueueHeads[symbolIdx] + 1) % 512;
         m_tradeQueueCounts[symbolIdx]--;
         return true;
      }
      else {
         Print("ERROR: Trade Retry - RequestID: ", req.requestID, " | Retcode: ", ret, " | Symbol: ", symbol, " | Type: ", req.type, " | NextRetryAt: ", TimeCurrent() + m_retryDelay);
         m_tradeQueues[symbolIdx][m_tradeQueueHeads[symbolIdx]].retryAt = TimeCurrent() + m_retryDelay;
         return false; // Don't dequeue; retry later
      }
   }
};
