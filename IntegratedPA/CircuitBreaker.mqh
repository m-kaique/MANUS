//+------------------------------------------------------------------+
//|                                                  CircuitBreaker.mqh |
//|                                                                  |
//+------------------------------------------------------------------+
#property strict

#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Classe para controle de Circuit Breaker                          |
//+------------------------------------------------------------------+
class CCircuitBreaker
{
private:
   int      m_errorCount;       // Número de erros na janela atual
   int      m_errorThreshold;   // Limite de erros para disparar o breaker
   int      m_windowSeconds;    // Tamanho da janela de contagem
   datetime m_windowStart;      // Início da janela
   datetime m_lastTrip;         // Momento em que foi ativado
   int      m_cooldownSeconds;  // Tempo de espera após disparo
   bool     m_tripped;          // Flag indicando se está ativo
   CLogger *m_logger;           // Logger opcional

   // Atualizar contadores e verificar janela
   void CheckWindow()
   {
      datetime now = TimeCurrent();

      if(now - m_windowStart > m_windowSeconds)
      {
         m_windowStart = now;
         m_errorCount = 0;
      }

      if(m_tripped && now - m_lastTrip > m_cooldownSeconds)
      {
         m_tripped = false;
         if(m_logger != NULL)
            m_logger.Info("CircuitBreaker reabilitado");
      }
   }

public:
   CCircuitBreaker()
   {
      m_errorCount      = 0;
      m_errorThreshold  = 5;
      m_windowSeconds   = 60;
      m_windowStart     = TimeCurrent();
      m_lastTrip        = 0;
      m_cooldownSeconds = 60;
      m_tripped         = false;
      m_logger          = NULL;
   }

   bool Initialize(int threshold, int windowSeconds, int cooldownSeconds, CLogger *logger=NULL)
   {
      if(threshold <= 0 || windowSeconds <= 0 || cooldownSeconds <= 0)
         return false;

      m_errorThreshold  = threshold;
      m_windowSeconds   = windowSeconds;
      m_cooldownSeconds = cooldownSeconds;
      m_logger          = logger;

      m_errorCount  = 0;
      m_windowStart = TimeCurrent();
      m_lastTrip    = 0;
      m_tripped     = false;

      return true;
   }

   bool CanOperate()
   {
      CheckWindow();
      return !m_tripped;
   }

   void RegisterSuccess()
   {
      CheckWindow();
      m_errorCount = 0;
   }

   void RegisterError()
   {
      CheckWindow();
      m_errorCount++;
      if(m_errorCount >= m_errorThreshold)
      {
         m_tripped  = true;
         m_lastTrip = TimeCurrent();
         if(m_logger != NULL)
            m_logger.Warning("CircuitBreaker ativado devido a erros consecutivos");
      }
   }

   bool IsTripped() const { return m_tripped; }
};

//+------------------------------------------------------------------+
