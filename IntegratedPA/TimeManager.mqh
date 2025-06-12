#ifndef TIMEMANAGER_MQH
#define TIMEMANAGER_MQH

#include "Structures.mqh"
#include "Logger.mqh"
#include "TradeExecutor.mqh"

//+------------------------------------------------------------------+
//| Classe de gerenciamento de horários de negociação                |
//+------------------------------------------------------------------+
class CTimeManager
  {
private:
   CLogger        *m_logger;
   CTradeExecutor *m_executor;
   TradingHours    m_defaultHours;
   string          m_symbols[];
   TradingHours    m_hours[];
   bool            m_enabled;

   int FindIndex(string symbol)
     {
      for(int i=0;i<ArraySize(m_symbols);i++)
         if(m_symbols[i]==symbol)
            return i;
      return -1;
     }



public:
   // Converte string HH:MM em hora e minuto
   bool ParseTimeString(const string timeStr, int &hour, int &minute)
     {
      string parts[];
      int cnt=StringSplit(timeStr, ':', parts);
      if(cnt!=2)
         return false;
      hour   = (int)StringToInteger(parts[0]);
      minute = (int)StringToInteger(parts[1]);
      if(hour<0 || hour>23 || minute<0 || minute>59)
         return false;
      return true;
     }
   CTimeManager()
     {
      m_logger   = NULL;
      m_executor = NULL;
      m_defaultHours = TradingHours();
      m_enabled  = true;
     }

   bool Initialize(CLogger *logger, CTradeExecutor *executor, TradingHours &defaults)
     {
      m_logger   = logger;
      m_executor = executor;
      m_defaultHours = defaults;
      return true;
     }

   void Enable(bool enable){m_enabled=enable;}

   bool ConfigureSymbol(string symbol, TradingHours &hours)
     {
      int idx = FindIndex(symbol);
      if(idx<0)
        {
         int newSize=ArraySize(m_symbols)+1;
         ArrayResize(m_symbols,newSize);
         ArrayResize(m_hours,newSize);
         idx = newSize-1;
         m_symbols[idx]=symbol;
        }
      m_hours[idx]=hours;
      if(m_logger!=NULL)
         m_logger.Info("CTimeManager: configurado horario para " + symbol);
      return true;
     }

   TradingHours GetHours(string symbol)
     {
      int idx=FindIndex(symbol);
      if(idx>=0)
         return m_hours[idx];
      return m_defaultHours;
     }

   bool IsWithinTradingHours(string symbol)
     {
      if(!m_enabled)
         return true;
      TradingHours h=GetHours(symbol);
      datetime now=TimeCurrent();
      MqlDateTime tm;
      TimeToStruct(now, tm);
      int current=tm.hour*60+tm.min;
      int start=h.startHour*60+h.startMinute;
      int end=h.endHour*60+h.endMinute;
      return(current>=start && current<=end);
     }

   bool ShouldForceClose()
     {
      if(!m_enabled)
         return false;
      datetime now=TimeCurrent();
      MqlDateTime tm;
      TimeToStruct(now, tm);
      int current=tm.hour*60+tm.min;
      int closeTime=m_defaultHours.closeHour*60+m_defaultHours.closeMinute;
      return(current>=closeTime);
     }

   void UpdatePermissions()
     {
      if(m_executor==NULL)
         return;
      bool allow=true;
      if(m_enabled)
        {
         allow=false;
         for(int i=0;i<ArraySize(m_symbols);i++)
            if(IsWithinTradingHours(m_symbols[i]))
             {allow=true; break;}
        }
      m_executor.SetTradeAllowed(allow);
     }

   void CheckForcedClose()
     {
      if(!m_enabled || m_executor==NULL)
         return;
      if(ShouldForceClose())
        {
         if(m_logger!=NULL)
            m_logger.Warning("CTimeManager: fechamento forçado de todas as posicoes");
         m_executor.CloseAllPositions();
        }
     }
  };

#endif // TIMEMANAGER_MQH
