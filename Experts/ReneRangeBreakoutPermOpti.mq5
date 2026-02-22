#include <Trade/Trade.mqh>
CTrade trade;

enum RiskManagementMode{
   RiskPercentage,
   RiskPercentageStartAccount,
   FixedLotSize,
};

struct ResultStruct{
   int pass;
   double customVal;
   double profit;
   int trades;
   int StartMinAM;
   int EndMinAS;
   int CloseTH;
   double SLMulti;
   int BiDiTrade;
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

input group "Trade Settings"
input bool UseTakeProfit = true;
input double TPMultiplier = 1;
input double SLMultiplier = 1;
input bool BiDirectionalTrading = true;

input group "Additional Settings"
input string TradeComment = "Enter Comment";
input bool Logs = false;
input bool PrintOnChart = false;
input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;


int normalizeStep;
double high = 0, low = 0;
string currentSymbol;
double fixedRiskMoney;
datetime closeTime, startTime, endTime;
bool tradesToday = false;
bool firstTick = true;
bool backtest = false;

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
   if(StartMinutesAfterMidnight + EndMinutesAfterStart > CloseTradesHour * 60){
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
            Print("if open trades close all trades immediately");
            if(positionTicket != 0){
               closePosition(positionTicket);
            }
            if(openOrders){
               deleteOrders();
            }
         }
         if(backtest){
            backtest();
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
         if(PrintOnChart){
            Comment("\nHigh: ", high, "\nLow: ", low);
         }
      }
      
      if(high != 0 && low != 0 && !openOrders && !tradesToday){
         executeOrdersTrades();
         tradesToday = true;
      }
   }
}

void OnTrade(){
   ulong positionTicket = getOpenPositionTicket();
   bool openOrders = checkOrders();
   if(!BiDirectionalTrading && positionTicket != 0){
      deleteOrders();
   }
}

double OnTester(){
   double metric = 0.0;
   metric = TesterStatistics(STAT_SHARPE_RATIO) * (TesterStatistics(STAT_PROFIT) / (TesterStatistics(STAT_EQUITY_DD) / 4500)) / 100000;
   if(TesterStatistics(STAT_PROFIT) <= 0){
      return 0;
   }
   return metric;
}

void backtest(){
   int startStart = 15, startEnd = 900, startIntervall = 30;
   int endStart = 60, endEnd = 600, endIntervall = 15;
   int closeStart = 16, closeEnd = 22, closeIntervall = 1;
   int slMultiStart = 4, slMultiEnd = 20, slMultiIntervall = 2;
   int biDirStart = 0, biDirEnd = 1, biDirIntervall = 1;
   int totalRuns = ((startEnd - startStart) / startIntervall) * ((endEnd - endStart) / endIntervall) * ((closeEnd - closeStart) / closeIntervall) *
                   ((slMultiEnd - slMultiStart) / slMultiIntervall) * ((biDirEnd - biDirStart) / biDirIntervall);
   ResultStruct result[];
   ArrayResize(result, totalRuns);
   
   bool tradeBuy = false, tradeSell = false, tradeBuyCurrent = false, tradeSellCurrent = false;
   double buySlPrice = 0, sellSlPrice = 0;

   for(; startStart <= startEnd; startStart += startIntervall){
      for(; endStart <= endEnd; endStart += endIntervall){
         for(; closeStart <= closeEnd; closeStart += closeIntervall){
            for(; slMultiStart <= slMultiEnd; slMultiStart += slMultiIntervall){
               for(; biDirStart <= biDirEnd; biDirStart += biDirIntervall){
                  datetime zeroTime = getTimes(startStart, endStart, closeStart, TimeCurrent() - 1000);
                  tradeBuy = false;
                  tradeBuyCurrent = false;
                  tradeSell = false;
                  tradeSellCurrent = false;
                  int numberBarsStartEnd = Bars(currentSymbol,PERIOD_M1,startTime,endTime);
                  int numberBarsEndToCurrent = Bars(currentSymbol,PERIOD_M1,endTime,zeroTime);
                  high = iHigh(currentSymbol,PERIOD_M1,iHighest(currentSymbol,PERIOD_M1,MODE_HIGH,numberBarsStartEnd,numberBarsEndToCurrent));
                  low = iLow(currentSymbol,PERIOD_M1,iLowest(currentSymbol,PERIOD_M1,MODE_LOW,numberBarsStartEnd,numberBarsEndToCurrent));
                  for(; numberBarsEndToCurrent > 0; numberBarsEndToCurrent--){
                     double barHigh = iHigh(currentSymbol,PERIOD_M1,numberBarsEndToCurrent);
                     double barLow = iLow(currentSymbol,PERIOD_M1,numberBarsEndToCurrent);
                     if(barHigh > high && ! tradeBuy){
                        if(biDirStart == 0){
                           tradeSell = true;
                        }
                        tradeBuy = true;
                        tradeBuyCurrent = true;
                        buySlPrice = high - (high - low) * slMultiStart;
                        //trade Logic
                     }
                     if(barLow < low && ! tradeSell){
                        if(biDirStart == 0){
                           tradeBuy = true;
                        }
                        tradeSell = true;
                        tradeSellCurrent = true;
                        sellSlPrice = low + (high - low) * slMultiStart;
                        //trade Logic
                     }
                     if(tradeBuyCurrent){
                        if(barLow < buySlPrice){
                           
                        }
                     }
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
      }
   }
}

void closePosition(ulong ticket){
   trade.PositionClose(ticket);
}

void placeBuyStop(double price, double stopLoss, double takeProfit, double volume){
   volume = NormalizeDouble(volume, normalizeStep);
   Print("volume ", volume, "price ", price, "stoploss ", stopLoss, "takeprofit ", takeProfit);
   trade.BuyStop(volume, price, currentSymbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, TradeComment);
}

void placeSellStop(double price, double stopLoss, double takeProfit, double volume){
   volume = NormalizeDouble(volume, normalizeStep);
   Print("volume ", volume, "price ", price, "stoploss ", stopLoss, "takeprofit ", takeProfit);
   trade.SellStop(volume, price, currentSymbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, TradeComment);
}

void executeBuy(double stopLoss, double takeProfit, double volume){
   volume = NormalizeDouble(volume, normalizeStep);
   Print("volume ", volume, "stoploss ", stopLoss, "takeprofit ", takeProfit);
   trade.Buy(volume, currentSymbol, 0, stopLoss, takeProfit, TradeComment);
}

void executeSell(double stopLoss, double takeProfit, double volume){
   volume = NormalizeDouble(volume, normalizeStep);
   Print("volume ", volume, "stoploss ", stopLoss, "takeprofit ", takeProfit);
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
      Print(volume);
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
      Print("buystop");
   }
   else{
      executeBuy(buySl, buyTp, volume);
      Print("marketbuy");
   }
   if(SymbolInfoDouble(currentSymbol,SYMBOL_BID) > low + 10 * SymbolInfoDouble(currentSymbol,SYMBOL_TRADE_TICK_SIZE)){
      placeSellStop(low, sellSl, sellTp, volume);
      Print("sellstop");
   }
   else{
      executeSell(sellSl, sellTp, volume);
      Print("marketsell");
   }
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
   }
   return 0;
}

datetime getTimes(int startMinAfterMidnight, int endMinAfterStart, int closeTrades, datetime time){
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
   if(PrintOnChart){
      Comment("Start Time Today: ", startTime, "\nEnd Time Today: ", endTime, "\nClose Time Today: ", closeTime);
   }
   return StringToTime(timeString) + 86400;
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