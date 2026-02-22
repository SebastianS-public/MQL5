input int lookbackPeriod = 20;

void OnTick(){
   findHigh();
}
double high = 0;
int highestBar = 0;
int highestBarFinal;
int lookbackTotal = lookbackPeriod;
double findHigh(){
   if(iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackPeriod,0) >= 5){
      highestBar = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackPeriod,0);
      high = iHigh(_Symbol,PERIOD_CURRENT,highestBar);
      lookbackTotal = lookbackPeriod;
      Print(" ",highestBar);
      return high;
   }
   else 
      while(iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackTotal,0) < 5){
         highestBar = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackTotal,0);
         highestBarFinal = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,lookbackTotal,highestBar+1);
         high = iHigh(_Symbol,PERIOD_CURRENT,highestBarFinal);
         lookbackTotal = lookbackTotal + 1;
      }
   Print(high," ",highestBarFinal," ", lookbackTotal);
   return high;

}