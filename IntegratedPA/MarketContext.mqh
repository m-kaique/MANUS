#ifndef MARKETCONTEXT_MQH_
#define MARKETCONTEXT_MQH_

//+------------------------------------------------------------------+
//|                                            MarketContext.mqh ||
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property strict

#include "Structures.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Classe para análise de contexto de mercado                        |
//+------------------------------------------------------------------+
class CMarketContext {
private:
   string m_symbol;                  // Símbolo atual
   ENUM_TIMEFRAMES m_timeframe;      // Timeframe principal
   CLogger* m_logger;                // Ponteiro para o logger
   MARKET_PHASE m_currentPhase;      // Fase atual do mercado
   
   // Handles de indicadores - Mantidos durante toda a vida do objeto
   int m_ema9Handle;
   int m_ema21Handle;
   int m_ema50Handle;
   int m_ema200Handle;
   int m_rsiHandle;
   int m_atrHandle;
   int m_macdHandle;
   int m_stochHandle;
   int m_bollingerHandle;
   
   // Handles para timeframes adicionais - Mantidos como arrays
   int m_ema9Handles[4];   // Um para cada timeframe [principal, maior, intermediário, menor]
   int m_ema21Handles[4];
   int m_ema50Handles[4];
   int m_ema200Handles[4];
   int m_rsiHandles[4];
   int m_atrHandles[4];
   int m_macdHandles[4];
   int m_stochHandles[4];
   int m_bollingerHandles[4];
   
   // Timeframes para análise multi-timeframe
   ENUM_TIMEFRAMES m_timeframes[4];  // [principal, maior, intermediário, menor]
   
   // Flag para indicar se os dados são válidos
   bool m_hasValidData;
   
   // Mínimo de barras necessárias para análise
   int m_minRequiredBars;
   
   // Métodos privados para análise
   bool IsRange(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool IsTrend(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool IsReversal(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool CheckMovingAveragesAlignment(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool CheckMomentum(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   
   // Métodos para gerenciamento de handles
   bool CreateIndicatorHandles();
   bool CreateTimeframeHandles();
   void ReleaseIndicatorHandles();
   int GetIndicatorHandle(int baseHandle, ENUM_TIMEFRAMES timeframe);
   
   // Método para verificar se há dados suficientes
   bool CheckDataValidity();

public:
   // Construtor e destrutor
   CMarketContext();
   ~CMarketContext();
   
   // Métodos públicos
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CLogger* logger = NULL, bool checkHistory = true);
   bool UpdateSymbol(string symbol);
   MARKET_PHASE DetectPhase();
   MARKET_PHASE DetermineMarketPhase();
   MARKET_PHASE GetCurrentPhase() { return m_currentPhase; }
   bool HasValidData() { return m_hasValidData; }
   bool UpdateMarketDepth(string symbol);
   
   // Métodos para verificação de fases de mercado específicas
   bool IsTrendUp();
   bool IsTrendDown();
   bool IsInRange();
   bool IsInReversal();
   
   // Métodos para análise de suporte e resistência
   double FindNearestSupport(double price, int lookbackBars = 50);
   double FindNearestResistance(double price, int lookbackBars = 50);
   
   // Métodos para análise de volatilidade
   double GetATR(int period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   double GetVolatilityRatio();
   
   // Métodos para análise de tendência
   double GetTrendStrength();
   bool IsPriceAboveEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool IsPriceBelowEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   int CheckTrendDirection();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CMarketContext::CMarketContext() {
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_logger = NULL;
   m_currentPhase = PHASE_UNDEFINED;
   m_hasValidData = false;
   m_minRequiredBars = 100;
   
   // Inicializar handles como inválidos
   m_ema9Handle = INVALID_HANDLE;
   m_ema21Handle = INVALID_HANDLE;
   m_ema50Handle = INVALID_HANDLE;
   m_ema200Handle = INVALID_HANDLE;
   m_rsiHandle = INVALID_HANDLE;
   m_atrHandle = INVALID_HANDLE;
   m_macdHandle = INVALID_HANDLE;
   m_stochHandle = INVALID_HANDLE;
   m_bollingerHandle = INVALID_HANDLE;
   
   // Inicializar arrays de handles
   ArrayInitialize(m_ema9Handles, INVALID_HANDLE);
   ArrayInitialize(m_ema21Handles, INVALID_HANDLE);
   ArrayInitialize(m_ema50Handles, INVALID_HANDLE);
   ArrayInitialize(m_ema200Handles, INVALID_HANDLE);
   ArrayInitialize(m_rsiHandles, INVALID_HANDLE);
   ArrayInitialize(m_atrHandles, INVALID_HANDLE);
   ArrayInitialize(m_macdHandles, INVALID_HANDLE);
   ArrayInitialize(m_stochHandles, INVALID_HANDLE);
   ArrayInitialize(m_bollingerHandles, INVALID_HANDLE);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CMarketContext::~CMarketContext() {
   ReleaseIndicatorHandles();
}

//+------------------------------------------------------------------+
//| Inicialização do contexto de mercado                             |
//+------------------------------------------------------------------+
bool CMarketContext::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CLogger* logger = NULL, bool checkHistory = true) {
   // Liberar handles existentes
   ReleaseIndicatorHandles();
   
   // Configurar parâmetros básicos
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_logger = logger;
   m_currentPhase = PHASE_UNDEFINED;
   m_hasValidData = false;
   
   // Configurar timeframes para análise multi-timeframe
   m_timeframes[0] = timeframe;                                // Principal
   m_timeframes[1] = PERIOD_D1;  // Maior
   m_timeframes[2] = PERIOD_H1;  // Intermediário
   m_timeframes[3] = PERIOD_M15; // Menor
   
   // Verificar se o histórico está disponível
   if(checkHistory) {
      int bars = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
      if(bars < m_minRequiredBars) {
         if(m_logger != NULL) {
            m_logger.Warning("Histórico insuficiente para " + m_symbol + " em " + 
                           EnumToString(m_timeframe) + ": " + IntegerToString(bars) + 
                           " barras (mínimo: " + IntegerToString(m_minRequiredBars) + ")");
         }
         return true; // Continuar sem criar handles
      }
   }
   
   // Criar handles de indicadores
   if(!CreateIndicatorHandles()) {
      if(m_logger != NULL) {
         m_logger.Warning("Falha ao criar handles de indicadores para " + m_symbol);
      }
      return true; // Continuar mesmo sem handles
   }
   
   // Criar handles para timeframes adicionais
   if(!CreateTimeframeHandles()) {
      if(m_logger != NULL) {
         m_logger.Warning("Falha ao criar handles para timeframes adicionais para " + m_symbol);
      }
   }
   
   // Verificar se há dados suficientes
   m_hasValidData = CheckDataValidity();
   
   return true;
}

//+------------------------------------------------------------------+
//| Atualizar símbolo do contexto de mercado                         |
//+------------------------------------------------------------------+
bool CMarketContext::UpdateSymbol(string symbol) {
   if(m_symbol == symbol) {
      // Se o símbolo for o mesmo, apenas verificar se os handles são válidos
      if(m_hasValidData) {
         return true;
      }
   }
   
   // Registrar a mudança de símbolo
   if(m_logger != NULL) {
      m_logger.Info("Atualizando contexto de mercado para símbolo: " + symbol);
   }
   
   // Liberar handles existentes
   ReleaseIndicatorHandles();
   
   // Atualizar símbolo
   m_symbol = symbol;
   m_hasValidData = false;
   
   // Criar novos handles
   if(!CreateIndicatorHandles()) {
      if(m_logger != NULL) {
         m_logger.Warning("Falha ao criar handles de indicadores para " + m_symbol);
      }
      return false;
   }
   
   // Criar handles para timeframes adicionais
   if(!CreateTimeframeHandles()) {
      if(m_logger != NULL) {
         m_logger.Warning("Falha ao criar handles para timeframes adicionais para " + m_symbol);
      }
   }
   
   // Verificar se há dados suficientes
   m_hasValidData = CheckDataValidity();
   
   // Determinar fase de mercado
   if(m_hasValidData) {
      m_currentPhase = DetectPhase();
   }
   
   return m_hasValidData;
}

//+------------------------------------------------------------------+
//| Determinar fase de mercado                                       |
//+------------------------------------------------------------------+
MARKET_PHASE CMarketContext::DetermineMarketPhase() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      if(m_logger != NULL) {
         m_logger.Warning("Dados insuficientes para determinar fase de mercado para " + m_symbol);
      }
      return PHASE_UNDEFINED;
   }
   
   // Detectar fase e atualizar estado
   m_currentPhase = DetectPhase();
   
   return m_currentPhase;
}

//+------------------------------------------------------------------+
//| Atualizar informações de profundidade de mercado                 |
//+------------------------------------------------------------------+
bool CMarketContext::UpdateMarketDepth(string symbol) {
   // Verificar se o símbolo é válido
   if(symbol == "" || StringLen(symbol) == 0) {
      if(m_logger != NULL) {
         m_logger.Error("Símbolo inválido para atualização de profundidade de mercado");
      }
      return false;
   }
   
   // Verificar se o livro de ofertas está disponível para o símbolo
   if(!MarketBookAdd(symbol)) {
      if(m_logger != NULL) {
         m_logger.Warning("Livro de ofertas não disponível para " + symbol);
      }
      return false;
   }
   
   // Registrar a atualização
   if(m_logger != NULL) {
      m_logger.Debug("Profundidade de mercado atualizada para " + symbol);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Criar handles de indicadores                                     |
//+------------------------------------------------------------------+
bool CMarketContext::CreateIndicatorHandles() {
   // Liberar handles existentes primeiro
   ReleaseIndicatorHandles();
   
   // Verificar se há barras suficientes
   int bars = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
   if(bars < m_minRequiredBars) {
      if(m_logger != NULL) {
         m_logger.Warning("Histórico insuficiente para " + m_symbol + ", handles não serão criados agora");
      }
      return false;
   }
   
   // Criar handles para o timeframe principal
   m_ema9Handle = iMA(m_symbol, m_timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
   m_ema21Handle = iMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
   m_ema50Handle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   m_ema200Handle = iMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
   m_rsiHandle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
   m_atrHandle = iATR(m_symbol, m_timeframe, 14);
   m_macdHandle = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
   m_stochHandle = iStochastic(m_symbol, m_timeframe, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   m_bollingerHandle = iBands(m_symbol, m_timeframe, 20, 2, 0, PRICE_CLOSE);
   
   // Verificar se todos os handles foram criados com sucesso
   bool allHandlesValid = (m_ema9Handle != INVALID_HANDLE && 
                          m_ema21Handle != INVALID_HANDLE && 
                          m_ema50Handle != INVALID_HANDLE && 
                          m_ema200Handle != INVALID_HANDLE && 
                          m_rsiHandle != INVALID_HANDLE && 
                          m_atrHandle != INVALID_HANDLE && 
                          m_macdHandle != INVALID_HANDLE && 
                          m_stochHandle != INVALID_HANDLE && 
                          m_bollingerHandle != INVALID_HANDLE);
   
   if(!allHandlesValid && m_logger != NULL) {
      m_logger.Error("Falha ao criar um ou mais handles de indicadores para " + m_symbol);
   }
   
   return allHandlesValid;
}

//+------------------------------------------------------------------+
//| Criar handles para timeframes adicionais                         |
//+------------------------------------------------------------------+
bool CMarketContext::CreateTimeframeHandles() {
   bool allHandlesValid = true;
   
   // Criar handles para cada timeframe adicional
   for(int i = 1; i < 4; i++) {  // Começar de 1 pois 0 é o timeframe principal
      ENUM_TIMEFRAMES tf = m_timeframes[i];
      
      // Verificar se há barras suficientes
      int bars = (int)SeriesInfoInteger(m_symbol, tf, SERIES_BARS_COUNT);
      if(bars < m_minRequiredBars) {
         if(m_logger != NULL) {
            m_logger.Warning("Histórico insuficiente para " + m_symbol + " em " + 
                           EnumToString(tf) + ", handles não serão criados");
         }
         continue;
      }
      
      // Criar handles
      m_ema9Handles[i] = iMA(m_symbol, tf, 9, 0, MODE_EMA, PRICE_CLOSE);
      m_ema21Handles[i] = iMA(m_symbol, tf, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_ema50Handles[i] = iMA(m_symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200Handles[i] = iMA(m_symbol, tf, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_rsiHandles[i] = iRSI(m_symbol, tf, 14, PRICE_CLOSE);
      m_atrHandles[i] = iATR(m_symbol, tf, 14);
      m_macdHandles[i] = iMACD(m_symbol, tf, 12, 26, 9, PRICE_CLOSE);
      m_stochHandles[i] = iStochastic(m_symbol, tf, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
      m_bollingerHandles[i] = iBands(m_symbol, tf, 20, 2, 0, PRICE_CLOSE);
      
      // Verificar se todos os handles foram criados com sucesso
      bool tfHandlesValid = (m_ema9Handles[i] != INVALID_HANDLE && 
                            m_ema21Handles[i] != INVALID_HANDLE && 
                            m_ema50Handles[i] != INVALID_HANDLE && 
                            m_ema200Handles[i] != INVALID_HANDLE && 
                            m_rsiHandles[i] != INVALID_HANDLE && 
                            m_atrHandles[i] != INVALID_HANDLE && 
                            m_macdHandles[i] != INVALID_HANDLE && 
                            m_stochHandles[i] != INVALID_HANDLE && 
                            m_bollingerHandles[i] != INVALID_HANDLE);
      
      if(!tfHandlesValid && m_logger != NULL) {
         m_logger.Warning("Falha ao criar um ou mais handles para " + m_symbol + " em " + EnumToString(tf));
      }
      
      allHandlesValid = allHandlesValid && tfHandlesValid;
   }
   
   return allHandlesValid;
}

//+------------------------------------------------------------------+
//| Liberar handles de indicadores                                   |
//+------------------------------------------------------------------+
void CMarketContext::ReleaseIndicatorHandles() {
   // Liberar handles do timeframe principal
   if(m_ema9Handle != INVALID_HANDLE) { IndicatorRelease(m_ema9Handle); m_ema9Handle = INVALID_HANDLE; }
   if(m_ema21Handle != INVALID_HANDLE) { IndicatorRelease(m_ema21Handle); m_ema21Handle = INVALID_HANDLE; }
   if(m_ema50Handle != INVALID_HANDLE) { IndicatorRelease(m_ema50Handle); m_ema50Handle = INVALID_HANDLE; }
   if(m_ema200Handle != INVALID_HANDLE) { IndicatorRelease(m_ema200Handle); m_ema200Handle = INVALID_HANDLE; }
   if(m_rsiHandle != INVALID_HANDLE) { IndicatorRelease(m_rsiHandle); m_rsiHandle = INVALID_HANDLE; }
   if(m_atrHandle != INVALID_HANDLE) { IndicatorRelease(m_atrHandle); m_atrHandle = INVALID_HANDLE; }
   if(m_macdHandle != INVALID_HANDLE) { IndicatorRelease(m_macdHandle); m_macdHandle = INVALID_HANDLE; }
   if(m_stochHandle != INVALID_HANDLE) { IndicatorRelease(m_stochHandle); m_stochHandle = INVALID_HANDLE; }
   if(m_bollingerHandle != INVALID_HANDLE) { IndicatorRelease(m_bollingerHandle); m_bollingerHandle = INVALID_HANDLE; }
   
   // Liberar handles dos timeframes adicionais
   for(int i = 1; i < 4; i++) {
      if(m_ema9Handles[i] != INVALID_HANDLE) { IndicatorRelease(m_ema9Handles[i]); m_ema9Handles[i] = INVALID_HANDLE; }
      if(m_ema21Handles[i] != INVALID_HANDLE) { IndicatorRelease(m_ema21Handles[i]); m_ema21Handles[i] = INVALID_HANDLE; }
      if(m_ema50Handles[i] != INVALID_HANDLE) { IndicatorRelease(m_ema50Handles[i]); m_ema50Handles[i] = INVALID_HANDLE; }
      if(m_ema200Handles[i] != INVALID_HANDLE) { IndicatorRelease(m_ema200Handles[i]); m_ema200Handles[i] = INVALID_HANDLE; }
      if(m_rsiHandles[i] != INVALID_HANDLE) { IndicatorRelease(m_rsiHandles[i]); m_rsiHandles[i] = INVALID_HANDLE; }
      if(m_atrHandles[i] != INVALID_HANDLE) { IndicatorRelease(m_atrHandles[i]); m_atrHandles[i] = INVALID_HANDLE; }
      if(m_macdHandles[i] != INVALID_HANDLE) { IndicatorRelease(m_macdHandles[i]); m_macdHandles[i] = INVALID_HANDLE; }
      if(m_stochHandles[i] != INVALID_HANDLE) { IndicatorRelease(m_stochHandles[i]); m_stochHandles[i] = INVALID_HANDLE; }
      if(m_bollingerHandles[i] != INVALID_HANDLE) { IndicatorRelease(m_bollingerHandles[i]); m_bollingerHandles[i] = INVALID_HANDLE; }
   }
}

//+------------------------------------------------------------------+
//| Obter handle de indicador para o timeframe especificado          |
//+------------------------------------------------------------------+
int CMarketContext::GetIndicatorHandle(int baseHandle, ENUM_TIMEFRAMES timeframe) {
   // Se o timeframe for o principal, retornar o handle base
   if(timeframe == m_timeframe || timeframe == PERIOD_CURRENT) {
      return baseHandle;
   }
   
   // Caso contrário, encontrar o índice do timeframe
   for(int i = 0; i < 4; i++) {
      if(m_timeframes[i] == timeframe) {
         // Determinar qual array de handles usar
         if(baseHandle == m_ema9Handle) return m_ema9Handles[i];
         if(baseHandle == m_ema21Handle) return m_ema21Handles[i];
         if(baseHandle == m_ema50Handle) return m_ema50Handles[i];
         if(baseHandle == m_ema200Handle) return m_ema200Handles[i];
         if(baseHandle == m_rsiHandle) return m_rsiHandles[i];
         if(baseHandle == m_atrHandle) return m_atrHandles[i];
         if(baseHandle == m_macdHandle) return m_macdHandles[i];
         if(baseHandle == m_stochHandle) return m_stochHandles[i];
         if(baseHandle == m_bollingerHandle) return m_bollingerHandles[i];
      }
   }
   
   // Se não encontrar, retornar handle inválido
   return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Verificar se há dados suficientes para análise                   |
//+------------------------------------------------------------------+
bool CMarketContext::CheckDataValidity() {
   // Verificar se há barras suficientes
   int bars = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
   if(bars < m_minRequiredBars) {
      if(m_logger != NULL) {
         m_logger.Warning("Histórico insuficiente para " + m_symbol + ": " + 
                        IntegerToString(bars) + " barras (mínimo: " + 
                        IntegerToString(m_minRequiredBars) + ")");
      }
      return false;
   }
   
   // Verificar se os handles são válidos
   if(m_ema9Handle == INVALID_HANDLE || m_ema21Handle == INVALID_HANDLE || 
      m_ema50Handle == INVALID_HANDLE || m_ema200Handle == INVALID_HANDLE || 
      m_rsiHandle == INVALID_HANDLE || m_atrHandle == INVALID_HANDLE || 
      m_macdHandle == INVALID_HANDLE || m_stochHandle == INVALID_HANDLE || 
      m_bollingerHandle == INVALID_HANDLE) {
      if(m_logger != NULL) {
         m_logger.Warning("Um ou mais handles de indicadores são inválidos para " + m_symbol);
      }
      return false;
   }
   
   // Verificar se os buffers dos indicadores têm dados suficientes
   double buffer[];
   if(CopyBuffer(m_ema200Handle, 0, 0, 1, buffer) <= 0) {
      if(m_logger != NULL) {
         m_logger.Warning("Dados de indicadores insuficientes para " + m_symbol);
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Detectar fase de mercado                                         |
//+------------------------------------------------------------------+
MARKET_PHASE CMarketContext::DetectPhase() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return PHASE_UNDEFINED;
   }
   
   // Verificar tendência
   if(IsTrend()) {
      return PHASE_TREND;
   }
   
   // Verificar range
   if(IsRange()) {
      return PHASE_RANGE;
   }
   
   // Verificar reversão
   if(IsReversal()) {
      return PHASE_REVERSAL;
   }
   
   // Se não for nenhuma das fases acima, considerar como indefinida
   return PHASE_UNDEFINED;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência                         |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrend(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   // Verificar alinhamento das médias móveis
   if(!CheckMovingAveragesAlignment(timeframe)) {
      return false;
   }
   
   // Verificar momentum
   if(!CheckMomentum(timeframe)) {
      return false;
   }
   
   // Verificar RSI
   double rsiBuffer[];
   int rsiHandle = GetIndicatorHandle(m_rsiHandle, timeframe);
   
   if(rsiHandle == INVALID_HANDLE || CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) <= 0) {
      return false;
   }
   
   // RSI deve estar acima de 60 para tendência de alta ou abaixo de 40 para tendência de baixa
   double rsi = rsiBuffer[0];
   int trendDirection = CheckTrendDirection();
   
   if(trendDirection > 0 && rsi < 60) {
      return false;
   }
   
   if(trendDirection < 0 && rsi > 40) {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em range                             |
//+------------------------------------------------------------------+
bool CMarketContext::IsRange(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   // Verificar se as médias móveis estão próximas
   double ema9Buffer[], ema21Buffer[], ema50Buffer[];
   int ema9Handle = GetIndicatorHandle(m_ema9Handle, timeframe);
   int ema21Handle = GetIndicatorHandle(m_ema21Handle, timeframe);
   int ema50Handle = GetIndicatorHandle(m_ema50Handle, timeframe);
   
   if(ema9Handle == INVALID_HANDLE || ema21Handle == INVALID_HANDLE || ema50Handle == INVALID_HANDLE ||
      CopyBuffer(ema9Handle, 0, 0, 3, ema9Buffer) <= 0 ||
      CopyBuffer(ema21Handle, 0, 0, 3, ema21Buffer) <= 0 ||
      CopyBuffer(ema50Handle, 0, 0, 3, ema50Buffer) <= 0) {
      return false;
   }
   
   // Calcular a distância entre as médias
   double distance1 = MathAbs(ema9Buffer[0] - ema21Buffer[0]);
   double distance2 = MathAbs(ema21Buffer[0] - ema50Buffer[0]);
   
   // Obter ATR para normalizar a distância
   double atrBuffer[];
   int atrHandle = GetIndicatorHandle(m_atrHandle, timeframe);
   
   if(atrHandle == INVALID_HANDLE || CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
      return false;
   }
   
   double atr = atrBuffer[0];
   double normalizedDistance1 = distance1 / atr;
   double normalizedDistance2 = distance2 / atr;
   
   // Verificar se as médias estão próximas (distância menor que 0.5 * ATR)
   if(normalizedDistance1 > 0.5 || normalizedDistance2 > 1.0) {
      return false;
   }
   
   // Verificar RSI
   double rsiBuffer[];
   int rsiHandle = GetIndicatorHandle(m_rsiHandle, timeframe);
   
   if(rsiHandle == INVALID_HANDLE || CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) <= 0) {
      return false;
   }
   
   // RSI deve estar entre 40 e 60 para range
   double rsi = rsiBuffer[0];
   if(rsi < 40 || rsi > 60) {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em reversão                          |
//+------------------------------------------------------------------+
bool CMarketContext::IsReversal(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   // Verificar divergência no RSI
   double rsiBuffer[];
   double closeBuffer[];
   int rsiHandle = GetIndicatorHandle(m_rsiHandle, timeframe);
   
   if(rsiHandle == INVALID_HANDLE || CopyBuffer(rsiHandle, 0, 0, 10, rsiBuffer) <= 0 ||
      CopyClose(m_symbol, timeframe, 0, 10, closeBuffer) <= 0) {
      return false;
   }
   
   // Verificar divergência de alta (preço em baixa, RSI em alta)
   bool bullishDivergence = false;
   if(closeBuffer[0] < closeBuffer[5] && rsiBuffer[0] > rsiBuffer[5]) {
      bullishDivergence = true;
   }
   
   // Verificar divergência de baixa (preço em alta, RSI em baixa)
   bool bearishDivergence = false;
   if(closeBuffer[0] > closeBuffer[5] && rsiBuffer[0] < rsiBuffer[5]) {
      bearishDivergence = true;
   }
   
   // Verificar condições de sobrecompra/sobrevenda
   bool oversold = rsiBuffer[0] < 30;
   bool overbought = rsiBuffer[0] > 70;
   
   // Verificar cruzamento de médias móveis
   double ema9Buffer[], ema21Buffer[];
   int ema9Handle = GetIndicatorHandle(m_ema9Handle, timeframe);
   int ema21Handle = GetIndicatorHandle(m_ema21Handle, timeframe);
   
   if(ema9Handle == INVALID_HANDLE || ema21Handle == INVALID_HANDLE ||
      CopyBuffer(ema9Handle, 0, 0, 3, ema9Buffer) <= 0 ||
      CopyBuffer(ema21Handle, 0, 0, 3, ema21Buffer) <= 0) {
      return false;
   }
   
   bool crossUp = ema9Buffer[1] < ema21Buffer[1] && ema9Buffer[0] > ema21Buffer[0];
   bool crossDown = ema9Buffer[1] > ema21Buffer[1] && ema9Buffer[0] < ema21Buffer[0];
   
   // Combinar condições para reversão
   if((bullishDivergence && oversold) || (bearishDivergence && overbought) || crossUp || crossDown) {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar alinhamento das médias móveis                          |
//+------------------------------------------------------------------+
bool CMarketContext::CheckMovingAveragesAlignment(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   double ema9Buffer[], ema21Buffer[], ema50Buffer[], ema200Buffer[];
   int ema9Handle = GetIndicatorHandle(m_ema9Handle, timeframe);
   int ema21Handle = GetIndicatorHandle(m_ema21Handle, timeframe);
   int ema50Handle = GetIndicatorHandle(m_ema50Handle, timeframe);
   int ema200Handle = GetIndicatorHandle(m_ema200Handle, timeframe);
   
   if(ema9Handle == INVALID_HANDLE || ema21Handle == INVALID_HANDLE || 
      ema50Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE ||
      CopyBuffer(ema9Handle, 0, 0, 1, ema9Buffer) <= 0 ||
      CopyBuffer(ema21Handle, 0, 0, 1, ema21Buffer) <= 0 ||
      CopyBuffer(ema50Handle, 0, 0, 1, ema50Buffer) <= 0 ||
      CopyBuffer(ema200Handle, 0, 0, 1, ema200Buffer) <= 0) {
      return false;
   }
   
   // Verificar alinhamento para tendência de alta
   if(ema9Buffer[0] > ema21Buffer[0] && ema21Buffer[0] > ema50Buffer[0] && ema50Buffer[0] > ema200Buffer[0]) {
      return true;
   }
   
   // Verificar alinhamento para tendência de baixa
   if(ema9Buffer[0] < ema21Buffer[0] && ema21Buffer[0] < ema50Buffer[0] && ema50Buffer[0] < ema200Buffer[0]) {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar momentum                                               |
//+------------------------------------------------------------------+
bool CMarketContext::CheckMomentum(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   double macdBuffer[], signalBuffer[];
   int macdHandle = GetIndicatorHandle(m_macdHandle, timeframe);
   
   if(macdHandle == INVALID_HANDLE || 
      CopyBuffer(macdHandle, 0, 0, 3, macdBuffer) <= 0 ||
      CopyBuffer(macdHandle, 1, 0, 3, signalBuffer) <= 0) {
      return false;
   }
   
   // Verificar se MACD está acima da linha de sinal para tendência de alta
   if(macdBuffer[0] > signalBuffer[0] && macdBuffer[0] > 0) {
      return true;
   }
   
   // Verificar se MACD está abaixo da linha de sinal para tendência de baixa
   if(macdBuffer[0] < signalBuffer[0] && macdBuffer[0] < 0) {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência de alta                 |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrendUp() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   // Verificar se está em tendência
   if(!IsTrend()) {
      return false;
   }
   
   // Verificar direção da tendência
   return CheckTrendDirection() > 0;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência de baixa                |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrendDown() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   // Verificar se está em tendência
   if(!IsTrend()) {
      return false;
   }
   
   // Verificar direção da tendência
   return CheckTrendDirection() < 0;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em range                             |
//+------------------------------------------------------------------+
bool CMarketContext::IsInRange() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   return IsRange();
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em reversão                          |
//+------------------------------------------------------------------+
bool CMarketContext::IsInReversal() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   return IsReversal();
}

//+------------------------------------------------------------------+
//| Encontrar suporte mais próximo                                   |
//+------------------------------------------------------------------+
double CMarketContext::FindNearestSupport(double price, int lookbackBars = 50) {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return 0.0;
   }
   
   double lowBuffer[];
   if(CopyLow(m_symbol, m_timeframe, 0, lookbackBars, lowBuffer) <= 0) {
      return 0.0;
   }
   
   double support = 0.0;
   double minDistance = DBL_MAX;
   
   // Encontrar mínimos locais
   for(int i = 2; i < lookbackBars - 2; i++) {
      if(lowBuffer[i] < lowBuffer[i-1] && lowBuffer[i] < lowBuffer[i-2] &&
         lowBuffer[i] < lowBuffer[i+1] && lowBuffer[i] < lowBuffer[i+2]) {
         
         // Verificar se é o suporte mais próximo abaixo do preço atual
         if(lowBuffer[i] < price && price - lowBuffer[i] < minDistance) {
            minDistance = price - lowBuffer[i];
            support = lowBuffer[i];
         }
      }
   }
   
   return support;
}

//+------------------------------------------------------------------+
//| Encontrar resistência mais próxima                               |
//+------------------------------------------------------------------+
double CMarketContext::FindNearestResistance(double price, int lookbackBars = 50) {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return 0.0;
   }
   
   double highBuffer[];
   if(CopyHigh(m_symbol, m_timeframe, 0, lookbackBars, highBuffer) <= 0) {
      return 0.0;
   }
   
   double resistance = 0.0;
   double minDistance = DBL_MAX;
   
   // Encontrar máximos locais
   for(int i = 2; i < lookbackBars - 2; i++) {
      if(highBuffer[i] > highBuffer[i-1] && highBuffer[i] > highBuffer[i-2] &&
         highBuffer[i] > highBuffer[i+1] && highBuffer[i] > highBuffer[i+2]) {
         
         // Verificar se é a resistência mais próxima acima do preço atual
         if(highBuffer[i] > price && highBuffer[i] - price < minDistance) {
            minDistance = highBuffer[i] - price;
            resistance = highBuffer[i];
         }
      }
   }
   
   return resistance;
}

//+------------------------------------------------------------------+
//| Obter valor do ATR                                               |
//+------------------------------------------------------------------+
double CMarketContext::GetATR(int period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return 0.0;
   }
   
   double atrBuffer[];
   int atrHandle = GetIndicatorHandle(m_atrHandle, timeframe);
   
   if(atrHandle == INVALID_HANDLE || CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
      return 0.0;
   }
   
   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Obter razão de volatilidade                                      |
//+------------------------------------------------------------------+
double CMarketContext::GetVolatilityRatio() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return 0.0;
   }
   
   double atrBuffer[];
   if(CopyBuffer(m_atrHandle, 0, 0, 20, atrBuffer) <= 0) {
      return 0.0;
   }
   
   double currentATR = atrBuffer[0];
   double avgATR = 0.0;
   
   // Calcular média do ATR dos últimos 20 períodos
   for(int i = 0; i < 20; i++) {
      avgATR += atrBuffer[i];
   }
   avgATR /= 20;
   
   // Calcular razão de volatilidade
   if(avgATR > 0) {
      return currentATR / avgATR;
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Obter força da tendência                                         |
//+------------------------------------------------------------------+
double CMarketContext::GetTrendStrength() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return 0.0;
   }
   
   // Verificar direção da tendência
   int direction = CheckTrendDirection();
   if(direction == 0) {
      return 0.0;
   }
   
   // Obter valores de indicadores
   double rsiBuffer[];
   double macdBuffer[];
   
   if(CopyBuffer(m_rsiHandle, 0, 0, 1, rsiBuffer) <= 0 ||
      CopyBuffer(m_macdHandle, 0, 0, 1, macdBuffer) <= 0) {
      return 0.0;
   }
   
   double rsi = rsiBuffer[0];
   double macd = macdBuffer[0];
   
   // Calcular força da tendência
   double strength = 0.0;
   
   if(direction > 0) {  // Tendência de alta
      strength = (rsi - 50) / 50.0;  // Normalizar RSI para 0-1
      strength += MathAbs(macd) / 100.0;  // Adicionar contribuição do MACD
   } else {  // Tendência de baixa
      strength = (50 - rsi) / 50.0;  // Normalizar RSI para 0-1
      strength += MathAbs(macd) / 100.0;  // Adicionar contribuição do MACD
   }
   
   // Normalizar para 0-1
   strength = MathMin(strength / 2.0, 1.0);
   
   return strength;
}

//+------------------------------------------------------------------+
//| Verificar se o preço está acima da EMA                           |
//+------------------------------------------------------------------+
bool CMarketContext::IsPriceAboveEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   // Selecionar handle correto
   int emaHandle = INVALID_HANDLE;
   switch(emaPeriod) {
      case 9:
         emaHandle = GetIndicatorHandle(m_ema9Handle, timeframe);
         break;
      case 21:
         emaHandle = GetIndicatorHandle(m_ema21Handle, timeframe);
         break;
      case 50:
         emaHandle = GetIndicatorHandle(m_ema50Handle, timeframe);
         break;
      case 200:
         emaHandle = GetIndicatorHandle(m_ema200Handle, timeframe);
         break;
      default:
         return false;
   }
   
   if(emaHandle == INVALID_HANDLE) {
      return false;
   }
   
   // Obter valores
   double emaBuffer[];
   double closeBuffer[];
   
   if(CopyBuffer(emaHandle, 0, 0, 1, emaBuffer) <= 0 ||
      CopyClose(m_symbol, timeframe, 0, 1, closeBuffer) <= 0) {
      return false;
   }
   
   return closeBuffer[0] > emaBuffer[0];
}

//+------------------------------------------------------------------+
//| Verificar se o preço está abaixo da EMA                          |
//+------------------------------------------------------------------+
bool CMarketContext::IsPriceBelowEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return false;
   }
   
   // Selecionar handle correto
   int emaHandle = INVALID_HANDLE;
   switch(emaPeriod) {
      case 9:
         emaHandle = GetIndicatorHandle(m_ema9Handle, timeframe);
         break;
      case 21:
         emaHandle = GetIndicatorHandle(m_ema21Handle, timeframe);
         break;
      case 50:
         emaHandle = GetIndicatorHandle(m_ema50Handle, timeframe);
         break;
      case 200:
         emaHandle = GetIndicatorHandle(m_ema200Handle, timeframe);
         break;
      default:
         return false;
   }
   
   if(emaHandle == INVALID_HANDLE) {
      return false;
   }
   
   // Obter valores
   double emaBuffer[];
   double closeBuffer[];
   
   if(CopyBuffer(emaHandle, 0, 0, 1, emaBuffer) <= 0 ||
      CopyClose(m_symbol, timeframe, 0, 1, closeBuffer) <= 0) {
      return false;
   }
   
   return closeBuffer[0] < emaBuffer[0];
}

//+------------------------------------------------------------------+
//| Verificar direção da tendência                                   |
//+------------------------------------------------------------------+
int CMarketContext::CheckTrendDirection() {
   // Verificar se os dados são válidos
   if(!m_hasValidData) {
      return 0;
   }
   
   // Obter valores das médias móveis
   double ema9Buffer[], ema21Buffer[], ema50Buffer[];
   
   if(CopyBuffer(m_ema9Handle, 0, 0, 1, ema9Buffer) <= 0 ||
      CopyBuffer(m_ema21Handle, 0, 0, 1, ema21Buffer) <= 0 ||
      CopyBuffer(m_ema50Handle, 0, 0, 1, ema50Buffer) <= 0) {
      return 0;
   }
   
   // Verificar tendência de alta
   if(ema9Buffer[0] > ema21Buffer[0] && ema21Buffer[0] > ema50Buffer[0]) {
      return 1;  // Tendência de alta
   }
   
   // Verificar tendência de baixa
   if(ema9Buffer[0] < ema21Buffer[0] && ema21Buffer[0] < ema50Buffer[0]) {
      return -1;  // Tendência de baixa
   }
   
   return 0;  // Sem tendência definida
}
//+------------------------------------------------------------------+


#endif // MARKETCONTEXT_MQH_
