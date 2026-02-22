input int count = 20;

int x = 0;
int arrayCount[20];
void OnInit(){
   ArrayInitialize(arrayCount,0);
}

void OnTick(){
   bool newCandle = detectNewCandle();
   if(newCandle){
      detectSupport();
   }
}

void detectSupport(){

   //ArrayResize(arrayCount,count);
   //ArraySetAsSeries(arrayCount,true);
   if(x < count){
      arrayCount[0] = x;
      int a = 0;
      while(a<x){
         arrayCount[a] = x-a;
         a++;
      }
      x++;
      ArrayPrint(arrayCount);
   }
}

bool detectNewCandle(){
   MqlRates priceData[];
   ArraySetAsSeries(priceData,true);
   CopyRates(_Symbol,PERIOD_CURRENT,0,3,priceData);
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