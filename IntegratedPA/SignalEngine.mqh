
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
   CSetupClassifier *m_setupClassifier;
   // CACHE SPIKE AND CHANNEL
   CSpikeAndChannel *m_spikeAndChannelCache;
   // Cache de validação por símbolo/timeframe
   struct SymbolValidationCache
   {
      string symbol;
      ENUM_TIMEFRAMES timeframe;
      datetime lastValidation;
      bool isValid;
      int validitySeconds;
   };
   SymbolValidationCache m_symbolCache[];

   // Cooldown para evitar sinais repetitivos
   struct SignalCooldown
   {
      string symbol;
      string strategy;
      datetime lastSignalTime;
      int cooldownSeconds;
   };
   SignalCooldown m_signalCooldowns[];

   // Métodos para gerenciamento de cache
   bool IsInCooldown(string symbol, string strategy);
   void AddToCooldown(string symbol, string strategy, int cooldownSeconds = 180);
   bool GetCachedValidation(string symbol, ENUM_TIMEFRAMES timeframe);
   void SetCachedValidation(string symbol, ENUM_TIMEFRAMES timeframe, bool isValid);

   //------------------------------------------------------------------------------------
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
   bool CheckIndicatorReady(int handle, string symbol, string context);
   int SafeCopyBuffer(int handle, int bufferIndex, int start, int count, double &buffer[], string symbol, string context);
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
   m_spikeAndChannelCache = NULL;
   ArrayResize(m_symbolCache, 0);
   ArrayResize(m_signalCooldowns, 0);
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
   if (m_setupClassifier != NULL)
   {
      delete m_setupClassifier;
      m_setupClassifier = NULL;
   }

   if (m_spikeAndChannelCache != NULL)
   {
      delete m_spikeAndChannelCache;
      m_spikeAndChannelCache = NULL;
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
   if (m_setupClassifier != NULL)
   {
      delete m_setupClassifier;
   }

   m_setupClassifier = new CSetupClassifier(m_logger, m_marketContext);
   if (m_setupClassifier == NULL)
   {
      m_logger.Error("SignalEngine: Falha ao criar SetupClassifier");
      return false;
   }

   if (!m_setupClassifier.Initialize(m_logger, m_marketContext))
   {
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
bool CSignalEngine::CheckDataValidity(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod = "") {
   ENUM_TIMEFRAMES normalizedTF = NormalizeTimeframe(timeframe);
   
   // OTIMIZAÇÃO: Verificar cache primeiro
   if(GetCachedValidation(symbol, normalizedTF)) {
      return true;
   }
   
   // Realizar validação completa
   bool result = PerformFullValidation(symbol, normalizedTF, callingMethod);
   
   // OTIMIZAÇÃO: Armazenar no cache
   SetCachedValidation(symbol, normalizedTF, result);
   
   // OTIMIZAÇÃO: Log apenas se for erro ou primeira validação
   if(!result || callingMethod == "CSignalEngine::IsDataValid") {
      LogValidationResult(result, symbol, normalizedTF, callingMethod);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Executa validação completa dos dados                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Função auxiliar para verificar disponibilidade de dados          |
//+------------------------------------------------------------------+
bool CSignalEngine::CheckIndicatorReady(int handle, string symbol, string context = "")
{
   if(handle == INVALID_HANDLE) {
      if(m_logger != NULL) {
         m_logger.Error("SignalEngine: " + context + "Handle inválido para " + symbol);
      }
      return false;
   }
   
   // Verificar se o indicador calculou dados suficientes
   int calculated = BarsCalculated(handle);
   if(calculated < 0) {
      if(m_logger != NULL) {
         m_logger.Debug("SignalEngine: " + context + "Indicador não pronto para " + symbol + " (BarsCalculated: " + IntegerToString(calculated) + ")");
      }
      return false;
   }
   
   if(calculated < 20) { // Mínimo para análise
      if(m_logger != NULL) {
         m_logger.Debug("SignalEngine: " + context + "Indicador com poucas barras para " + symbol + " (" + IntegerToString(calculated) + "/20)");
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Função auxiliar para copiar buffer com retry                     |
//+------------------------------------------------------------------+
int CSignalEngine::SafeCopyBuffer(int handle, int bufferIndex, int start, int count, double &buffer[], string symbol = "", string context = "")
{
   if(!CheckIndicatorReady(handle, symbol, context)) {
      return -1;
   }
   
   ArraySetAsSeries(buffer, true);
   int attempts = 0;
   int maxAttempts = 3;
   int copied = 0;
   
   while(attempts < maxAttempts) {
      ResetLastError();
      copied = CopyBuffer(handle, bufferIndex, start, count, buffer);
      
      if(copied >= count) {
         return copied; // Sucesso
      }
      
      int error = GetLastError();
      attempts++;
      
      if(error == 4806 && attempts < maxAttempts) {
         // Aguardar e tentar novamente
         Sleep(5 + attempts * 5); // Espera progressiva: 10ms, 15ms, 20ms
         continue;
      } else {
         // Falha definitiva
         if(m_logger != NULL && symbol != "") {
            m_logger.Debug("SignalEngine: " + context + "Falha ao copiar buffer para " + symbol + 
                         " após " + IntegerToString(attempts) + " tentativas - Erro: " + IntegerToString(error));
         }
         break;
      }
   }
   
   return copied;
}

//+------------------------------------------------------------------+
//| Versão melhorada do método de validação com cache                |
//+------------------------------------------------------------------+
bool CSignalEngine::PerformFullValidation(string symbol, ENUM_TIMEFRAMES timeframe, string callingMethod)
{
   if (!ValidateBasicParameters(symbol, timeframe, callingMethod))
      return false;

   if (!ValidateMarketData(symbol, timeframe, callingMethod))
      return false;

   // *** VALIDAÇÃO MELHORADA DE INDICADORES ***
   string context = (callingMethod != "") ? callingMethod + ": " : "";
   
   // Criar handle temporário para teste
   int testHandle = iMA(symbol, timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   
   if(testHandle == INVALID_HANDLE) {
      if (m_logger != NULL)
         m_logger.Error("SignalEngine: " + context + "Falha ao criar handle de teste para " + symbol);
      return false;
   }
   
   // Verificar se está pronto
   bool isReady = CheckIndicatorReady(testHandle, symbol, context);
   
   if(isReady) {
      // Tentar copiar dados
      double testBuffer[];
      int copied = SafeCopyBuffer(testHandle, 0, 0, 3, testBuffer, symbol, context);
      isReady = (copied > 0);
   }
   
   // Liberar handle de teste
   IndicatorRelease(testHandle);
   
   if(!isReady) {
      if (m_logger != NULL) {
         m_logger.Debug("SignalEngine: " + context + "Indicadores não prontos para " + symbol + " - aguardando próximo tick");
      }
      return false;
   }

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

   // *** CORREÇÃO PRINCIPAL: Verificar se o indicador está pronto ***
   int calculated = BarsCalculated(maHandle.GetHandle());
   if(calculated < 0) {
      if (m_logger != NULL)
         m_logger.Warning("SignalEngine: " + context + "Indicador não calculado para " + symbol + " (BarsCalculated: " + IntegerToString(calculated) + ")");
      return false;
   }
   
   if(calculated < 50) { // Precisamos de pelo menos 50 barras calculadas
      if (m_logger != NULL)
         m_logger.Warning("SignalEngine: " + context + "Indicador com poucas barras calculadas para " + symbol + " (" + IntegerToString(calculated) + "/50)");
      return false;
   }

   // *** TENTATIVA COM RETRY E TIMEOUT ***
   double maBuffer[];
   ArraySetAsSeries(maBuffer, true);
   
   int attempts = 0;
   int maxAttempts = 3;
   int copied = 0;
   
   while(attempts < maxAttempts) {
      ResetLastError();
      copied = CopyBuffer(maHandle.GetHandle(), 0, 0, 3, maBuffer);
      
      if(copied > 0) {
         break; // Sucesso!
      }
      
      int error = GetLastError();
      attempts++;
      
      if(error == 4806) { // ERR_INDICATOR_DATA_NOT_FOUND
         if (m_logger != NULL) {
            m_logger.Debug("SignalEngine: " + context + "Tentativa " + IntegerToString(attempts) + "/" + IntegerToString(maxAttempts) + 
                         " - Dados do indicador não encontrados para " + symbol + " (erro 4806)");
         }
         
         if(attempts < maxAttempts) {
            Sleep(10); // Aguardar 10ms antes da próxima tentativa
            continue;
         }
      } else {
         // Outro tipo de erro
         if (m_logger != NULL) {
            m_logger.Error("SignalEngine: " + context + "Erro diferente de 4806 ao copiar dados de indicador para " +
                         symbol + " - Erro: " + IntegerToString(error));
         }
         return false;
      }
   }
   
   if(copied <= 0) {
      if (m_logger != NULL) {
         m_logger.Warning("SignalEngine: " + context + "Falha ao copiar dados de indicador para " + symbol + 
                        " após " + IntegerToString(maxAttempts) + " tentativas - Erro: " + IntegerToString(GetLastError()));
      }
      return false;
   }

   // *** VERIFICAÇÃO DE SPREAD (warning apenas) ***
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
   if (m_logger == NULL)
      return;

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
   if (StringFind(symbol, "WIN") >= 0)
      return 10.0; // Mini Índice
   if (StringFind(symbol, "WDO") >= 0)
      return 3.0; // Mini Dólar
   if (StringFind(symbol, "BIT") >= 0)
      return 50.0; // Bitcoin

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
   if (signal.id > 0)
      return signal;

   signal = GeneratePullbackToEMASignal(symbol, timeframe);
   if (signal.id > 0)
      return signal;

   signal = GenerateBreakoutPullbackSignal(symbol, timeframe);
   if (signal.id > 0)
      return signal;

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
   if (signal.id > 0)
      return signal;

   signal = GenerateFailedBreakoutSignal(symbol, timeframe);
   if (signal.id > 0)
      return signal;

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
   if (signal.id > 0)
      return signal;

   signal = GenerateDivergenceSignal(symbol, timeframe);
   if (signal.id > 0)
      return signal;

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
   if (m_setupClassifier == NULL)
   {
      if (m_logger != NULL)
      {
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
   if (signal.id <= 0)
      return false;
   if (signal.symbol == "")
      return false;
   if (signal.direction != ORDER_TYPE_BUY && signal.direction != ORDER_TYPE_SELL)
      return false;
   if (signal.entryPrice <= 0 || signal.stopLoss <= 0)
      return false;

   // Verificar se o stop loss está no lado correto da entrada
   if (signal.direction == ORDER_TYPE_BUY && signal.stopLoss >= signal.entryPrice)
      return false;
   if (signal.direction == ORDER_TYPE_SELL && signal.stopLoss <= signal.entryPrice)
      return false;

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

   if (!hasValidTakeProfit)
      return false;

   // Verificar se a relação risco/retorno é aceitável
   signal.CalculateRiskRewardRatio();
   if (signal.riskRewardRatio < m_minRiskReward)
      return false;

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
Signal CSignalEngine::GenerateSpikeAndChannelSignal(string symbol, ENUM_TIMEFRAMES timeframe) {
   Signal signal;
   signal.id = 0;

   if(!CheckDataValidity(symbol, timeframe, "GenerateSpikeAndChannelSignal"))
      return signal;

   if(m_marketContext != NULL && !m_marketContext.IsTrendUp() && !m_marketContext.IsTrendDown()) {
      if(m_logger != NULL)
         m_logger.Debug("SignalEngine: Mercado não está em tendência para padrão Spike & Channel");
      return signal;
   }

   // OTIMIZAÇÃO: Verificar cooldown antes de processar
   if(IsInCooldown(symbol, "Spike and Channel")) {
      if(m_logger != NULL) {
         m_logger.Debug("SignalEngine: Spike & Channel em cooldown para " + symbol);
      }
      return signal;
   }

   // OTIMIZAÇÃO: Reutilizar objeto em cache
   if(m_spikeAndChannelCache == NULL) {
      m_spikeAndChannelCache = new CSpikeAndChannel();
      if(m_spikeAndChannelCache == NULL) {
         if(m_logger != NULL)
            m_logger.Error("SignalEngine: Falha ao criar objeto SpikeAndChannel");
         return signal;
      }

      if(!m_spikeAndChannelCache.Initialize(m_logger, m_marketContext)) {
         if(m_logger != NULL)
            m_logger.Error("SignalEngine: Falha ao inicializar objeto SpikeAndChannel");
         delete m_spikeAndChannelCache;
         m_spikeAndChannelCache = NULL;
         return signal;
      }

      // Configurar parâmetros apenas uma vez
      m_spikeAndChannelCache.SetSpikeParameters(3, 5, 0.7);
      m_spikeAndChannelCache.SetChannelParameters(0.3);
      m_spikeAndChannelCache.SetLookbackBars(m_lookbackBars);
      
      if(m_logger != NULL) {
         m_logger.Info("SignalEngine: SpikeAndChannel cache criado e configurado");
      }
   }

   SpikeChannelPattern pattern;
   if(!m_spikeAndChannelCache.DetectPattern(symbol, timeframe, pattern)) {
      if(m_logger != NULL)
         m_logger.Debug("SignalEngine: Padrão Spike & Channel não detectado para " + symbol);
      return signal;
   }

   // Tentar diferentes tipos de entrada em ordem de prioridade
   SPIKE_CHANNEL_ENTRY_TYPE entryTypes[] = {
      ENTRY_PULLBACK_LINHA_TENDENCIA,
      ENTRY_FALHA_PULLBACK,
      ENTRY_PULLBACK_MINIMO,
      ENTRY_FECHAMENTO_FORTE
   };
   
   for(int i = 0; i < ArraySize(entryTypes); i++) {
      signal = m_spikeAndChannelCache.GenerateSignal(symbol, timeframe, pattern, entryTypes[i]);
      if(signal.id > 0) {
         // OTIMIZAÇÃO: Adicionar ao cooldown quando sinal for gerado
         AddToCooldown(symbol, "Spike and Channel", 180); // 3 minutos
         break;
      }
   }

   if(signal.id > 0) {
      signal.timeframe = timeframe;
      if(m_logger != NULL) {
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

bool CSignalEngine::IsInCooldown(string symbol, string strategy)
{
   datetime currentTime = TimeCurrent();

   for (int i = 0; i < ArraySize(m_signalCooldowns); i++)
   {
      if (m_signalCooldowns[i].symbol == symbol &&
          m_signalCooldowns[i].strategy == strategy)
      {

         if (currentTime - m_signalCooldowns[i].lastSignalTime < m_signalCooldowns[i].cooldownSeconds)
         {
            return true;
         }
         else
         {
            // Remover cooldown expirado
            for (int j = i; j < ArraySize(m_signalCooldowns) - 1; j++)
            {
               m_signalCooldowns[j] = m_signalCooldowns[j + 1];
            }
            ArrayResize(m_signalCooldowns, ArraySize(m_signalCooldowns) - 1);
            return false;
         }
      }
   }

   return false;
}

void CSignalEngine::AddToCooldown(string symbol, string strategy, int cooldownSeconds = 180)
{
   // Verificar se já existe
   for (int i = 0; i < ArraySize(m_signalCooldowns); i++)
   {
      if (m_signalCooldowns[i].symbol == symbol &&
          m_signalCooldowns[i].strategy == strategy)
      {
         m_signalCooldowns[i].lastSignalTime = TimeCurrent();
         m_signalCooldowns[i].cooldownSeconds = cooldownSeconds;
         return;
      }
   }

   // Adicionar novo
   int size = ArraySize(m_signalCooldowns);
   ArrayResize(m_signalCooldowns, size + 1);
   m_signalCooldowns[size].symbol = symbol;
   m_signalCooldowns[size].strategy = strategy;
   m_signalCooldowns[size].lastSignalTime = TimeCurrent();
   m_signalCooldowns[size].cooldownSeconds = cooldownSeconds;
}

bool CSignalEngine::GetCachedValidation(string symbol, ENUM_TIMEFRAMES timeframe)
{
   datetime currentTime = TimeCurrent();

   for (int i = 0; i < ArraySize(m_symbolCache); i++)
   {
      if (m_symbolCache[i].symbol == symbol &&
          m_symbolCache[i].timeframe == timeframe)
      {

         if (currentTime - m_symbolCache[i].lastValidation < m_symbolCache[i].validitySeconds)
         {
            return m_symbolCache[i].isValid;
         }
         else
         {
            // Cache expirado, remover
            for (int j = i; j < ArraySize(m_symbolCache) - 1; j++)
            {
               m_symbolCache[j] = m_symbolCache[j + 1];
            }
            ArrayResize(m_symbolCache, ArraySize(m_symbolCache) - 1);
            return false;
         }
      }
   }

   return false;
}
void CSignalEngine::SetCachedValidation(string symbol, ENUM_TIMEFRAMES timeframe, bool isValid)
{
   // Verificar se já existe
   for (int i = 0; i < ArraySize(m_symbolCache); i++)
   {
      if (m_symbolCache[i].symbol == symbol &&
          m_symbolCache[i].timeframe == timeframe)
      {
         m_symbolCache[i].isValid = isValid;
         m_symbolCache[i].lastValidation = TimeCurrent();
         return;
      }
   }

   // Adicionar novo
   int size = ArraySize(m_symbolCache);
   ArrayResize(m_symbolCache, size + 1);
   m_symbolCache[size].symbol = symbol;
   m_symbolCache[size].timeframe = timeframe;
   m_symbolCache[size].isValid = isValid;
   m_symbolCache[size].lastValidation = TimeCurrent();
   m_symbolCache[size].validitySeconds = 300; // 5 minutos
}