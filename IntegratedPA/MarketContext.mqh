//+------------------------------------------------------------------+
//|                                             MarketContext.mqh |
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
//| Classe para análise de contexto de mercado                        |
//+------------------------------------------------------------------+
class CMarketContext {
private:
   string m_symbol;                  // Símbolo atual
   ENUM_TIMEFRAMES m_timeframe;      // Timeframe principal
   CLogger* m_logger;                // Ponteiro para o logger
   CIndicatorManager* m_indicatorManager; // Ponteiro para o gerenciador de indicadores
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
   
   // Configurações
   int m_minRequiredBars;
   
   // Métodos privados
   bool CreateIndicatorHandles();
   bool CreateTimeframeHandles();
   void ReleaseIndicatorHandles();
   bool CheckDataValidity();
   double GetIndicatorValue(int handle, int buffer, int index);
   bool IsIndicatorReady(int handle, int minBars = 50);
   int GetIndicatorHandle(int mainHandle, ENUM_TIMEFRAMES timeframe);
   
   // Métodos de análise privados
   bool IsTrend(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool IsRange(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool IsReversal(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool CheckMovingAveragesAlignment(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool CheckMomentum(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   
public:
   // Construtor e destrutor
   CMarketContext();
   ~CMarketContext();
   
   // Métodos de inicialização
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CLogger* logger = NULL, bool checkHistory = true, CIndicatorManager* indicatorManager = NULL);
   bool UpdateSymbol(string symbol);
   void UpdateMarketDepth(string symbol);
   
   // Métodos de análise
   MARKET_PHASE DetermineMarketPhase();
   MARKET_PHASE GetCurrentPhase() { return m_currentPhase; }
   bool IsMarketOpen();
   bool HasValidData() { return m_hasValidData; }
   
   // Métodos de indicadores
   double GetEMAValue(int period, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   double GetRSIValue(int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   double GetATRValue(int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   double GetMACDValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   double GetStochasticValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   double GetBollingerValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   
   // Métodos de análise de tendência
   double GetTrendStrength();
   bool IsPriceAboveEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool IsPriceBelowEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   int CheckTrendDirection();
   
   // Métodos de análise de mercado - FUNÇÕES QUE ESTAVAM FALTANDO
   bool IsTrendUp();
   bool IsTrendDown();
   bool IsInRange();
   bool IsInReversal();
   double FindNearestSupport(double price, int lookbackBars = 50);
   double FindNearestResistance(double price, int lookbackBars = 50);
   double GetATR(int period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   double GetVolatilityRatio();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CMarketContext::CMarketContext() {
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_logger = NULL;
   m_indicatorManager = NULL; // Inicializar como NULL
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
bool CMarketContext::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CLogger* logger = NULL, bool checkHistory = true, CIndicatorManager* indicatorManager = NULL) {
   // Liberar handles existentes
   ReleaseIndicatorHandles();
   
   // Configurar parâmetros básicos
   m_indicatorManager = indicatorManager;
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_logger = logger;
   m_currentPhase = PHASE_UNDEFINED;
   m_hasValidData = false;
   
   // Verificar se o IndicatorManager foi fornecido
   if(m_indicatorManager == NULL) {
      if(m_logger != NULL) {
         m_logger.Warning("IndicatorManager não fornecido para " + m_symbol + ", handles não serão criados");
      }
      return true; // Continuar sem handles
   }
   
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
//| Criar handles de indicadores                                     |
//+------------------------------------------------------------------+
bool CMarketContext::CreateIndicatorHandles() {
   // Liberar handles existentes primeiro
   ReleaseIndicatorHandles();
   
   // VERIFICAÇÃO DE SEGURANÇA: Verificar se o IndicatorManager está disponível
   if(m_indicatorManager == NULL) {
      if(m_logger != NULL) {
         m_logger.Warning("IndicatorManager não disponível para criar handles de " + m_symbol);
      }
      return false;
   }
   
   // Verificar se há barras suficientes
   int bars = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
   if(bars < m_minRequiredBars) {
      if(m_logger != NULL) {
         m_logger.Warning("Histórico insuficiente para " + m_symbol + ", handles não serão criados agora");
      }
      return false;
   }
   
   // Criar handles para o timeframe principal usando o IndicatorManager
   m_ema9Handle = m_indicatorManager.GetMA(m_symbol, m_timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
   m_ema21Handle = m_indicatorManager.GetMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
   m_ema50Handle = m_indicatorManager.GetMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   m_ema200Handle = m_indicatorManager.GetMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
   m_rsiHandle = m_indicatorManager.GetRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
   m_atrHandle = m_indicatorManager.GetATR(m_symbol, m_timeframe, 14);
   m_macdHandle = m_indicatorManager.GetMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
   m_stochHandle = m_indicatorManager.GetStochastic(m_symbol, m_timeframe, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   m_bollingerHandle = m_indicatorManager.GetBollinger(m_symbol, m_timeframe, 20, 2, PRICE_CLOSE);
   
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
   // VERIFICAÇÃO DE SEGURANÇA: Verificar se o IndicatorManager está disponível
   if(m_indicatorManager == NULL) {
      if(m_logger != NULL) {
         m_logger.Warning("IndicatorManager não disponível para criar handles de timeframes adicionais");
      }
      return false;
   }
   
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
      
      // Criar handles usando o IndicatorManager
      m_ema9Handles[i] = m_indicatorManager.GetMA(m_symbol, tf, 9, 0, MODE_EMA, PRICE_CLOSE);
      m_ema21Handles[i] = m_indicatorManager.GetMA(m_symbol, tf, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_ema50Handles[i] = m_indicatorManager.GetMA(m_symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_ema200Handles[i] = m_indicatorManager.GetMA(m_symbol, tf, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_rsiHandles[i] = m_indicatorManager.GetRSI(m_symbol, tf, 14, PRICE_CLOSE);
      m_atrHandles[i] = m_indicatorManager.GetATR(m_symbol, tf, 14);
      m_macdHandles[i] = m_indicatorManager.GetMACD(m_symbol, tf, 12, 26, 9, PRICE_CLOSE);
      m_stochHandles[i] = m_indicatorManager.GetStochastic(m_symbol, tf, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
      m_bollingerHandles[i] = m_indicatorManager.GetBollinger(m_symbol, tf, 20, 2, PRICE_CLOSE);
      
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
   // NOTA: Com o IndicatorManager, não precisamos liberar handles manualmente
   // O IndicatorManager gerencia automaticamente os handles
   
   // Apenas resetar as variáveis locais
   m_ema9Handle = INVALID_HANDLE;
   m_ema21Handle = INVALID_HANDLE;
   m_ema50Handle = INVALID_HANDLE;
   m_ema200Handle = INVALID_HANDLE;
   m_rsiHandle = INVALID_HANDLE;
   m_atrHandle = INVALID_HANDLE;
   m_macdHandle = INVALID_HANDLE;
   m_stochHandle = INVALID_HANDLE;
   m_bollingerHandle = INVALID_HANDLE;
   
   // Resetar arrays de handles
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
//| Verificar se os dados são válidos                                |
//+------------------------------------------------------------------+
bool CMarketContext::CheckDataValidity() {
   // Verificar se há barras suficientes
   int bars = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
   if(bars < m_minRequiredBars) {
      return false;
   }
   
   // Verificar se pelo menos alguns indicadores estão prontos
   if(m_ema9Handle != INVALID_HANDLE && IsIndicatorReady(m_ema9Handle)) {
      return true;
   }
   
   if(m_ema21Handle != INVALID_HANDLE && IsIndicatorReady(m_ema21Handle)) {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar se um indicador está pronto                            |
//+------------------------------------------------------------------+
bool CMarketContext::IsIndicatorReady(int handle, int minBars = 50) {
   if(handle == INVALID_HANDLE) {
      return false;
   }
   
   return (BarsCalculated(handle) >= minBars);
}

//+------------------------------------------------------------------+
//| Obter valor de indicador com verificação de segurança            |
//+------------------------------------------------------------------+
double CMarketContext::GetIndicatorValue(int handle, int buffer, int index) {
   if(handle == INVALID_HANDLE) {
      return EMPTY_VALUE;
   }
   
   if(!IsIndicatorReady(handle)) {
      return EMPTY_VALUE;
   }
   
   double value[];
   if(CopyBuffer(handle, buffer, index, 1, value) <= 0) {
      return EMPTY_VALUE;
   }
   
   return value[0];
}

//+------------------------------------------------------------------+
//| Obter handle de indicador para timeframe específico              |
//+------------------------------------------------------------------+
int CMarketContext::GetIndicatorHandle(int mainHandle, ENUM_TIMEFRAMES timeframe) {
   if(timeframe == PERIOD_CURRENT || timeframe == m_timeframe) {
      return mainHandle;
   }
   
   // Para timeframes diferentes, seria necessário implementar lógica adicional
   // Por enquanto, retornar o handle principal
   return mainHandle;
}

//+------------------------------------------------------------------+
//| Atualizar símbolo                                                |
//+------------------------------------------------------------------+
bool CMarketContext::UpdateSymbol(string symbol) {
   if(m_symbol != symbol) {
      // Símbolo mudou, reinicializar
      return Initialize(symbol, m_timeframe, m_logger, true, m_indicatorManager);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Atualizar profundidade de mercado                                |
//+------------------------------------------------------------------+
void CMarketContext::UpdateMarketDepth(string symbol) {
   // Implementação básica - pode ser expandida conforme necessário
   if(m_logger != NULL) {
      m_logger.Debug("Atualizando profundidade de mercado para " + symbol);
   }
}

//+------------------------------------------------------------------+
//| Determinar fase de mercado                                       |
//+------------------------------------------------------------------+
MARKET_PHASE CMarketContext::DetermineMarketPhase() {
   if(!m_hasValidData) {
      return PHASE_UNDEFINED;
   }
   
   // Verificar tendência
   if(IsTrend()) {
      m_currentPhase = PHASE_TREND;
      return m_currentPhase;
   }
   
   // Verificar range
   if(IsRange()) {
      m_currentPhase = PHASE_RANGE;
      return m_currentPhase;
   }
   
   // Verificar reversão
   if(IsReversal()) {
      m_currentPhase = PHASE_REVERSAL;
      return m_currentPhase;
   }
   
   // Se não for nenhuma das fases acima, considerar como indefinida
   m_currentPhase = PHASE_UNDEFINED;
   return m_currentPhase;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está aberto                               |
//+------------------------------------------------------------------+
bool CMarketContext::IsMarketOpen() {
   return (SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL);
}

//+------------------------------------------------------------------+
//| Obter valor de EMA                                               |
//+------------------------------------------------------------------+
double CMarketContext::GetEMAValue(int period, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   int handle = INVALID_HANDLE;
   
   // Determinar qual handle usar baseado no período
   if(timeframe == PERIOD_CURRENT || timeframe == m_timeframe) {
      switch(period) {
         case 9: handle = m_ema9Handle; break;
         case 21: handle = m_ema21Handle; break;
         case 50: handle = m_ema50Handle; break;
         case 200: handle = m_ema200Handle; break;
      }
   }
   
   return GetIndicatorValue(handle, 0, index);
}

//+------------------------------------------------------------------+
//| Obter valor de RSI                                               |
//+------------------------------------------------------------------+
double CMarketContext::GetRSIValue(int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   int handle = (timeframe == PERIOD_CURRENT || timeframe == m_timeframe) ? m_rsiHandle : INVALID_HANDLE;
   return GetIndicatorValue(handle, 0, index);
}

//+------------------------------------------------------------------+
//| Obter valor de ATR                                               |
//+------------------------------------------------------------------+
double CMarketContext::GetATRValue(int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   int handle = (timeframe == PERIOD_CURRENT || timeframe == m_timeframe) ? m_atrHandle : INVALID_HANDLE;
   return GetIndicatorValue(handle, 0, index);
}

//+------------------------------------------------------------------+
//| Obter valor de MACD                                              |
//+------------------------------------------------------------------+
double CMarketContext::GetMACDValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   int handle = (timeframe == PERIOD_CURRENT || timeframe == m_timeframe) ? m_macdHandle : INVALID_HANDLE;
   return GetIndicatorValue(handle, buffer, index);
}

//+------------------------------------------------------------------+
//| Obter valor de Stochastic                                        |
//+------------------------------------------------------------------+
double CMarketContext::GetStochasticValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   int handle = (timeframe == PERIOD_CURRENT || timeframe == m_timeframe) ? m_stochHandle : INVALID_HANDLE;
   return GetIndicatorValue(handle, buffer, index);
}

//+------------------------------------------------------------------+
//| Obter valor de Bollinger Bands                                   |
//+------------------------------------------------------------------+
double CMarketContext::GetBollingerValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   int handle = (timeframe == PERIOD_CURRENT || timeframe == m_timeframe) ? m_bollingerHandle : INVALID_HANDLE;
   return GetIndicatorValue(handle, buffer, index);
}

//+------------------------------------------------------------------+
//| Obter força da tendência                                         |
//+------------------------------------------------------------------+
double CMarketContext::GetTrendStrength() {
   double ema9 = GetEMAValue(9);
   double ema21 = GetEMAValue(21);
   double ema50 = GetEMAValue(50);
   
   if(ema9 == EMPTY_VALUE || ema21 == EMPTY_VALUE || ema50 == EMPTY_VALUE) {
      return 0.0;
   }
   
   // Calcular força da tendência baseada na separação das EMAs
   double separation = MathAbs(ema9 - ema50) / ema50;
   return separation * 100; // Retornar como percentual
}

//+------------------------------------------------------------------+
//| Verificar se preço está acima da EMA                             |
//+------------------------------------------------------------------+
bool CMarketContext::IsPriceAboveEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   double emaValue = GetEMAValue(emaPeriod, 0, timeframe);
   if(emaValue == EMPTY_VALUE) {
      return false;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   return (currentPrice > emaValue);
}

//+------------------------------------------------------------------+
//| Verificar se preço está abaixo da EMA                            |
//+------------------------------------------------------------------+
bool CMarketContext::IsPriceBelowEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   double emaValue = GetEMAValue(emaPeriod, 0, timeframe);
   if(emaValue == EMPTY_VALUE) {
      return false;
   }
   
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   return (currentPrice < emaValue);
}

//+------------------------------------------------------------------+
//| Verificar direção da tendência                                   |
//+------------------------------------------------------------------+
int CMarketContext::CheckTrendDirection() {
   double ema9 = GetEMAValue(9);
   double ema21 = GetEMAValue(21);
   double ema50 = GetEMAValue(50);
   
   if(ema9 == EMPTY_VALUE || ema21 == EMPTY_VALUE || ema50 == EMPTY_VALUE) {
      return 0; // Indefinido
   }
   
   if(ema9 > ema21 && ema21 > ema50) {
      return 1; // Tendência de alta
   }
   else if(ema9 < ema21 && ema21 < ema50) {
      return -1; // Tendência de baixa
   }
   
   return 0; // Sem tendência clara
}

//+------------------------------------------------------------------+
//| FUNÇÕES QUE ESTAVAM FALTANDO - IMPLEMENTAÇÃO COMPLETA           |
//+------------------------------------------------------------------+

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
   double rsi = GetRSIValue(0, timeframe);
   if(rsi == EMPTY_VALUE) {
      return false;
   }
   
   // RSI deve estar acima de 60 para tendência de alta ou abaixo de 40 para tendência de baixa
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
   double ema9 = GetEMAValue(9, 0, timeframe);
   double ema21 = GetEMAValue(21, 0, timeframe);
   double ema50 = GetEMAValue(50, 0, timeframe);
   
   if(ema9 == EMPTY_VALUE || ema21 == EMPTY_VALUE || ema50 == EMPTY_VALUE) {
      return false;
   }
   
   // Calcular a distância entre as médias
   double distance1 = MathAbs(ema9 - ema21);
   double distance2 = MathAbs(ema21 - ema50);
   
   // Obter ATR para normalizar a distância
   double atr = GetATRValue(0, timeframe);
   if(atr == EMPTY_VALUE || atr <= 0) {
      return false;
   }
   
   double normalizedDistance1 = distance1 / atr;
   double normalizedDistance2 = distance2 / atr;
   
   // Verificar se as médias estão próximas (distância menor que 0.5 * ATR)
   if(normalizedDistance1 > 0.5 || normalizedDistance2 > 1.0) {
      return false;
   }
   
   // Verificar RSI
   double rsi = GetRSIValue(0, timeframe);
   if(rsi == EMPTY_VALUE) {
      return false;
   }
   
   // RSI deve estar entre 40 e 60 para range
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
   
   if(CopyBuffer(m_rsiHandle, 0, 0, 10, rsiBuffer) <= 0 ||
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
   double ema9_0 = GetEMAValue(9, 0, timeframe);
   double ema9_1 = GetEMAValue(9, 1, timeframe);
   double ema21_0 = GetEMAValue(21, 0, timeframe);
   double ema21_1 = GetEMAValue(21, 1, timeframe);
   
   if(ema9_0 == EMPTY_VALUE || ema9_1 == EMPTY_VALUE || ema21_0 == EMPTY_VALUE || ema21_1 == EMPTY_VALUE) {
      return false;
   }
   
   bool crossUp = ema9_1 < ema21_1 && ema9_0 > ema21_0;
   bool crossDown = ema9_1 > ema21_1 && ema9_0 < ema21_0;
   
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
   double ema9 = GetEMAValue(9, 0, timeframe);
   double ema21 = GetEMAValue(21, 0, timeframe);
   double ema50 = GetEMAValue(50, 0, timeframe);
   double ema200 = GetEMAValue(200, 0, timeframe);
   
   if(ema9 == EMPTY_VALUE || ema21 == EMPTY_VALUE || ema50 == EMPTY_VALUE || ema200 == EMPTY_VALUE) {
      return false;
   }
   
   // Verificar alinhamento para tendência de alta
   if(ema9 > ema21 && ema21 > ema50 && ema50 > ema200) {
      return true;
   }
   
   // Verificar alinhamento para tendência de baixa
   if(ema9 < ema21 && ema21 < ema50 && ema50 < ema200) {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar momentum                                               |
//+------------------------------------------------------------------+
bool CMarketContext::CheckMomentum(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   double macd = GetMACDValue(0, 0, timeframe);
   double signal = GetMACDValue(1, 0, timeframe);
   
   if(macd == EMPTY_VALUE || signal == EMPTY_VALUE) {
      return false;
   }
   
   // Verificar se MACD está acima da linha de sinal para tendência de alta
   if(macd > signal && macd > 0) {
      return true;
   }
   
   // Verificar se MACD está abaixo da linha de sinal para tendência de baixa
   if(macd < signal && macd < 0) {
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
   
   double atr = GetATRValue(0, timeframe);
   return (atr != EMPTY_VALUE) ? atr : 0.0;
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

