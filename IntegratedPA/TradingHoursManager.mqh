#ifndef TRADING_HOURS_MANAGER_MQH
#define TRADING_HOURS_MANAGER_MQH
#property strict

#include "TradeExecutor.mqh"
#include "Logger.mqh"

class CTradingHoursManager
  {
private:
   int            m_startHour;
   int            m_startMinute;
   int            m_endHour;
   int            m_endMinute;
   int            m_midStartHour;
   int            m_midStartMinute;
   int            m_midEndHour;
   int            m_midEndMinute;
   CTradeExecutor *m_executor;
   CLogger        *m_logger;
   bool           m_tradingAllowed;
   datetime       m_lastDay;
   bool           m_midShutdownDone;
   bool           m_endShutdownDone;

   int MinutesOfDay(datetime t)
     {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return dt.hour * 60 + dt.min;
     }

public:
   CTradingHoursManager()
     {
      m_startHour      = 9;
      m_startMinute    = 15;
      m_endHour        = 16;
      m_endMinute      = 30;
      m_midStartHour   = 12;
      m_midStartMinute = 0;
      m_midEndHour     = 14;
      m_midEndMinute   = 0;
      m_executor       = NULL;
      m_logger         = NULL;
      m_tradingAllowed = true;
      m_lastDay        = 0;
      m_midShutdownDone = false;
      m_endShutdownDone = false;
     }

   bool Initialize(CTradeExecutor *executor, CLogger *logger,
                   int startHour=9, int startMinute=15,
                   int endHour=16, int endMinute=30,
                   int midStartHour=12, int midStartMinute=0,
                   int midEndHour=14, int midEndMinute=0)
     {
      if(executor==NULL || logger==NULL)
         return false;
      m_executor    = executor;
      m_logger      = logger;
      m_startHour   = startHour;
      m_startMinute = startMinute;
      m_endHour     = endHour;
      m_endMinute   = endMinute;
      m_midStartHour   = midStartHour;
      m_midStartMinute = midStartMinute;
      m_midEndHour     = midEndHour;
      m_midEndMinute   = midEndMinute;
      m_lastDay     = TimeCurrent();
      m_tradingAllowed = true;
      m_midShutdownDone = false;
      m_endShutdownDone = false;
      return true;
     }

   void Update()
     {
      if(m_executor==NULL)
         return;
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);

      int minutes         = dt.hour*60 + dt.min;
      int startMinutes    = m_startHour*60 + m_startMinute;
      int endMinutes      = m_endHour*60 + m_endMinute;
      int midStartMinutes = m_midStartHour*60 + m_midStartMinute;
      int midEndMinutes   = m_midEndHour*60 + m_midEndMinute;
      int preMidBlock = midStartMinutes - 10;
      int preEndBlock = endMinutes - 10;

      MqlDateTime ld;
      TimeToStruct(m_lastDay, ld);
      if(dt.day!=ld.day || dt.mon!=ld.mon || dt.year!=ld.year)
        {
         m_midShutdownDone = false;
         m_endShutdownDone = false;
         m_lastDay      = now;
        }
        
      if(minutes >= preEndBlock && minutes <= endMinutes + 1)
        {
         if(!m_endShutdownDone)
           {
            if(m_logger!=NULL)
               m_logger.Info("Encerrando operações antes do fim da sessão");
            m_executor.CancelAllPendingOrders();
            m_executor.CloseAllPositions();
            m_endShutdownDone = true;
           }
         if(m_tradingAllowed)
           {
            m_executor.SetTradeAllowed(false);
            m_tradingAllowed = false;
           }
         return;
        }

      if(minutes >= preMidBlock && minutes <= midStartMinutes + 1)
        {
         if(!m_midShutdownDone)
           {
            if(m_logger!=NULL)
               m_logger.Info("Encerrando operações para intervalo de almoço" + (string)TimeCurrent());
            m_executor.CancelAllPendingOrders();
            m_executor.CloseAllPositions();
            m_midShutdownDone = true;
           }
         if(m_tradingAllowed)
           {
            m_executor.SetTradeAllowed(false);
            m_tradingAllowed = false;
           }
         return;
        }

      if(minutes >= midStartMinutes && minutes < midEndMinutes)
        {
         if(m_tradingAllowed)
           {
            m_executor.SetTradeAllowed(false);
            m_tradingAllowed = false;
           }
         return;
        }

      if(minutes < startMinutes || minutes > endMinutes)
        {
         if(m_tradingAllowed)
           {
            m_executor.SetTradeAllowed(false);
            m_tradingAllowed = false;
            if(m_logger!=NULL)
               m_logger.Info("Trading bloqueado fora do horário");
           }
         return;
        }

      if(!m_tradingAllowed)
        {
         m_executor.SetTradeAllowed(true);
         m_tradingAllowed = true;
         if(m_logger!=NULL)
            m_logger.Info("Trading liberado");
        }
     }

   bool IsTradingAllowed() const { return m_tradingAllowed; }
  };

#endif // TRADING_HOURS_MANAGER_MQH
