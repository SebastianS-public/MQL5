//#include <Controls\Dialog.mqh>
//CAppDialog AppWindow;
#property script_show_inputs

input datetime TimeStart = D'21.11.2022';
input datetime TimeEnd = D'30.12.2022';

int slippageInUSDJPY = 0;
int slippageOutUSDJPY = 0;
int counterInUSDJPY = 0;
int counterOutUSDJPY = 0;

int slippageInEURUSD = 0;
int slippageOutEURUSD = 0;
int counterInEURUSD = 0;
int counterOutEURUSD = 0;

int slippageInGBPUSD = 0;
int slippageOutGBPUSD = 0;
int counterInGBPUSD = 0;
int counterOutGBPUSD = 0;

double dealPrice;
double orderPrice;

void OnStart(){
   HistorySelect(TimeStart,TimeEnd);

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--){
      ulong dealTicket = HistoryDealGetTicket(i);
      ulong orderTicket = HistoryDealGetInteger(dealTicket,DEAL_ORDER);
      
      dealPrice = HistoryDealGetDouble(dealTicket,DEAL_PRICE);
      orderPrice = HistoryOrderGetDouble(orderTicket,ORDER_PRICE_OPEN);
      
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket,DEAL_ENTRY);
      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket,DEAL_TYPE);
      
      string dealSymbol = HistoryDealGetString(dealTicket,DEAL_SYMBOL);
      
      if(dealSymbol == "USDJPY" && dealPrice > 0 && orderPrice > 0){
         calcSlippageInUSDJPY(dealEntry,dealType);
         calcSlippageOutUSDJPY(dealEntry,dealType);
      }
      if(dealSymbol == "EURUSD" && dealPrice > 0 && orderPrice > 0){
         calcSlippageInEURUSD(dealEntry,dealType);
         calcSlippageOutEURUSD(dealEntry,dealType);
      }
      if(dealSymbol == "GBPUSD" && dealPrice > 0 && orderPrice > 0){
         calcSlippageInGBPUSD(dealEntry,dealType);
         calcSlippageOutGBPUSD(dealEntry,dealType);
      }
   }
   string averageSlippageInEURUSD = DoubleToString((double)(slippageInEURUSD)/counterInEURUSD,2);
   string averageSlippageInGBPUSD = DoubleToString((double)(slippageInGBPUSD)/counterInGBPUSD,2);
   string averageSlippageInUSDJPY = DoubleToString((double)(slippageInUSDJPY)/counterInUSDJPY,2);
   string averageSlippageOutEURUSD = DoubleToString((double)(slippageOutEURUSD)/counterOutEURUSD,2);
   string averageSlippageOutGBPUSD = DoubleToString((double)(slippageOutGBPUSD)/counterOutGBPUSD,2);
   string averageSlippageOutUSDJPY = DoubleToString((double)(slippageOutUSDJPY)/counterOutUSDJPY,2);
   string totalSlippageUSDJPY = IntegerToString(slippageInUSDJPY + slippageOutUSDJPY);
   string totalSlippageEURUSD = IntegerToString(slippageInEURUSD + slippageOutEURUSD);
   string totalSlippageGBPUSD = IntegerToString(slippageInGBPUSD + slippageOutGBPUSD);
   string averageSlippageEURUSD = DoubleToString(((double)(slippageInEURUSD) + (double)(slippageOutEURUSD))/counterInEURUSD,2);
   string averageSlippageGBPUSD = DoubleToString(((double)(slippageInGBPUSD) + (double)(slippageOutGBPUSD))/counterInGBPUSD,2);
   string averageSlippageUSDJPY = DoubleToString(((double)(slippageInUSDJPY) + (double)(slippageOutUSDJPY))/counterInUSDJPY,2);
   string message = "                                                                               "
                  + "                                           "
                    "EURUSD:\n\nTotal Positions: " + IntegerToString(counterInEURUSD) + "\nSlippage In: " + 
                     IntegerToString(slippageInEURUSD) + " (" + averageSlippageInEURUSD + ")" + "\nSlippage Out: " + IntegerToString(slippageOutEURUSD) +
                     " (" + averageSlippageOutEURUSD + ")" + "\nTotal Slippage: " + totalSlippageEURUSD + "\nAverage Slippage: " + averageSlippageEURUSD + "\n\n\n"
                  +  "GBPUSD:\n\nTotal Positions: " + IntegerToString(counterInGBPUSD) + "\nSlippage In: " + 
                     IntegerToString(slippageInGBPUSD) + " (" + averageSlippageInGBPUSD + ")" + "\nSlippage Out: " + IntegerToString(slippageOutGBPUSD) +
                     " (" + averageSlippageOutGBPUSD + ")" + "\nTotal Slippage: " + totalSlippageGBPUSD + "\nAverage Slippage: " + averageSlippageGBPUSD + "\n\n\n"
                  +  "USDJPY:\n\nTotal Positions: " + IntegerToString(counterInUSDJPY) + "\nSlippage In: " + 
                     IntegerToString(slippageInUSDJPY) + " (" + averageSlippageInUSDJPY + ")" + "\nSlippage Out: " + IntegerToString(slippageOutUSDJPY) +
                     " (" + averageSlippageOutUSDJPY + ")" + "\nTotal Slippage: " + totalSlippageUSDJPY + "\nAverage Slippage: " + averageSlippageUSDJPY + "\n\n\n";
   MessageBox(message,"Slippage Analyzer",0);
}

void calcSlippageInUSDJPY(ENUM_DEAL_ENTRY dealEntry,ENUM_DEAL_TYPE dealType){
   if(dealEntry == DEAL_ENTRY_IN){
      if(dealType == DEAL_TYPE_BUY){
         slippageInUSDJPY += (int)(NormalizeDouble((orderPrice-dealPrice)/SymbolInfoDouble("USDJPY",SYMBOL_POINT),_Digits));
      }
      if(dealType == DEAL_TYPE_SELL){
         slippageInUSDJPY += (int)(NormalizeDouble((dealPrice-orderPrice)/SymbolInfoDouble("USDJPY",SYMBOL_POINT),_Digits));
      }
      counterInUSDJPY++;
   }
}

void calcSlippageOutUSDJPY(ENUM_DEAL_ENTRY dealEntry,ENUM_DEAL_TYPE dealType){
   if(dealEntry == DEAL_ENTRY_OUT){
      if(dealType == DEAL_TYPE_BUY){
         slippageOutUSDJPY += (int)(NormalizeDouble((orderPrice-dealPrice)/SymbolInfoDouble("USDJPY",SYMBOL_POINT),_Digits));
      }
      if(dealType == DEAL_TYPE_SELL){
         slippageOutUSDJPY += (int)(NormalizeDouble((dealPrice-orderPrice)/SymbolInfoDouble("USDJPY",SYMBOL_POINT),_Digits));
      }
      counterOutUSDJPY++;
   }
}

void calcSlippageInEURUSD(ENUM_DEAL_ENTRY dealEntry,ENUM_DEAL_TYPE dealType){
   if(dealEntry == DEAL_ENTRY_IN){
      if(dealType == DEAL_TYPE_BUY){
         slippageInEURUSD += (int)(NormalizeDouble((orderPrice-dealPrice)/SymbolInfoDouble("EURUSD",SYMBOL_POINT),_Digits));
      }
      if(dealType == DEAL_TYPE_SELL){
         slippageInEURUSD += (int)(NormalizeDouble((dealPrice-orderPrice)/SymbolInfoDouble("EURUSD",SYMBOL_POINT),_Digits));
      }
      counterInEURUSD++;
   }
}

void calcSlippageOutEURUSD(ENUM_DEAL_ENTRY dealEntry,ENUM_DEAL_TYPE dealType){
   if(dealEntry == DEAL_ENTRY_OUT){
      if(dealType == DEAL_TYPE_BUY){
         slippageOutEURUSD += (int)(NormalizeDouble((orderPrice-dealPrice)/SymbolInfoDouble("EURUSD",SYMBOL_POINT),_Digits));
      }
      if(dealType == DEAL_TYPE_SELL){
         slippageOutEURUSD += (int)(NormalizeDouble((dealPrice-orderPrice)/SymbolInfoDouble("EURUSD",SYMBOL_POINT),_Digits));
      }
      counterOutEURUSD++;
   }
}

void calcSlippageInGBPUSD(ENUM_DEAL_ENTRY dealEntry,ENUM_DEAL_TYPE dealType){
   if(dealEntry == DEAL_ENTRY_IN){
      if(dealType == DEAL_TYPE_BUY){
         slippageInGBPUSD += (int)(NormalizeDouble((orderPrice-dealPrice)/SymbolInfoDouble("GBPUSD",SYMBOL_POINT),_Digits));
      }
      if(dealType == DEAL_TYPE_SELL){
         slippageInGBPUSD += (int)(NormalizeDouble((dealPrice-orderPrice)/SymbolInfoDouble("GBPUSD",SYMBOL_POINT),_Digits));
      }
      counterInGBPUSD++;
   }
}

void calcSlippageOutGBPUSD(ENUM_DEAL_ENTRY dealEntry,ENUM_DEAL_TYPE dealType){
   if(dealEntry == DEAL_ENTRY_OUT){
      if(dealType == DEAL_TYPE_BUY){
         slippageOutGBPUSD += (int)(NormalizeDouble((orderPrice-dealPrice)/SymbolInfoDouble("GBPUSD",SYMBOL_POINT),_Digits));
      }
      if(dealType == DEAL_TYPE_SELL){
         slippageOutGBPUSD += (int)(NormalizeDouble((dealPrice-orderPrice)/SymbolInfoDouble("GBPUSD",SYMBOL_POINT),_Digits));
      }
      counterOutGBPUSD++;
   }
}