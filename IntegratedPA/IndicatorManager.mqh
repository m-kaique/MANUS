//+------------------------------------------------------------------+
//|                                          IndicatorManager.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

#ifndef INDICATORMANAGER_MQH
#define INDICATORMANAGER_MQH

#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Classe para gerenciamento PERMANENTE de handles de indicadores   |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
   struct IndicatorHandle {
      string key;              // Chave única (símbolo_timeframe_tipo_params)
      int handle;              // Handle do indicador
      datetime createdTime;    // Quando foi criado
      int useCount;           // Contador de uso (para estatísticas)
   };

   IndicatorHandle m_handles[];  // Array de handles PERMANENTES
   CLogger* m_logger;

   // Gerar chave única para o indicador
   string GenerateKey(string symbol, ENUM_TIMEFRAMES tf, string type, string params) {
      return symbol + "_" + IntegerToString(tf) + "_" + type + "_" + params;
   }
   
   // Buscar handle existente
   int FindHandle(string key) {
      int size = ArraySize(m_handles);
      for(int i = 0; i < size; i++) {
         if(m_handles[i].key == key) {
            m_handles[i].useCount++;
            return m_handles[i].handle;
         }
      }
      return INVALID_HANDLE;
   }
   
   // Adicionar novo handle ao array PERMANENTE
   bool AddHandle(string key, int handle) {
      if(handle == INVALID_HANDLE) {
         return false;
      }
      
      int size = ArraySize(m_handles);
      ArrayResize(m_handles, size + 1);
      
      m_handles[size].key = key;
      m_handles[size].handle = handle;
      m_handles[size].createdTime = TimeCurrent();
      m_handles[size].useCount = 1;
      
      if(m_logger != NULL) {
         m_logger.Debug(StringFormat("IndicatorManager: Handle criado e armazenado permanentemente: %s (Total: %d)", 
                                   key, size + 1));
      }
      
      return true;
   }

public:
   // Construtor
   CIndicatorManager() {
      m_logger = NULL;
      ArrayResize(m_handles, 0);
   }
   
   // Destrutor - AQUI é onde liberamos TODOS os handles
   ~CIndicatorManager() {
      ReleaseAll();
   }
   
   // Inicialização
   void Initialize(CLogger* logger) {
      m_logger = logger;
      
      if(m_logger != NULL) {
         m_logger.Info("IndicatorManager inicializado - Handles serão mantidos permanentemente");
      }
   }

   // Métodos para obter handles - REUTILIZAM handles existentes
   int GetMA(string symbol, ENUM_TIMEFRAMES tf, int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price) {
      string params = IntegerToString(period) + "_" + IntegerToString(shift) + "_" + 
                     IntegerToString(method) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "MA", params);
      
      // Verificar se já existe
      int existingHandle = FindHandle(key);
      if(existingHandle != INVALID_HANDLE) {
         return existingHandle;
      }
      
      // Criar novo handle APENAS se não existir
      int handle = iMA(symbol, tf, period, shift, method, price);
      
      if(handle != INVALID_HANDLE) {
         AddHandle(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle MA: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }

   int GetRSI(string symbol, ENUM_TIMEFRAMES tf, int period, ENUM_APPLIED_PRICE price) {
      string params = IntegerToString(period) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "RSI", params);
      
      // Verificar se já existe
      int existingHandle = FindHandle(key);
      if(existingHandle != INVALID_HANDLE) {
         return existingHandle;
      }
      
      // Criar novo handle APENAS se não existir
      int handle = iRSI(symbol, tf, period, price);
      
      if(handle != INVALID_HANDLE) {
         AddHandle(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle RSI: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }
   
   int GetATR(string symbol, ENUM_TIMEFRAMES tf, int period) {
      string params = IntegerToString(period);
      string key = GenerateKey(symbol, tf, "ATR", params);
      
      // Verificar se já existe
      int existingHandle = FindHandle(key);
      if(existingHandle != INVALID_HANDLE) {
         return existingHandle;
      }
      
      // Criar novo handle APENAS se não existir
      int handle = iATR(symbol, tf, period);
      
      if(handle != INVALID_HANDLE) {
         AddHandle(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle ATR: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }
   
   int GetMACD(string symbol, ENUM_TIMEFRAMES tf, int fastPeriod, int slowPeriod, int signalPeriod, ENUM_APPLIED_PRICE price) {
      string params = IntegerToString(fastPeriod) + "_" + IntegerToString(slowPeriod) + "_" + 
                     IntegerToString(signalPeriod) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "MACD", params);
      
      // Verificar se já existe
      int existingHandle = FindHandle(key);
      if(existingHandle != INVALID_HANDLE) {
         return existingHandle;
      }
      
      // Criar novo handle APENAS se não existir
      int handle = iMACD(symbol, tf, fastPeriod, slowPeriod, signalPeriod, price);
      
      if(handle != INVALID_HANDLE) {
         AddHandle(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle MACD: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }
   
   int GetStochastic(string symbol, ENUM_TIMEFRAMES tf, int kPeriod, int dPeriod, int slowing, ENUM_MA_METHOD method, ENUM_STO_PRICE price) {
      string params = IntegerToString(kPeriod) + "_" + IntegerToString(dPeriod) + "_" + 
                     IntegerToString(slowing) + "_" + IntegerToString(method) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "STOCH", params);
      
      // Verificar se já existe
      int existingHandle = FindHandle(key);
      if(existingHandle != INVALID_HANDLE) {
         return existingHandle;
      }
      
      // Criar novo handle APENAS se não existir
      int handle = iStochastic(symbol, tf, kPeriod, dPeriod, slowing, method, price);
      
      if(handle != INVALID_HANDLE) {
         AddHandle(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle Stochastic: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }
   
   int GetBollinger(string symbol, ENUM_TIMEFRAMES tf, int period, double deviation, ENUM_APPLIED_PRICE price) {
      string params = IntegerToString(period) + "_" + DoubleToString(deviation, 1) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "BANDS", params);
      
      // Verificar se já existe
      int existingHandle = FindHandle(key);
      if(existingHandle != INVALID_HANDLE) {
         return existingHandle;
      }
      
      // Criar novo handle APENAS se não existir
      int handle = iBands(symbol, tf, period, (int)deviation, 0, price);
      
      if(handle != INVALID_HANDLE) {
         AddHandle(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle Bollinger: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }

   // Verificar se um indicador está pronto
   bool IsReady(int handle, int minBars = 50) {
      if(handle == INVALID_HANDLE) {
         return false;
      }
      
      int calculated = BarsCalculated(handle);
      return (calculated >= minBars);
   }
   
   // Liberar TODOS os handles - chamado APENAS no destrutor
   void ReleaseAll() {
      int size = ArraySize(m_handles);
      int released = 0;
      
      for(int i = 0; i < size; i++) {
         if(m_handles[i].handle != INVALID_HANDLE) {
            IndicatorRelease(m_handles[i].handle);
            m_handles[i].handle = INVALID_HANDLE;
            released++;
         }
      }
      
      if(m_logger != NULL && released > 0) {
         m_logger.Info(StringFormat("IndicatorManager: Liberados %d handles no encerramento", released));
      }
      
      ArrayResize(m_handles, 0);
   }
   
   // Obter número de handles ativos
   int GetHandleCount() {
      return ArraySize(m_handles);
   }
   
   // Imprimir estatísticas
   void PrintHandleStats() {
      int size = ArraySize(m_handles);
      
      if(m_logger != NULL) {
         m_logger.Info(StringFormat("=== IndicatorManager: %d handles PERMANENTES em uso ===", size));
         
         for(int i = 0; i < size; i++) {
            // Calcular tempo desde criação
            int secondsSinceCreation = (int)(TimeCurrent() - m_handles[i].createdTime);
            int minutes = secondsSinceCreation / 60;
            int hours = minutes / 60;
            
            string timeStr;
            if(hours > 0) {
               timeStr = StringFormat("%dh %dm", hours, minutes % 60);
            } else {
               timeStr = StringFormat("%dm", minutes);
            }
            
            m_logger.Debug(StringFormat("Handle #%d: %s | Uso: %d vezes | Ativo há: %s",
                                       i,
                                       m_handles[i].key,
                                       m_handles[i].useCount,
                                       timeStr));
         }
      }
   }
   
   // NÃO há mais métodos de manutenção ou limpeza!
   // Os handles são mantidos até o EA ser desligado
};

#endif // INDICATORMANAGER_MQH