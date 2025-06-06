//+------------------------------------------------------------------+
//|                                    MarketContext_Diagnostico.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property strict

#include "Structures.mqh"
#include "Logger.mqh"
#include "IndicatorManager.mqh"

//+------------------------------------------------------------------+
//| Classe para diagnóstico do MarketContext                         |
//+------------------------------------------------------------------+
class CMarketContextDiagnostic {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   CLogger* m_logger;
   CIndicatorManager* m_indicatorManager;
   
   // Handles de indicadores
   int m_ema9Handle;
   int m_ema21Handle;
   int m_ema50Handle;
   int m_ema200Handle;
   int m_rsiHandle;
   int m_atrHandle;
   int m_macdHandle;
   
public:
   CMarketContextDiagnostic() {
      m_symbol = "";
      m_timeframe = PERIOD_CURRENT;
      m_logger = NULL;
      m_indicatorManager = NULL;
      
      m_ema9Handle = INVALID_HANDLE;
      m_ema21Handle = INVALID_HANDLE;
      m_ema50Handle = INVALID_HANDLE;
      m_ema200Handle = INVALID_HANDLE;
      m_rsiHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
      m_macdHandle = INVALID_HANDLE;
   }
   
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CLogger* logger, CIndicatorManager* indicatorManager) {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_logger = logger;
      m_indicatorManager = indicatorManager;
      
      if(m_logger != NULL) {
         m_logger.Info("=== INICIANDO DIAGNÓSTICO DO MARKETCONTEXT ===");
         m_logger.Info("Símbolo: " + m_symbol + ", Timeframe: " + EnumToString(m_timeframe));
      }
      
      // Verificar se o IndicatorManager está disponível
      if(m_indicatorManager == NULL) {
         if(m_logger != NULL) {
            m_logger.Error("DIAGNÓSTICO: IndicatorManager é NULL!");
         }
         return false;
      }
      
      // Verificar histórico
      int bars = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
      if(m_logger != NULL) {
         m_logger.Info("DIAGNÓSTICO: Barras disponíveis: " + IntegerToString(bars));
      }
      
      if(bars < 100) {
         if(m_logger != NULL) {
            m_logger.Warning("DIAGNÓSTICO: Histórico insuficiente (" + IntegerToString(bars) + " barras)");
         }
         return false;
      }
      
      // Criar handles de indicadores
      return CreateAndTestHandles();
   }
   
   bool CreateAndTestHandles() {
      if(m_logger != NULL) {
         m_logger.Info("DIAGNÓSTICO: Criando handles de indicadores...");
      }
      
      // Criar handles usando o IndicatorManager
      m_ema9Handle = m_indicatorManager.GetMA(m_symbol, m_timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
      m_ema21Handle = m_indicatorManager.GetMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_ema50Handle = m_indicatorManager.GetMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200Handle = m_indicatorManager.GetMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_rsiHandle = m_indicatorManager.GetRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
      m_atrHandle = m_indicatorManager.GetATR(m_symbol, m_timeframe, 14);
      m_macdHandle = m_indicatorManager.GetMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
      
      // Verificar se os handles foram criados
      if(m_logger != NULL) {
         m_logger.Info("DIAGNÓSTICO: Handles criados:");
         m_logger.Info("  EMA9: " + IntegerToString(m_ema9Handle));
         m_logger.Info("  EMA21: " + IntegerToString(m_ema21Handle));
         m_logger.Info("  EMA50: " + IntegerToString(m_ema50Handle));
         m_logger.Info("  EMA200: " + IntegerToString(m_ema200Handle));
         m_logger.Info("  RSI: " + IntegerToString(m_rsiHandle));
         m_logger.Info("  ATR: " + IntegerToString(m_atrHandle));
         m_logger.Info("  MACD: " + IntegerToString(m_macdHandle));
      }
      
      // Aguardar um pouco para os indicadores calcularem
      Sleep(1000);
      
      // Verificar se os indicadores estão prontos
      return TestIndicatorReadiness();
   }
   
   bool TestIndicatorReadiness() {
      if(m_logger != NULL) {
         m_logger.Info("DIAGNÓSTICO: Verificando se indicadores estão prontos...");
      }
      
      bool allReady = true;
      
      // Testar cada indicador
      if(m_ema9Handle != INVALID_HANDLE) {
         int calculated = BarsCalculated(m_ema9Handle);
         if(m_logger != NULL) {
            m_logger.Info("  EMA9 calculado: " + IntegerToString(calculated) + " barras");
         }
         if(calculated < 50) allReady = false;
      } else {
         if(m_logger != NULL) {
            m_logger.Error("  EMA9: Handle inválido!");
         }
         allReady = false;
      }
      
      if(m_ema21Handle != INVALID_HANDLE) {
         int calculated = BarsCalculated(m_ema21Handle);
         if(m_logger != NULL) {
            m_logger.Info("  EMA21 calculado: " + IntegerToString(calculated) + " barras");
         }
         if(calculated < 50) allReady = false;
      } else {
         if(m_logger != NULL) {
            m_logger.Error("  EMA21: Handle inválido!");
         }
         allReady = false;
      }
      
      if(m_rsiHandle != INVALID_HANDLE) {
         int calculated = BarsCalculated(m_rsiHandle);
         if(m_logger != NULL) {
            m_logger.Info("  RSI calculado: " + IntegerToString(calculated) + " barras");
         }
         if(calculated < 50) allReady = false;
      } else {
         if(m_logger != NULL) {
            m_logger.Error("  RSI: Handle inválido!");
         }
         allReady = false;
      }
      
      if(m_atrHandle != INVALID_HANDLE) {
         int calculated = BarsCalculated(m_atrHandle);
         if(m_logger != NULL) {
            m_logger.Info("  ATR calculado: " + IntegerToString(calculated) + " barras");
         }
         if(calculated < 50) allReady = false;
      } else {
         if(m_logger != NULL) {
            m_logger.Error("  ATR: Handle inválido!");
         }
         allReady = false;
      }
      
      // Testar leitura de valores
      if(allReady) {
         TestIndicatorValues();
      }
      
      return allReady;
   }
   
   void TestIndicatorValues() {
      if(m_logger != NULL) {
         m_logger.Info("DIAGNÓSTICO: Testando leitura de valores...");
      }
      
      // Testar EMA9
      double ema9Buffer[];
      if(CopyBuffer(m_ema9Handle, 0, 0, 1, ema9Buffer) > 0) {
         if(m_logger != NULL) {
            m_logger.Info("  EMA9[0]: " + DoubleToString(ema9Buffer[0], 5));
         }
      } else {
         if(m_logger != NULL) {
            m_logger.Error("  Falha ao ler EMA9! Erro: " + IntegerToString(GetLastError()));
         }
      }
      
      // Testar EMA21
      double ema21Buffer[];
      if(CopyBuffer(m_ema21Handle, 0, 0, 1, ema21Buffer) > 0) {
         if(m_logger != NULL) {
            m_logger.Info("  EMA21[0]: " + DoubleToString(ema21Buffer[0], 5));
         }
      } else {
         if(m_logger != NULL) {
            m_logger.Error("  Falha ao ler EMA21! Erro: " + IntegerToString(GetLastError()));
         }
      }
      
      // Testar RSI
      double rsiBuffer[];
      if(CopyBuffer(m_rsiHandle, 0, 0, 1, rsiBuffer) > 0) {
         if(m_logger != NULL) {
            m_logger.Info("  RSI[0]: " + DoubleToString(rsiBuffer[0], 2));
         }
      } else {
         if(m_logger != NULL) {
            m_logger.Error("  Falha ao ler RSI! Erro: " + IntegerToString(GetLastError()));
         }
      }
      
      // Testar ATR
      double atrBuffer[];
      if(CopyBuffer(m_atrHandle, 0, 0, 1, atrBuffer) > 0) {
         if(m_logger != NULL) {
            m_logger.Info("  ATR[0]: " + DoubleToString(atrBuffer[0], 5));
         }
      } else {
         if(m_logger != NULL) {
            m_logger.Error("  Falha ao ler ATR! Erro: " + IntegerToString(GetLastError()));
         }
      }
      
      // Testar análise de tendência
      TestTrendAnalysis(ema9Buffer[0], ema21Buffer[0]);
   }
   
   void TestTrendAnalysis(double ema9, double ema21) {
      if(m_logger != NULL) {
         m_logger.Info("DIAGNÓSTICO: Testando análise de tendência...");
         
         if(ema9 > ema21) {
            m_logger.Info("  Tendência: ALTA (EMA9 > EMA21)");
         } else if(ema9 < ema21) {
            m_logger.Info("  Tendência: BAIXA (EMA9 < EMA21)");
         } else {
            m_logger.Info("  Tendência: NEUTRA (EMA9 = EMA21)");
         }
      }
   }
   
   void PrintHandleStats() {
      if(m_indicatorManager != NULL && m_logger != NULL) {
         int handleCount = m_indicatorManager.GetHandleCount();
         m_logger.Info("DIAGNÓSTICO: Total de handles no IndicatorManager: " + IntegerToString(handleCount));
         m_indicatorManager.PrintHandleStats();
      }
   }
};

