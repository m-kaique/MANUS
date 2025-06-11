//+------------------------------------------------------------------+
//|                                                  HandlePool.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "IndicatorHandle.mqh"
#include "../Logging/Logger.mqh"
#include "../Structures.mqh"

//+------------------------------------------------------------------+
//| Classe para gerenciamento centralizado de handles de indicadores |
//+------------------------------------------------------------------+
class CHandlePool
{
private:
   // Mapa hash de handles (chave → handle)
   CIndicatorHandle* m_handles[];
   string m_hashKeys[];
   int m_handleCount;
   
   // Estatísticas e monitoramento
   CHandlePoolStats* m_stats;
   CLogger* m_logger;
   
   // Configurações
   int m_maxHandles;
   int m_cleanupInterval;
   datetime m_lastCleanup;
   
   // Métodos privados
   int FindHandleIndex(string hashKey);
   void CleanupUnusedHandles();
   string CreateHashKey(INDICATOR_TYPE type, string symbol, ENUM_TIMEFRAMES timeframe, IndicatorParams &params);
   
public:
   // Construtor e destrutor
   CHandlePool(int maxHandles = 100);
   ~CHandlePool();
   
   // Inicialização
   bool Initialize(CLogger* logger);
   
   // Métodos principais para obter handles
   CIndicatorHandle* GetMA(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price);
   CIndicatorHandle* GetEMA(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift, ENUM_APPLIED_PRICE price);
   CIndicatorHandle* GetRSI(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_APPLIED_PRICE price);
   CIndicatorHandle* GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   CIndicatorHandle* GetMACD(string symbol, ENUM_TIMEFRAMES timeframe, int fast, int slow, int signal, ENUM_APPLIED_PRICE price);
   CIndicatorHandle* GetStochastic(string symbol, ENUM_TIMEFRAMES timeframe, int kPeriod, int dPeriod, int slowing, ENUM_MA_METHOD method);
   CIndicatorHandle* GetBollinger(string symbol, ENUM_TIMEFRAMES timeframe, int period, double deviation, int shift, ENUM_APPLIED_PRICE price);
   
   // Métodos para cópia de dados com cache
   int CopyBuffer(string symbol, ENUM_TIMEFRAMES timeframe, INDICATOR_TYPE type, IndicatorParams &params, int buffer_num, int start_pos, int count, double &buffer[]);
   
   // Métodos de limpeza e manutenção
   void InvalidateCache(string symbol = "");
   void CleanupExpiredHandles();
   void ForceCleanup();
   
   // Métodos de monitoramento
   CHandlePoolStats* GetStats() { return m_stats; }
   void PrintStats();
   void ResetStats();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CHandlePool::CHandlePool(int maxHandles = 100)
{
   m_handleCount = 0;
   m_maxHandles = maxHandles;
   m_cleanupInterval = 300; // 5 minutos
   m_lastCleanup = TimeCurrent();
   m_logger = NULL;
   
   // Inicializar arrays
   ArrayResize(m_handles, 0);
   ArrayResize(m_hashKeys, 0);
   
   // Criar objeto de estatísticas
   m_stats = new CHandlePoolStats();
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CHandlePool::~CHandlePool()
{
   // Liberar todos os handles
   for(int i = 0; i < m_handleCount; i++)
   {
      if(m_handles[i] != NULL)
      {
         delete m_handles[i];
      }
   }
   
   // Limpar arrays
   ArrayResize(m_handles, 0);
   ArrayResize(m_hashKeys, 0);
   
   // Liberar estatísticas
   if(m_stats != NULL)
   {
      delete m_stats;
   }
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CHandlePool::Initialize(CLogger* logger)
{
   m_logger = logger;
   
   if(m_logger != NULL)
   {
      m_logger.Info("HandlePool inicializado - Capacidade máxima: " + IntegerToString(m_maxHandles));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obter handle de Moving Average                                   |
//+------------------------------------------------------------------+
CIndicatorHandle* CHandlePool::GetMA(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price)
{
   // Criar parâmetros
   IndicatorParams params;
   params.type = I_IND_MA;
   params.symbol = symbol;
   params.timeframe = timeframe;
   params.period1 = period;
   params.shift = shift;
   params.method = method;
   params.price = price;
   
   // Gerar chave hash
   string hashKey = params.GetHashKey();
   
   // Verificar se já existe
   int index = FindHandleIndex(hashKey);
   if(index >= 0)
   {
      m_stats.cacheHits++;
      return m_handles[index];
   }
   
   // Criar novo handle
   if(m_handleCount >= m_maxHandles)
   {
      CleanupUnusedHandles();
      
      if(m_handleCount >= m_maxHandles)
      {
         if(m_logger != NULL)
         {
            m_logger.Warning("HandlePool: Limite máximo de handles atingido");
         }
         return NULL;
      }
   }
   
   // Expandir arrays
   ArrayResize(m_handles, m_handleCount + 1);
   ArrayResize(m_hashKeys, m_handleCount + 1);
   
   // Criar handle
   m_handles[m_handleCount] = new CIndicatorHandle(params);
   m_hashKeys[m_handleCount] = hashKey;
   
   if(m_handles[m_handleCount].IsValid())
   {
      m_handleCount++;
      m_stats.cacheMisses++;
      m_stats.handlesCreated++;
      m_stats.totalHandles++;
      m_stats.activeHandles++;
      
      if(m_logger != NULL)
      {
         m_logger.Debug("HandlePool: Novo handle MA criado para " + symbol + " " + EnumToString(timeframe) + " period=" + IntegerToString(period));
      }
      
      return m_handles[m_handleCount - 1];
   }
   else
   {
      // Falha ao criar handle
      delete m_handles[m_handleCount];
      m_handles[m_handleCount] = NULL;
      
      if(m_logger != NULL)
      {
         m_logger.Error("HandlePool: Falha ao criar handle MA para " + symbol);
      }
      
      return NULL;
   }
}

//+------------------------------------------------------------------+
//| Obter handle de Exponential Moving Average                       |
//+------------------------------------------------------------------+
CIndicatorHandle* CHandlePool::GetEMA(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift, ENUM_APPLIED_PRICE price)
{
   return GetMA(symbol, timeframe, period, shift, MODE_EMA, price);
}

//+------------------------------------------------------------------+
//| Obter handle de RSI                                              |
//+------------------------------------------------------------------+
CIndicatorHandle* CHandlePool::GetRSI(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_APPLIED_PRICE price)
{
   IndicatorParams params;
   params.type = I_IND_RSI;
   params.symbol = symbol;
   params.timeframe = timeframe;
   params.period1 = period;
   params.price = price;
   
   string hashKey = params.GetHashKey();
   
   int index = FindHandleIndex(hashKey);
   if(index >= 0)
   {
      m_stats.cacheHits++;
      return m_handles[index];
   }
   
   if(m_handleCount >= m_maxHandles)
   {
      CleanupUnusedHandles();
      if(m_handleCount >= m_maxHandles) return NULL;
   }
   
   ArrayResize(m_handles, m_handleCount + 1);
   ArrayResize(m_hashKeys, m_handleCount + 1);
   
   m_handles[m_handleCount] = new CIndicatorHandle(params);
   m_hashKeys[m_handleCount] = hashKey;
   
   if(m_handles[m_handleCount].IsValid())
   {
      m_handleCount++;
      m_stats.cacheMisses++;
      m_stats.handlesCreated++;
      m_stats.totalHandles++;
      m_stats.activeHandles++;
      
      if(m_logger != NULL)
      {
         m_logger.Debug("HandlePool: Novo handle RSI criado para " + symbol + " " + EnumToString(timeframe));
      }
      
      return m_handles[m_handleCount - 1];
   }
   else
   {
      delete m_handles[m_handleCount];
      m_handles[m_handleCount] = NULL;
      return NULL;
   }
}

//+------------------------------------------------------------------+
//| Obter handle de ATR                                              |
//+------------------------------------------------------------------+
CIndicatorHandle* CHandlePool::GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   IndicatorParams params;
   params.type = I_IND_ATR;
   params.symbol = symbol;
   params.timeframe = timeframe;
   params.period1 = period;
   
   string hashKey = params.GetHashKey();
   
   int index = FindHandleIndex(hashKey);
   if(index >= 0)
   {
      m_stats.cacheHits++;
      return m_handles[index];
   }
   
   if(m_handleCount >= m_maxHandles)
   {
      CleanupUnusedHandles();
      if(m_handleCount >= m_maxHandles) return NULL;
   }
   
   ArrayResize(m_handles, m_handleCount + 1);
   ArrayResize(m_hashKeys, m_handleCount + 1);
   
   m_handles[m_handleCount] = new CIndicatorHandle(params);
   m_hashKeys[m_handleCount] = hashKey;
   
   if(m_handles[m_handleCount].IsValid())
   {
      m_handleCount++;
      m_stats.cacheMisses++;
      m_stats.handlesCreated++;
      m_stats.totalHandles++;
      m_stats.activeHandles++;
      
      return m_handles[m_handleCount - 1];
   }
   else
   {
      delete m_handles[m_handleCount];
      m_handles[m_handleCount] = NULL;
      return NULL;
   }
}

//+------------------------------------------------------------------+
//| Obter handle de MACD                                             |
//+------------------------------------------------------------------+
CIndicatorHandle* CHandlePool::GetMACD(string symbol, ENUM_TIMEFRAMES timeframe, int fast, int slow, int signal, ENUM_APPLIED_PRICE price)
{
   IndicatorParams params;
   params.type = I_IND_MACD;
   params.symbol = symbol;
   params.timeframe = timeframe;
   params.period1 = fast;
   params.period2 = slow;
   params.period3 = signal;
   params.price = price;
   
   string hashKey = params.GetHashKey();
   
   int index = FindHandleIndex(hashKey);
   if(index >= 0)
   {
      m_stats.cacheHits++;
      return m_handles[index];
   }
   
   if(m_handleCount >= m_maxHandles)
   {
      CleanupUnusedHandles();
      if(m_handleCount >= m_maxHandles) return NULL;
   }
   
   ArrayResize(m_handles, m_handleCount + 1);
   ArrayResize(m_hashKeys, m_handleCount + 1);
   
   m_handles[m_handleCount] = new CIndicatorHandle(params);
   m_hashKeys[m_handleCount] = hashKey;
   
   if(m_handles[m_handleCount].IsValid())
   {
      m_handleCount++;
      m_stats.cacheMisses++;
      m_stats.handlesCreated++;
      m_stats.totalHandles++;
      m_stats.activeHandles++;
      
      return m_handles[m_handleCount - 1];
   }
   else
   {
      delete m_handles[m_handleCount];
      m_handles[m_handleCount] = NULL;
      return NULL;
   }
}

//+------------------------------------------------------------------+
//| Obter handle de Bollinger Bands                                  |
//+------------------------------------------------------------------+
CIndicatorHandle* CHandlePool::GetBollinger(string symbol, ENUM_TIMEFRAMES timeframe, int period, double deviation, int shift, ENUM_APPLIED_PRICE price)
{
   IndicatorParams params;
   params.type = I_IND_BOLLINGER;
   params.symbol = symbol;
   params.timeframe = timeframe;
   params.period1 = period;
   params.deviation = deviation;
   params.shift = shift;
   params.price = price;
   
   string hashKey = params.GetHashKey();
   
   int index = FindHandleIndex(hashKey);
   if(index >= 0)
   {
      m_stats.cacheHits++;
      return m_handles[index];
   }
   
   if(m_handleCount >= m_maxHandles)
   {
      CleanupUnusedHandles();
      if(m_handleCount >= m_maxHandles) return NULL;
   }
   
   ArrayResize(m_handles, m_handleCount + 1);
   ArrayResize(m_hashKeys, m_handleCount + 1);
   
   m_handles[m_handleCount] = new CIndicatorHandle(params);
   m_hashKeys[m_handleCount] = hashKey;
   
   if(m_handles[m_handleCount].IsValid())
   {
      m_handleCount++;
      m_stats.cacheMisses++;
      m_stats.handlesCreated++;
      m_stats.totalHandles++;
      m_stats.activeHandles++;
      
      return m_handles[m_handleCount - 1];
   }
   else
   {
      delete m_handles[m_handleCount];
      m_handles[m_handleCount] = NULL;
      return NULL;
   }
}

//+------------------------------------------------------------------+
//| Cópia de dados com cache integrado                               |
//+------------------------------------------------------------------+
int CHandlePool::CopyBuffer(string symbol, ENUM_TIMEFRAMES timeframe, INDICATOR_TYPE type, IndicatorParams &params, int buffer_num, int start_pos, int count, double &buffer[])
{
   string hashKey = params.GetHashKey();
   
   int index = FindHandleIndex(hashKey);
   if(index >= 0)
   {
      return m_handles[index].CopyBuffer(buffer_num, start_pos, count, buffer);
   }
   
   return 0; // Handle não encontrado
}

//+------------------------------------------------------------------+
//| Encontrar índice do handle pela chave hash                       |
//+------------------------------------------------------------------+
int CHandlePool::FindHandleIndex(string hashKey)
{
   for(int i = 0; i < m_handleCount; i++)
   {
      if(m_hashKeys[i] == hashKey && m_handles[i] != NULL && m_handles[i].IsValid())
      {
         return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Limpeza de handles não utilizados                                |
//+------------------------------------------------------------------+
void CHandlePool::CleanupUnusedHandles()
{
   datetime currentTime = TimeCurrent();
   int removed = 0;
   
   for(int i = m_handleCount - 1; i >= 0; i--)
   {
      if(m_handles[i] != NULL)
      {
         // Remover handles não acessados nos últimos 30 minutos
         if(currentTime - m_handles[i].GetLastAccess() > 1800)
         {
            if(m_logger != NULL)
            {
               m_logger.Debug("HandlePool: Removendo handle não utilizado: " + m_hashKeys[i]);
            }
            
            delete m_handles[i];
            
            // Mover elementos para frente
            for(int j = i; j < m_handleCount - 1; j++)
            {
               m_handles[j] = m_handles[j + 1];
               m_hashKeys[j] = m_hashKeys[j + 1];
            }
            
            m_handleCount--;
            removed++;
            m_stats.handlesReleased++;
            m_stats.activeHandles--;
         }
      }
   }
   
   if(removed > 0)
   {
      ArrayResize(m_handles, m_handleCount);
      ArrayResize(m_hashKeys, m_handleCount);
      
      if(m_logger != NULL)
      {
         m_logger.Info("HandlePool: " + IntegerToString(removed) + " handles removidos na limpeza");
      }
   }
   
   m_lastCleanup = currentTime;
   m_stats.lastCleanup = currentTime;
}

//+------------------------------------------------------------------+
//| Invalidar cache para um símbolo específico                       |
//+------------------------------------------------------------------+
void CHandlePool::InvalidateCache(string symbol = "")
{
   for(int i = 0; i < m_handleCount; i++)
   {
      if(m_handles[i] != NULL)
      {
         if(symbol == "" || StringFind(m_hashKeys[i], symbol) >= 0)
         {
            m_handles[i].InvalidateCache();
         }
      }
   }
   
   if(m_logger != NULL)
   {
      if(symbol == "")
      {
         m_logger.Info("HandlePool: Cache invalidado para todos os símbolos");
      }
      else
      {
         m_logger.Info("HandlePool: Cache invalidado para " + symbol);
      }
   }
}

//+------------------------------------------------------------------+
//| Limpeza forçada de todos os handles                              |
//+------------------------------------------------------------------+
void CHandlePool::ForceCleanup()
{
   for(int i = 0; i < m_handleCount; i++)
   {
      if(m_handles[i] != NULL)
      {
         delete m_handles[i];
      }
   }
   
   ArrayResize(m_handles, 0);
   ArrayResize(m_hashKeys, 0);
   
   m_stats.handlesReleased += m_handleCount;
   m_stats.activeHandles = 0;
   m_handleCount = 0;
   
   if(m_logger != NULL)
   {
      m_logger.Info("HandlePool: Limpeza forçada executada - Todos os handles removidos");
   }
}

//+------------------------------------------------------------------+
//| Imprimir estatísticas do pool                                    |
//+------------------------------------------------------------------+
void CHandlePool::PrintStats()
{
   if(m_logger != NULL && m_stats != NULL)
   {
      m_logger.Info(m_stats.GetReport());
   }
}

//+------------------------------------------------------------------+
//| Resetar estatísticas                                             |
//+------------------------------------------------------------------+
void CHandlePool::ResetStats()
{
   if(m_stats != NULL)
   {
      m_stats.Reset();
   }
}