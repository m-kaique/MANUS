#ifndef CIRCUIT_BREAKER_MQH
#define CIRCUIT_BREAKER_MQH
//+------------------------------------------------------------------+
//|                                               CircuitBreaker.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "Logger.mqh" 

//+------------------------------------------------------------------+
//| CircuitBreaker.mqh — Classe antifalhas para uso em EAs e módulos |
//+------------------------------------------------------------------+
class CCircuitBreaker
{
private:
   int        m_consecutiveErrors;      // Número de erros consecutivos
   datetime   m_lastErrorTime;          // Momento do último erro
   datetime   m_pauseUntil;             // Timestamp até quando está pausado
   bool       m_isActive;               // Está em pausa?
   int        m_maxConsecutiveErrors;   // Erros até acionar breaker
   int        m_pauseDurationMinutes;   // Tempo de pausa
   CLogger   *m_logger;                 // Logger opcional para logs

public:
   // Construtor
   CCircuitBreaker(CLogger *logger = NULL, int maxErrors = 3, int pauseMinutes = 30)
   {
      m_logger = logger;
      m_consecutiveErrors = 0;
      m_lastErrorTime = 0;
      m_pauseUntil = 0;
      m_isActive = false;
      m_maxConsecutiveErrors = maxErrors;
      m_pauseDurationMinutes = pauseMinutes;
   }

   // Consulta: operação permitida?
   bool IsOperationAllowed(string context = "")
   {
      datetime now = TimeCurrent();
      if(m_isActive && now < m_pauseUntil)
      {
         if(m_logger != NULL && context != "")
         {
            int minLeft = int((m_pauseUntil - now)/60);
            m_logger.Warning("CIRCUIT BREAKER ATIVO [" + context + "]: Bloqueado por " + IntegerToString(minLeft) + " min");
         }
         return false;
      }
      // Reset se pausa expirou
      if(m_isActive && now >= m_pauseUntil)
         Reset();
      return true;
   }

   // Registrar erro, ativar breaker se limite atingido
   void RegisterError(string errorType = "")
   {
      datetime now = TimeCurrent();
      if(now - m_lastErrorTime > 3600) // Reset após 1h sem erros
         m_consecutiveErrors = 0;
      m_consecutiveErrors++;
      m_lastErrorTime = now;
      if(m_logger != NULL)
         m_logger.Error("Circuit Breaker: Erro registrado [" + errorType + "] (" + IntegerToString(m_consecutiveErrors) + "/" + IntegerToString(m_maxConsecutiveErrors) + ")");
      if(m_consecutiveErrors >= m_maxConsecutiveErrors)
         Activate(errorType);
   }

   // Ativar o circuit breaker (pausa)
   void Activate(string lastErrorType = "")
   {
      m_isActive = true;
      m_pauseUntil = TimeCurrent() + m_pauseDurationMinutes * 60;
      if(m_logger != NULL)
         m_logger.Error("CIRCUIT BREAKER ATIVADO: " + IntegerToString(m_consecutiveErrors) + " erros consecutivos [" + lastErrorType + "]. Pausa de " + IntegerToString(m_pauseDurationMinutes) + " minutos.");
   }

   // Resetar breaker após pausa
   void Reset()
   {
      m_consecutiveErrors = 0;
      m_isActive = false;
      m_pauseUntil = 0;
      if(m_logger != NULL)
         m_logger.Info("CIRCUIT BREAKER RESETADO: Operações liberadas.");
   }

   // Sucesso: zera contador de erros
   void RegisterSuccess()
   {
      if(m_consecutiveErrors > 0)
      {
         m_consecutiveErrors = 0;
         if(m_logger != NULL)
            m_logger.Info("OPERAÇÃO OK: Contador de erros resetado.");
      }
   }
};

#endif // CIRCUIT_BREAKER_MQH
