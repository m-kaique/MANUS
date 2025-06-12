#ifndef __TIME_MANAGER_MQH__
#define __TIME_MANAGER_MQH__

#include <Trade/Trade.mqh>
#include "TradingControl.mqh"

// --- entrada EA --------------------------------------------------
input string   InpSessionCutoff   = "18:20"; // horário hard-cut off (HH:MM)
input int      InpCutoffBufferMin = 2;        // buffer de minutos (bloqueia entradas antes)

//------------------------------------------------------------------
class CTimeManager
{
private:
   datetime  m_cutoff;        // horário hard-cut (data/hora)
   datetime  m_currentDay;    // dia para o qual m_cutoff foi calculado
   int       m_bufferMin;     // minutos de buffer
   bool      m_entryBlocked;  // se entradas já bloqueadas
   bool      m_closeExecuted; // se close forçado já executado
   CTrade    m_trade;         // handler de trade MT5

   // Obtém o dia corrente (zerando hora/min/seg)
   datetime GetToday()
   {
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(), tm);
      tm.hour = 0;
      tm.min  = 0;
      tm.sec  = 0;
      return StructToTime(tm);
   }

   // Atualiza m_cutoff para um determinado dia
   void UpdateCutoff(datetime day)
   {
      int h = (int)StringToInteger(StringSubstr(InpSessionCutoff,0,2));
      int m = (int)StringToInteger(StringSubstr(InpSessionCutoff,3,2));
      MqlDateTime tm;
      TimeToStruct(day, tm);
      tm.hour = h;
      tm.min  = m;
      tm.sec  = 0;
      m_cutoff = StructToTime(tm);
      m_currentDay = day;
   }

public:
   // --------------------------------------------------------------
   bool Init()
   {
      m_bufferMin     = InpCutoffBufferMin;
      m_entryBlocked  = false;
      m_closeExecuted = false;
      m_currentDay = GetToday();
      UpdateCutoff(m_currentDay);
      TradingControl::EnableEntry();
      TradingControl::EnableExit();
      return true;
   }

   // --------------------------------------------------------------
   void Pulse()
   {
      datetime now = TimeCurrent();
      datetime today = GetToday();

      // Recalcula cutoff e reseta flags se o dia mudou
      if(today != m_currentDay)
      {
         m_entryBlocked  = false;
         m_closeExecuted = false;
         TradingControl::EnableEntry();
         TradingControl::EnableExit();
         UpdateCutoff(today);
      }

      // 1) Pré-fechamento – bloquear entradas
      if(!m_entryBlocked && now >= (m_cutoff - m_bufferMin*60))
      {
         TradingControl::DisableEntry();
         m_entryBlocked = true;
         Print("[TimeManager] Entradas bloqueadas (buffer pré-fechamento)");
      }

      // 2) Hard cutoff – liquidar posições e bloquear saídas
      if(!m_closeExecuted && now >= m_cutoff)
      {
         ForceCloseAllPositions();
         TradingControl::DisableExit();
         m_closeExecuted = true;
         Print("[TimeManager] Posições fechadas e saídas bloqueadas após cutoff");
      }

      // 3) Watch-dog – garante que não fique nada aberto após cutoff
      if(now > m_cutoff && PositionsTotal()>0)
      {
         static datetime lastReport = 0;
         if(now - lastReport >= 10) // reporta a cada 10 s
         {
            Print("[WatchDog] Ainda há", PositionsTotal(), " posição(ões) abertas após cutoff. Tentando fechar…");
            lastReport = now;
         }
         ForceCloseAllPositions();
      }
   }

private:
   // --------------------------------------------------------------
   void ForceCloseAllPositions()
   {
      // habilita saída temporariamente caso esteja bloqueada
      bool prevExit = TradingControl::AllowExit();
      TradingControl::EnableExit();

      for(int i = PositionsTotal()-1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;

         if(!m_trade.PositionClose(ticket))
            Print("[ForceClose] Falha ao fechar posição", ticket, " - ", m_trade.ResultRetcode());
      }

      // restaura status original
      if(!prevExit)
         TradingControl::DisableExit();
   }
};

#endif // __TIME_MANAGER_MQH__
