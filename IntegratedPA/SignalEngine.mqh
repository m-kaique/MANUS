//+------------------------------------------------------------------+
//|                                              SignalEngine.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include "Structures.mqh"
#include "Utils.mqh"
#include "Logging/Logger.mqh"
#include "MarketContext.mqh"
#include "SetupClassifier.mqh"
#include "Risk/CircuitBreaker.mqh"

// Strategies
#include "strategies/SpikeAndChannel.mqh"

//+------------------------------------------------------------------+
//| Classe para geração de sinais de trading                         |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
   CLogger *m_logger;                   // Ponteiro para o logger
   CMarketContext *m_marketContext;     // Ponteiro para o contexto de mercado
   CSetupClassifier *m_setupClassifier; // Ponteiro para o contexto de mercado
   CCircuitBreaker *m_circuitBreaker;   // Circuit breaker compartilhado

   // Variáveis para armazenar configurações
   int m_lookbackBars;     // Número de barras para análise retroativa
   double m_minRiskReward; // Relação risco/retorno mínima aceitável
   bool m_hasValidData;    // Flag para indicar se os dados são válidos

   // Métodos privados auxiliares
   bool IsValidSignal(Signal &signal);
   bool CheckDataValidity(string symbol, ENUM_TIMEFRAMES timeframe);

   // Métodos privados para estratégias específicas de tendência
   Signal GenerateSpikeAndChannelSignal(string symbol, ENUM_TIMEFRAMES timeframe);

public:
   // Construtores e destrutor
   CSignalEngine();
   CSignalEngine(CLogger *logger, CMarketContext *marketContext, CSetupClassifier *setupClass, CCircuitBreaker *circuitBreaker=NULL);
   ~CSignalEngine();

   // Método de inicialização
   bool Initialize(CLogger *logger, CMarketContext *marketContext, CSetupClassifier *setupclass, CCircuitBreaker *circuitBreaker=NULL);

   // Método principal para geração de sinais
   Signal Generate(string symbol, MARKET_PHASE phase, ENUM_TIMEFRAMES timeframe);

   // Métodos para estratégias específicas por fase de mercado
   Signal GenerateTrendSignals(string symbol, ENUM_TIMEFRAMES timeframe);
   Signal GenerateRangeSignals(string symbol, ENUM_TIMEFRAMES timeframe);
   Signal GenerateReversalSignals(string symbol, ENUM_TIMEFRAMES timeframe);

   // Métodos de configuração
   void SetLookbackBars(int bars) { m_lookbackBars = bars; }
   void SetMinRiskReward(double ratio) { m_minRiskReward = ratio; }

   // Método para verificar se os dados são válidos
   bool HasValidData() const { return m_hasValidData; }
};

//+------------------------------------------------------------------+
//| Construtor padrão                                                |
//+------------------------------------------------------------------+
CSignalEngine::CSignalEngine()
{
   m_logger = NULL;
   m_marketContext = NULL;
   m_setupClassifier = NULL;
   m_circuitBreaker = NULL;
   m_lookbackBars = 100;
   m_minRiskReward = 1.5;
   m_hasValidData = false;
}

//+------------------------------------------------------------------+
//| Construtor com parâmetros                                        |
//+------------------------------------------------------------------+
CSignalEngine::CSignalEngine(CLogger *logger, CMarketContext *marketContext, CSetupClassifier *setupClass, CCircuitBreaker *circuitBreaker=NULL)
{
   m_logger = logger;
   m_marketContext = marketContext;
   m_setupClassifier = setupClass;
   m_circuitBreaker = circuitBreaker;
   m_lookbackBars = 100;
   m_minRiskReward = 1.5;
   m_hasValidData = false;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CSignalEngine::~CSignalEngine()
{
   // Não liberamos m_logger e m_marketContext aqui pois são apenas referências
}

//+------------------------------------------------------------------+
//| Inicializa o motor de sinais                                     |
//+------------------------------------------------------------------+
bool CSignalEngine::Initialize(CLogger *logger, CMarketContext *marketContext, CSetupClassifier *setupClass, CCircuitBreaker *circuitBreaker)
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
   m_setupClassifier = setupClass;
   m_circuitBreaker = circuitBreaker;

   m_logger.Info("SignalEngine inicializado com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Verifica se os dados são válidos para análise                    |
//+------------------------------------------------------------------+
bool CSignalEngine::CheckDataValidity(string symbol, ENUM_TIMEFRAMES timeframe)
{
   // Verificar se o símbolo e timeframe são válidos
   if (symbol == "" || timeframe == PERIOD_CURRENT)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("SignalEngine: Símbolo ou timeframe inválidos");
      }
      return false;
   }

   // Verificar se há barras suficientes
   int bars = Bars(symbol, timeframe);
   if (bars < m_lookbackBars)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("SignalEngine: Dados históricos insuficientes para " + symbol +
                          " em " + EnumToString(timeframe) + ". Necessário: " +
                          IntegerToString(m_lookbackBars) + ", Disponível: " + IntegerToString(bars));
      }
      return false;
   }

   // Verificar se os indicadores básicos podem ser calculados
   int maHandle = iMA(symbol, timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   if (maHandle == INVALID_HANDLE)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("SignalEngine: Falha ao criar handle de indicador para " + symbol);
      }
      return false;
   }

   // Alterar para o pool de indicadores
   double maBuffer[];
   ArraySetAsSeries(maBuffer, true);
   int copied = CopyBuffer(maHandle, 0, 0, 10, maBuffer);
   IndicatorRelease(maHandle);

   if (copied <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("SignalEngine: Falha ao copiar dados de indicador para " + symbol +
                        ": " + IntegerToString(GetLastError()));
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Método principal para geração de sinais                          |
//+------------------------------------------------------------------+
Signal CSignalEngine::Generate(string symbol, MARKET_PHASE phase, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0; // Sinal vazio/inválido por padrão

   if(m_circuitBreaker != NULL && !m_circuitBreaker.CanOperate())
   {
      if(m_logger != NULL)
         m_logger.Warning("Signal generation blocked by Circuit Breaker");
      m_circuitBreaker.RegisterError();
      return signal;
   }

   // Validação rigorosa de parâmetros
   if (symbol == "" || timeframe == PERIOD_CURRENT)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("SignalEngine: Parâmetros inválidos para geração de sinal. Símbolo: '" +
                          symbol + "', Timeframe: " + EnumToString(timeframe));
      }
      m_hasValidData = false;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return signal;
   }

   // Verificar se o símbolo existe
   if (!SymbolSelect(symbol, true))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("SignalEngine: Símbolo '" + symbol + "' não encontrado ou não selecionado");
      }
      m_hasValidData = false;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return signal;
   }

   // Verificar se os dados são válidos para análise
   m_hasValidData = CheckDataValidity(symbol, timeframe);
   if (!m_hasValidData)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("SignalEngine: Dados inválidos ou insuficientes para geração de sinal em " +
                          symbol + " (" + EnumToString(timeframe) + ")");
      }
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return signal;
   }

   // Gerar sinal com base na fase de mercado
   switch (phase)
   {
   case PHASE_TREND:
      signal = GenerateTrendSignals(symbol, timeframe);
      break;
   case PHASE_RANGE:
      signal = GenerateRangeSignals(symbol, timeframe);
      break;
   case PHASE_REVERSAL:
      signal = GenerateReversalSignals(symbol, timeframe);
      break;
   default:
      if (m_logger != NULL)
      {
         m_logger.Warning("SignalEngine: Fase de mercado indefinida ou não suportada: " +
                          EnumToString(phase));
      }
      break;
   }

   // Se um sinal válido foi gerado, classificar sua qualidade
   if (signal.id > 0)
   {

      signal.quality = m_setupClassifier.ClassifySetup(symbol, PERIOD_CURRENT, signal);
      signal.generatedTime = TimeCurrent();

      if (m_logger != NULL)
      {
         m_logger.LogSignal(signal);
      }
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterSuccess();
   }

   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinais para mercados em tendência                           |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateTrendSignals(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0; // Sinal vazio/inválido por padrão

   // Verificar se os dados são válidos
   // if (!m_hasValidData)
   // {
   //    return signal;
   // }

   // Verificar se o mercado está realmente em tendência
   if (m_marketContext != NULL && !m_marketContext.IsTrendUp() && !m_marketContext.IsTrendDown())
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("SignalEngine: Tentativa de gerar sinal de tendência em mercado não-tendencial para " +
                          symbol + " (" + EnumToString(timeframe) + ")");
      }
      return signal;
   }

   // Tentar gerar sinais com diferentes estratégias de tendência
   signal = GenerateSpikeAndChannelSignal(symbol, timeframe);
   if (signal.id > 0)
      return signal;

   // Nenhum sinal válido encontrado
   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinais para mercados em range                               |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateRangeSignals(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0; // Sinal vazio/inválido por padrão

   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return signal;
   }

   // Verificar se o mercado está realmente em range
   if (m_marketContext != NULL && !m_marketContext.IsInRange())
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("SignalEngine: Tentativa de gerar sinal de range em mercado não-lateral para " +
                          symbol + " (" + EnumToString(timeframe) + ")");
      }
      return signal;
   }

   // Nenhum sinal válido encontrado
   return signal;
}

//+------------------------------------------------------------------+
//| Gera sinais para mercados em reversão                            |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateReversalSignals(string symbol, ENUM_TIMEFRAMES timeframe)
{
   Signal signal;
   signal.id = 0; // Sinal vazio/inválido por padrão

   // Verificar se os dados são válidos
   if (!m_hasValidData)
   {
      return signal;
   }

   // Verificar se o mercado está realmente em reversão
   if (m_marketContext != NULL && !m_marketContext.IsInReversal())
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("SignalEngine: Tentativa de gerar sinal de reversão em mercado não-reversal para " +
                          symbol + " (" + EnumToString(timeframe) + ")");
      }
      return signal;
   }

   // Nenhum sinal válido encontrado
   return signal;
}

//+------------------------------------------------------------------+
//| Verifica se um sinal é válido                                    |
//+------------------------------------------------------------------+
bool CSignalEngine::IsValidSignal(Signal &signal)
{
   // // Verificar se os dados são válidos
   // if (!m_hasValidData)
   // {
   //    return false;
   // }

   // Verificar se o sinal tem ID válido
   if (signal.id <= 0)
      return false;

   // Verificar se o símbolo é válido
   if (signal.symbol == "")
      return false;

   // Verificar se a direção é válida
   if (signal.direction != ORDER_TYPE_BUY && signal.direction != ORDER_TYPE_SELL)
      return false;

   // Verificar se os preços são válidos
   if (signal.entryPrice <= 0 || signal.stopLoss <= 0)
      return false;

   // Verificar se o stop loss está no lado correto da entrada
   if (signal.direction == ORDER_TYPE_BUY && signal.stopLoss >= signal.entryPrice)
      return false;
   if (signal.direction == ORDER_TYPE_SELL && signal.stopLoss <= signal.entryPrice)
      return false;

   // Verificar se pelo menos um take profit é válido
   bool hasValidTakeProfit = false;
   for (int i = 0; i < 3; i++)
   {
      if (signal.takeProfits[i] > 0)
      {
         // Verificar se o take profit está no lado correto da entrada
         if (signal.direction == ORDER_TYPE_BUY && signal.takeProfits[i] > signal.entryPrice)
         {
            hasValidTakeProfit = true;
            break;
         }
         if (signal.direction == ORDER_TYPE_SELL && signal.takeProfits[i] < signal.entryPrice)
         {
            hasValidTakeProfit = true;
            break;
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
//| Gera sinal baseado em spike e canal                              |
//+------------------------------------------------------------------+
Signal CSignalEngine::GenerateSpikeAndChannelSignal(string symbol, ENUM_TIMEFRAMES timeframe)
{
   
   Signal signal;
   signal.id = 0; // Sinal vazio/inválido por padrão

   // Verificar se o mercado está em tendência
   if (m_marketContext != NULL && !m_marketContext.IsTrendUp() && !m_marketContext.IsTrendDown())
   {
      if (m_logger != NULL)
      {
         m_logger.Debug("SignalEngine: Mercado não está em tendência para padrão Spike & Channel");
      }
      return signal;
   }

   // Criar e inicializar objeto SpikeAndChannel
   CSpikeAndChannel *spikeAndChannel = new CSpikeAndChannel();
   if (spikeAndChannel == NULL)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("SignalEngine: Falha ao criar objeto SpikeAndChannel");
      }
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return signal;
   }

   if (!spikeAndChannel.Initialize(m_logger, m_marketContext))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("SignalEngine: Falha ao inicializar objeto SpikeAndChannel");
      }
      delete spikeAndChannel;
      if(m_circuitBreaker != NULL)
         m_circuitBreaker.RegisterError();
      return signal;
   }

   // Configurar parâmetros do detector de padrão
   spikeAndChannel.SetSpikeParameters(3, 5, 0.7);
   spikeAndChannel.SetChannelParameters(0.3);
   spikeAndChannel.SetLookbackBars(m_lookbackBars);

   // Detectar padrão
   SpikeChannelPattern pattern;
   if (!spikeAndChannel.DetectPattern(symbol, timeframe, pattern))
   {
      if (m_logger != NULL)
      {
         m_logger.Debug("SignalEngine: Padrão Spike & Channel não detectado para " + symbol);
      }
      delete spikeAndChannel;
      return signal;
   }

   // Gerar sinal com base no padrão detectado
   // Priorizar entradas na linha de tendência para melhor relação risco/retorno
   signal = spikeAndChannel.GenerateSignal(symbol, timeframe, pattern, ENTRY_PULLBACK_LINHA_TENDENCIA);
   // Se não encontrou entrada na linha de tendência, tentar outros tipos
   if (signal.id == 0)
   {
      signal = spikeAndChannel.GenerateSignal(symbol, timeframe, pattern, ENTRY_FALHA_PULLBACK);
   }

   if (signal.id == 0)
   {
      signal = spikeAndChannel.GenerateSignal(symbol, timeframe, pattern, ENTRY_PULLBACK_MINIMO);
   }

   if (signal.id == 0)
   {
      signal = spikeAndChannel.GenerateSignal(symbol, timeframe, pattern, ENTRY_FECHAMENTO_FORTE);
   }

   // Liberar memória
   delete spikeAndChannel;

   // Verificar se o sinal é válido
   if (signal.id > 0)
   {
      // Classificar qualidade do setup
      signal.quality = m_setupClassifier.ClassifySetup(symbol, PERIOD_CURRENT, signal);

      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("SignalEngine: Sinal Spike & Channel gerado para %s - %s, Qualidade: %s",
                                    symbol,
                                    signal.direction == ORDER_TYPE_BUY ? "Compra" : "Venda",
                                    EnumToString(signal.quality)));
      }
      return signal;
   }

   return signal;
}