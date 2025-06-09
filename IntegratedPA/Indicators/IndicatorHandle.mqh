//+------------------------------------------------------------------+
//|                                             IndicatorHandle.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Enumeração para tipos de indicadores suportados                  |
//+------------------------------------------------------------------+
enum INDICATOR_TYPE
{
   I_IND_MA,           // Moving Average
   I_IND_EMA,          // Exponential Moving Average
   I_IND_RSI,          // Relative Strength Index
   I_IND_ATR,          // Average True Range
   I_IND_MACD,         // MACD
   I_IND_STOCHASTIC,   // Stochastic Oscillator
   I_IND_BOLLINGER,    // Bollinger Bands
   I_IND_CUSTOM        // Indicador customizado
};

//+------------------------------------------------------------------+
//| Estrutura para parâmetros de indicadores                         |
//+------------------------------------------------------------------+
struct IndicatorParams
{
   INDICATOR_TYPE type;           // Tipo do indicador
   string symbol;                 // Símbolo
   ENUM_TIMEFRAMES timeframe;     // Timeframe
   
   // Parâmetros específicos por tipo
   int period1;                   // Período principal
   int period2;                   // Período secundário (MACD, etc.)
   int period3;                   // Período terciário (MACD signal)
   ENUM_MA_METHOD method;         // Método da média móvel
   ENUM_APPLIED_PRICE price;      // Preço aplicado
   double deviation;              // Desvio (Bollinger)
   
   // Campos para criação de hash único
   string customName;             // Nome customizado
   int shift;                     // Shift do indicador
   
   // Construtor
   IndicatorParams()
   {
      type = I_IND_MA;
      symbol = "";
      timeframe = PERIOD_CURRENT;
      period1 = 14;
      period2 = 0;
      period3 = 0;
      method = MODE_SMA;
      price = PRICE_CLOSE;
      deviation = 2.0;
      customName = "";
      shift = 0;
   }
   
   // Gerar hash único para identificação
   string GetHashKey() const
   {
      return StringFormat("%s_%s_%d_%d_%d_%d_%d_%d_%.2f_%s_%d",
                         EnumToString(type),
                         symbol,
                         (int)timeframe,
                         period1,
                         period2,
                         period3,
                         (int)method,
                         (int)price,
                         deviation,
                         customName,
                         shift);
   }
};

//+------------------------------------------------------------------+
//| Classe para encapsular um handle de indicador                    |
//+------------------------------------------------------------------+
class CIndicatorHandle
{
private:
   int m_handle;                    // Handle do indicador
   IndicatorParams m_params;        // Parâmetros de criação
   datetime m_lastAccess;           // Último acesso
   int m_refCount;                  // Contador de referências
   bool m_isValid;                  // Status de validade
   string m_hashKey;                // Chave hash única
   
   // Buffer de dados cache (opcional)
   double m_bufferCache[];
   datetime m_lastUpdate;
   bool m_hasCachedData;
   
public:
   // Construtor
   CIndicatorHandle(const IndicatorParams &params)
   {
      m_params = params;
      m_handle = INVALID_HANDLE;
      m_lastAccess = TimeCurrent();
      m_refCount = 1;
      m_isValid = false;
      m_hashKey = params.GetHashKey();
      m_lastUpdate = 0;
      m_hasCachedData = false;
      ArrayResize(m_bufferCache, 0);
      
      CreateHandle();
   }
   
   // Destrutor
   ~CIndicatorHandle()
   {
      ReleaseHandle();
   }
   
   // Métodos de acesso
   int GetHandle() 
   { 
      m_lastAccess = TimeCurrent(); 
      return m_handle; 
   }
   
   string GetHashKey() const { return m_hashKey; }
   bool IsValid() const { return m_isValid && m_handle != INVALID_HANDLE; }
   datetime GetLastAccess() const { return m_lastAccess; }
   int GetRefCount() const { return m_refCount; }
   const IndicatorParams GetParams() const { return m_params; }
   
   // Gerenciamento de referências
   void AddRef() { m_refCount++; }
   void Release() 
   { 
      m_refCount--; 
      if(m_refCount <= 0) 
      {
         ReleaseHandle();
      }
   }
   
   // Métodos para cópia de dados com cache
   int CopyBuffer(int buffer_num, int start_pos, int count, double &buffer[])
   {
      if(!IsValid()) return 0;
      
      m_lastAccess = TimeCurrent();
      
      // Implementar cache simples para buffer 0
      if(buffer_num == 0 && count <= 10 && start_pos == 0)
      {
         datetime currentTime = TimeCurrent();
         if(m_hasCachedData && (currentTime - m_lastUpdate) < 60) // Cache por 1 minuto
         {
            int cacheSize = ArraySize(m_bufferCache);
            if(cacheSize >= count)
            {
               ArrayResize(buffer, count);
               for(int i = 0; i < count; i++)
               {
                  buffer[i] = m_bufferCache[i];
               }
               return count;
            }
         }
      }
      
      // Copiar dados do indicador
      int copied = ::CopyBuffer(m_handle, buffer_num, start_pos, count, buffer);
      
      // Atualizar cache se aplicável
      if(copied > 0 && buffer_num == 0 && count <= 10 && start_pos == 0)
      {
         ArrayResize(m_bufferCache, copied);
         for(int i = 0; i < copied; i++)
         {
            m_bufferCache[i] = buffer[i];
         }
         m_lastUpdate = TimeCurrent();
         m_hasCachedData = true;
      }
      
      return copied;
   }
   
   // Invalidar cache
   void InvalidateCache()
   {
      m_hasCachedData = false;
      m_lastUpdate = 0;
   }

private:
   // Criar handle baseado nos parâmetros
   bool CreateHandle()
   {
      ReleaseHandle();
      
      switch(m_params.type)
      {
         case I_IND_MA:
         case I_IND_EMA:
            m_handle = iMA(m_params.symbol, m_params.timeframe, m_params.period1, 
                          m_params.shift, m_params.method, m_params.price);
            break;
            
         case I_IND_RSI:
            m_handle = iRSI(m_params.symbol, m_params.timeframe, m_params.period1, m_params.price);
            break;
            
         case I_IND_ATR:
            m_handle = iATR(m_params.symbol, m_params.timeframe, m_params.period1);
            break;
            
         case I_IND_MACD:
            m_handle = iMACD(m_params.symbol, m_params.timeframe, m_params.period1, 
                           m_params.period2, m_params.period3, m_params.price);
            break;
            
         case I_IND_STOCHASTIC:
            m_handle = iStochastic(m_params.symbol, m_params.timeframe, m_params.period1, 
                                 m_params.period2, m_params.period3, m_params.method, 
                                 STO_LOWHIGH);
            break;
            
         case I_IND_BOLLINGER:
            m_handle = iBands(m_params.symbol, m_params.timeframe, m_params.period1, 
                            (int)m_params.deviation, m_params.shift, m_params.price);
            break;
            
         default:
            m_handle = INVALID_HANDLE;
            break;
      }
      
      m_isValid = (m_handle != INVALID_HANDLE);
      return m_isValid;
   }
   
   // Liberar handle
   void ReleaseHandle()
   {
      if(m_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle);
         m_handle = INVALID_HANDLE;
      }
      m_isValid = false;
      m_hasCachedData = false;
   }
};

//+------------------------------------------------------------------+
//| Classe para estatísticas do pool de handles                      |
//+------------------------------------------------------------------+
class CHandlePoolStats
{
public:
   int totalHandles;           // Total de handles criados
   int activeHandles;          // Handles ativos
   int cacheHits;             // Acertos no cache
   int cacheMisses;           // Falhas no cache
   int handlesReused;         // Handles reutilizados
   int handlesCreated;        // Novos handles criados
   int handlesReleased;       // Handles liberados
   datetime lastCleanup;      // Última limpeza
   
   CHandlePoolStats()
   {
      Reset();
   }
   
   void Reset()
   {
      totalHandles = 0;
      activeHandles = 0;
      cacheHits = 0;
      cacheMisses = 0;
      handlesReused = 0;
      handlesCreated = 0;
      handlesReleased = 0;
      lastCleanup = TimeCurrent();
   }
   
   string GetReport() const
   {
      double hitRate = (cacheHits + cacheMisses > 0) ? 
                      (double)cacheHits / (cacheHits + cacheMisses) * 100.0 : 0.0;
      
      return StringFormat(
         "=== Handle Pool Stats ===\n"
         "Total Handles: %d\n"
         "Active: %d\n"
         "Cache Hit Rate: %.1f%% (%d/%d)\n"
         "Reused: %d | Created: %d | Released: %d\n"
         "Last Cleanup: %s",
         totalHandles, activeHandles, hitRate, cacheHits, (cacheHits + cacheMisses),
         handlesReused, handlesCreated, handlesReleased,
         TimeToString(lastCleanup, TIME_DATE | TIME_MINUTES)
      );
   }
};