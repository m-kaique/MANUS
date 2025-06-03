
//+------------------------------------------------------------------+
//|                                              SignalEngine.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

#include "Structures.mqh"
#include "Utils.mqh"
#include "Logger.mqh"
#include "MarketContext.mqh"
#include "SetupClassifier.mqh"

// Strategies
#include "strategies/SpikeAndChannel.mqh"

//+------------------------------------------------------------------+
//| Estrutura para cache de validação                                |
//+------------------------------------------------------------------+
struct ValidationCache
{
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime lastValidation;
   bool isValid;
   int validityPeriodSeconds;
   
   ValidationCache()
   {
      symbol = "";
      timeframe = PERIOD_CURRENT;
      lastValidation = 0;
      isValid = false;
      validityPeriodSeconds = 300; // 5 minutos
   }
   
   bool IsExpired()
   {
      return (TimeCurrent() - lastValidation) > validityPeriodSeconds;
   }
   
   void Update(string sym, ENUM_TIMEFRAMES tf, bool valid)
   {
      symbol = sym;
      timeframe = tf;
      isValid = valid;
      lastValidation = TimeCurrent();
   }
   
   bool Matches(string sym, ENUM_TIMEFRAMES tf)
   {
      return (symbol == sym && timeframe == tf);
   }
};

//+------------------------------------------------------------------+
//| Classe RAII para gerenciamento de handles de indicadores         |
//+------------------------------------------------------------------+
class CIndicatorHandle
{
private:
   int m_handle;
   
public:
   CIndicatorHandle() : m_handle(INVALID_HANDLE) {}
   
   ~CIndicatorHandle()
   {
      Release();
   }
   
   void SetHandle(int handle)
   {
      Release(); // Libera handle anterior se existir
      m_handle = handle;
   }
   
   int GetHandle() const { return m_handle; }
   
   bool IsValid() const { return m_handle != INVALID_HANDLE; }
   
   void Release()
   {
      if (m_handle != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle);
         m_handle = INVALID_HANDLE;
      }
   }
};

//+------------------------------------------------------------------+
//| Classe para geração de sinais de trading                         |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
   CLogger *m_logger;               
   CMarketContext *m_marketContext;
   CSetupClassifier* m_setupClassifier;

   // Configurações
   int m_lookbackBars;     
   double m_minRiskReward; 
   
   // Cache de validação
   ValidationCache m_validationCache;
   
   // Métodos privados auxiliares
   bool IsValidSignal(Signal &signal);
   bool HasConfirmation(string symbol, ENUM_TIMEFRAMES timeframe, int signalType);
   double CalculateSignalStrength(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);
   bool CheckDataValidity(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod = "");
   bool PerformFullValidation(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod);
   ENUM_TIMEFRAMES NormalizeTimeframe(ENUM_TIMEFRAMES timeframe);
   bool ValidateBasicParameters(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod);
   bool ValidateMarketData(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod);
   bool ValidateIndicatorAccess(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod);
   void LogValidationResult(bool result, string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod);

   // Métodos privados para estratégias específicas de tendência
   Signal GenerateSpikeAndChannelSignal(string symbol, ENUM_TIMEFRAMES timeframe);
   Signal GeneratePullbackToEMASignal(string symbol, ENUM_TIMEFRAMES timeframe);
   Signal GenerateBreakoutPullbackSignal(string symbol, ENUM_TIMEFRAMES timeframe);

   // Métodos privados para estratégias específicas de range
   Signal GenerateRangeExtremesRejectionSignal(string symbol, ENUM_TIMEFRAMES timeframe);
   Signal GenerateFailedBreakoutSignal(string symbol, ENUM_TIMEFRAMES timeframe);

   // Métodos privados para estratégias específicas de reversão
   Signal GenerateReversalPatternSignal(string symbol, ENUM_TIMEFRAMES timeframe);
   Signal GenerateDivergenceSignal(string symbol, ENUM_TIMEFRAMES timeframe);

public:
   // Construtores e destrutor
   CSignalEngine();
   CSignalEngine(CLogger *logger, CMarketContext *marketContext);
   ~CSignalEngine();

   // Método de inicialização
   bool Initialize(CLogger *logger, CMarketContext *marketContext);

   // Método principal para geração de sinais
   Signal Generate(string symbol, MARKET_PHASE phase, ENUM_TIMEFRAMES timeframe);

   // Métodos para estratégias específicas por fase de mercado
   Signal GenerateTrendSignals(string symbol, ENUM_TIMEFRAMES timeframe);
   Signal GenerateRangeSignals(string symbol, ENUM_TIMEFRAMES timeframe);
   Signal GenerateReversalSignals(string symbol, ENUM_TIMEFRAMES timeframe);

   // Método para classificação de qualidade de setup
   SETUP_QUALITY ClassifySetupQuality(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal);

   // Métodos de configuração
   void SetLookbackBars(int bars) { m_lookbackBars = MathMax(bars, 50); }
   void SetMinRiskReward(double ratio) { m_minRiskReward = MathMax(ratio, 1.0); }
   void SetValidationCachePeriod(int seconds) { m_validationCache.validityPeriodSeconds = MathMax(seconds, 60); }

   // Métodos utilitários
   double GetMaxAllowedSpread(string symbol);
   bool IsDataValid(string symbol, ENUM_TIMEFRAMES timeframe);
   void ClearValidationCache() { m_validationCache = ValidationCache(); }
};

//+------------------------------------------------------------------+
//| Construtor padrão                                                |
//+------------------------------------------------------------------+
CSignalEngine::CSignalEngine()
{
   m_logger = NULL;
   m_marketContext = NULL;
   m_setupClassifier = NULL;
   m_lookbackBars = 100;
   m_minRiskReward = 1.5;
   m_validationCache = ValidationCache();
}

//+------------------------------------------------------------------+
//| Construtor com parâmetros                                        |
//+------------------------------------------------------------------+
CSignalEngine::CSignalEngine(CLogger *logger, CMarketContext *marketContext)
{
   m_logger = logger;
   m_marketContext = marketContext;
   m_setupClassifier = NULL;
   m_lookbackBars = 100;
   m_minRiskReward = 1.5;
   m_validationCache = ValidationCache();
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CSignalEngine::~CSignalEngine()
{
   // Liberar SetupClassifier
   if (m_setupClassifier != NULL) {
      delete m_setupClassifier;
      m_setupClassifier = NULL;
   }
   // Não liberamos m_logger e m_marketContext aqui pois são apenas referências
}

//+------------------------------------------------------------------+
//| Inicializa o motor de sinais                                     |
//+------------------------------------------------------------------+
bool CSignalEngine::Initialize(CLogger *logger, CMarketContext *marketContext)
{
   if (logger == NULL || marketContext == NULL)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("SignalEngine: Falha na inicialização - parâmetros inválidos");
      }
      return false;
   }

   m_logger = logger;
   m_marketContext = marketContext;

   // ADICIONAR: Criar e inicializar SetupClassifier
   if (m_setupClassifier != NULL) {
      delete m_setupClassifier;
   }

    m_setupClassifier = new CSetupClassifier(m_logger, m_marketContext);
   if (m_setupClassifier == NULL) {
      m_logger.Error("SignalEngine: Falha ao criar SetupClassifier");
      return false;
   }
   
   if (!m_setupClassifier.Initialize(m_logger, m_marketContext)) {
      m_logger.Error("SignalEngine: Falha ao inicializar SetupClassifier");
      delete m_setupClassifier;
      m_setupClassifier = NULL;
      return false;
   }
   
   m_validationCache = ValidationCache();
   m_logger.Info("SignalEngine inicializado com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Normaliza timeframe                                              |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES CSignalEngine::NormalizeTimeframe(ENUM_TIMEFRAMES timeframe)
{
   if (timeframe == PERIOD_CURRENT)
   {
      return Period();
   }
   return timeframe;
}

//+------------------------------------------------------------------+
//| Verifica se os dados são válidos (com cache)                     |
//+------------------------------------------------------------------+
bool CSignalEngine::CheckDataValidity(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod = "")
{
   ENUM_TIMEFRAMES normalizedTF = NormalizeTimeframe(timeframe);
   
   // Verificar cache primeiro
   if (m_validationCache.Matches(symbol, normalizedTF) && !m_validationCache.IsExpired())
   {
      return m_validationCache.isValid;
   }
   
   // Realizar validação completa
   bool result = PerformFullValidation(symbol, normalizedTF, callingMethod);
   
   // Atualizar cache
   m_validationCache.Update(symbol, normalizedTF, result);
   
   LogValidationResult(result, symbol, normalizedTF, callingMethod);
   
   return result;
}

//+------------------------------------------------------------------+
//| Executa validação completa dos dados                             |
//+------------------------------------------------------------------+
bool CSignalEngine::PerformFullValidation(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod)
{
   if (!ValidateBasicParameters(symbol, timeframe, callingMethod))
      return false;
      
   if (!ValidateMarketData(symbol, timeframe, callingMethod))
      return false;
      
   if (!ValidateIndicatorAccess(symbol, timeframe, callingMethod))
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Valida parâmetros básicos                                        |
//+------------------------------------------------------------------+
bool CSignalEngine::ValidateBasicParameters(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod)
{
   string context = (callingMethod != "") ? callingMethod + ": " : "";

   if (symbol == "" || StringLen(symbol) == 0)
   {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: " + context + "Símbolo inválido");
      return false;
   }

   if (!SymbolSelect(symbol, true))
   {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: " + context + "Símbolo indisponível: " + symbol);
      return false;
   }

   if (timeframe == PERIOD_CURRENT)
   {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: " + context + "Timeframe não normalizado");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Valida dados de mercado                                          |
//+------------------------------------------------------------------+
bool CSignalEngine::ValidateMarketData(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod)
{
   string context = (callingMethod != "") ? callingMethod + ": " : "";

   int bars = Bars(symbol, timeframe);
   if (bars < m_lookbackBars)
   {
      if (m_logger != NULL)
         m_logger.Warning("SignalEngine: " + context + "Histórico insuficiente para " + symbol +
                         " - Necessário: " + IntegerToString(m_lookbackBars) + 
                         ", Disponível: " + IntegerToString(bars));
      return false;
   }

   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if (CopyClose(symbol, timeframe, 0, 3, close) <= 0 ||
       CopyHigh(symbol, timeframe, 0, 3, high) <= 0 ||
       CopyLow(symbol, timeframe, 0, 3, low) <= 0)
   {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: " + context + "Falha ao acessar dados OHLC de " + symbol);
      return false;
   }

   for (int i = 0; i < ArraySize(close); i++)
   {
      if (close[i] <= 0 || high[i] <= 0 || low[i] <= 0 || high[i] < low[i])
      {
         if (m_logger != NULL)
            m_logger.Error("SignalEngine: " + context + "Dados OHLC inválidos para " + symbol);
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Valida acesso a indicadores                                      |
//+------------------------------------------------------------------+
bool CSignalEngine::ValidateIndicatorAccess(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod)
{
   string context = (callingMethod != "") ? callingMethod + ": " : "";
   
   CIndicatorHandle maHandle;
   maHandle.SetHandle(iMA(symbol, timeframe, 20, 0, MODE_EMA, PRICE_CLOSE));
   
   if (!maHandle.IsValid())
   {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: " + context + "Falha ao criar indicador para " + symbol);
      return false;
   }

   double maBuffer[];
   ArraySetAsSeries(maBuffer, true);
   int copied = CopyBuffer(maHandle.GetHandle(), 0, 0, 3, maBuffer);
   
   if (copied <= 0)
   {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: " + context + "Falha ao copiar dados de indicador para " + 
                        symbol + " - Erro: " + IntegerToString(GetLastError()));
      return false;
   }

   // Verificação de spread (warning apenas)
   MqlTick tick;
   if (SymbolInfoTick(symbol, tick))
   {
      double spread = tick.ask - tick.bid;
      double maxSpread = GetMaxAllowedSpread(symbol);

      if (spread > maxSpread)
      {
         if (m_logger != NULL)
            m_logger.Warning("SignalEngine: " + context + "Spread elevado para " + symbol +
                             ": " + DoubleToString(spread, 5) + 
                             " (máx: " + DoubleToString(maxSpread, 5) + ")");
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Log do resultado da validação                                    |
//+------------------------------------------------------------------+
void CSignalEngine::LogValidationResult(bool result, string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod)
{
   if (m_logger == NULL) return;
   
   string context = (callingMethod != "") ? callingMethod + ": " : "";
   
   if (result)
   {
      m_logger.Debug("SignalEngine: " + context + "Dados válidos para " + symbol + 
                     " (" + EnumToString(timeframe) + ")");
   }
   else
   {
      m_logger.Warning("SignalEngine: " + context + "Dados inválidos para " + symbol + 
                       " (" + EnumToString(timeframe) + ")");
   }
}

//+------------------------------------------------------------------+
//| Função auxiliar para spread máximo permitido                     |
//+------------------------------------------------------------------+
double CSignalEngine::GetMaxAllowedSpread(string symbol)
{
   // Spreads específicos por tipo de ativo
   if (StringFind(symbol, "WIN") >= 0) return 10.0;  // Mini Índice
   if (StringFind(symbol, "WDO") >= 0) return 3.0;   // Mini Dólar
   if (StringFind(symbol, "BIT") >= 0) return 50.0;  // Bitcoin
   
   // Para outros símbolos: 3x o spread atual
   long currentSpreadPoints = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double currentSpread = currentSpreadPoints * point;
   
   return MathMax(currentSpread * 3.0, point * 5.0); // Mínimo de 5 pontos
}

//+------------------------------------------------------------------+
//| Verifica se os dados são válidos (interface pública)             |
//+------------------------------------------------------------------+
bool CSignalEngine::IsDataValid(string symbol, ENUM_TIMEFRAMES timeframe)
{
   return CheckDataValidity(symbol, timeframe, "CSignalEngine::IsDataValid");
}

//+------------------------------------------------------------------+
//| Método principal para geração de sinais                          |
//+------------------------------------------------------------------+
Signal CSignalEngine::Generate(string symbol, MARKET_PHASE phase, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0; // Sinal vazio/inválido por padrão

   // Normalizar timeframe
   ENUM_TIMEFRAMES normalizedTimeframe = NormalizeTimeframe(timeframe);

   // Verificar se os dados são válidos para análise
   if (!CheckDataValidity(symbol, normalizedTimeframe, "CSignalEngine::Generate"))
   {
      return signal;
   }

   // Gerar sinal com base na fase de mercado
   switch (phase)
   {
   case PHASE_TREND:
      signal = GenerateTrendSignals(symbol, normalizedTimeframe);
      break;
   case PHASE_RANGE:
      signal = GenerateRangeSignals(symbol, normalizedTimeframe);
      break;
   case PHASE_REVERSAL:
      signal = GenerateReversalSignals(symbol, normalizedTimeframe);
      break;
   default:
      if (m_logger != NULL)
         m_logger.Warning("SignalEngine: Fase de mercado não suportada: " + EnumToString(phase));
      break;
   }

   // Processar sinal válido
   if (signal.id > 0 && IsValidSignal(signal))
   {
      signal.quality = ClassifySetupQuality(symbol, normalizedTimeframe, signal);
      signal.generatedTime = TimeCurrent();
      signal.timeframe = normalizedTimeframe; // Garantir que o timeframe está setado

      if (m_logger != NULL)
         m_logger.LogSignal(signal);
   }
   else if (signal.id > 0)
   {
      // Sinal gerado mas inválido
      signal.id = 0;
      if (m_logger != NULL)
         m_logger.Warning("SignalEngine: Sinal gerado para " + symbol + " é inválido");
   }

   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinais para mercados em tendência                           |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateTrendSignals(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   // Verificar se os dados são válidos
   if (!CheckDataValidity(symbol, timeframe, "GenerateTrendSignals"))
      return signal;

   // Verificar se o mercado está realmente em tendência
   if (m_marketContext != NULL && !m_marketContext.IsTrendUp() && !m_marketContext.IsTrendDown())
   {
      if (m_logger != NULL)
         m_logger.Debug("SignalEngine: Mercado não está em tendência para " + symbol);
      return signal;
   }

   // Tentar gerar sinais com diferentes estratégias de tendência
   signal = GenerateSpikeAndChannelSignal(symbol, timeframe);
   if (signal.id > 0) return signal;

   signal = GeneratePullbackToEMASignal(symbol, timeframe);
   if (signal.id > 0) return signal;

   signal = GenerateBreakoutPullbackSignal(symbol, timeframe);
   if (signal.id > 0) return signal;

   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinais para mercados em range                               |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateRangeSignals(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GenerateRangeSignals"))
      return signal;

   if (m_marketContext != NULL && !m_marketContext.IsInRange())
   {
      if (m_logger != NULL)
         m_logger.Debug("SignalEngine: Mercado não está em range para " + symbol);
      return signal;
   }

   signal = GenerateRangeExtremesRejectionSignal(symbol, timeframe);
   if (signal.id > 0) return signal;

   signal = GenerateFailedBreakoutSignal(symbol, timeframe);
   if (signal.id > 0) return signal;

   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinais para mercados em reversão                            |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateReversalSignals(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GenerateReversalSignals"))
      return signal;

   if (m_marketContext != NULL && !m_marketContext.IsInReversal())
   {
      if (m_logger != NULL)
         m_logger.Debug("SignalEngine: Mercado não está em reversão para " + symbol);
      return signal;
   }

   signal = GenerateReversalPatternSignal(symbol, timeframe);
   if (signal.id > 0) return signal;

   signal = GenerateDivergenceSignal(symbol, timeframe);
   if (signal.id > 0) return signal;

   return signal;
}
//+------------------------------------------------------------------+
//| Gera sinal baseado em rejeição de extremos de range              |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateRangeExtremesRejectionSignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GenerateRangeExtremesRejectionSignal"))
      return signal;

   // Implementação será expandida posteriormente
   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinal baseado em falha de breakout                          |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateFailedBreakoutSignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GenerateFailedBreakoutSignal"))
      return signal;

   // Implementação será expandida posteriormente
   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinal baseado em padrão de reversão                         |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateReversalPatternSignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GenerateReversalPatternSignal"))
      return signal;

   // Implementação será expandida posteriormente
   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinal baseado em divergência                                |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateDivergenceSignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GenerateDivergenceSignal"))
      return signal;

   // Implementação será expandida posteriormente
   return signal;
}
//+------------------------------------------------------------------+
//| Classifica a qualidade do setup                                  |
//+------------------------------------------------------------------+
SETUP_QUALITY CSignalEngine::ClassifySetupQuality(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   if (!CheckDataValidity(symbol, timeframe, "ClassifySetupQuality"))
      return SETUP_INVALID;

   if (signal.id <= 0)
      return SETUP_INVALID;
   
   // Verificação de segurança
   if (m_setupClassifier == NULL) {
      if (m_logger != NULL) {
         m_logger.Error("SignalEngine: SetupClassifier não inicializado");
      }
      return SETUP_INVALID;
   }

   return m_setupClassifier.ClassifySetup(symbol, timeframe, signal);
}

//+------------------------------------------------------------------+
//| Verifica se um sinal é válido                                    |
//+------------------------------------------------------------------+
bool CSignalEngine::IsValidSignal(Signal &signal)
{
   if (signal.id <= 0) return false;
   if (signal.symbol == "") return false;
   if (signal.direction != ORDER_TYPE_BUY && signal.direction != ORDER_TYPE_SELL) return false;
   if (signal.entryPrice <= 0 || signal.stopLoss <= 0) return false;

   // Verificar se o stop loss está no lado correto da entrada
   if (signal.direction == ORDER_TYPE_BUY && signal.stopLoss >= signal.entryPrice) return false;
   if (signal.direction == ORDER_TYPE_SELL && signal.stopLoss <= signal.entryPrice) return false;

   // Verificar se pelo menos um take profit é válido e está em ordem lógica
   bool hasValidTakeProfit = false;
   double lastValidTP = signal.entryPrice;
   
   for (int i = 0; i < 3; i++)
   {
      if (signal.takeProfits[i] > 0)
      {
         bool validDirection = false;
         bool validOrder = false;
         
         if (signal.direction == ORDER_TYPE_BUY)
         {
            validDirection = (signal.takeProfits[i] > signal.entryPrice);
            validOrder = (signal.takeProfits[i] > lastValidTP);
         }
         else if (signal.direction == ORDER_TYPE_SELL)
         {
            validDirection = (signal.takeProfits[i] < signal.entryPrice);
            validOrder = (signal.takeProfits[i] < lastValidTP);
         }
         
         if (validDirection && validOrder)
         {
            hasValidTakeProfit = true;
            lastValidTP = signal.takeProfits[i];
         }
         else if (validDirection && !validOrder)
         {
            // TP fora de ordem - invalidar este TP mas continuar verificando
            signal.takeProfits[i] = 0;
         }
         else
         {
            // TP na direção errada - invalidar
            signal.takeProfits[i] = 0;
         }
      }
   }

   if (!hasValidTakeProfit) return false;

   // Verificar se a relação risco/retorno é aceitável
   signal.CalculateRiskRewardRatio();
   if (signal.riskRewardRatio < m_minRiskReward) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Verifica se há confirmação para o sinal                          |
//+------------------------------------------------------------------+
bool CSignalEngine::HasConfirmation(string symbol, ENUM_TIMEFRAMES timeframe, int signalType)
{
   if (!CheckDataValidity(symbol, timeframe, "HasConfirmation"))
      return false;

   // Implementação básica - será expandida posteriormente
   return true;
}

//+------------------------------------------------------------------+
//| Calcula a força do sinal                                         |
//+------------------------------------------------------------------+
double CSignalEngine::CalculateSignalStrength(string symbol, ENUM_TIMEFRAMES timeframe, Signal &signal)
{
   if (!CheckDataValidity(symbol, timeframe, "CalculateSignalStrength"))
      return 0.0;

   // Implementação básica baseada na relação risco/retorno
   double strength = MathMin(signal.riskRewardRatio / 5.0, 1.0);
   return MathMax(strength, 0.0);
}

//+------------------------------------------------------------------+
//| Gera sinal baseado em spike e canal                              |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateSpikeAndChannelSignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GenerateSpikeAndChannelSignal"))
      return signal;

   if (m_marketContext != NULL && !m_marketContext.IsTrendUp() && !m_marketContext.IsTrendDown())
   {
      if (m_logger != NULL)
         m_logger.Debug("SignalEngine: Mercado não está em tendência para padrão Spike & Channel");
      return signal;
   }

   CSpikeAndChannel *spikeAndChannel = new CSpikeAndChannel();
   if (spikeAndChannel == NULL)
   {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: Falha ao criar objeto SpikeAndChannel");
      return signal;
   }

   if (!spikeAndChannel.Initialize(m_logger, m_marketContext))
   {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: Falha ao inicializar objeto SpikeAndChannel");
      delete spikeAndChannel;
      return signal;
   }

   spikeAndChannel.SetSpikeParameters(3, 5, 0.7);
   spikeAndChannel.SetChannelParameters(0.3);
   spikeAndChannel.SetLookbackBars(m_lookbackBars);

   SpikeChannelPattern pattern;
   if (!spikeAndChannel.DetectPattern(symbol, timeframe, pattern))
   {
      if (m_logger != NULL)
         m_logger.Debug("SignalEngine: Padrão Spike & Channel não detectado para " + symbol);
      delete spikeAndChannel;
      return signal;
   }

   // Tentar diferentes tipos de entrada em ordem de prioridade
   SPIKE_CHANNEL_ENTRY_TYPE entryTypes[] = {
      ENTRY_PULLBACK_LINHA_TENDENCIA,
      ENTRY_FALHA_PULLBACK,
      ENTRY_PULLBACK_MINIMO,
      ENTRY_FECHAMENTO_FORTE
   };
   
   for (int i = 0; i < ArraySize(entryTypes); i++)
   {
      signal = spikeAndChannel.GenerateSignal(symbol, timeframe, pattern, entryTypes[i]);
      if (signal.id > 0) break;
   }

   delete spikeAndChannel;

   if (signal.id > 0)
   {
      signal.timeframe = timeframe;
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("SignalEngine: Sinal Spike & Channel gerado para %s - %s",
                                    symbol,
                                    signal.direction == ORDER_TYPE_BUY ? "Compra" : "Venda"));
      }
   }

   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinal baseado em pullback para EMA                          |
//+------------------------------------------------------------------+
Signal CSignalEngine::GeneratePullbackToEMASignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GeneratePullbackToEMASignal"))
      return signal;

   // Implementação será expandida posteriormente
   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinal baseado em breakout e pullback                        |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateBreakoutPullbackSignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0;

   if (!CheckDataValidity(symbol, timeframe, "GenerateBreakoutPullbackSignal"))
      return signal;

   // Implementação será expandida posteriormente
   return signal;
}

//+