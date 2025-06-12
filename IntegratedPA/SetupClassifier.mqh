//+------------------------------------------------------------------+
//|                                            SetupClassifier.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include "Structures.mqh"
#include "Logger.mqh"
#include "MarketContext.mqh"
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Enumeração para fatores de confluência                           |
//+------------------------------------------------------------------+
enum CONFLUENCE_FACTOR
{
   FACTOR_PATTERN_QUALITY,     // Qualidade do padrão (ex: spike bem definido)
   FACTOR_MA_ALIGNMENT,        // Alinhamento de médias móveis
   FACTOR_VOLUME_CONFIRMATION, // Confirmação de volume
   FACTOR_KEY_LEVEL,           // Proximidade a nível-chave (S/R, VWAP, etc)
   FACTOR_TREND_STRENGTH,      // Força da tendência
   FACTOR_MOMENTUM,            // Momentum (RSI, MACD)
   FACTOR_MULTI_TIMEFRAME,     // Confirmação multi-timeframe
   FACTOR_MARKET_STRUCTURE,    // Estrutura de mercado favorável
   FACTOR_TIME_SESSION,        // Horário da sessão favorável
   FACTOR_RISK_REWARD          // Relação risco/retorno
};

//+------------------------------------------------------------------+
//| Estrutura para armazenar fatores de confluência                  |
//+------------------------------------------------------------------+
struct ConfluenceFactors
{
   bool patternQuality;     // Padrão bem definido
   bool maAlignment;        // Médias alinhadas
   bool volumeConfirmation; // Volume acima da média
   bool nearKeyLevel;       // Próximo a nível importante
   bool strongTrend;        // Tendência forte
   bool momentumConfirmed;  // Momentum favorável
   bool mtfConfirmation;    // Confirmação em TF maior
   bool favorableStructure; // Estrutura de mercado favorável
   bool optimalSession;     // Horário ideal de negociação
   bool goodRiskReward;     // R:R >= 2:1

   int totalFactors;       // Total de fatores positivos
   double confluenceScore; // Score de 0 a 1

   // Construtor
   ConfluenceFactors()
   {
      Reset();
   }

   // Resetar todos os fatores
   void Reset()
   {
      patternQuality = false;
      maAlignment = false;
      volumeConfirmation = false;
      nearKeyLevel = false;
      strongTrend = false;
      momentumConfirmed = false;
      mtfConfirmation = false;
      favorableStructure = false;
      optimalSession = false;
      goodRiskReward = false;
      totalFactors = 0;
      confluenceScore = 0.0;
   }

   // Calcular total de fatores e score
   void Calculate()
   {
      totalFactors = 0;

      if (patternQuality)
         totalFactors++;
      if (maAlignment)
         totalFactors++;
      if (volumeConfirmation)
         totalFactors++;
      if (nearKeyLevel)
         totalFactors++;
      if (strongTrend)
         totalFactors++;
      if (momentumConfirmed)
         totalFactors++;
      if (mtfConfirmation)
         totalFactors++;
      if (favorableStructure)
         totalFactors++;
      if (optimalSession)
         totalFactors++;
      if (goodRiskReward)
         totalFactors++;

      confluenceScore = (double)totalFactors / 10.0;
   }
};

//+------------------------------------------------------------------+
//| Classe para classificação de setups                              |
//+------------------------------------------------------------------+
class CSetupClassifier
{
private:
   CLogger *m_logger;
   CMarketContext *m_marketContext;

   // Configurações para análise
   double m_minVolumeRatio;   // Razão mínima de volume vs média
   double m_keyLevelDistance; // Distância máxima para nível-chave em ATRs
   double m_minTrendStrength; // Força mínima da tendência
   double m_spreadThreshold;  // Limite de spread em múltiplos do spread médio

   // Métodos privados para análise de fatores
   bool CheckPatternQuality(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);
   bool CheckMAAlignment(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);
   bool CheckVolumeConfirmation(string symbol, ENUM_TIMEFRAMES timeframe, int signalBar);
   bool CheckNearKeyLevel(string symbol, ENUM_TIMEFRAMES timeframe, double price);
   bool CheckTrendStrength(string symbol, ENUM_TIMEFRAMES timeframe);
   bool CheckMomentum(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);
   bool CheckMultiTimeframeConfirmation(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);
   bool CheckMarketStructure(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);
   bool CheckOptimalSession(string symbol);
   bool CheckRiskReward(Signal &signal, double minRatio);

   // Métodos auxiliares
   double GetAverageVolume(string symbol, ENUM_TIMEFRAMES timeframe, int periods);
   double FindNearestKeyLevel(string symbol, ENUM_TIMEFRAMES timeframe, double price);
   bool IsWithinSpreadLimit(string symbol, double currentSpread);
   double CalculateSpreadMultiple(string symbol, double currentSpread);

public:
   // Construtores e destrutor
   CSetupClassifier();
   CSetupClassifier(CLogger *logger, CMarketContext *marketContext);
   ~CSetupClassifier();

   // Inicialização
   bool Initialize(CLogger *logger, CMarketContext *marketContext);

   // Configurações
   void SetVolumeRatio(double ratio) { m_minVolumeRatio = ratio; }
   void SetKeyLevelDistance(double distance) { m_keyLevelDistance = distance; }
   void SetTrendStrength(double strength) { m_minTrendStrength = strength; }
   void SetSpreadThreshold(double threshold) { m_spreadThreshold = threshold; }

   // Método principal de classificação
   SETUP_QUALITY ClassifySetup(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);

   // Análise de confluência
   ConfluenceFactors AnalyzeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);

   // Validação de spread
   bool ValidateSpread(string symbol);
};

//+------------------------------------------------------------------+
//| Construtor padrão                                                |
//+------------------------------------------------------------------+
CSetupClassifier::CSetupClassifier()
{
   m_logger = NULL;
   m_marketContext = NULL;
   m_minVolumeRatio = 1.2;   // Volume 20% acima da média
   m_keyLevelDistance = 1.0; // 1 ATR de distância
   m_minTrendStrength = 0.6; // 60% de força de tendência
   m_spreadThreshold = 2.0;  // 2x o spread médio
}

//+------------------------------------------------------------------+
//| Construtor com parâmetros                                        |
//+------------------------------------------------------------------+
CSetupClassifier::CSetupClassifier(CLogger *logger, CMarketContext *marketContext)
{
   m_logger = logger;
   m_marketContext = marketContext;
   m_minVolumeRatio = 1.2;
   m_keyLevelDistance = 1.0;
   m_minTrendStrength = 0.6;
   m_spreadThreshold = 2.0;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CSetupClassifier::~CSetupClassifier()
{
   // Não liberamos ponteiros pois são apenas referências
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CSetupClassifier::Initialize(CLogger *logger, CMarketContext *marketContext)
{
   if (logger == NULL || marketContext == NULL)
   {
      return false;
   }

   m_logger = logger;
   m_marketContext = marketContext;

   if (m_logger != NULL)
   {
      m_logger.Info("SetupClassifier inicializado com sucesso");
   }

   return true;
}

//+------------------------------------------------------------------+
//| Classificar setup principal                                      |
//+------------------------------------------------------------------+
SETUP_QUALITY CSetupClassifier::ClassifySetup(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   // Validar parâmetros
   if (symbol == "" || signal.id <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("SetupClassifier: Parâmetros inválidos para classificação");
      }
      return SETUP_INVALID;
   }

   // Analisar confluência
   ConfluenceFactors factors = AnalyzeConfluence(symbol, timeframe, signal);

   // Validar spread
   if (!ValidateSpread(symbol))
   {
      if (m_logger != NULL)
      {
         m_logger.Warning(StringFormat("SetupClassifier: Spread muito alto para %s", symbol));
      }
      return SETUP_INVALID;
   }

   // Classificar com base nos critérios definidos

   string factorDetails = StringFormat(
       "CONFLUÊNCIA [%s]: PatternQuality:%s | MAAlignment:%s | Volume:%s | KeyLevel:%s | Trend:%s | Momentum:%s | MTF:%s | Structure:%s | Session:%s | RR:%s",
       symbol,
       factors.patternQuality ? "✓" : "✗",
       factors.maAlignment ? "✓" : "✗",
       factors.volumeConfirmation ? "✓" : "✗",
       factors.nearKeyLevel ? "✓" : "✗",
       factors.strongTrend ? "✓" : "✗",
       factors.momentumConfirmed ? "✓" : "✗",
       factors.mtfConfirmation ? "✓" : "✗",
       factors.favorableStructure ? "✓" : "✗",
       factors.optimalSession ? "✓" : "✗",
       factors.goodRiskReward ? "✓" : "✗");
   m_logger.Info(factorDetails);

   if ((factors.strongTrend && factors.patternQuality && factors.goodRiskReward))
   {
      // Setup A+ (Alta Qualidade)
      if (factors.totalFactors >= 7 && signal.riskRewardRatio >= 3.0)
      {
         // Verificar critérios essenciais para A+
         if (factors.patternQuality && factors.maAlignment && factors.nearKeyLevel &&
             factors.goodRiskReward && (factors.strongTrend || factors.favorableStructure))
         {

            if (m_logger != NULL)
            {
               m_logger.Info(StringFormat("SetupClassifier: Setup A+ identificado para %s - %d fatores, R:R %.2f",
                                          symbol, factors.totalFactors, signal.riskRewardRatio));
            }
            return SETUP_A_PLUS;
         }
      }

      // Setup A (Boa Qualidade)
      if (factors.totalFactors >= 5 && signal.riskRewardRatio >= 2.5)
      {
         // Verificar critérios essenciais para A
         if (factors.patternQuality && factors.goodRiskReward &&
             (factors.maAlignment || factors.strongTrend || factors.momentumConfirmed))
         {

            if (m_logger != NULL)
            {
               m_logger.Info(StringFormat("SetupClassifier: Setup A identificado para %s - %d fatores, R:R %.2f",
                                          symbol, factors.totalFactors, signal.riskRewardRatio));
            }
            return SETUP_A;
         }
      }

      // Setup B (Qualidade Intermediária)
      if (factors.totalFactors >= 3 && signal.riskRewardRatio >= 2.0)
      {
         // Verificar critérios mínimos para B
         if (factors.patternQuality || factors.goodRiskReward)
         {

            if (m_logger != NULL)
            {
               m_logger.Info(StringFormat("SetupClassifier: Setup B identificado para %s - %d fatores, R:R %.2f",
                                          symbol, factors.totalFactors, signal.riskRewardRatio));
            }
            return SETUP_B;
         }
      }

      // Setup C (Baixa Qualidade)
      if (factors.totalFactors >= 1 && signal.riskRewardRatio >= 1.5)
      {
         if (m_logger != NULL)
         {
            m_logger.Info(StringFormat("SetupClassifier: Setup C identificado para %s - %d fatores, R:R %.2f",
                                       symbol, factors.totalFactors, signal.riskRewardRatio));
         }
         return SETUP_C;
      }
   }

   // Setup Inválido
   if (m_logger != NULL)
   {
      m_logger.Warning(StringFormat("SetupClassifier: Setup inválido para %s - apenas %d fatores, R:R %.2f",
                                    symbol, factors.totalFactors, signal.riskRewardRatio));
   }

   //

   return SETUP_INVALID;
}

//+------------------------------------------------------------------+
//| Analisar confluência de fatores                                  |
//+------------------------------------------------------------------+
ConfluenceFactors CSetupClassifier::AnalyzeConfluence(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   ConfluenceFactors factors;

   // Analisar cada fator
   factors.patternQuality = CheckPatternQuality(symbol, timeframe, signal);
   factors.maAlignment = CheckMAAlignment(symbol, timeframe, signal);
   factors.volumeConfirmation = CheckVolumeConfirmation(symbol, timeframe, 0);
   factors.nearKeyLevel = CheckNearKeyLevel(symbol, timeframe, signal.entryPrice);
   factors.strongTrend = CheckTrendStrength(symbol, timeframe);
   factors.momentumConfirmed = CheckMomentum(symbol, timeframe, signal);
   factors.mtfConfirmation = CheckMultiTimeframeConfirmation(symbol, timeframe, signal);
   factors.favorableStructure = CheckMarketStructure(symbol, timeframe, signal);
   factors.optimalSession = CheckOptimalSession(symbol);
   factors.goodRiskReward = CheckRiskReward(signal, 2.0);

   // Calcular total e score
   factors.Calculate();

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("SetupClassifier: Confluência analisada para %s - Total: %d/10, Score: %.2f",
                                  symbol, factors.totalFactors, factors.confluenceScore));
   }

   return factors;
}

//+------------------------------------------------------------------+
//| Verificar qualidade do padrão                                    |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckPatternQuality(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   bool hasQuality = false;

   // Verificar se o padrão tem características bem definidas
   if (signal.strategy == "Spike and Channel")
   {
      // Verificar se o sinal tem dados consistentes
      if (signal.entryPrice > 0 && signal.stopLoss > 0 && signal.takeProfits[0] > 0)
      {
         // Verificar se o stop loss está no lado correto
         if (signal.direction == ORDER_TYPE_BUY && signal.stopLoss < signal.entryPrice)
         {
            hasQuality = true;
         }
         else if (signal.direction == ORDER_TYPE_SELL && signal.stopLoss > signal.entryPrice)
         {
            hasQuality = true;
         }

         // Verificar se o primeiro take profit está no lado correto
         if (hasQuality)
         {
            if (signal.direction == ORDER_TYPE_BUY && signal.takeProfits[0] <= signal.entryPrice)
            {
               hasQuality = false;
            }
            else if (signal.direction == ORDER_TYPE_SELL && signal.takeProfits[0] >= signal.entryPrice)
            {
               hasQuality = false;
            }
         }
      }
   }

   // Log detalhado para debugging
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("SetupClassifier: PatternQuality para %s (%s): %s - Entry:%.5f, SL:%.5f, TP1:%.5f",
                                  symbol, signal.strategy, hasQuality ? "✓" : "✗",
                                  signal.entryPrice, signal.stopLoss, signal.takeProfits[0]));
   }

   return hasQuality;
}

//+------------------------------------------------------------------+
//| Verificar alinhamento de médias móveis                           |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckMAAlignment(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   if (m_marketContext == NULL)
      return false;

   // Verificar se as médias estão alinhadas na direção do sinal
   bool ema9Above21 = m_marketContext.IsPriceAboveEMA(9, timeframe) &&
                      m_marketContext.IsPriceAboveEMA(21, timeframe);
   bool ema9Below21 = m_marketContext.IsPriceBelowEMA(9, timeframe) &&
                      m_marketContext.IsPriceBelowEMA(21, timeframe);

   if (signal.direction == ORDER_TYPE_BUY && ema9Above21)
   {
      return true;
   }

   if (signal.direction == ORDER_TYPE_SELL && ema9Below21)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Verificar confirmação de volume                                  |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckVolumeConfirmation(string symbol, ENUM_TIMEFRAMES timeframe, int signalBar)
{
   // Obter volume atual e médio
   long volumes[];
   ArraySetAsSeries(volumes, true);

   if (CopyTickVolume(symbol, timeframe, 0, 20, volumes) <= 0)
   {
      return false;
   }

   // Calcular média de volume
   double avgVolume = GetAverageVolume(symbol, timeframe, 20);
   if (avgVolume <= 0)
      return false;

   // Verificar se o volume atual está acima da média
   double currentVolume = (double)volumes[signalBar];
   double volumeRatio = currentVolume / avgVolume;

   return (volumeRatio >= m_minVolumeRatio);
}

//+------------------------------------------------------------------+
//| Verificar proximidade a nível-chave                              |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckNearKeyLevel(string symbol, ENUM_TIMEFRAMES timeframe, double price)
{
   if (m_marketContext == NULL)
      return false;

   // Obter ATR para normalizar distância
   double atr = m_marketContext.GetATR(14, timeframe);
   if (atr <= 0)
      return false;

   // Encontrar nível-chave mais próximo
   double nearestLevel = FindNearestKeyLevel(symbol, timeframe, price);
   if (nearestLevel <= 0)
      return false;

   // Calcular distância em ATRs
   double distance = MathAbs(price - nearestLevel) / atr;

   return (distance <= m_keyLevelDistance);
}

//+------------------------------------------------------------------+
//| Verificar força da tendência                                     |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckTrendStrength(string symbol, ENUM_TIMEFRAMES timeframe)
{
   if (m_marketContext == NULL)
      return false;

   double trendStrength = m_marketContext.GetTrendStrength();

   return (trendStrength >= m_minTrendStrength);
}

//+------------------------------------------------------------------+
//| Verificar momentum                                               |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckMomentum(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   // ✅ Usar handle diretamente (quando precisa de mais controle)
   CIndicatorHandle *rsiHandle = m_marketContext.GetRSIHandle(timeframe);
   if (!rsiHandle || !rsiHandle.IsValid())
      return false;

   double rsiBuffer[];
   // ✅ Configurar array como série temporal

   ArraySetAsSeries(rsiBuffer, true);

   if (rsiHandle.CopyBuffer(0, 0, 3, rsiBuffer) <= 0)
      return false;

   double rsi = rsiBuffer[0];

   // Verificar momentum na direção do sinal
   if (signal.direction == ORDER_TYPE_BUY)
   {
      return (rsi > 50 && rsi < 70); // Momentum positivo mas não sobrecomprado
   }
   else
   {
      return (rsi < 50 && rsi > 30); // Momentum negativo mas não sobrevendido
   }
}

//+------------------------------------------------------------------+
//| Verificar confirmação multi-timeframe                            |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckMultiTimeframeConfirmation(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   if (m_marketContext == NULL)
      return false;

   // Obter timeframe superior
   ENUM_TIMEFRAMES higherTF = GetHigherTimeframe(timeframe);

   // Usar pool através do MarketContext
   CIndicatorHandle *ema21Handle = m_marketContext.GetEMAHandle(21, higherTF);
   CIndicatorHandle *ema50Handle = m_marketContext.GetEMAHandle(50, higherTF);

   if (ema21Handle == NULL || ema50Handle == NULL ||
       !ema21Handle.IsValid() || !ema50Handle.IsValid())
   {
      return false;
   }

   double ema21[], ema50[];
   ArraySetAsSeries(ema21, true);
   ArraySetAsSeries(ema50, true);

   int higherTrend = 0;
   if (ema21Handle.CopyBuffer(0, 0, 1, ema21) > 0 &&
       ema50Handle.CopyBuffer(0, 0, 1, ema50) > 0)
   {

      if (ema21[0] > ema50[0])
         higherTrend = 1;
      else if (ema21[0] < ema50[0])
         higherTrend = -1;
   }
   // Verificar alinhamento
   if (signal.direction == ORDER_TYPE_BUY && higherTrend > 0)
      return true;
   if (signal.direction == ORDER_TYPE_SELL && higherTrend < 0)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Verificar estrutura de mercado                                   |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckMarketStructure(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   if (m_marketContext == NULL)
      return false;

   MARKET_PHASE currentPhase = m_marketContext.GetCurrentPhase();

   // Verificar se a fase do mercado é compatível com o sinal
   switch (signal.marketPhase)
   {
   case PHASE_TREND:
      return (currentPhase == PHASE_TREND);

   case PHASE_RANGE:
      return (currentPhase == PHASE_RANGE);

   case PHASE_REVERSAL:
      return (currentPhase == PHASE_REVERSAL);

   default:
      return false;
   }
}

//+------------------------------------------------------------------+
//| Verificar horário ótimo de negociação                            |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckOptimalSession(string symbol)
{
   // Obter hora atual
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);

   int hour = currentTime.hour;

   // Definir horários ótimos por tipo de ativo
   if (StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 ||
       StringFind(symbol, "GBP") >= 0)
   {
      // Forex: sessões de Londres e Nova York
      return ((hour >= 8 && hour <= 11) || (hour >= 13 && hour <= 17));
   }
   else if (StringFind(symbol, "WIN") >= 0 || StringFind(symbol, "WDO") >= 0)
   {
      // Índice e Dólar: horário do pregão brasileiro
      return (hour >= 9 && hour <= 17);
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      // Bitcoin: 24 horas, mas evitar madrugada
      return (hour >= 6 && hour <= 23);
   }

   // Por padrão, considerar horário comercial
   return (hour >= 9 && hour <= 18);
}

//+------------------------------------------------------------------+
//| Verificar relação risco/retorno                                  |
//+------------------------------------------------------------------+
bool CSetupClassifier::CheckRiskReward(Signal &signal, double minRatio)
{
   // Recalcular R:R para garantir precisão
   signal.CalculateRiskRewardRatio();

   bool isGoodRR = (signal.riskRewardRatio >= minRatio);

   // Log detalhado para debugging
   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("SetupClassifier: RiskReward check - Calculado:%.2f, Mínimo:%.2f, Resultado:%s",
                                  signal.riskRewardRatio, minRatio, isGoodRR ? "✓" : "✗"));
   }

   return isGoodRR;
}

//+------------------------------------------------------------------+
//| Obter volume médio                                              |
//+------------------------------------------------------------------+
double CSetupClassifier::GetAverageVolume(string symbol, ENUM_TIMEFRAMES timeframe, int periods)
{
   long volumes[];
   ArraySetAsSeries(volumes, true);

   if (CopyTickVolume(symbol, timeframe, 1, periods, volumes) <= 0)
   {
      return 0;
   }

   double sum = 0;
   for (int i = 0; i < periods; i++)
   {
      sum += (double)volumes[i];
   }

   return sum / periods;
}

//+------------------------------------------------------------------+
//| Encontrar nível-chave mais próximo                               |
//+------------------------------------------------------------------+
double CSetupClassifier::FindNearestKeyLevel(string symbol, ENUM_TIMEFRAMES timeframe, double price)
{
   if (m_marketContext == NULL)
      return 0;

   // Procurar suporte/resistência mais próximo
   double support = m_marketContext.FindNearestSupport(price, 50);
   double resistance = m_marketContext.FindNearestResistance(price, 50);

   double distToSupport = (support > 0) ? MathAbs(price - support) : DBL_MAX;
   double distToResistance = (resistance > 0) ? MathAbs(price - resistance) : DBL_MAX;

   // Adicionar outros níveis importantes (VWAP, abertura diária, etc)
   double dailyOpen = iOpen(symbol, PERIOD_D1, 0);
   double distToDailyOpen = MathAbs(price - dailyOpen);

   // Retornar o nível mais próximo
   if (distToSupport < distToResistance && distToSupport < distToDailyOpen)
   {
      return support;
   }
   else if (distToResistance < distToDailyOpen)
   {
      return resistance;
   }
   else
   {
      return dailyOpen;
   }
}

//+------------------------------------------------------------------+
//| Validar spread                                                   |
//+------------------------------------------------------------------+
bool CSetupClassifier::ValidateSpread(string symbol)
{
   MqlTick lastTick;
   if (!SymbolInfoTick(symbol, lastTick))
   {
      return false;
   }

   double currentSpread = lastTick.ask - lastTick.bid;

   return IsWithinSpreadLimit(symbol, currentSpread);
}

//+------------------------------------------------------------------+
//| Verificar se spread está dentro do limite                        |
//+------------------------------------------------------------------+
bool CSetupClassifier::IsWithinSpreadLimit(string symbol, double currentSpread)
{
   // Calcular spread médio histórico
   double spreads[];
   ArrayResize(spreads, 100);

   int count = 0;
   double sum = 0;

   // Coletar últimos 100 ticks
   MqlTick ticks[];
   int copied = CopyTicksRange(symbol, ticks, COPY_TICKS_INFO,
                               TimeCurrent() - 3600, TimeCurrent()); // Última hora

   if (copied > 0)
   {
      for (int i = 0; i < MathMin(copied, 100); i++)
      {
         double spread = ticks[i].ask - ticks[i].bid;
         sum += spread;
         count++;
      }
   }

   if (count == 0)
      return true; // Se não há dados, permitir

   double avgSpread = sum / count;
   double spreadMultiple = (avgSpread > 0) ? currentSpread / avgSpread : 0;

   bool withinLimit = (spreadMultiple <= m_spreadThreshold);

   if (m_logger != NULL && !withinLimit)
   {
      m_logger.Warning(StringFormat("SetupClassifier: Spread alto para %s - Atual: %.5f, Médio: %.5f, Múltiplo: %.2f",
                                    symbol, currentSpread, avgSpread, spreadMultiple));
   }

   return withinLimit;
}

//+------------------------------------------------------------------+
//| Calcular múltiplo do spread                                      |
//+------------------------------------------------------------------+
double CSetupClassifier::CalculateSpreadMultiple(string symbol, double currentSpread)
{
   // Similar ao método IsWithinSpreadLimit, mas retorna o múltiplo
   double spreads[];
   ArrayResize(spreads, 100);

   int count = 0;
   double sum = 0;

   MqlTick ticks[];
   int copied = CopyTicksRange(symbol, ticks, COPY_TICKS_INFO,
                               TimeCurrent() - 3600, TimeCurrent());

   if (copied > 0)
   {
      for (int i = 0; i < MathMin(copied, 100); i++)
      {
         double spread = ticks[i].ask - ticks[i].bid;
         sum += spread;
         count++;
      }
   }

   if (count == 0)
      return 1.0;

   double avgSpread = sum / count;

   return (avgSpread > 0) ? currentSpread / avgSpread : 1.0;
}
