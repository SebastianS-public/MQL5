input int openTimeHour = 9;
input int closeTimeHour = 17;

void OnTick(){
   bool session = duringSession();
   Print(session);
}
bool duringSession(){
   bool duringSession = false;
   MqlDateTime structTime;
   TimeCurrent(structTime);
   if(structTime.hour < closeTimeHour && structTime.hour >= openTimeHour){
      duringSession = true;
   }
   return duringSession;
}