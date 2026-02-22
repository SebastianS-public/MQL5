input double baseLot = 2.0;
double totalVolume;

void OnInit(){
   EventSetTimer(1);
}

void OnTimer(){
   if(!checkFile()){
      writeFile();
   }
}

void OnTrade(){
   writeFile();
}

void OnDeinit(const int reason){
   EventKillTimer();
}

void writeFile(){
   int orderFileHandle = FileOpen("test.txt",FILE_WRITE | FILE_COMMON | FILE_TXT);
   totalVolume = 0;
   string symbolString;
   for(int i = PositionsTotal() - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);
      double volume = PositionGetDouble(POSITION_VOLUME);
      symbolString = PositionGetString(POSITION_SYMBOL);
      if(PositionGetInteger(POSITION_TYPE) == 0){
         totalVolume = totalVolume + volume;
      }
      else if(PositionGetInteger(POSITION_TYPE) == 1){
         totalVolume = totalVolume - volume;
      }
   }
   double baseMultiplier = NormalizeDouble(totalVolume,2) / baseLot;
   Print(NormalizeDouble(totalVolume,2)," ",baseMultiplier);
   FileWrite(orderFileHandle,symbolString,",",baseMultiplier);
   FileClose(orderFileHandle);
}

bool checkFile(){
   return true;
}
