#include <Trade/Trade.mqh>
CTrade trade;

input int MACDfast = 12;
input int MACDslow = 26;
input int MACDsignal = 9;
input int MAPeriod = 200;
input double MAinclineTrigger = 0.990;
input double SlDistanceMultiplier = 1.0;
input double TpDistanceMultiplier = 1.0;
input double RiskInPercent = 1.0;
input ENUM_TIMEFRAMES Timeframe;

int MACDhandle;
int MAhandle;

void OnInit(){
   MACDhandle = iMACD(_Symbol,Timeframe,MACDfast,MACDslow,MACDsignal,PRICE_CLOSE);
   MAhandle = iMA(_Symbol,Timeframe,MAPeriod,0,MODE_EMA,PRICE_CLOSE);
}

void OnTick(){
   bool newCandle = detectNewCandle();
   if(newCandle){
      double MACDmainLine[];
      CopyBuffer(MACDhandle,MAIN_LINE,1,2,MACDmainLine);
      double MACDsignalLine[];
      CopyBuffer(MACDhandle,SIGNAL_LINE,1,2,MACDsignalLine);
      double MAvalue[];
      CopyBuffer(MAhandle,0,1,20,MAvalue);
      bool upCross = false;
      bool downCross = false;
      double lastClose = iClose(_Symbol,Timeframe,1);
      double maIncline = MathMin(MAvalue[19],MAvalue[0]) / MathMax(MAvalue[19],MAvalue[0]);
      Print(maIncline);
      if(MACDmainLine[0] < MACDsignalLine[0] && MACDmainLine[1] > MACDsignalLine[1] && MACDmainLine[1] < 0 && MACDsignalLine[1] < 0 &&
         lastClose > MAvalue[19] && maIncline < MAinclineTrigger){
            upCross = true;
      }
      if(MACDmainLine[0] > MACDsignalLine[0] && MACDmainLine[1] < MACDsignalLine[1] && MACDmainLine[1] > 0 && MACDsignalLine[1] > 0 &&
         lastClose < MAvalue[19] && maIncline < MAinclineTrigger){
            downCross = true;
      }
      if(upCross){
         double distance = lastClose - MAvalue[19];
         double sl = lastClose - distance * SlDistanceMultiplier;
         double tp = lastClose + distance * TpDistanceMultiplier;
         double lots = calcLots(distance * SlDistanceMultiplier / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
         trade.Buy(lots,_Symbol,0,sl,tp);
      }
      if(downCross){
         double distance = MAvalue[19] - lastClose;
         double sl = lastClose + distance * SlDistanceMultiplier;
         double tp = lastClose - distance * TpDistanceMultiplier;
         double lots = calcLots(distance * SlDistanceMultiplier / SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
         trade.Sell(lots,_Symbol,0,sl,tp);
      }
   }
}

bool detectNewCandle(){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,Timeframe,0,3,priceData);
   datetime currentCandle;
   static datetime lastCandle;
   currentCandle = priceData[0].time;
   bool newCandle = false;
   if(currentCandle != lastCandle){
      lastCandle = currentCandle;
      newCandle = true;
   }
   return newCandle;
}

double calcLots(double stopLossPoints){
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0){
      return 0;
   }
   
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskInPercent/100;
   double moneyPerLotstep = stopLossPoints * tickvalue * lotstep;
   if(moneyPerLotstep == 0){
      return 0;
   }
   
   int normalizeStep = 0;
   
   if(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.01){
      normalizeStep = 2;
   }
   if (SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP) == 0.1){
      normalizeStep = 1;
   }
   
   double tradeLots = NormalizeDouble(riskMoney / moneyPerLotstep * lotstep, normalizeStep);
   if(tradeLots < SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)){
      tradeLots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   }
   if(tradeLots > SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)){
      tradeLots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   }
   return tradeLots;
}