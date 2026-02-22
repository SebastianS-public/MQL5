#include <Trade/Trade.mqh>
CTrade trade;

input double baseLot = 0.2;

void OnInit(){
   EventSetMillisecondTimer(500);
}

string fileName = "test.txt";
ushort splitChar = StringGetCharacter(",",0);

void OnTimer(){
   int fileHandle = FileOpen(fileName, FILE_READ | FILE_COMMON | FILE_TXT);
   string fileString = FileReadString(fileHandle);
   FileClose(fileHandle);
   string stringArray[2];
   StringSplit(fileString,splitChar,stringArray);
   string symbol = stringArray[0];
   double baseMultiplier = StringToDouble(stringArray[1]);
   double totalLots = baseMultiplier * baseLot;
   
   int totalPositions = PositionsTotal();
   double openLots = 0;
   for(int i = 0; i < totalPositions; i++){
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);
      double volume = PositionGetDouble(POSITION_VOLUME);
      if(PositionGetInteger(POSITION_TYPE) == 0){
         openLots = openLots + volume;
      }
      else if(PositionGetInteger(POSITION_TYPE) == 1){
         openLots = openLots - volume;
      }
   }
   if(openLots < totalLots && openLots >= 0){
      double lots = MathAbs(NormalizeDouble(totalLots - openLots,2));
      trade.Buy(lots,symbol,0,0,0,NULL);
   }
   else if(openLots > totalLots && openLots <= 0){
      double lots = MathAbs(NormalizeDouble(totalLots - openLots,2));
      trade.Sell(lots,symbol,0,0,0,NULL);
   }
   else if(openLots < totalLots && openLots <= 0){
      double volumeToClose = NormalizeDouble(MathAbs(openLots - totalLots),2);
      double closedVolume = 0;
      while(closedVolume != volumeToClose){
         ulong ticket = PositionGetTicket(0);
         if(PositionSelectByTicket(ticket)){
            if(PositionGetDouble(POSITION_VOLUME) <= volumeToClose - closedVolume){
               Print("Close trade ",ticket," with volume ",PositionGetDouble(POSITION_VOLUME));
               trade.PositionClose(ticket);
               closedVolume = closedVolume + PositionGetDouble(POSITION_VOLUME);
               Print("Trade closed, closed Volume: ",closedVolume,"/",volumeToClose);
            }
            else if(PositionGetDouble(POSITION_VOLUME) > volumeToClose - closedVolume){
               Print("Close partial trade ",ticket," closing volume ",NormalizeDouble(volumeToClose - closedVolume,2));
               trade.PositionClosePartial(ticket,NormalizeDouble(volumeToClose - closedVolume,2));
               closedVolume = volumeToClose;
               Print("Partial closed, closed Volume: ",closedVolume,"/",volumeToClose);
            }
         }
      }
   }
   else if(openLots > totalLots && openLots >= 0){
      double volumeToClose = NormalizeDouble(MathAbs(openLots - totalLots),2);
      double closedVolume = 0;
      while(closedVolume != volumeToClose){
         ulong ticket = PositionGetTicket(0);
         if(PositionSelectByTicket(ticket)){
            if(PositionGetDouble(POSITION_VOLUME) <= volumeToClose - closedVolume){
               Print("Close trade ",ticket," with volume ",PositionGetDouble(POSITION_VOLUME));
               trade.PositionClose(ticket);
               closedVolume = closedVolume + PositionGetDouble(POSITION_VOLUME);
               Print("Trade closed, closed Volume: ",closedVolume,"/",volumeToClose);
            }
            else if(PositionGetDouble(POSITION_VOLUME) > volumeToClose - closedVolume){
               Print("Close partial trade ",ticket," closing volume ",NormalizeDouble(volumeToClose - closedVolume,2));
               trade.PositionClosePartial(ticket,NormalizeDouble(volumeToClose - closedVolume,2));
               closedVolume = volumeToClose;
               Print("Partial closed, closed Volume: ",closedVolume,"/",volumeToClose);
            }
         }
      }
   }
}

void OnDeinit(const int reason){
   EventKillTimer();
}