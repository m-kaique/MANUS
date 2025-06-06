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
   
   // Flag para indicar se os dados são válidos
   bool m_hasValidData;
   
   // Configurações
   int m_minRequiredBars;
   
   // Métodos privados
   bool CreateIndicatorHandles();
   void ReleaseIndicatorHandles();
   bool CheckDataValidity();
   double GetIndicatorValue(int handle, int buffer, int index);
   bool IsIndicatorReady(int handle, int minBars = 50);
   
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
   
   // Métodos de análise de mercado
   bool IsTrendUp();
   bool IsTrendDown();
   bool IsInRange();
   bool IsInReversal();
   double FindNearestSupport(double price, int lookbackBars = 50);
   double FindNearestResistance(double price, int lookbackBars = 50);
   double GetATR(int period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   double GetVolatilityRatio();
   
   // MÉTODO PÚBLICO PARA DEBUG
   void PrintDebugInfo();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CMarketContext::CMarketContext() {
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_logger = NULL;
   m_indicatorManager = NULL;
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
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CMarketContext::~CMarketContext() {
   // Não precisamos liberar handles quando usando IndicatorManager
   // pois ele gerencia isso automaticamente
}

//+------------------------------------------------------------------+
//| Inicialização do contexto de mercado                             |
//+------------------------------------------------------------------+
bool CMarketContext::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CLogger* logger = NULL, bool checkHistory = true, CIndicatorManager* indicatorManager = NULL) {
   // Configurar parâmetros básicos
   m_indicatorManager = indicatorManager;
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_logger = logger;
   m_currentPhase = PHASE_UNDEFINED;
   m_hasValidData = false;
   
   // Log de inicialização
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("MarketContext: Iniciando para %s (%s)", m_symbol, EnumToString(m_timeframe)));
   }
   
   // Verificar se o IndicatorManager foi fornecido
   if(m_indicatorManager == NULL) {
      if(m_logger != NULL) {
         m_logger.Warning("MarketContext: IndicatorManager não fornecido - operando sem indicadores");
      }
      // Marcar como válido mesmo sem indicadores para permitir análise básica
      m_hasValidData = true;
      return true;
   }
   
   // Verificar se o histórico está disponível
   if(checkHistory) {
      int bars = Bars(m_symbol, m_timeframe);
      if(bars < m_minRequiredBars) {
         if(m_logger != NULL) {
            m_logger.Warning(StringFormat("MarketContext: Histórico insuficiente para %s - %d barras (mínimo: %d)", 
                           m_symbol, bars, m_minRequiredBars));
         }
         return true; // Continuar sem criar handles
      }
   }
   
   // Criar handles de indicadores
   if(!CreateIndicatorHandles()) {
      if(m_logger != NULL) {
         m_logger.Warning("MarketContext: Falha parcial ao criar handles - continuando com os disponíveis");
      }
   }
   
   // Verificar se há dados suficientes
   m_hasValidData = CheckDataValidity();
   
   if(m_logger != NULL) {
      m_logger.Info(StringFormat("MarketContext: Inicializado para %s - Dados válidos: %s", 
                               m_symbol, m_hasValidData ? "Sim" : "Não"));
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Criar handles de indicadores                                     |
//+------------------------------------------------------------------+
bool CMarketContext::CreateIndicatorHandles() {
   if(m_indicatorManager == NULL) {
      return false;
   }
   
   // Verificar se há barras suficientes
   int bars = Bars(m_symbol, m_timeframe);
   if(bars < m_minRequiredBars) {
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
   
   // Verificar quais handles foram criados com sucesso
   int validHandles = 0;
   if(m_ema9Handle != INVALID_HANDLE) validHandles++;
   if(m_ema21Handle != INVALID_HANDLE) validHandles++;
   if(m_ema50Handle != INVALID_HANDLE) validHandles++;
   if(m_ema200Handle != INVALID_HANDLE) validHandles++;
   if(m_rsiHandle != INVALID_HANDLE) validHandles++;
   if(m_atrHandle != INVALID_HANDLE) validHandles++;
   if(m_macdHandle != INVALID_HANDLE) validHandles++;
   if(m_stochHandle != INVALID_HANDLE) validHandles++;
   if(m_bollingerHandle != INVALID_HANDLE) validHandles++;
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("MarketContext: %d de 9 handles criados para %s", validHandles, m_symbol));
   }
   
   // Retornar true se pelo menos alguns handles foram criados
   return (validHandles >= 4); // Precisamos de pelo menos 4 indicadores para análise básica
}

//+------------------------------------------------------------------+
//| Verificar se os dados são válidos                                |
//+------------------------------------------------------------------+
bool CMarketContext::CheckDataValidity() {
   // Se não temos IndicatorManager, considerar válido para análise básica
   if(m_indicatorManager == NULL) {
      return true;
   }
   
   // Verificar se há barras suficientes
   int bars = Bars(m_symbol, m_timeframe);
   if(bars < m_minRequiredBars) {
      return false;
   }
   
   // Verificar se pelo menos alguns indicadores estão prontos
   int readyIndicators = 0;
   
   if(m_ema9Handle != INVALID_HANDLE && m_indicatorManager.IsReady(m_ema9Handle, 20)) readyIndicators++;
   if(m_ema21Handle != INVALID_HANDLE && m_indicatorManager.IsReady(m_ema21Handle, 30)) readyIndicators++;
   if(m_ema50Handle != INVALID_HANDLE && m_indicatorManager.IsReady(m_ema50Handle, 60)) readyIndicators++;
   if(m_rsiHandle != INVALID_HANDLE && m_indicatorManager.IsReady(m_rsiHandle, 20)) readyIndicators++;
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("MarketContext: %d indicadores prontos para %s", readyIndicators, m_symbol));
   }
   
   // Precisamos de pelo menos 2 indicadores prontos
   return (readyIndicators >= 2);
}

//+------------------------------------------------------------------+
//| Obter valor de indicador com verificação de segurança            |
//+------------------------------------------------------------------+
double CMarketContext::GetIndicatorValue(int handle, int buffer, int index) {
   if(handle == INVALID_HANDLE) {
      return EMPTY_VALUE;
   }
   
   if(m_indicatorManager != NULL && !m_indicatorManager.IsReady(handle, index + 10)) {
      return EMPTY_VALUE;
   }
   
   double value[];
   ArraySetAsSeries(value, true);
   
   if(CopyBuffer(handle, buffer, index, 1, value) <= 0) {
      return EMPTY_VALUE;
   }
   
   return value[0];
}

//+------------------------------------------------------------------+
//| Atualizar símbolo                                                |
//+------------------------------------------------------------------+
bool CMarketContext::UpdateSymbol(string symbol) {
   if(m_symbol != symbol) {
      // Símbolo mudou, reinicializar
      return Initialize(symbol, m_timeframe, m_logger, true, m_indicatorManager);
   }
   
   // Verificar se dados continuam válidos
   m_hasValidData = CheckDataValidity();
   
   return true;
}

//+------------------------------------------------------------------+
//| Determinar fase de mercado                                       |
//+------------------------------------------------------------------+
MARKET_PHASE CMarketContext::DetermineMarketPhase() {
   // Análise simplificada se não temos dados completos
   if(!m_hasValidData && m_indicatorManager != NULL) {
      // Tentar análise básica com dados de preço
      double close[], high[], low[];
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      if(CopyClose(m_symbol, m_timeframe, 0, 50, close) > 0 &&
         CopyHigh(m_symbol, m_timeframe, 0, 50, high) > 0 &&
         CopyLow(m_symbol, m_timeframe, 0, 50, low) > 0) {
         
         // Análise simples de tendência
         double avgClose20 = 0, avgClose50 = 0;
         for(int i = 0; i < 20; i++) avgClose20 += close[i];
         for(int i = 0; i < 50; i++) avgClose50 += close[i];
         avgClose20 /= 20;
         avgClose50 /= 50;
         
         if(close[0] > avgClose20 && avgClose20 > avgClose50) {
            m_currentPhase = PHASE_TREND;
         } else if(close[0] < avgClose20 && avgClose20 < avgClose50) {
            m_currentPhase = PHASE_TREND;
         } else {
            // Verificar range
            double highestHigh = high[ArrayMaximum(high, 0, 20)];
            double lowestLow = low[ArrayMinimum(low, 0, 20)];
            double range = highestHigh - lowestLow;
            double avgRange = 0;
            
            for(int i = 1; i < 20; i++) {
               avgRange += (high[i] - low[i]);
            }
            avgRange /= 19;
            
            if(range < avgRange * 2) {
               m_currentPhase = PHASE_RANGE;
            } else {
               m_currentPhase = PHASE_UNDEFINED;
            }
         }
         
         if(m_logger != NULL) {
            m_logger.Debug(StringFormat("MarketContext: Fase determinada por análise básica: %s", 
                                      EnumToString(m_currentPhase)));
         }
         
         return m_currentPhase;
      }
      
      return PHASE_UNDEFINED;
   }
   
   // Análise completa com indicadores
   if(IsTrend()) {
      m_currentPhase = PHASE_TREND;
   } else if(IsRange()) {
      m_currentPhase = PHASE_RANGE;
   } else if(IsReversal()) {
      m_currentPhase = PHASE_REVERSAL;
   } else {
      m_currentPhase = PHASE_UNDEFINED;
   }
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("MarketContext: Fase determinada: %s", EnumToString(m_currentPhase)));
   }
   
   return m_currentPhase;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência                         |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrend(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Se não temos dados válidos, usar análise básica
   if(!m_hasValidData) {
      return false;
   }
   
   // Verificar alinhamento das médias móveis
   double ema9 = GetEMAValue(9);
   double ema21 = GetEMAValue(21);
   double ema50 = GetEMAValue(50);
   
   bool hasEMAs = (ema9 != EMPTY_VALUE && ema21 != EMPTY_VALUE && ema50 != EMPTY_VALUE);
   
   if(hasEMAs) {
      // Verificar alinhamento para tendência
      bool uptrend = (ema9 > ema21 && ema21 > ema50);
      bool downtrend = (ema9 < ema21 && ema21 < ema50);
      
      if(uptrend || downtrend) {
         // Verificar momentum
         double rsi = GetRSIValue();
         if(rsi != EMPTY_VALUE) {
            if((uptrend && rsi > 50 && rsi < 80) || (downtrend && rsi < 50 && rsi > 20)) {
               return true;
            }
         } else {
            // Se não temos RSI, aceitar apenas com EMAs alinhadas
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em range                             |
//+------------------------------------------------------------------+
bool CMarketContext::IsRange(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Se não temos dados válidos, usar análise básica
   if(!m_hasValidData) {
      return false;
   }
   
   // Verificar se as médias móveis estão próximas
   double ema9 = GetEMAValue(9);
   double ema21 = GetEMAValue(21);
   double ema50 = GetEMAValue(50);
   
   if(ema9 == EMPTY_VALUE || ema21 == EMPTY_VALUE || ema50 == EMPTY_VALUE) {
      return false;
   }
   
   // Calcular a distância entre as médias
   double avgPrice = (ema9 + ema21 + ema50) / 3;
   double maxDeviation = MathMax(MathAbs(ema9 - avgPrice), MathMax(MathAbs(ema21 - avgPrice), MathAbs(ema50 - avgPrice)));
   double deviationPercent = maxDeviation / avgPrice * 100;
   
   // Se as médias estão muito próximas (menos de 0.5%), indica range
   if(deviationPercent < 0.5) {
      // Verificar RSI
      double rsi = GetRSIValue();
      if(rsi != EMPTY_VALUE) {
         // RSI entre 40 e 60 confirma range
         if(rsi >= 40 && rsi <= 60) {
            return true;
         }
      } else {
         // Se não temos RSI, aceitar apenas com médias próximas
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em reversão                          |
//+------------------------------------------------------------------+
bool CMarketContext::IsReversal(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   // Se não temos dados válidos, não podemos detectar reversão
   if(!m_hasValidData) {
      return false;
   }
   
   // Verificar condições de sobrecompra/sobrevenda
   double rsi = GetRSIValue();
   if(rsi != EMPTY_VALUE) {
      bool oversold = rsi < 30;
      bool overbought = rsi > 70;
      
      if(oversold || overbought) {
         // Verificar se há sinais de reversão nas médias
         double ema9_0 = GetEMAValue(9, 0);
         double ema9_1 = GetEMAValue(9, 1);
         double ema21_0 = GetEMAValue(21, 0);
         double ema21_1 = GetEMAValue(21, 1);
         
         if(ema9_0 != EMPTY_VALUE && ema9_1 != EMPTY_VALUE && 
            ema21_0 != EMPTY_VALUE && ema21_1 != EMPTY_VALUE) {
            
            // Cruzamento de médias
            bool crossUp = ema9_1 < ema21_1 && ema9_0 > ema21_0;
            bool crossDown = ema9_1 > ema21_1 && ema9_0 < ema21_0;
            
            if((oversold && crossUp) || (overbought && crossDown)) {
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência de alta                 |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrendUp() {
   if(!m_hasValidData) {
      // Análise básica sem indicadores
      double close[];
      ArraySetAsSeries(close, true);
      
      if(CopyClose(m_symbol, m_timeframe, 0, 50, close) > 0) {
         double avg20 = 0, avg50 = 0;
         for(int i = 0; i < 20; i++) avg20 += close[i];
         for(int i = 0; i < 50; i++) avg50 += close[i];
         avg20 /= 20;
         avg50 /= 50;
         
         return (close[0] > avg20 && avg20 > avg50);
      }
      return false;
   }
   
   return IsTrend() && CheckTrendDirection() > 0;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em tendência de baixa                |
//+------------------------------------------------------------------+
bool CMarketContext::IsTrendDown() {
   if(!m_hasValidData) {
      // Análise básica sem indicadores
      double close[];
      ArraySetAsSeries(close, true);
      
      if(CopyClose(m_symbol, m_timeframe, 0, 50, close) > 0) {
         double avg20 = 0, avg50 = 0;
         for(int i = 0; i < 20; i++) avg20 += close[i];
         for(int i = 0; i < 50; i++) avg50 += close[i];
         avg20 /= 20;
         avg50 /= 50;
         
         return (close[0] < avg20 && avg20 < avg50);
      }
      return false;
   }
   
   return IsTrend() && CheckTrendDirection() < 0;
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em range                             |
//+------------------------------------------------------------------+
bool CMarketContext::IsInRange() {
   return IsRange();
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está em reversão                          |
//+------------------------------------------------------------------+
bool CMarketContext::IsInReversal() {
   return IsReversal();
}

//+------------------------------------------------------------------+
//| Obter valor de EMA                                               |
//+------------------------------------------------------------------+
double CMarketContext::GetEMAValue(int period, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   int handle = INVALID_HANDLE;
   
   // Determinar qual handle usar baseado no período
   switch(period) {
      case 9: handle = m_ema9Handle; break;
      case 21: handle = m_ema21Handle; break;
      case 50: handle = m_ema50Handle; break;
      case 200: handle = m_ema200Handle; break;
   }
   
   return GetIndicatorValue(handle, 0, index);
}

//+------------------------------------------------------------------+
//| Obter valor de RSI                                               |
//+------------------------------------------------------------------+
double CMarketContext::GetRSIValue(int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   return GetIndicatorValue(m_rsiHandle, 0, index);
}

//+------------------------------------------------------------------+
//| Obter valor de ATR                                               |
//+------------------------------------------------------------------+
double CMarketContext::GetATRValue(int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   return GetIndicatorValue(m_atrHandle, 0, index);
}

//+------------------------------------------------------------------+
//| Obter valor de MACD                                              |
//+------------------------------------------------------------------+
double CMarketContext::GetMACDValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   return GetIndicatorValue(m_macdHandle, buffer, index);
}

//+------------------------------------------------------------------+
//| Obter valor de Stochastic                                        |
//+------------------------------------------------------------------+
double CMarketContext::GetStochasticValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   return GetIndicatorValue(m_stochHandle, buffer, index);
}

//+------------------------------------------------------------------+
//| Obter valor de Bollinger Bands                                   |
//+------------------------------------------------------------------+
double CMarketContext::GetBollingerValue(int buffer, int index = 0, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   return GetIndicatorValue(m_bollingerHandle, buffer, index);
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
//| Atualizar profundidade de mercado                                |
//+------------------------------------------------------------------+
void CMarketContext::UpdateMarketDepth(string symbol) {
   // Implementação básica - pode ser expandida conforme necessário
   if(m_logger != NULL) {
      m_logger.Debug("Atualizando profundidade de mercado para " + symbol);
   }
}

//+------------------------------------------------------------------+
//| Verificar se o mercado está aberto                               |
//+------------------------------------------------------------------+
bool CMarketContext::IsMarketOpen() {
   return (SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL);
}

//+------------------------------------------------------------------+
//| Verificar alinhamento das médias móveis                          |
//+------------------------------------------------------------------+
bool CMarketContext::CheckMovingAveragesAlignment(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
   double ema9 = GetEMAValue(9, 0, timeframe);
   double ema21 = GetEMAValue(21, 0, timeframe);
   double ema50 = GetEMAValue(50, 0, timeframe);
   double ema200 = GetEMAValue(200, 0, timeframe);
   
   if(ema9 == EMPTY_VALUE || ema21 == EMPTY_VALUE || ema50 == EMPTY_VALUE) {
      return false;
   }
   
   // Verificar alinhamento para tendência de alta
   if(ema9 > ema21 && ema21 > ema50) {
      return true;
   }
   
   // Verificar alinhamento para tendência de baixa
   if(ema9 < ema21 && ema21 < ema50) {
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
      // Se não temos MACD, verificar RSI
      double rsi = GetRSIValue(0, timeframe);
      if(rsi != EMPTY_VALUE) {
         return (rsi > 50 && rsi < 80) || (rsi < 50 && rsi > 20);
      }
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
//| Encontrar suporte mais próximo                                   |
//+------------------------------------------------------------------+
double CMarketContext::FindNearestSupport(double price, int lookbackBars = 50) {
   double lowBuffer[];
   ArraySetAsSeries(lowBuffer, true);
   
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
   double highBuffer[];
   ArraySetAsSeries(highBuffer, true);
   
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
   double atr = GetATRValue(0, timeframe);
   return (atr != EMPTY_VALUE) ? atr : 0.0;
}

//+------------------------------------------------------------------+
//| Obter razão de volatilidade                                      |
//+------------------------------------------------------------------+
double CMarketContext::GetVolatilityRatio() {
   if(!m_hasValidData || m_atrHandle == INVALID_HANDLE) {
      return 1.0;
   }
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(m_atrHandle, 0, 0, 20, atrBuffer) <= 0) {
      return 1.0;
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
   
   return 1.0;
}

//+------------------------------------------------------------------+
//| Verificar se um indicador está pronto                            |
//+------------------------------------------------------------------+
bool CMarketContext::IsIndicatorReady(int handle, int minBars = 50) {
   if(handle == INVALID_HANDLE) {
      return false;
   }
   
   if(m_indicatorManager != NULL) {
      return m_indicatorManager.IsReady(handle, minBars);
   }
   
   return (BarsCalculated(handle) >= minBars);
}

//+------------------------------------------------------------------+
//| Imprimir informações de debug                                    |
//+------------------------------------------------------------------+
void CMarketContext::PrintDebugInfo() {
   if(m_logger == NULL) return;
   
   m_logger.Info("=== MarketContext Debug Info ===");
   m_logger.Info(StringFormat("Símbolo: %s | Timeframe: %s", m_symbol, EnumToString(m_timeframe)));
   m_logger.Info(StringFormat("Dados válidos: %s | Fase atual: %s", 
                            m_hasValidData ? "Sim" : "Não", 
                            EnumToString(m_currentPhase)));
   
   if(m_indicatorManager != NULL) {
      m_logger.Info(StringFormat("IndicatorManager: Ativo | Handles: %d", 
                               m_indicatorManager.GetHandleCount()));
   } else {
      m_logger.Info("IndicatorManager: NULL");
   }
   
   // Status dos handles
   m_logger.Info("Status dos Handles:");
   m_logger.Info(StringFormat("  EMA9: %s | EMA21: %s | EMA50: %s | EMA200: %s",
                            m_ema9Handle != INVALID_HANDLE ? "OK" : "INVALID",
                            m_ema21Handle != INVALID_HANDLE ? "OK" : "INVALID",
                            m_ema50Handle != INVALID_HANDLE ? "OK" : "INVALID",
                            m_ema200Handle != INVALID_HANDLE ? "OK" : "INVALID"));
   m_logger.Info(StringFormat("  RSI: %s | ATR: %s | MACD: %s | Stoch: %s | BB: %s",
                            m_rsiHandle != INVALID_HANDLE ? "OK" : "INVALID",
                            m_atrHandle != INVALID_HANDLE ? "OK" : "INVALID",
                            m_macdHandle != INVALID_HANDLE ? "OK" : "INVALID",
                            m_stochHandle != INVALID_HANDLE ? "OK" : "INVALID",
                            m_bollingerHandle != INVALID_HANDLE ? "OK" : "INVALID"));
   
   // Valores atuais
   double ema9 = GetEMAValue(9);
   double ema21 = GetEMAValue(21);
   double ema50 = GetEMAValue(50);
   double rsi = GetRSIValue();
   
   m_logger.Info("Valores Atuais:");
   m_logger.Info(StringFormat("  EMA9: %s | EMA21: %s | EMA50: %s",
                            ema9 != EMPTY_VALUE ? DoubleToString(ema9, 5) : "N/A",
                            ema21 != EMPTY_VALUE ? DoubleToString(ema21, 5) : "N/A",
                            ema50 != EMPTY_VALUE ? DoubleToString(ema50, 5) : "N/A"));
   m_logger.Info(StringFormat("  RSI: %s | Tendência: %s",
                            rsi != EMPTY_VALUE ? DoubleToString(rsi, 2) : "N/A",
                            CheckTrendDirection() > 0 ? "Alta" : (CheckTrendDirection() < 0 ? "Baixa" : "Lateral")));
}

//+------------------------------------------------------------------+