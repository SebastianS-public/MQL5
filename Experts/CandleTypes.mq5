#include <Canvas\Canvas.mqh>

#define SIZE 1000

int type[SIZE];
struct ObjectNames{
   string name[SIZE];
   int size;
};

struct barTypesDynamic{
   int barType;
   double barSize;
   double barSizeTotal;
   double upperWickToTotalSize;
   double lowerWickToTotalSize;
   double bodyToTotalSize;
   double gapToLastBar;
};

string objectList[SIZE];
barTypesDynamic barTypesArray[SIZE];

CCanvas canvas;

void OnInit(){
   datetime startTime = StringToTime("20250212 1500");
   ArrayInitialize(type, 0);
   MqlRates bars[];
   CopyRates(_Symbol, PERIOD_CURRENT, startTime, SIZE, bars);
   
   //int barTypesTotal = getBarTypesHardcoded(bars);
   getBarTypesDynamic(bars);
   printCandleTypeObjects(startTime, bars);
   Print("Canvas created: ", canvas.Create("C", 300, 300, COLOR_FORMAT_ARGB_NORMALIZE));
}

void OnDeinit(const int reason){
   for(int i = 0; i < ArraySize(objectList); i++){
      ObjectDelete(0, objectList[i]);
   }
   canvas.Destroy();
}

void printCandleTypeObjects(datetime startTime, MqlRates &bars[]){
   ObjectNames objectNames;
   objectNames.size = 0;
   int arrayCounter[91];
   ArrayInitialize(arrayCounter, 0);
   string printString = "";
   int manBarCount = 0;
   
   for(int i = 0; i < SIZE; i++){
      datetime objectTime = iTime(_Symbol, PERIOD_CURRENT, Bars(_Symbol, PERIOD_CURRENT, TimeCurrent(), startTime) + SIZE - 2 - i);
      string objectString = TimeToString(objectTime);
      if(type[i] > 0){
         if(ObjectFind(0, objectString) < 0){
            ObjectCreate(0, objectString, OBJ_TEXT, 0, objectTime, bars[i].high + 0.0001);
            ObjectSetInteger(0, objectString, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, objectString, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, objectString, OBJPROP_TEXT, IntegerToString(type[i]));
            objectNames.name[objectNames.size] = objectString;
            objectNames.size++;
         }
         arrayCounter[type[i] - 1]++;
      }
   }
   
   for(int i = 0; i < ArraySize(arrayCounter); i++){
      manBarCount += arrayCounter[i];
      printString += IntegerToString(i + 1) + ": " + IntegerToString(arrayCounter[i])+ "\n";
   }
   PrintFormat("%s\nTotal Bars Counted: %d", printString, manBarCount);
   
   ChartRedraw();   
   ArrayCopy(objectList, objectNames.name);
}

void getBarTypesDynamic(MqlRates &bars[]){
   for(int i = 0; i < SIZE; i++){
      MqlRates bar = bars[i];
      MqlRates lastBar;
      double upperWickSize;
      double lowerWickSize;
      
      //if green bar
      if(bar.open < bar.close){
         upperWickSize = bar.high - bar.close;
         lowerWickSize = bar.open - bar.low;
         barTypesArray[i].barType = 1;
      }
      else{
         upperWickSize = bar.high - bar.open;
         lowerWickSize = bar.close - bar.low;
         barTypesArray[i].barType = 0;
      }
      
      barTypesArray[i].barSize = MathAbs(bar.open - bar.close);
      barTypesArray[i].barSizeTotal = MathAbs(bar.high - bar.low);      
      barTypesArray[i].upperWickToTotalSize = upperWickSize / barTypesArray[i].barSizeTotal;
      barTypesArray[i].lowerWickToTotalSize = lowerWickSize / barTypesArray[i].barSizeTotal;
      barTypesArray[i].bodyToTotalSize = barTypesArray[i].barSize / barTypesArray[i].barSizeTotal;
      if(i != 0){
         lastBar = bars[i-1];
         barTypesArray[i].gapToLastBar = MathAbs(bar.open - lastBar.close);
      }
      else{
         barTypesArray[i].gapToLastBar = 0;
      }
   }
   //TODO: analyze data (e.g. display graphically, calc median etc.), remove outliers and categorize the data
   
}

int getBarTypesHardcoded(MqlRates &bars[]){
   for(int i = 0; i < SIZE; i++){
      MqlRates bar = bars[i];
      double barSize = MathAbs(bar.open - bar.close);
      
      //if red bar
      if(bar.close <= bar.open){
         
         double upperWickSize = bar.high - bar.open;
         double lowerWickSize = bar.close - bar.low;
         
         //if bar without or barely any wicks(both)
         if(upperWickSize < 0.2 * barSize && lowerWickSize < 0.2 * barSize){
            if(barSize > 0.00100){
               type[i] = 1;
            }
            else if(barSize > 0.00050){
               type[i] = 2;
            }
            else if(barSize > 0.00015){
               type[i] = 3;
            }
            else if(barSize > 0.00008){
               type[i] = 4;
            }
            else{
               type[i] = 5;
            }
         }
         
         //if bar without upper wick but with small lower wick
         else if(upperWickSize < 0.2 * barSize && lowerWickSize < 0.5 * barSize){
            if(barSize > 0.00100){
               type[i] = 6;
            }
            else if(barSize > 0.00050){
               type[i] = 7;
            }
            else if(barSize > 0.00015){
               type[i] = 8;
            }
            else if(barSize > 0.00008){
               type[i] = 9;
            }
            else{
               type[i] = 10;
            }
         }
         
         //if bar without upper wick but with big lower wick
         else if(upperWickSize < 0.2 * barSize && lowerWickSize >= 0.5 * barSize){
            if(barSize > 0.00050){
               type[i] = 11;
            }
            else if(barSize > 0.00015){
               type[i] = 12;
            }
            else if(barSize > 0.00008){
               type[i] = 13;
            }
            else{
               type[i] = 14;
            }
         }
         
         //if bar with small upper wick but without lower wick
         else if(upperWickSize < 0.5 * barSize && lowerWickSize < 0.2 * barSize){
            if(barSize > 0.00100){
               type[i] = 15;
            }
            else if(barSize > 0.00050){
               type[i] = 16;
            }
            else if(barSize > 0.00015){
               type[i] = 17;
            }
            else if(barSize > 0.00008){
               type[i] = 18;
            }
            else{
               type[i] = 19;
            }
         }
         
         //if bar with big upper wick but without lower wick
         else if(upperWickSize >= 0.5 * barSize && lowerWickSize < 0.2 * barSize){
            if(barSize > 0.00050){
               type[i] = 20;
            }
            else if(barSize > 0.00015){
               type[i] = 21;
            }
            else if(barSize > 0.00008){
               type[i] = 22;
            }
            else{
               type[i] = 23;
            }
         }
         
         //if bar with small upper wick and with small lower wick
         else if(upperWickSize < 0.5 * barSize && lowerWickSize < 0.5 * barSize){
            if(barSize > 0.00050){
               type[i] = 24;
            }
            else if(barSize > 0.00015){
               type[i] = 25;
            }
            else if(barSize > 0.00008){
               type[i] = 26;
            }
            else{
               type[i] = 27;
            }
         }
         
         //if bar with big upper wick and with big lower wick
         else if(upperWickSize >= 0.5 * barSize && lowerWickSize >= 0.5 * barSize){
            if(barSize > 0.00050){
               type[i] = 28;
            }
            else if(barSize > 0.00015){
               type[i] = 29;
            }
            else if(barSize > 0.00008){
               type[i] = 30;
            }
            else if(upperWickSize > 3 * lowerWickSize){
               type[i] = 31;
            }
            else if(upperWickSize > 2 * lowerWickSize){
               type[i] = 32;
            }
            else if(upperWickSize > 1.1 * lowerWickSize){
               type[i] = 33;
            }
            else if(upperWickSize > 0.9 * lowerWickSize){
               type[i] = 34;
            }
            else if(upperWickSize > 0.5 * lowerWickSize){
               type[i] = 35;
            }
            else if(upperWickSize > 0.33 * lowerWickSize){
               type[i] = 36;
            }
            else{
               type[i] = 37;
            }
         }
         
         //if bar with small upper wick and big lower wick
         else if(upperWickSize < 0.5 * barSize && lowerWickSize >= 0.5 * barSize){
            if(barSize > 0.00050){
               type[i] = 38;
            }
            else if(barSize > 0.00015){
               type[i] = 39;
            }
            else if(barSize > 0.00008){
               type[i] = 40;
            }
            else{
               type[i] = 41;
            }
         }
         
         //if bar with big upper wick and small lower wick
         else if(upperWickSize >= 0.5 * barSize && lowerWickSize < 0.5 * barSize){
            if(barSize > 0.00050){
               type[i] = 42;
            }
            else if(barSize > 0.00015){
               type[i] = 43;
            }
            else if(barSize > 0.00008){
               type[i] = 44;
            }
            else{
               type[i] = 45;
            }
         }
      }
      
      //if green bar
      if(bar.close >= bar.open){
         
         double upperWickSize = bar.high - bar.close;
         double lowerWickSize = bar.open - bar.low;
         
         //if bar without or barely any wicks(both)
         if(upperWickSize < 0.2 * barSize && lowerWickSize < 0.2 * barSize){
            if(barSize > 0.00100){
               type[i] = 46;
            }
            else if(barSize > 0.00050){
               type[i] = 47;
            }
            else if(barSize > 0.00015){
               type[i] = 48;
            }
            else if(barSize > 0.00008){
               type[i] = 49;
            }
            else{
               type[i] = 50;
            }
         }
         
         //if bar without upper wick but with small lower wick
         else if(upperWickSize < 0.2 * barSize && lowerWickSize < 0.5 * barSize){
            if(barSize > 0.00100){
               type[i] = 51;
            }
            else if(barSize > 0.00050){
               type[i] = 52;
            }
            else if(barSize > 0.00015){
               type[i] = 53;
            }
            else if(barSize > 0.00008){
               type[i] = 54;
            }
            else{
               type[i] = 55;
            }
         }
         
         //if bar without upper wick but with big lower wick
         else if(upperWickSize < 0.2 * barSize && lowerWickSize >= 0.5 * barSize){
            if(barSize > 0.00050){
               type[i] = 56;
            }
            else if(barSize > 0.00015){
               type[i] = 57;
            }
            else if(barSize > 0.00008){
               type[i] = 58;
            }
            else{
               type[i] = 59;
            }
         }
         
         //if bar with small upper wick but without lower wick
         else if(upperWickSize < 0.5 * barSize && lowerWickSize < 0.2 * barSize){
            if(barSize > 0.00100){
               type[i] = 60;
            }
            else if(barSize > 0.00050){
               type[i] = 61;
            }
            else if(barSize > 0.00015){
               type[i] = 62;
            }
            else if(barSize > 0.00008){
               type[i] = 63;
            }
            else{
               type[i] = 64;
            }
         }
         
         //if bar with big upper wick but without lower wick
         else if(upperWickSize >= 0.5 * barSize && lowerWickSize < 0.2 * barSize){
            if(barSize > 0.00100){
               type[i] = 65;
            }
            else if(barSize > 0.00050){
               type[i] = 66;
            }
            else if(barSize > 0.00015){
               type[i] = 67;
            }
            else if(barSize > 0.00008){
               type[i] = 68;
            }
            else{
               type[i] = 69;
            }
         }
         
         //if bar with small upper wick and with small lower wick
         else if(upperWickSize < 0.5 * barSize && lowerWickSize < 0.5 * barSize){
            if(barSize > 0.00100){
               type[i] = 70;
            }
            else if(barSize > 0.00050){
               type[i] = 71;
            }
            else if(barSize > 0.00015){
               type[i] = 72;
            }
            else if(barSize > 0.00008){
               type[i] = 73;
            }
            else{
               type[i] = 74;
            }
         }
         
         //if bar with big upper wick and with big lower wick
         else if(upperWickSize >= 0.5 * barSize && lowerWickSize >= 0.5 * barSize){
            if(barSize > 0.00050){
               type[i] = 75;
            }
            else if(barSize > 0.00015){
               type[i] = 76;
            }
            else if(barSize > 0.00008){
               type[i] = 77;
            }
            else if(upperWickSize > 3 * lowerWickSize){
               type[i] = 78;
            }
            else if(upperWickSize > 2 * lowerWickSize){
               type[i] = 79;
            }
            else if(upperWickSize > 1.1 * lowerWickSize){
               type[i] = 80;
            }
            else if(upperWickSize > 0.9 * lowerWickSize){
               type[i] = 81;
            }
            else if(upperWickSize > 0.5 * lowerWickSize){
               type[i] = 82;
            }
            else if(upperWickSize > 0.33 * lowerWickSize){
               type[i] = 83;
            }
            else{
               type[i] = 84;
            }
         }
         
         //if bar with small upper wick and big lower wick
         else if(upperWickSize < 0.5 * barSize && lowerWickSize >= 0.5 * barSize){
            if(barSize > 0.00015){
               type[i] = 85;
            }
            else if(barSize > 0.00008){
               type[i] = 86;
            }
            else{
               type[i] = 87;
            }
         }
         
         //if bar with big upper wick and small lower wick
         else if(upperWickSize >= 0.5 * barSize && lowerWickSize < 0.5 * barSize){
            if(barSize > 0.00050){
               type[i] = 88;
            }
            else if(barSize > 0.00015){
               type[i] = 89;
            }
            else if(barSize > 0.00008){
               type[i] = 90;
            }
            else{
               type[i] = 91;
            }
         }
      }
   }
   return 91;
}