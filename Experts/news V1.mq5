#include <News__2.mqh>

CNews news;

int OnInit()
  {
   news.GMT_offset_winter=0;
   news.GMT_offset_summer=1;
   return(INIT_SUCCEEDED);
  }
  
void OnTick()
  {
   news.update();
   chart_print("news event test",0,30,30,30,5,clrLightBlue);
   static string font="Arial";
   static int fontsize=12;
   static color fontclr=clrYellow;
   chart_print("built-in TimeGMT() function: "+TimeToString(TimeGMT()),-1,-1,-1,fontsize,5,fontclr,font);
   chart_print("new.GMT() simulated GMT time: "+TimeToString(news.GMT()),-1,-1,-1,fontsize,5,fontclr,font);
   chart_print("server time: "+TimeToString(TimeTradeServer()),-1,-1,-1,fontsize,5,fontclr,font);
   int next_event=news.next(news.GMT(),"USD");
   chart_print(" #next event (index "+IntegerToString(next_event)+"): "+news.eventname[next_event],-1,-1,-1,fontsize,5,fontclr,font);
   chart_print("event time: "+TimeToString(news.event[next_event].time),-1,-1,-1,fontsize,5,fontclr,font);
   chart_print("event sector: "+EnumToString(news.event[next_event].sector),-1,-1,-1,fontsize,5,fontclr,font);
   chart_print("affected country: "+EnumToString(ENUM_COUNTRY_ID(news.event[next_event].country_id)),-1,-1,-1,fontsize,5,fontclr,font);
   chart_print("affected currency: "+news.CountryIdToCurrency(ENUM_COUNTRY_ID(news.event[next_event].country_id)),-1,-1,-1,fontsize,5,fontclr,font);
   chart_print("event importance: "+EnumToString(news.event[next_event].importance),-1,-1,-1,fontsize,5,fontclr,font);
  }
  





// AUXILIARY FUNCTION:

//+----------------------------------------------------------------------+
//| chart print: multiple text lines, optionally  with '#' as separator  |
//+----------------------------------------------------------------------+
int chart_print(string text,int identifier=-1,int x_pos=-1,int y_pos=-1,int fontsize=10,int linespace=2,color fontcolor=clrGray,string font="Arial",string label_prefix="chart_print_",long chart_id=0,int subwindow=0)
  {
   // set message identifier
   //       negative number:      set next identifier
   //       specific number >=0:  replace older messages with same identifier
   static int id=0;
   static int x_static=0;
   static int y_static=0;   
   if (identifier>=0)
     {id=identifier;}
   else
     {id++;}
   ObjectsDeleteAll(0,label_prefix+IntegerToString(id));
   
   if (text!="") //note: chart_print("",n) can be used to delete a specific message
     {
      // initialize or set cursor position
      //       keep last line feed position: set negative number for y_pos
      //       same x position as last message: set negative number for x_pos
      if (x_pos>=0){x_static=x_pos;}
      if (y_pos>=0){y_static=y_pos;}
      
      // get number of lines ('#' sign is used for line feed)
      int lines=1+MathMax(StringReplace(text,"#","#"),0);
      
      // get substrings
      string substring[];
      StringSplit(text,'#',substring);
      
      // print lines
      for (int l=1;l<=lines;l++)
        {
         string msg_label=label_prefix+IntegerToString(id)+", line "+IntegerToString(l);
         ObjectCreate(chart_id,msg_label,OBJ_LABEL,subwindow,0,0);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_XDISTANCE,x_static);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_YDISTANCE,y_static);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetString(chart_id,msg_label,OBJPROP_TEXT,substring[l-1]);
         ObjectSetString(chart_id,msg_label,OBJPROP_FONT,font);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_FONTSIZE,fontsize);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_COLOR,fontcolor);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_BACK,false); 
         // line feed
         y_static+=fontsize+linespace;
        }
     } 
   return y_static;
  }