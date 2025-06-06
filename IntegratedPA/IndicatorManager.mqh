//+------------------------------------------------------------------+
//|                                          IndicatorManager.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"
#property strict

#ifndef INDICATORMANAGER_MQH
#define INDICATORMANAGER_MQH

#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Classe para gerenciamento de handles de indicadores              |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
   struct IndicatorHandle {
      string key;
      int handle;
      datetime lastUsed;
      int useCount;
   };

   IndicatorHandle m_handles[];
   int m_maxHandles;
   int m_cacheTimeout;
   CLogger* m_logger;

   string GenerateKey(string symbol, ENUM_TIMEFRAMES tf, string type, string params) {
      return symbol + "_" + IntegerToString(tf) + "_" + type + "_" + params;
   }
   
   void CleanupOldHandles() {
      datetime currentTime = TimeCurrent();
      int size = ArraySize(m_handles);
      
      for(int i = size - 1; i >= 0; i--) {
         if(currentTime - m_handles[i].lastUsed > m_cacheTimeout) {
            if(m_handles[i].handle != INVALID_HANDLE) {
               IndicatorRelease(m_handles[i].handle);
               
               if(m_logger != NULL) {
                  m_logger.Debug(StringFormat("Liberado handle não utilizado: %s (último uso: %s)",
                                            m_handles[i].key,
                                            TimeToString(m_handles[i].lastUsed)));
               }
            }
            
            // Remover do array
            for(int j = i; j < size - 1; j++) {
               m_handles[j] = m_handles[j + 1];
            }
            
            ArrayResize(m_handles, size - 1);
            size--;
         }
      }
   }
   
   // Função auxiliar para adicionar handle ao cache
   int AddHandleToCache(string key, int handle) {
      if(handle == INVALID_HANDLE) {
         return INVALID_HANDLE;
      }
      
      int size = ArraySize(m_handles);
      
      // Verificar se precisa fazer limpeza
      if(size >= m_maxHandles) {
         CleanupOldHandles();
         size = ArraySize(m_handles);
         
         if(size >= m_maxHandles) {
            // Se ainda estiver cheio, remover o handle mais antigo
            int oldestIndex = 0;
            datetime oldestTime = m_handles[0].lastUsed;
            
            for(int i = 1; i < size; i++) {
               if(m_handles[i].lastUsed < oldestTime) {
                  oldestTime = m_handles[i].lastUsed;
                  oldestIndex = i;
               }
            }
            
            if(m_handles[oldestIndex].handle != INVALID_HANDLE) {
               IndicatorRelease(m_handles[oldestIndex].handle);
               
               if(m_logger != NULL) {
                  m_logger.Debug(StringFormat("Liberado handle mais antigo: %s (último uso: %s)",
                                            m_handles[oldestIndex].key,
                                            TimeToString(m_handles[oldestIndex].lastUsed)));
               }
            }
            
            // Substituir o handle mais antigo
            m_handles[oldestIndex].key = key;
            m_handles[oldestIndex].handle = handle;
            m_handles[oldestIndex].lastUsed = TimeCurrent();
            m_handles[oldestIndex].useCount = 1;
            
            return handle;
         }
      }
      
      // Adicionar novo handle ao array
      ArrayResize(m_handles, size + 1);
      m_handles[size].key = key;
      m_handles[size].handle = handle;
      m_handles[size].lastUsed = TimeCurrent();
      m_handles[size].useCount = 1;
      
      if(m_logger != NULL) {
         m_logger.Debug(StringFormat("Criado novo handle: %s (total: %d)", key, size + 1));
      }
      
      return handle;
   }

public:
   // Reduzir o limite máximo para evitar problemas
   CIndicatorManager(int maxHandles = 30, int cacheTimeout = 3600) {
      m_maxHandles = maxHandles;
      m_cacheTimeout = cacheTimeout;
      m_logger = NULL;
   }
   
   ~CIndicatorManager() {
      ReleaseAll();
   }
   
   void Initialize(CLogger* logger) {
      m_logger = logger;
      
      if(m_logger != NULL) {
         m_logger.Info(StringFormat("IndicatorManager inicializado (max handles: %d, timeout: %d)",
                                   m_maxHandles, m_cacheTimeout));
      }
   }

   int GetMA(string symbol, ENUM_TIMEFRAMES tf, int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price) {
      string params = IntegerToString(period) + "_" + IntegerToString(shift) + "_" + 
                     IntegerToString(method) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "MA", params);
      
      // Verificar se já existe no cache
      int size = ArraySize(m_handles);
      for(int i = 0; i < size; i++) {
         if(m_handles[i].key == key) {
            m_handles[i].lastUsed = TimeCurrent();
            m_handles[i].useCount++;
            
            if(m_logger != NULL) {
               m_logger.Debug(StringFormat("Reutilizando handle existente: %s (uso #%d)", key, m_handles[i].useCount));
            }
            
            return m_handles[i].handle;
         }
      }
      
      // Criar novo handle
      int handle = iMA(symbol, tf, period, shift, method, price);
      
      if(handle != INVALID_HANDLE) {
         return AddHandleToCache(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle MA: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }

   int GetRSI(string symbol, ENUM_TIMEFRAMES tf, int period, ENUM_APPLIED_PRICE price) {
      string params = IntegerToString(period) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "RSI", params);
      
      // Verificar se já existe no cache
      int size = ArraySize(m_handles);
      for(int i = 0; i < size; i++) {
         if(m_handles[i].key == key) {
            m_handles[i].lastUsed = TimeCurrent();
            m_handles[i].useCount++;
            
            if(m_logger != NULL) {
               m_logger.Debug(StringFormat("Reutilizando handle existente: %s (uso #%d)", key, m_handles[i].useCount));
            }
            
            return m_handles[i].handle;
         }
      }
      
      // Criar novo handle
      int handle = iRSI(symbol, tf, period, price);
      
      if(handle != INVALID_HANDLE) {
         return AddHandleToCache(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle RSI: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }
   
   int GetATR(string symbol, ENUM_TIMEFRAMES tf, int period) {
      string params = IntegerToString(period);
      string key = GenerateKey(symbol, tf, "ATR", params);
      
      // Verificar se já existe no cache
      int size = ArraySize(m_handles);
      for(int i = 0; i < size; i++) {
         if(m_handles[i].key == key) {
            m_handles[i].lastUsed = TimeCurrent();
            m_handles[i].useCount++;
            
            if(m_logger != NULL) {
               m_logger.Debug(StringFormat("Reutilizando handle existente: %s (uso #%d)", key, m_handles[i].useCount));
            }
            
            return m_handles[i].handle;
         }
      }
      
      // Criar novo handle
      int handle = iATR(symbol, tf, period);
      
      if(handle != INVALID_HANDLE) {
         return AddHandleToCache(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle ATR: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }
   
   int GetMACD(string symbol, ENUM_TIMEFRAMES tf, int fastPeriod, int slowPeriod, int signalPeriod, ENUM_APPLIED_PRICE price) {
      string params = IntegerToString(fastPeriod) + "_" + IntegerToString(slowPeriod) + "_" + 
                     IntegerToString(signalPeriod) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "MACD", params);
      
      // Verificar se já existe no cache
      int size = ArraySize(m_handles);
      for(int i = 0; i < size; i++) {
         if(m_handles[i].key == key) {
            m_handles[i].lastUsed = TimeCurrent();
            m_handles[i].useCount++;
            
            if(m_logger != NULL) {
               m_logger.Debug(StringFormat("Reutilizando handle existente: %s (uso #%d)", key, m_handles[i].useCount));
            }
            
            return m_handles[i].handle;
         }
      }
      
      // Criar novo handle
      int handle = iMACD(symbol, tf, fastPeriod, slowPeriod, signalPeriod, price);
      
      if(handle != INVALID_HANDLE) {
         return AddHandleToCache(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle MACD: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }
   
   int GetStochastic(string symbol, ENUM_TIMEFRAMES tf, int kPeriod, int dPeriod, int slowing, ENUM_MA_METHOD method, ENUM_STO_PRICE price) {
      string params = IntegerToString(kPeriod) + "_" + IntegerToString(dPeriod) + "_" + 
                     IntegerToString(slowing) + "_" + IntegerToString(method) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "STOCH", params);
      
      // Verificar se já existe no cache
      int size = ArraySize(m_handles);
      for(int i = 0; i < size; i++) {
         if(m_handles[i].key == key) {
            m_handles[i].lastUsed = TimeCurrent();
            m_handles[i].useCount++;
            
            if(m_logger != NULL) {
               m_logger.Debug(StringFormat("Reutilizando handle existente: %s (uso #%d)", key, m_handles[i].useCount));
            }
            
            return m_handles[i].handle;
         }
      }
      
      // Criar novo handle
      int handle = iStochastic(symbol, tf, kPeriod, dPeriod, slowing, method, price);
      
      if(handle != INVALID_HANDLE) {
         return AddHandleToCache(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle Stochastic: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }
   
   int GetBollinger(string symbol, ENUM_TIMEFRAMES tf, int period, double deviation, ENUM_APPLIED_PRICE price) {
      string params = IntegerToString(period) + "_" + DoubleToString(deviation, 1) + "_" + IntegerToString(price);
      string key = GenerateKey(symbol, tf, "BANDS", params);
      
      // Verificar se já existe no cache
      int size = ArraySize(m_handles);
      for(int i = 0; i < size; i++) {
         if(m_handles[i].key == key) {
            m_handles[i].lastUsed = TimeCurrent();
            m_handles[i].useCount++;
            
            if(m_logger != NULL) {
               m_logger.Debug(StringFormat("Reutilizando handle existente: %s (uso #%d)", key, m_handles[i].useCount));
            }
            
            return m_handles[i].handle;
         }
      }
      
      // Criar novo handle
      int handle = iBands(symbol, tf, period, (int)deviation, 0, price);
      
      if(handle != INVALID_HANDLE) {
         return AddHandleToCache(key, handle);
      } else if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao criar handle Bollinger: %s (erro: %d)", key, GetLastError()));
      }
      
      return handle;
   }

   bool IsReady(int handle, int minBars = 50) {
      if(handle == INVALID_HANDLE) {
         return false;
      }
      
      return (BarsCalculated(handle) >= minBars);
   }
   
   void ReleaseAll() {
      int size = ArraySize(m_handles);
      
      for(int i = 0; i < size; i++) {
         if(m_handles[i].handle != INVALID_HANDLE) {
            IndicatorRelease(m_handles[i].handle);
            m_handles[i].handle = INVALID_HANDLE;
         }
      }
      
      ArrayResize(m_handles, 0);
      
      if(m_logger != NULL) {
         m_logger.Info(StringFormat("Liberados todos os %d handles de indicadores", size));
      }
   }
   
   int GetHandleCount() {
      return ArraySize(m_handles);
   }
   
   void PrintHandleStats() {
      int size = ArraySize(m_handles);
      
      if(m_logger != NULL) {
         m_logger.Info(StringFormat("Estatísticas de handles: %d handles em uso", size));
         
         for(int i = 0; i < size; i++) {
            m_logger.Debug(StringFormat("Handle #%d: %s, Uso: %d, Último uso: %s",
                                       i,
                                       m_handles[i].key,
                                       m_handles[i].useCount,
                                       TimeToString(m_handles[i].lastUsed)));
         }
      }
   }
   
   // Função para limpeza manual de handles antigos
   void PerformMaintenance() {
      int sizeBefore = ArraySize(m_handles);
      CleanupOldHandles();
      int sizeAfter = ArraySize(m_handles);
      
      if(m_logger != NULL && sizeBefore != sizeAfter) {
         m_logger.Info(StringFormat("Manutenção de handles: %d -> %d handles", sizeBefore, sizeAfter));
      }
   }
};

#endif // INDICATORMANAGER_MQH

