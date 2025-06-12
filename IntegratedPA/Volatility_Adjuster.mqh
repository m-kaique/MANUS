#ifndef VOLATILITYADJUSTER_MQH
#define VOLATILITYADJUSTER_MQH
//+------------------------------------------------------------------+
//|                                           VolatilityAdjuster.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Classe para ajuste dinâmico de volume por volatilidade (ATR)     |
//+------------------------------------------------------------------+
class CVolatilityAdjuster
  {
private:
   int      m_atrHandle;
   double   m_baselineATR;
   double   m_currentATR;
   CLogger *m_logger;
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int      m_atrPeriod;

public:
   // Construtor padrão
   CVolatilityAdjuster()
     {
      m_logger      = NULL;
      m_atrHandle   = INVALID_HANDLE;
      m_baselineATR = 0.0;
      m_currentATR  = 0.0;
      m_symbol      = "";
      m_timeframe   = PERIOD_CURRENT;
      m_atrPeriod   = 14;
     }

   // Inicialização (com logger)
   bool Initialize(CLogger *logger, string symbol, ENUM_TIMEFRAMES timeframe=PERIOD_M5, int atrPeriod=14)
     {
      m_logger = logger;
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_atrPeriod = atrPeriod;
      m_atrHandle = iATR(m_symbol, m_timeframe, m_atrPeriod);
      if(m_atrHandle == INVALID_HANDLE)
        {
         if(m_logger != NULL)
            m_logger.Error("VolatilityAdjuster: Erro ao criar handle ATR para " + m_symbol);
         return false;
        }
      double atrValues[20];
      if(CopyBuffer(m_atrHandle, 0, 1, 20, atrValues) == 20)
        {
         double sum = 0;
         for(int i = 0; i < 20; i++)
            sum += atrValues[i];
         m_baselineATR = sum / 20.0;
        }
      else
        {
         if(m_logger != NULL)
            m_logger.Warning("VolatilityAdjuster: Falha ao obter baseline ATR para " + m_symbol);
         m_baselineATR = 0.0;
         return false;
        }
      return true;
     }

   // Atualizar baseline (opcional, para atualização dinâmica)
   bool UpdateBaseline()
     {
      if(m_atrHandle == INVALID_HANDLE)
         return false;
      double atrValues[20];
      if(CopyBuffer(m_atrHandle, 0, 1, 20, atrValues) == 20)
        {
         double sum = 0;
         for(int i = 0; i < 20; i++)
            sum += atrValues[i];
         m_baselineATR = sum / 20.0;
         return true;
        }
      return false;
     }

   // Fator de ajuste por volatilidade
   double GetAdjustmentFactor()
     {
      if(m_atrHandle == INVALID_HANDLE || m_baselineATR <= 0)
         return 1.0;
      double current[1];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, current) != 1)
         return 1.0;
      m_currentATR = current[0];
      double ratio = m_currentATR / m_baselineATR;
      if(ratio > 2.0)
         return 0.3;
      if(ratio > 1.5)
         return 0.5;
      if(ratio > 1.2)
         return 0.7;
      if(ratio < 0.5)
         return 1.3;
      if(ratio < 0.8)
         return 1.1;
      return 1.0;
     }

   double GetBaselineATR()  { return m_baselineATR;  }
   double GetCurrentATR()   { return m_currentATR;   }
   string GetSymbol()       { return m_symbol;       }
   int    GetATRPeriod()    { return m_atrPeriod;    }
  };

#endif // VOLATILITYADJUSTER_MQH
