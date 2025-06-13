//+------------------------------------------------------------------+
//|                                             MarketContext.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#ifndef MARKET_CONTEXT_MQH
#define MARKET_CONTEXT_MQH
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property strict

#include "Structures.mqh"
#include "Logger.mqh"
#include "Indicators/IndicatorHandlePool.mqh"

//+------------------------------------------------------------------+
//| Classe para análise de contexto de mercado                        |
//+------------------------------------------------------------------+
class CMarketContext
{
private:
   string m_symbol;             // Símbolo atual
   ENUM_TIMEFRAMES m_timeframe; // Timeframe principal
   CLogger *m_logger;           // Ponteiro para o logger
   CHandlePool *m_handlePool;   // ← NOVA: Ponteiro para o pool de handles
   MARKET_PHASE m_currentPhase; // Fase atual do mercado

   // Timeframes para análise multi-timeframe
   ENUM_TIMEFRAMES m_timeframes[4]; // [principal, maior, intermediário, menor]

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

   // Método para verificar se há dados suficientes
   bool CheckDataValidity();

public:
   // Construtor e destrutor
   CMarketContext();
   ~CMarketContext();

   // Métodos públicos
   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CHandlePool *handlePool, CLogger *logger = NULL, bool checkHistory = true);
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

   // Métodos auxiliares para acesso aos indicadores via pool
   CIndicatorHandle *GetEMAHandle(int period, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   CIndicatorHandle *GetRSIHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   CIndicatorHandle *GetATRHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   CIndicatorHandle *GetMACDHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   CIndicatorHandle *GetStochasticHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   CIndicatorHandle *GetBollingerHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CMarketContext::CMarketContext()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_logger = NULL;
   m_handlePool = NULL;
   m_currentPhase = PHASE_UNDEFINED;
   m_hasValidData = false;
   m_minRequiredBars = 100;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CMarketContext::~CMarketContext()
{
   // O pool de handles é gerenciado externamente, não precisamos liberar aqui
}

//+------------------------------------------------------------------+
//| Inicialização do contexto de mercado                             |
//+------------------------------------------------------------------+
bool CMarketContext::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CHandlePool *handlePool, CLogger *logger = NULL, bool checkHistory = true)
{
   // Configurar parâmetros básicos
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_handlePool = handlePool;
   m_logger = logger;
   m_currentPhase = PHASE_UNDEFINED;
   m_hasValidData = false;

   // Verificar se o pool de handles foi fornecido
   if (m_handlePool == NULL)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Pool de handles não fornecido para " + m_symbol);
      }
      return false;
   }

   // Configurar timeframes para análise multi-timeframe
   m_timeframes[0] = timeframe;  // Principal
   m_timeframes[1] = PERIOD_D1;  // Maior
   m_timeframes[2] = PERIOD_H1;  // Intermediário
   m_timeframes[3] = PERIOD_M15; // Menor

   // Verificar se o histórico está disponível
   if (checkHistory)
   {
      int bars = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
      if (bars < m_minRequiredBars)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning("Histórico insuficiente para " + m_symbol + " em " +
                             EnumToString(m_timeframe) + ": " + IntegerToString(bars) +
                             " barras (mínimo: " + IntegerToString(m_minRequiredBars) + ")");
         }
         return true; // Continuar sem criar handles
      }
   }

   // Verificar se há dados suficientes
   m_hasValidData = CheckDataValidity();

   return true;
}

//+------------------------------------------------------------------+
//| Atualizar símbolo do contexto de mercado                         |
//+------------------------------------------------------------------+
bool CMarketContext::UpdateSymbol(string symbol)
{
   if (m_symbol == symbol)
   {
      // Se o símbolo for o mesmo, apenas verificar se os handles são válidos
      if (m_hasValidData)
      {
         return true;
      }
   }

   // Registrar a mudança de símbolo
   if (m_logger != NULL)
   {
      m_logger.Info("Atualizando contexto de mercado para símbolo: " + symbol);
   }

   // Invalidar cache do pool para o símbolo anterior
   if (m_handlePool != NULL)
   {
      m_handlePool.InvalidateCache(m_symbol);
   }

   // Atualizar símbolo
   m_symbol = symbol;
   m_hasValidData = false;

   // Verificar se há dados suficientes
   m_hasValidData = CheckDataValidity();

   // Determinar fase de mercado
   if (m_hasValidData)
   {
      m_currentPhase = DetectPhase();
   }

   return m_hasValidData;
}

//+------------------------------------------------------------------+
//| Determinar fase de mercado                                       |
//+------------------------------------------------------------------+
MARKET_PHASE CMarketContext::DetermineMarketPhase()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      if (m_logger != NULL)
      {
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
bool CMarketContext::UpdateMarketDepth(string symbol)
{
   // Verificar se o símbolo é válido
   if (symbol == "" || StringLen(symbol) == 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Símbolo inválido para atualização de profundidade de mercado");
      }
      return false;
   }

   // Verificar se o livro de ofertas está disponível para o símbolo
   if (!MarketBookAdd(symbol))
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Livro de ofertas não disponível para " + symbol);
      }
      return false;
   }

   // Registrar a atualização
   if (m_logger != NULL)
   {
      m_logger.Debug("Profundidade de mercado atualizada para " + symbol);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Métodos auxiliares para acesso aos indicadores via pool          |
//+------------------------------------------------------------------+
CIndicatorHandle *CMarketContext::GetEMAHandle(int period, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   if (m_handlePool == NULL)
      return NULL;

   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;
   return m_handlePool.GetEMA(m_symbol, tf, period, 0, PRICE_CLOSE);
}

CIndicatorHandle *CMarketContext::GetRSIHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   if (m_handlePool == NULL)
      return NULL;

   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;
   return m_handlePool.GetRSI(m_symbol, tf, 14, PRICE_CLOSE);
}

CIndicatorHandle *CMarketContext::GetATRHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   if (m_handlePool == NULL)
      return NULL;

   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;
   return m_handlePool.GetATR(m_symbol, tf, 14);
}

CIndicatorHandle *CMarketContext::GetMACDHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   if (m_handlePool == NULL)
      return NULL;

   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;
   return m_handlePool.GetMACD(m_symbol, tf, 12, 26, 9, PRICE_CLOSE);
}

CIndicatorHandle *CMarketContext::GetStochasticHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   if (m_handlePool == NULL)
      return NULL;

   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;
   return m_handlePool.GetStochastic(m_symbol, tf, 5, 3, 3, MODE_SMA);
}

CIndicatorHandle *CMarketContext::GetBollingerHandle(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   if (m_handlePool == NULL)
      return NULL;

   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;
   return m_handlePool.GetBollinger(m_symbol, tf, 20, 2.0, 0, PRICE_CLOSE);
}

//+------------------------------------------------------------------+
//| Verificar se há dados suficientes para análise                   |
//+------------------------------------------------------------------+
bool CMarketContext::CheckDataValidity()
{
   // Verificar se há barras suficientes
   int bars = (int)SeriesInfoInteger(m_symbol, m_timeframe, SERIES_BARS_COUNT);
   if (bars < m_minRequiredBars)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Histórico insuficiente para " + m_symbol + ": " +
                          IntegerToString(bars) + " barras (mínimo: " +
                          IntegerToString(m_minRequiredBars) + ")");
      }
      return false;
   }

   // Verificar se o pool de handles está disponível
   if (m_handlePool == NULL)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Pool de handles não disponível para " + m_symbol);
      }
      return false;
   }

   // Tentar obter um handle básico para verificar se o sistema está funcionando
   CIndicatorHandle *emaHandle = GetEMAHandle(200);
   if (emaHandle == NULL || !emaHandle.IsValid())
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Não foi possível obter handle EMA200 para " + m_symbol);
      }
      return false;
   }

   // Verificar se os buffers dos indicadores têm dados suficientes
   double buffer[];
   ArraySetAsSeries(buffer, true);

   if (emaHandle.CopyBuffer(0, 0, 1, buffer) <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Dados de indicadores insuficientes para " + m_symbol);
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Detectar fase de mercado                                         |
//+------------------------------------------------------------------+
MARKET_PHASE CMarketContext::DetectPhase()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return PHASE_UNDEFINED;
   }

   // Verificar tendência
   if (IsTrend())
   {
      return PHASE_TREND;
   }

   // Verificar range
   if (IsRange())
   {
      return PHASE_RANGE;
   }

   // Verificar reversão
   if (IsReversal())
   {
      return PHASE_REVERSAL;
   }

   // Se não for nenhuma das fases acima, considerar como indefinida
   return PHASE_UNDEFINED;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência                         |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrend(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   // Verificar alinhamento das médias móveis
   if (!CheckMovingAveragesAlignment(timeframe))
   {
      return false;
   }

   // Verificar momentum
   if (!CheckMomentum(timeframe))
   {
      return false;
   }

   // Verificar RSI
   CIndicatorHandle *rsiHandle = GetRSIHandle(timeframe);
   if (rsiHandle == NULL || !rsiHandle.IsValid())
   {
      return false;
   }

   double rsiBuffer[];
   if (rsiHandle.CopyBuffer(0, 0, 3, rsiBuffer) <= 0)
   {
      return false;
   }

   // RSI deve estar acima de 60 para tendência de alta ou abaixo de 40 para tendência de baixa
   double rsi = rsiBuffer[0];
   int trendDirection = CheckTrendDirection();

   if (trendDirection > 0 && rsi < 60)
   {
      return false;
   }

   if (trendDirection < 0 && rsi > 40)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em range                             |
//+------------------------------------------------------------------+
bool CMarketContext::IsRange(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   // Obter handles dos indicadores
   CIndicatorHandle *ema9Handle = GetEMAHandle(9, timeframe);
   CIndicatorHandle *ema21Handle = GetEMAHandle(21, timeframe);
   CIndicatorHandle *ema50Handle = GetEMAHandle(50, timeframe);
   CIndicatorHandle *atrHandle = GetATRHandle(timeframe);
   CIndicatorHandle *rsiHandle = GetRSIHandle(timeframe);

   if (ema9Handle == NULL || ema21Handle == NULL || ema50Handle == NULL ||
       atrHandle == NULL || rsiHandle == NULL ||
       !ema9Handle.IsValid() || !ema21Handle.IsValid() || !ema50Handle.IsValid() ||
       !atrHandle.IsValid() || !rsiHandle.IsValid())
   {
      return false;
   }

   // Verificar se as médias móveis estão próximas
   double ema9Buffer[], ema21Buffer[], ema50Buffer[];

   ArraySetAsSeries(ema9Buffer, true);
   ArraySetAsSeries(ema21Buffer, true);
   ArraySetAsSeries(ema50Buffer, true);

   if (ema9Handle.CopyBuffer(0, 0, 3, ema9Buffer) <= 0 ||
       ema21Handle.CopyBuffer(0, 0, 3, ema21Buffer) <= 0 ||
       ema50Handle.CopyBuffer(0, 0, 3, ema50Buffer) <= 0)
   {
      return false;
   }

   // Calcular a distância entre as médias
   double distance1 = MathAbs(ema9Buffer[0] - ema21Buffer[0]);
   double distance2 = MathAbs(ema21Buffer[0] - ema50Buffer[0]);

   // Obter ATR para normalizar a distância
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   if (atrHandle.CopyBuffer(0, 0, 1, atrBuffer) <= 0)
   {
      return false;
   }

   double atr = atrBuffer[0];
   double normalizedDistance1 = distance1 / atr;
   double normalizedDistance2 = distance2 / atr;

   // Verificar se as médias estão próximas (distância menor que 0.5 * ATR)
   if (normalizedDistance1 > 0.5 || normalizedDistance2 > 1.0)
   {
      return false;
   }

   // Verificar RSI
   double rsiBuffer[];
   ArraySetAsSeries(rsiBuffer, true);

   if (rsiHandle.CopyBuffer(0, 0, 3, rsiBuffer) <= 0)
   {
      return false;
   }

   // RSI deve estar entre 40 e 60 para range
   double rsi = rsiBuffer[0];
   if (rsi < 40 || rsi > 60)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em reversão                          |
//+------------------------------------------------------------------+
bool CMarketContext::IsReversal(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   // Obter handle do RSI
   CIndicatorHandle *rsiHandle = GetRSIHandle(timeframe);
   if (rsiHandle == NULL || !rsiHandle.IsValid())
   {
      return false;
   }

   // Verificar divergência no RSI
   double rsiBuffer[];
   double closeBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(closeBuffer, true);

   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;

   if (rsiHandle.CopyBuffer(0, 0, 10, rsiBuffer) <= 0 ||
       CopyClose(m_symbol, tf, 0, 10, closeBuffer) <= 0)
   {
      return false;
   }

   // Verificar divergência de alta (preço em baixa, RSI em alta)
   bool bullishDivergence = false;
   if (closeBuffer[0] < closeBuffer[5] && rsiBuffer[0] > rsiBuffer[5])
   {
      bullishDivergence = true;
   }

   // Verificar divergência de baixa (preço em alta, RSI em baixa)
   bool bearishDivergence = false;
   if (closeBuffer[0] > closeBuffer[5] && rsiBuffer[0] < rsiBuffer[5])
   {
      bearishDivergence = true;
   }

   // Verificar condições de sobrecompra/sobrevenda
   bool oversold = rsiBuffer[0] < 30;
   bool overbought = rsiBuffer[0] > 70;

   // Verificar cruzamento de médias móveis
   CIndicatorHandle *ema9Handle = GetEMAHandle(9, timeframe);
   CIndicatorHandle *ema21Handle = GetEMAHandle(21, timeframe);

   if (ema9Handle == NULL || ema21Handle == NULL ||
       !ema9Handle.IsValid() || !ema21Handle.IsValid())
   {
      return false;
   }

   double ema9Buffer[], ema21Buffer[];
   ArraySetAsSeries(ema9Buffer, true);
   ArraySetAsSeries(ema21Buffer, true);

   if (ema9Handle.CopyBuffer(0, 0, 3, ema9Buffer) <= 0 ||
       ema21Handle.CopyBuffer(0, 0, 3, ema21Buffer) <= 0)
   {
      return false;
   }

   bool crossUp = ema9Buffer[1] < ema21Buffer[1] && ema9Buffer[0] > ema21Buffer[0];
   bool crossDown = ema9Buffer[1] > ema21Buffer[1] && ema9Buffer[0] < ema21Buffer[0];

   // Combinar condições para reversão
   if ((bullishDivergence && oversold) || (bearishDivergence && overbought) || crossUp || crossDown)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Verificar alinhamento das médias móveis                          |
//+------------------------------------------------------------------+
bool CMarketContext::CheckMovingAveragesAlignment(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Obter handles das médias móveis
   CIndicatorHandle *ema9Handle = GetEMAHandle(9, timeframe);
   CIndicatorHandle *ema21Handle = GetEMAHandle(21, timeframe);
   CIndicatorHandle *ema50Handle = GetEMAHandle(50, timeframe);
   CIndicatorHandle *ema200Handle = GetEMAHandle(200, timeframe);

   if (ema9Handle == NULL || ema21Handle == NULL || ema50Handle == NULL || ema200Handle == NULL ||
       !ema9Handle.IsValid() || !ema21Handle.IsValid() || !ema50Handle.IsValid() || !ema200Handle.IsValid())
   {
      return false;
   }

   double ema9Buffer[], ema21Buffer[], ema50Buffer[], ema200Buffer[];

   ArraySetAsSeries(ema9Buffer, true);
   ArraySetAsSeries(ema21Buffer, true);
   ArraySetAsSeries(ema50Buffer, true);
   ArraySetAsSeries(ema200Buffer, true);

   if (ema9Handle.CopyBuffer(0, 0, 1, ema9Buffer) <= 0 ||
       ema21Handle.CopyBuffer(0, 0, 1, ema21Buffer) <= 0 ||
       ema50Handle.CopyBuffer(0, 0, 1, ema50Buffer) <= 0 ||
       ema200Handle.CopyBuffer(0, 0, 1, ema200Buffer) <= 0)
   {
      return false;
   }

   // Verificar alinhamento para tendência de alta
   if (ema9Buffer[0] > ema21Buffer[0] && ema21Buffer[0] > ema50Buffer[0] && ema50Buffer[0] > ema200Buffer[0])
   {
      return true;
   }

   // Verificar alinhamento para tendência de baixa
   if (ema9Buffer[0] < ema21Buffer[0] && ema21Buffer[0] < ema50Buffer[0] && ema50Buffer[0] < ema200Buffer[0])
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Verificar momentum                                               |
//+------------------------------------------------------------------+
bool CMarketContext::CheckMomentum(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   CIndicatorHandle *macdHandle = GetMACDHandle(timeframe);
   if (macdHandle == NULL || !macdHandle.IsValid())
   {
      return false;
   }

   double macdBuffer[], signalBuffer[];
   ArraySetAsSeries(macdBuffer, true);
   ArraySetAsSeries(signalBuffer, true);

   if (macdHandle.CopyBuffer(0, 0, 3, macdBuffer) <= 0 ||
       macdHandle.CopyBuffer(1, 0, 3, signalBuffer) <= 0)
   {
      return false;
   }

   // Verificar se MACD está acima da linha de sinal para tendência de alta
   if (macdBuffer[0] > signalBuffer[0] && macdBuffer[0] > 0)
   {
      return true;
   }

   // Verificar se MACD está abaixo da linha de sinal para tendência de baixa
   if (macdBuffer[0] < signalBuffer[0] && macdBuffer[0] < 0)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência de alta                 |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrendUp()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   // Verificar se está em tendência
   if (!IsTrend())
   {
      return false;
   }

   // Verificar direção da tendência
   return CheckTrendDirection() > 0;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência de baixa                |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrendDown()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   // Verificar se está em tendência
   if (!IsTrend())
   {
      return false;
   }

   // Verificar direção da tendência
   return CheckTrendDirection() < 0;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em range                             |
//+------------------------------------------------------------------+
bool CMarketContext::IsInRange()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   return IsRange();
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em reversão                          |
//+------------------------------------------------------------------+
bool CMarketContext::IsInReversal()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   return IsReversal();
}

//+------------------------------------------------------------------+
//| Encontrar suporte mais próximo                                   |
//+------------------------------------------------------------------+
double CMarketContext::FindNearestSupport(double price, int lookbackBars = 50)
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return 0.0;
   }

   double lowBuffer[];
   ArraySetAsSeries(lowBuffer, true);

   if (CopyLow(m_symbol, m_timeframe, 0, lookbackBars, lowBuffer) <= 0)
   {
      return 0.0;
   }

   double support = 0.0;
   double minDistance = DBL_MAX;

   // Encontrar mínimos locais
   for (int i = 2; i < lookbackBars - 2; i++)
   {
      if (lowBuffer[i] < lowBuffer[i - 1] && lowBuffer[i] < lowBuffer[i - 2] &&
          lowBuffer[i] < lowBuffer[i + 1] && lowBuffer[i] < lowBuffer[i + 2])
      {

         // Verificar se é o suporte mais próximo abaixo do preço atual
         if (lowBuffer[i] < price && price - lowBuffer[i] < minDistance)
         {
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
double CMarketContext::FindNearestResistance(double price, int lookbackBars = 50)
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return 0.0;
   }

   double highBuffer[];
   ArraySetAsSeries(highBuffer, true);

   if (CopyHigh(m_symbol, m_timeframe, 0, lookbackBars, highBuffer) <= 0)
   {
      return 0.0;
   }

   double resistance = 0.0;
   double minDistance = DBL_MAX;

   // Encontrar máximos locais
   for (int i = 2; i < lookbackBars - 2; i++)
   {
      if (highBuffer[i] > highBuffer[i - 1] && highBuffer[i] > highBuffer[i - 2] &&
          highBuffer[i] > highBuffer[i + 1] && highBuffer[i] > highBuffer[i + 2])
      {

         // Verificar se é a resistência mais próxima acima do preço atual
         if (highBuffer[i] > price && highBuffer[i] - price < minDistance)
         {
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
double CMarketContext::GetATR(int period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return 0.0;
   }

   CIndicatorHandle *atrHandle = GetATRHandle(timeframe);
   if (atrHandle == NULL || !atrHandle.IsValid())
   {
      return 0.0;
   }

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   if (atrHandle.CopyBuffer(0, 0, 1, atrBuffer) <= 0)
   {
      return 0.0;
   }

   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Obter razão de volatilidade                                      |
//+------------------------------------------------------------------+
double CMarketContext::GetVolatilityRatio()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return 0.0;
   }

   CIndicatorHandle *atrHandle = GetATRHandle();
   if (atrHandle == NULL || !atrHandle.IsValid())
   {
      return 0.0;
   }

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   if (atrHandle.CopyBuffer(0, 0, 20, atrBuffer) <= 0)
   {
      return 0.0;
   }

   // Calcular média dos últimos 20 períodos
   double avgATR = 0.0;
   for (int i = 0; i < 20; i++)
   {
      avgATR += atrBuffer[i];
   }
   avgATR /= 20.0;

   // Retornar razão entre ATR atual e média
   return (avgATR > 0) ? atrBuffer[0] / avgATR : 0.0;
}

//+------------------------------------------------------------------+
//| Obter força da tendência                                         |
//+------------------------------------------------------------------+
double CMarketContext::GetTrendStrength()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return 0.0;
   }

   // Obter handles das médias móveis
   CIndicatorHandle *ema9Handle = GetEMAHandle(9);
   CIndicatorHandle *ema21Handle = GetEMAHandle(21);
   CIndicatorHandle *ema50Handle = GetEMAHandle(50);
   CIndicatorHandle *ema200Handle = GetEMAHandle(200);

   if (ema9Handle == NULL || ema21Handle == NULL || ema50Handle == NULL || ema200Handle == NULL ||
       !ema9Handle.IsValid() || !ema21Handle.IsValid() || !ema50Handle.IsValid() || !ema200Handle.IsValid())
   {
      return 0.0;
   }

   double ema9Buffer[], ema21Buffer[], ema50Buffer[], ema200Buffer[];

   ArraySetAsSeries(ema9Buffer, true);
   ArraySetAsSeries(ema21Buffer, true);
   ArraySetAsSeries(ema50Buffer, true);
   ArraySetAsSeries(ema200Buffer, true);

   if (ema9Handle.CopyBuffer(0, 0, 1, ema9Buffer) <= 0 ||
       ema21Handle.CopyBuffer(0, 0, 1, ema21Buffer) <= 0 ||
       ema50Handle.CopyBuffer(0, 0, 1, ema50Buffer) <= 0 ||
       ema200Handle.CopyBuffer(0, 0, 1, ema200Buffer) <= 0)
   {
      return 0.0;
   }

   // Calcular distâncias entre médias
   double distance1 = MathAbs(ema9Buffer[0] - ema21Buffer[0]);
   double distance2 = MathAbs(ema21Buffer[0] - ema50Buffer[0]);
   double distance3 = MathAbs(ema50Buffer[0] - ema200Buffer[0]);

   // Normalizar pela EMA200
   double normalizedDistance = (distance1 + distance2 + distance3) / ema200Buffer[0];

   return normalizedDistance * 100.0; // Retornar como percentual
}

//+------------------------------------------------------------------+
//| Verificar se o preço está acima da EMA                           |
//+------------------------------------------------------------------+
bool CMarketContext::IsPriceAboveEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   CIndicatorHandle *emaHandle = GetEMAHandle(emaPeriod, timeframe);
   if (emaHandle == NULL || !emaHandle.IsValid())
   {
      return false;
   }

   double emaBuffer[];
   double closeBuffer[];

   ArraySetAsSeries(emaBuffer, true);
   ArraySetAsSeries(closeBuffer, true);

   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;

   if (emaHandle.CopyBuffer(0, 0, 1, emaBuffer) <= 0 ||
       CopyClose(m_symbol, tf, 0, 1, closeBuffer) <= 0)
   {
      return false;
   }

   return closeBuffer[0] > emaBuffer[0];
}

//+------------------------------------------------------------------+
//| Verificar se o preço está abaixo da EMA                          |
//+------------------------------------------------------------------+
bool CMarketContext::IsPriceBelowEMA(int emaPeriod, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return false;
   }

   CIndicatorHandle *emaHandle = GetEMAHandle(emaPeriod, timeframe);
   if (emaHandle == NULL || !emaHandle.IsValid())
   {
      return false;
   }

   double emaBuffer[];
   double closeBuffer[];
   ENUM_TIMEFRAMES tf = (timeframe == PERIOD_CURRENT) ? m_timeframe : timeframe;

   if (emaHandle.CopyBuffer(0, 0, 1, emaBuffer) <= 0 ||
       CopyClose(m_symbol, tf, 0, 1, closeBuffer) <= 0)
   {
      return false;
   }

   return closeBuffer[0] < emaBuffer[0];
}

//+------------------------------------------------------------------+
//| Verificar direção da tendência                                   |
//+------------------------------------------------------------------+
int CMarketContext::CheckTrendDirection()
{
   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return 0;
   }

   // Obter handles das médias móveis
   CIndicatorHandle *ema9Handle = GetEMAHandle(9);
   CIndicatorHandle *ema21Handle = GetEMAHandle(21);
   CIndicatorHandle *ema50Handle = GetEMAHandle(50);
   CIndicatorHandle *ema200Handle = GetEMAHandle(200);

   if (ema9Handle == NULL || ema21Handle == NULL || ema50Handle == NULL || ema200Handle == NULL ||
       !ema9Handle.IsValid() || !ema21Handle.IsValid() || !ema50Handle.IsValid() || !ema200Handle.IsValid())
   {
      return 0;
   }

   double ema9Buffer[], ema21Buffer[], ema50Buffer[], ema200Buffer[];

   ArraySetAsSeries(ema9Buffer, true);
   ArraySetAsSeries(ema21Buffer, true);
   ArraySetAsSeries(ema50Buffer, true);
   ArraySetAsSeries(ema200Buffer, true);

   if (ema9Handle.CopyBuffer(0, 0, 1, ema9Buffer) <= 0 ||
       ema21Handle.CopyBuffer(0, 0, 1, ema21Buffer) <= 0 ||
       ema50Handle.CopyBuffer(0, 0, 1, ema50Buffer) <= 0 ||
       ema200Handle.CopyBuffer(0, 0, 1, ema200Buffer) <= 0)
   {
      return 0;
   }

   // Verificar alinhamento para tendência de alta
   if (ema9Buffer[0] > ema21Buffer[0] && ema21Buffer[0] > ema50Buffer[0] && ema50Buffer[0] > ema200Buffer[0])
   {
      return 1; // Tendência de alta
   }

   // Verificar alinhamento para tendência de baixa
   if (ema9Buffer[0] < ema21Buffer[0] && ema21Buffer[0] < ema50Buffer[0] && ema50Buffer[0] < ema200Buffer[0])
   {
      return -1; // Tendência de baixa
   }

   return 0; // Sem tendência clara
}

#endif // MARKET_CONTEXT_MQH
