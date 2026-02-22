#property strict

#include <Trade/Trade.mqh>

// Constants for circular buffers (must be #define for array sizing)
#define MAX_QUEUE_SIZE 512
#define FATAL_BUFFER_SIZE 128
#define MAX_SYMBOLS 16  // Maximum symbols per instance

enum EAState {
   STATE_PROCESSING_CLOSE,
   STATE_PROCESSING_DELETE,
   STATE_PROCESSING_MODIFY 
};

enum RiskManagementMode {
   RiskFixedLot,
   RiskPercentBalance,
   RiskFixedMoney
};

// Added Enum for Request Status reporting
enum RequestStatus {
   REQ_STATUS_SUCCESS, // Not pending, not in fatal buffer -> Assumed Success
   REQ_STATUS_PENDING, // Still in queue or retrying
   REQ_STATUS_ERROR    // Found in fatal error buffer
};

struct TradeRequest {
   ENUM_ORDER_TYPE   type;
   double            volume;
   double            price;
   double            sl;
   double            tp;
   datetime          expiration;
   string            comment;
   datetime          retryAt; 
   int               requestID; // Added for ID Tracking
};

struct TicketRequest {
   ulong    ticket;
   EAState  action; 
   double   sl;     
   double   tp;     
   datetime retryAt; 
   int      requestID; // Added for ID Tracking
};

class COrderManager {
private:
   CTrade            m_trade;
   
   // Multi-symbol infrastructure
   string            m_symbols[16];
   int               m_symbolCount;
   
   // Per-symbol circular buffers (fixed size for backtesting efficiency)
   TradeRequest      m_tradeQueues[16][512];
   int               m_tradeQueueHeads[16];
   int               m_tradeQueueTails[16];
   int               m_tradeQueueCounts[16];
   
   TicketRequest     m_ticketQueues[16][512];
   int               m_ticketQueueHeads[16];
   int               m_ticketQueueTails[16];
   int               m_ticketQueueCounts[16];
   
   // Per-symbol market info (refreshed periodically)
   double            m_tickSizes[16];
   double            m_points[16];
   double            m_volSteps[16];
   double            m_volMins[16];
   double            m_volMaxs[16];
   int               m_stopLevels[16];
   
   // Per-symbol refresh timing
   ulong             m_lastSymbolRefresh[16];
   int               m_symbolRefreshBars[16];
   ENUM_ORDER_TYPE_FILLING m_fillingTypes[16];
   datetime          m_lastBarTime[16];     // Track last bar time for efficient bar detection in tester
   
   // Circular buffer for fatal request IDs (keeps most recent 128 failures)
   int               m_fatalIDBuffer[128];
   int               m_fatalIDCount;        // Current number of entries (0-128)
   int               m_fatalIDIndex;        // Next write position (circular)

   int               m_magicNumber;
   int               m_retryDelay;
   int               m_maxSpread;
   int               m_slippage;
   
   // Changed to ulong to match GetTickCount64
   ulong             m_processingBudgetMs;
   
   bool              m_isTester;

   RiskManagementMode m_riskMode;
   double             m_riskValue;

   // Helper: Find symbol index, return -1 if not found
   int GetSymbolIndex(string symbol) {
      for(int i = 0; i < m_symbolCount; i++) {
         if(m_symbols[i] == symbol) return i;
      }
      return -1;
   }

   ENUM_ORDER_TYPE_FILLING GetFillingType(string symbol) {
      int filling = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
      if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
      return ORDER_FILLING_RETURN;
   }

   double NormalizePrice(double p) {
      if(p <= 0) return 0;
      // Note: For multi-symbol, tickSize varies per symbol
      // This is a fallback; prefer NormalizePriceSymbol()
      return NormalizeDouble(p, _Digits);
   }

   // Normalize price for specific symbol
   double NormalizePriceSymbol(string symbol, double p) {
      if(p <= 0) return 0;
      int idx = GetSymbolIndex(symbol);
      if(idx < 0) return NormalizeDouble(p, _Digits);
      if(m_tickSizes[idx] == 0) return NormalizeDouble(p, _Digits);
      return NormalizeDouble(MathRound(p / m_tickSizes[idx]) * m_tickSizes[idx], _Digits);
   }

   // Normalize volume for specific symbol
   double NormalizeVolSymbol(string symbol, double v) {
      int idx = GetSymbolIndex(symbol);
      if(idx < 0) return NormalizeDouble(v, 2);
      double vol = MathFloor(v / m_volSteps[idx]) * m_volSteps[idx];
      if(vol < m_volMins[idx]) vol = m_volMins[idx];
      if(vol > m_volMaxs[idx]) vol = m_volMaxs[idx];
      return NormalizeDouble(vol, 2);
   }

   bool CheckStopLevel(ENUM_ORDER_TYPE type, double reqPrice, double curAsk, double curBid) {
      // Optimization: Skip stop level checks in tester to maximize speed
      if(m_isTester) return true;

      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL) return true;
      
      // Note: For multi-symbol, stopLevel varies per symbol
      // This method kept for compatibility; prefer CheckStopLevelSymbol()
      return true;
   }

   // Check stop level for specific symbol
   bool CheckStopLevelSymbol(string symbol, ENUM_ORDER_TYPE type, double reqPrice, double curAsk, double curBid) {
      // Optimization: Skip stop level checks in tester to maximize speed
      if(m_isTester) return true;

      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL) return true;
      
      int idx = GetSymbolIndex(symbol);
      if(idx < 0) return true;
      
      double minDist = m_stopLevels[idx] * m_points[idx];

      // BUY_STOP must be above current ask by minimum distance
      if(type == ORDER_TYPE_BUY_STOP) {
         if(reqPrice - curAsk < minDist) {
            Print("Error: BUY_STOP too close to Ask. Price: ", reqPrice, " Ask: ", curAsk, " MinDist: ", minDist);
            return false;
         }
      }
      // SELL_LIMIT must be above current bid by minimum distance
      if(type == ORDER_TYPE_SELL_LIMIT) {
         if(reqPrice - curBid < minDist) {
            Print("Error: SELL_LIMIT too close to Bid. Price: ", reqPrice, " Bid: ", curBid, " MinDist: ", minDist);
            return false;
         }
      }
      // SELL_STOP must be below current bid by minimum distance
      if(type == ORDER_TYPE_SELL_STOP) {
         if(curBid - reqPrice < minDist) {
            Print("Error: SELL_STOP too close to Bid. Price: ", reqPrice, " Bid: ", curBid, " MinDist: ", minDist);
            return false;
         }
      }
      // BUY_LIMIT must be below current ask by minimum distance
      if(type == ORDER_TYPE_BUY_LIMIT) {
         if(curAsk - reqPrice < minDist) {
            Print("Error: BUY_LIMIT too close to Ask. Price: ", reqPrice, " Ask: ", curAsk, " MinDist: ", minDist);
            return false;
         }
      }
      return true;
   }

   // O(1) circular buffer write - overwrites oldest fatal ID when buffer full
   void AddToFatalBuffer(int id) {
      if(id <= 0) return;
      
      // Always insert, overwrite oldest if full
      m_fatalIDBuffer[m_fatalIDIndex] = id;
      m_fatalIDIndex = (m_fatalIDIndex + 1) % 128;
      
      // Track count until we hit capacity
      if(m_fatalIDCount < 128) {
         m_fatalIDCount++;
      }
   }
   
   // O(n) linear buffer search where n <= 128 (keeps recent 128 fatal IDs)
   // Practical performance is acceptable due to small buffer size
   bool IsIDInFatalBuffer(int id) {
      if(id <= 0) return false;
      for(int i = 0; i < m_fatalIDCount; i++) {
         if(m_fatalIDBuffer[i] == id) return true;
      }
      return false;
   }

   // Efficient bar detection using iTime() instead of SeriesInfoInteger()
   // iTime() is cached by MT5, very fast compared to terminal API calls
   bool OnNewBar(int symbolIdx) {
      datetime currentBarTime = iTime(m_symbols[symbolIdx], _Period, 0);
      
      if(currentBarTime != m_lastBarTime[symbolIdx]) {
         m_lastBarTime[symbolIdx] = currentBarTime;
         return true;
      }
      return false;
   }

public:
   COrderManager() { 
      m_symbolCount = 0;
      m_fatalIDCount = 0;
      m_fatalIDIndex = 0;
      
      // Initialize all symbol arrays
      for(int s = 0; s < 16; s++) {
         m_symbols[s] = "";
         m_tradeQueueHeads[s] = 0;
         m_tradeQueueTails[s] = 0;
         m_tradeQueueCounts[s] = 0;
         m_ticketQueueHeads[s] = 0;
         m_ticketQueueTails[s] = 0;
         m_ticketQueueCounts[s] = 0;
         m_symbolRefreshBars[s] = -1;
         m_lastSymbolRefresh[s] = 0;
         m_lastBarTime[s] = 0;  // Initialize bar time tracking
      }
      
      // Initialize fatal ID buffer
      for(int i = 0; i < 128; i++) {
         m_fatalIDBuffer[i] = 0;
      }
   }

   // Initialize with first symbol
   void Init(string symbol, int magic, int retryDelay=5, int maxSpread=50, int slippage=10, uint timeBudgetMs=200) {
      m_magicNumber  = magic;
      m_retryDelay   = retryDelay;
      m_maxSpread    = maxSpread;
      m_slippage     = slippage;
      
      m_isTester     = (bool)MQLInfoInteger(MQL_TESTER);

      if(m_isTester) {
         m_processingBudgetMs = ULONG_MAX; // Remove timing constraints in tester
      } else {
         m_processingBudgetMs = (ulong)timeBudgetMs;
      }
      
      m_trade.SetExpertMagicNumber(m_magicNumber);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetAsyncMode(false);
      
      // Add first symbol
      AddSymbol(symbol);
   }

   // Add a symbol to the manager
   bool AddSymbol(string symbol) {
      if(m_symbolCount >= 16) {
         Print("Error: Maximum 16 symbols per instance");
         return false;
      }
      
      // Check if symbol already added
      if(GetSymbolIndex(symbol) >= 0) {
         Print("Symbol ", symbol, " already registered");
         return false;
      }
      
      int idx = m_symbolCount++;
      m_symbols[idx] = symbol;
      
      // Fetch symbol info
      RefreshSymbolInfo(idx);
      
      return true;
   }

   // Refresh symbol info for all symbols
   void RefreshSymbolInfo() {
      for(int i = 0; i < m_symbolCount; i++) {
         RefreshSymbolInfo(i);
      }
   }

   // Refresh symbol info for specific symbol
   void RefreshSymbolInfo(int symbolIdx) {
      if(symbolIdx < 0 || symbolIdx >= m_symbolCount) return;
      
      string symbol = m_symbols[symbolIdx];
      m_tickSizes[symbolIdx] = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      m_points[symbolIdx] = SymbolInfoDouble(symbol, SYMBOL_POINT);
      m_volSteps[symbolIdx] = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      m_volMins[symbolIdx] = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      m_volMaxs[symbolIdx] = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      m_stopLevels[symbolIdx] = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      m_fillingTypes[symbolIdx] = GetFillingType(symbol);
      
      if(m_isTester) {
         m_symbolRefreshBars[symbolIdx] = (int)SeriesInfoInteger(symbol, _Period, SERIES_BARS_COUNT);
      } else {
         m_lastSymbolRefresh[symbolIdx] = GetTickCount64();
      }
   }

   void SetRiskSettings(RiskManagementMode mode, double value) {
      m_riskMode  = mode;
      m_riskValue = value;
   }

   // Calculate risk volume for specific symbol (returns unnormalized value)
   double CalcRiskVolumeSymbol(string symbol, double entryPrice, double slPrice) {
      int idx = GetSymbolIndex(symbol);
      if(idx < 0) return 0;
      
      double calculatedVol = m_volMins[idx];
      if(m_riskMode == RiskFixedLot) return m_riskValue;
      
      double riskMoney = 0.0;
      if(m_riskMode == RiskPercentBalance) riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (m_riskValue / 100.0);
      else riskMoney = m_riskValue;

      ENUM_ORDER_TYPE tempType = (entryPrice > slPrice) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      
      double potentialProfit = 0.0;
      if(!OrderCalcProfit(tempType, symbol, 1.0, entryPrice, slPrice, potentialProfit)) {
         Print("Error: CalcRiskVolumeSymbol - OrderCalcProfit failed for symbol ", symbol, ". Using minimum volume.");
         return m_volMins[idx]; 
      }

      double lossPerLot = MathAbs(potentialProfit);

      if(lossPerLot > 0) calculatedVol = riskMoney / lossPerLot;
      
      return calculatedVol;
   }

   // O(1) circular buffer enqueue with bounds checking
   bool Trade(string symbol, ENUM_ORDER_TYPE type, double vol, double price, double sl, double tp, string comment, int requestID, datetime expiration=0) {
      int idx = GetSymbolIndex(symbol);
      if(idx < 0 || m_tradeQueueCounts[idx] >= 512) return false;

      // Handle automatic volume calculation based on risk mode
      if(vol == 0) {
         if(m_riskMode == RiskFixedLot) {
            // RiskFixedLot: use the fixed lot value directly
            vol = m_riskValue;
         }
         else if(m_riskMode == RiskPercentBalance || m_riskMode == RiskFixedMoney) {
            // RiskPercentBalance and RiskFixedMoney: calculate based on stop loss
            if(sl == 0) {
               Print("Error: Cannot auto-calculate volume without SL. Volume=0, SL=0.");
               return false;
            }
            
            // Determine entry price for calculation
            double entryPrice = price;
            if(entryPrice <= 0) {
               // Market order: use current bid/ask
               double curAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
               double curBid = SymbolInfoDouble(symbol, SYMBOL_BID);
               
               if(type == ORDER_TYPE_BUY) {
                  entryPrice = curAsk;
               }
               else if(type == ORDER_TYPE_SELL) {
                  entryPrice = curBid;
               }
               else if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) {
                  entryPrice = curAsk;
               }
               else if(type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP) {
                  entryPrice = curBid;
               }
            }
            
            vol = CalcRiskVolumeSymbol(symbol, entryPrice, sl);
         }
      }

      if(vol <= 0) return false;

      m_tradeQueues[idx][m_tradeQueueTails[idx]].type       = type;
      m_tradeQueues[idx][m_tradeQueueTails[idx]].volume     = NormalizeVolSymbol(symbol, vol);
      m_tradeQueues[idx][m_tradeQueueTails[idx]].price      = NormalizePriceSymbol(symbol, price);
      m_tradeQueues[idx][m_tradeQueueTails[idx]].sl         = NormalizePriceSymbol(symbol, sl);
      m_tradeQueues[idx][m_tradeQueueTails[idx]].tp         = NormalizePriceSymbol(symbol, tp);
      m_tradeQueues[idx][m_tradeQueueTails[idx]].expiration = expiration;
      m_tradeQueues[idx][m_tradeQueueTails[idx]].comment    = comment;
      m_tradeQueues[idx][m_tradeQueueTails[idx]].retryAt    = 0;
      m_tradeQueues[idx][m_tradeQueueTails[idx]].requestID  = requestID;

      m_tradeQueueTails[idx] = (m_tradeQueueTails[idx] + 1) % 512;
      m_tradeQueueCounts[idx]++;
      return true;
   }

   // O(1) circular buffer enqueue with bounds checking
   bool ClosePosition(string symbol, ulong ticket, int requestID) {
      int idx = GetSymbolIndex(symbol);
      if(idx < 0 || ticket <= 0 || m_ticketQueueCounts[idx] >= 512) return false;

      m_ticketQueues[idx][m_ticketQueueTails[idx]].ticket = ticket;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].action = STATE_PROCESSING_CLOSE;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].sl = 0; 
      m_ticketQueues[idx][m_ticketQueueTails[idx]].tp = 0; 
      m_ticketQueues[idx][m_ticketQueueTails[idx]].retryAt = 0;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].requestID = requestID;
      
      m_ticketQueueTails[idx] = (m_ticketQueueTails[idx] + 1) % 512;
      m_ticketQueueCounts[idx]++;
      return true;
   }

   // O(1) circular buffer enqueue with bounds checking
   bool DeletePendingOrder(string symbol, ulong ticket, int requestID) {
      int idx = GetSymbolIndex(symbol);
      if(idx < 0 || ticket <= 0 || m_ticketQueueCounts[idx] >= 512) return false;

      m_ticketQueues[idx][m_ticketQueueTails[idx]].ticket = ticket;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].action = STATE_PROCESSING_DELETE;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].sl = 0; 
      m_ticketQueues[idx][m_ticketQueueTails[idx]].tp = 0; 
      m_ticketQueues[idx][m_ticketQueueTails[idx]].retryAt = 0;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].requestID = requestID;
      
      m_ticketQueueTails[idx] = (m_ticketQueueTails[idx] + 1) % 512;
      m_ticketQueueCounts[idx]++;
      return true;
   }

   // O(1) circular buffer enqueue with bounds checking
   bool ModifyPosition(string symbol, ulong ticket, double sl, double tp, int requestID) {
      int idx = GetSymbolIndex(symbol);
      if(idx < 0 || ticket <= 0 || m_ticketQueueCounts[idx] >= 512) return false;

      m_ticketQueues[idx][m_ticketQueueTails[idx]].ticket = ticket;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].action = STATE_PROCESSING_MODIFY;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].sl = NormalizePriceSymbol(symbol, sl);
      m_ticketQueues[idx][m_ticketQueueTails[idx]].tp = NormalizePriceSymbol(symbol, tp);
      m_ticketQueues[idx][m_ticketQueueTails[idx]].retryAt = 0;
      m_ticketQueues[idx][m_ticketQueueTails[idx]].requestID = requestID;
      
      m_ticketQueueTails[idx] = (m_ticketQueueTails[idx] + 1) % 512;
      m_ticketQueueCounts[idx]++;
      return true;
   }
   
   // O(n*m) request status lookup where n = symbols, m = average queue size
   // Searches all symbols' trade and ticket queues linearly
   RequestStatus GetRequestStatus(int id) {
      // 1. Check Fatal Error Buffer first (O(n) where n <= 128)
      if(IsIDInFatalBuffer(id)) return REQ_STATUS_ERROR;
      
      // 2. Check all Trade Queues
      for(int s = 0; s < m_symbolCount; s++) {
         for(int i = 0; i < m_tradeQueueCounts[s]; i++) {
            int idx = (m_tradeQueueHeads[s] + i) % 512;
            if(m_tradeQueues[s][idx].requestID == id) return REQ_STATUS_PENDING;
         }
      }
      
      // 3. Check all Ticket Queues
      for(int s = 0; s < m_symbolCount; s++) {
         for(int i = 0; i < m_ticketQueueCounts[s]; i++) {
            int idx = (m_ticketQueueHeads[s] + i) % 512;
            if(m_ticketQueues[s][idx].requestID == id) return REQ_STATUS_PENDING;
         }
      }

      // 4. Not found in any queue or error buffer = success
      return REQ_STATUS_SUCCESS;
   }

   bool IsBusy() { 
      for(int s = 0; s < m_symbolCount; s++) {
         if(m_tradeQueueCounts[s] > 0 || m_ticketQueueCounts[s] > 0) return true;
      }
      return false;
   }

   void Process() {
      if(!m_isTester && !TerminalInfoInteger(TERMINAL_CONNECTED)) return;
      
      // In tester, skip timer checks; in live trading, enforce budget
      ulong startTime = m_isTester ? 0 : GetTickCount64();
      
      // Process all symbols
      for(int s = 0; s < m_symbolCount; s++) {
         // Optimize symbol refresh: use iTime() for bar detection in tester (cached, not a terminal call)
         // iTime() is ~1000x faster than SeriesInfoInteger() per tick
         if(m_isTester) {
            if(OnNewBar(s)) {
               RefreshSymbolInfo(s);
            }
         } else {
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
            if(!m_isTester && SymbolInfoInteger(m_symbols[s], SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL) break;
            if(!ProcessTradeItem(s)) {
               break; // Retry delay active, stop processing this symbol
            }
         }
      }
   }

private:
   bool ProcessTicketItem(int symbolIdx) {
      string symbol = m_symbols[symbolIdx];
      
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
      string symbol = m_symbols[symbolIdx];
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
         if(!m_isTester) Print("Trade Cancelled: StopLevel Violation.");
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
             if(!m_isTester) Print("Spread High (", spread, "). Waiting.");
             m_tradeQueues[symbolIdx][m_tradeQueueHeads[symbolIdx]].retryAt = TimeCurrent() + m_retryDelay;
             return false; // Don't dequeue; retry later
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