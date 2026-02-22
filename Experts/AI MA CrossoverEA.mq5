//+------------------------------------------------------------------+
//|                              EA MA Crossover                      |
//|                                                                  |
//| This EA opens a long position when the fast moving average        |
//| crosses above the slow moving average and a short position when   |
//| the fast moving average crosses below the slow moving average.   |
//+------------------------------------------------------------------+

#property copyright "Copyright 2022, XYZ Corp."
#property version   "1.0"

// Input parameters
input int    FastMA_Period = 10; // period of the fast MA
input int    SlowMA_Period = 20; // period of the slow MA
input ENUM_MA_METHOD FastMA_Method = MODE_SMA; // method of the fast MA
input ENUM_MA_METHOD SlowMA_Method = MODE_SMA; // method of the slow MA
input ENUM_APPLIED_PRICE FastMA_AppliedPrice = PRICE_CLOSE; // applied price of the fast MA
input ENUM_APPLIED_PRICE SlowMA_AppliedPrice = PRICE_CLOSE; // applied price of the slow MA
input int    Slippage = 3;       // slippage in points
input double LotSize = 0.01;     // lot size
input int    TakeProfit = 30;    // take profit in points
input int    StopLoss = 30;      // stop loss in points

// Global variables
int ticket = 0;    // ticket number of the opened position
double openPrice = 0.0; // open price of the opened position

//+------------------------------------------------------------------+
//| Expert start function                                             |
//+------------------------------------------------------------------+
void OnStart()
{
  // Create the moving average indicators
  MovingAverage fastMA(FastMA_Period, FastMA_Method, FastMA_AppliedPrice);
  MovingAverage slowMA(SlowMA_Period, SlowMA_Method, SlowMA_AppliedPrice);

  // Calculate the moving averages
  fastMA.Refresh(0);
  slowMA.Refresh(0);

  // Check if the fast MA has crossed above the slow MA
  if (fastMA.CrossesAbove(slowMA))
  {
    // Open a long position
    ticket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, Slippage, 0, 0, "MA Crossover EA", 0, 0, Green);

    // Check if the order was successfully placed
    if (ticket > 0)
    {
      // Save the open price of the position
      openPrice = Ask;

      // Print a message to the log
      Print("Opened a long position with ticket ", ticket, " at price ", openPrice);
    }
  }

  // Check if the fast MA has crossed below the slow MA
  if (fastMA.CrossesBelow(slowMA))
  {
    // Open a short position
    ticket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, Slippage, 0, 0, "MA Crossover EA", 0, 0, Red);

    // Check if the order was successfully placed
    if (ticket > 0)
    {
      // Save the open price of the position
      openPrice = Bid;

      // Print a message to the log
      Print("Opened a short position");
    }
   }
}
