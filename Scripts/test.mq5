input int StartHour = 1;
input int StartMin = 0;
datetime candleTriggerDatetime = 0;
datetime currentTime = 0;
void OnInit(){
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   for(int i = 0; i < 365; i++){
      Print("Struct:\n", timeStruct.day, ".", timeStruct.mon, ".", timeStruct.year, " ", timeStruct.hour, ":", timeStruct.min);
      Print(timeStruct.day_of_week, " ", timeStruct.day_of_year);
      timeStruct.day++;
      datetime time = StructToTime(timeStruct);
      Print("New Time: ", TimeToString(time));
   }
}