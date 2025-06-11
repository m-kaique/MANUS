//+------------------------------------------------------------------+
//|                                                  Structures.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

//+------------------------------------------------------------------+
//| Include Guards para evitar múltiplas inclusões                   |
//+------------------------------------------------------------------+
#ifndef STRUCTURES_MQH
#define STRUCTURES_MQH

//+------------------------------------------------------------------+
//| Enumeração para Fases de Mercado                                 |
//+------------------------------------------------------------------+
enum MARKET_PHASE
{
   PHASE_TREND,    // Mercado em tendência
   PHASE_RANGE,    // Mercado em range
   PHASE_REVERSAL, // Mercado em reversão
   PHASE_UNDEFINED // Fase não definida
};

//+------------------------------------------------------------------+
//| Enumeração para Classificação de Qualidade de Setup              |
//+------------------------------------------------------------------+
enum SETUP_QUALITY
{
   SETUP_INVALID, // Setup inválido
   SETUP_A_PLUS,  // Setup de alta qualidade (confluência máxima)
   SETUP_A,       // Setup de boa qualidade
   SETUP_B,       // Setup de qualidade média
   SETUP_C        // Setup de baixa qualidade
};

//+------------------------------------------------------------------+
//| Enumeração para Níveis de Log                                    |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_DEBUG,   // Informações detalhadas para depuração
   LOG_LEVEL_INFO,    // Informações gerais
   LOG_LEVEL_WARNING, // Avisos
   LOG_LEVEL_ERROR    // Erros
};

//+------------------------------------------------------------------+
//| Categorias de log estruturado                                   |
//+------------------------------------------------------------------+
enum ENUM_LOG_CATEGORY
{
   LOG_VOLUME_SCALING,     // Decisões de escalonamento de volume
   LOG_CIRCUIT_BREAKER,    // Ativações do circuit breaker
   LOG_VOLATILITY_ADJUST,  // Ajustes de volatilidade
   LOG_DRAWDOWN_CONTROL,   // Intervenções de drawdown
   LOG_QUALITY_CORRELATION,// Correlação de qualidade de setup
   LOG_RISK_MANAGEMENT,    // Gestão de risco geral
   LOG_TRADE_EXECUTION,    // Eventos de execução de trades
   LOG_SYSTEM_STATUS,      // Status e integridade do sistema
   LOG_ERROR_HANDLING,     // Tratamento de erros
   LOG_PERFORMANCE         // Métricas de performance
};

//+------------------------------------------------------------------+
//| ✅ SISTEMA DE PARCIAIS UNIVERSAL - Enumerações                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Enumeração para Tipos de Ativo                                   |
//+------------------------------------------------------------------+
#ifndef ASSET_TYPE_DEFINED
#define ASSET_TYPE_DEFINED
enum ASSET_TYPE
{
   ASSET_FRACTIONAL,    // Permite lotes fracionários (ex: EURUSD, BTCUSD)
   ASSET_INTEGER,       // Apenas lotes inteiros (ex: WIN$, WDO$)
   ASSET_LARGE_LOT,     // Lotes grandes (ex: ações em lotes de 100)
   ASSET_UNKNOWN        // Tipo não determinado
};
#endif

//+------------------------------------------------------------------+
//| Enumeração para Estratégias de Parciais                          |
//+------------------------------------------------------------------+
#ifndef PARTIAL_STRATEGY_DEFINED
#define PARTIAL_STRATEGY_DEFINED
enum PARTIAL_STRATEGY
{
   PARTIAL_STRATEGY_ORIGINAL,    // Usar percentuais originais
   PARTIAL_STRATEGY_SCALED,      // Escalar volume para permitir parciais
   PARTIAL_STRATEGY_ADAPTIVE,    // Adaptar percentuais para lotes inteiros
   PARTIAL_STRATEGY_CONDITIONAL, // Usar parciais apenas se viável
   PARTIAL_STRATEGY_DISABLED     // Desabilitar parciais
};
#endif

//+------------------------------------------------------------------+
//| ✅ SISTEMA DE PARCIAIS UNIVERSAL - Estruturas                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Estrutura para Características de Lote                           |
//+------------------------------------------------------------------+
struct LotCharacteristics
{
   double minLot;                    // Lote mínimo
   double maxLot;                    // Lote máximo
   double stepLot;                   // Step de incremento
   ASSET_TYPE type;                  // Tipo de ativo
   bool supportsPartials;            // Suporta parciais efetivamente
   double minVolumeForPartials;      // Volume mínimo para parciais
   PARTIAL_STRATEGY recommendedStrategy; // Estratégia recomendada
   
   // Construtor
   LotCharacteristics()
   {
      minLot = 0.01;
      maxLot = 100.0;
      stepLot = 0.01;
      type = ASSET_UNKNOWN;
      supportsPartials = false;
      minVolumeForPartials = 0.0;
      recommendedStrategy = PARTIAL_STRATEGY_ORIGINAL;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para Configuração de Parciais Adaptativas             |
//+------------------------------------------------------------------+
struct AdaptivePartialConfig
{
   bool enabled;                     // Parciais habilitadas
   PARTIAL_STRATEGY strategy;        // Estratégia a ser usada
   double originalPercentages[10];   // Percentuais originais
   double adaptedPercentages[10];    // Percentuais adaptados
   double originalVolume;            // Volume original calculado
   double finalVolume;               // Volume final a ser usado
   int numPartials;                  // Número de parciais
   bool volumeWasScaled;             // Indica se volume foi escalado
   double scalingFactor;             // Fator de escalonamento aplicado
   string reason;                    // Razão para a estratégia escolhida
   
   // Construtor
   AdaptivePartialConfig()
   {
      enabled = false;
      strategy = PARTIAL_STRATEGY_ORIGINAL;
      originalVolume = 0.0;
      finalVolume = 0.0;
      numPartials = 0;
      volumeWasScaled = false;
      scalingFactor = 1.0;
      reason = "";
      
      for (int i = 0; i < 10; i++)
      {
         originalPercentages[i] = 0.0;
         adaptedPercentages[i] = 0.0;
      }
   }
};

//+------------------------------------------------------------------+
//| Estrutura para Métricas de Performance de Parciais              |
//+------------------------------------------------------------------+
struct PartialMetrics
{
   int totalOperations;              // Total de operações
   int operationsWithPartials;       // Operações com parciais
   int operationsScaled;             // Operações com volume escalado
   int operationsAdapted;            // Operações com parciais adaptadas
   int operationsDisabled;           // Operações com parciais desabilitadas
   
   double totalVolumeOriginal;       // Volume total original
   double totalVolumeFinal;          // Volume total final
   double avgVolumeIncrease;         // Aumento médio de volume (%)
   double avgPartialEfficiency;      // Eficiência média das parciais
   
   datetime lastReset;               // Última reinicialização das métricas
   
   // Construtor
   PartialMetrics()
   {
      totalOperations = 0;
      operationsWithPartials = 0;
      operationsScaled = 0;
      operationsAdapted = 0;
      operationsDisabled = 0;
      totalVolumeOriginal = 0.0;
      totalVolumeFinal = 0.0;
      avgVolumeIncrease = 0.0;
      avgPartialEfficiency = 0.0;
      lastReset = TimeCurrent();
   }
};

//+------------------------------------------------------------------+
//| Estrutura para Métricas de Correção                             |
//+------------------------------------------------------------------+
struct CorrectionMetrics
{
   // Scaling metrics
   int      totalScalings;
   int      scalingsA_Plus;
   int      scalingsA;
   int      scalingsB;
   int      scalingsC;

   // Volume metrics
   double   avgVolumeBeforeCorrection;
   double   avgVolumeAfterCorrection;
   double   maxVolumeRecorded;
   int      outliersPrevented;

   // Control metrics
   int      drawdownInterventions;
   int      volatilityAdjustments;
   int      circuitBreakerActivations;

   // Timing
   datetime metricsStartTime;
   datetime lastReset;
   datetime lastReport;

   CorrectionMetrics()
   {
      totalScalings              = 0;
      scalingsA_Plus             = 0;
      scalingsA                  = 0;
      scalingsB                  = 0;
      scalingsC                  = 0;
      avgVolumeBeforeCorrection  = 0.0;
      avgVolumeAfterCorrection   = 0.0;
      maxVolumeRecorded          = 0.0;
      outliersPrevented          = 0;
      drawdownInterventions      = 0;
      volatilityAdjustments      = 0;
      circuitBreakerActivations  = 0;
      metricsStartTime           = TimeCurrent();
      lastReset                  = TimeCurrent();
      lastReport                 = 0;
   }
};

//+------------------------------------------------------------------+
//| ✅ ESTRUTURAS ORIGINAIS MANTIDAS                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Estrutura para Parâmetros de Ativos                              |
//+------------------------------------------------------------------+
struct AssetParams
{
   string symbol;                           // Símbolo do ativo (ex: "BTCUSD", "WIN", "WDO")
   ENUM_TIMEFRAMES mainTimeframe;           // Timeframe principal para análise
   ENUM_TIMEFRAMES additionalTimeframes[3]; // Timeframes adicionais para análise multi-timeframe
   double tickSize;                         // Tamanho do tick mínimo
   double pipValue;                         // Valor monetário de um pip/ponto
   double contractSize;                     // Tamanho do contrato
   double maxPositionSize;                  // Tamanho máximo de posição permitido
   double defaultStopLoss;                  // Stop loss padrão em pontos
   double defaultTakeProfit;                // Take profit padrão em pontos
   double riskPercentage;                   // Percentual de risco por operação
   bool isActive;                           // Indica se o ativo está ativo para operações

   // ✅ NOVOS CAMPOS PARA PARCIAIS UNIVERSAIS
   PARTIAL_STRATEGY partialStrategy;        // Estratégia de parciais
   double minVolumeForPartials;             // Volume mínimo para parciais
   bool allowVolumeScaling;                 // Permitir escalonamento de volume
   double maxScalingFactor;                 // Fator máximo de escalonamento
   ASSET_TYPE assetType;                    // Tipo de ativo detectado
   LotCharacteristics lotChar;              // Características de lote
   AdaptivePartialConfig lastPartialConfig; // Última configuração aplicada

   // Construtor com valores padrão
   AssetParams()
   {
      symbol = "";
      mainTimeframe = PERIOD_H1;
      additionalTimeframes[0] = PERIOD_D1;
      additionalTimeframes[1] = PERIOD_M15;
      additionalTimeframes[2] = PERIOD_M5;
      tickSize = 0.0;
      pipValue = 0.0;
      contractSize = 0.0;
      maxPositionSize = 5.0;
      defaultStopLoss = 0.0;
      defaultTakeProfit = 0.0;
      riskPercentage = 1.0;
      isActive = false;
      
      // ✅ INICIALIZAR NOVOS CAMPOS
      partialStrategy = PARTIAL_STRATEGY_ORIGINAL;
      minVolumeForPartials = 0.0;
      allowVolumeScaling = false;
      maxScalingFactor = 3.0;
      assetType = ASSET_UNKNOWN;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para Sinais de Trading                                 |
//+------------------------------------------------------------------+
struct Signal
{
   int id;                    // Identificador único do sinal
   string symbol;             // Símbolo do ativo
   ENUM_ORDER_TYPE direction; // Direção (compra/venda)
   MARKET_PHASE marketPhase;  // Fase de mercado associada
   SETUP_QUALITY quality;     // Qualidade do setup
   double entryPrice;         // Preço de entrada
   double stopLoss;           // Nível de stop loss
   double takeProfits[3];     // Níveis de take profit (múltiplos alvos)
   datetime generatedTime;    // Timestamp de geração do sinal
   string strategy;           // Estratégia que gerou o sinal
   string description;        // Descrição textual do sinal
   double riskRewardRatio;    // Relação risco/retorno
   bool isActive;             // Indica se o sinal está ativo

   // Construtor com valores padrão
   Signal()
   {
      id = 0;
      symbol = "";
      direction = ORDER_TYPE_BUY;
      marketPhase = PHASE_UNDEFINED;
      quality = SETUP_C;
      entryPrice = 0.0;
      stopLoss = 0.0;
      ArrayInitialize(takeProfits, 0.0);
      generatedTime = 0;
      strategy = "";
      description = "";
      riskRewardRatio = 0.0;
      isActive = false;
   }

   // Método para calcular a relação risco/retorno
   void CalculateRiskRewardRatio()
   {
      if (stopLoss == 0.0 || entryPrice == 0.0 || takeProfits[0] == 0.0)
         return;

      double risk = MathAbs(entryPrice - stopLoss);
      double reward = MathAbs(takeProfits[0] - entryPrice);

      if (risk > 0.0)
         riskRewardRatio = reward / risk;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para Requisições de Ordem                              |
//+------------------------------------------------------------------+
struct OrderRequest
{
   int id;               // Identificador único da requisição
   ENUM_ORDER_TYPE type; // Tipo de ordem (mercado, limite, stop)
   string symbol;        // Símbolo
   double volume;        // Volume (tamanho da posição)
   double price;         // Preço (para ordens limite e stop)
   double stopLoss;      // Stop Loss
   double takeProfit;    // Take Profit
   string comment;       // Comentário
   datetime expiration;  // Data de expiração (para ordens pendentes)
   int signalId;         // ID do sinal que gerou a ordem
   bool isProcessed;     // Indica se a requisição foi processada

   // Construtor com valores padrão
   OrderRequest()
   {
      id = 0;
      type = ORDER_TYPE_BUY;
      symbol = "";
      volume = 0.0;
      price = 0.0;
      stopLoss = 0.0;
      takeProfit = 0.0;
      comment = "";
      expiration = 0;
      signalId = 0;
      isProcessed = false;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para Armazenar o Estado do Mercado                     |
//+------------------------------------------------------------------+
struct MarketState
{
   MARKET_PHASE phase;       // Fase atual do mercado
   double keyLevels[];       // Suportes e resistências
   double trendStrength;     // 0.0 a 1.0
   bool isVolatile;          // Alta volatilidade
   datetime lastPhaseChange; // Quando a fase mudou pela última vez

   // Construtor com valores padrão
   MarketState()
   {
      phase = PHASE_UNDEFINED;
      ArrayResize(keyLevels, 0);
      trendStrength = 0.0;
      isVolatile = false;
      lastPhaseChange = 0;
   }
};

struct LastSignalInfo
{
   string symbol;
   datetime signalTime;
   ENUM_ORDER_TYPE direction;
   double entryPrice;
   bool isActive;
};

// Estrutura para armazenar parâmetros dos ativos
struct AssetConfig
{
   string symbol;
   bool enabled;
   double minLot;
   double maxLot;
   double lotStep;
   double tickValue;
   int digits;
   double riskPercentage;
   bool usePartials;
   double partialLevels[3];
   double partialVolumes[3];
   bool historyAvailable; // Flag para indicar se o histórico está disponível
   int minRequiredBars;   // Mínimo de barras necessárias para análise
   
   // ✅ NOVOS CAMPOS PARA PARCIAIS UNIVERSAIS
   PARTIAL_STRATEGY partialStrategy;        // Estratégia de parciais
   double minVolumeForPartials;             // Volume mínimo para parciais
   bool allowVolumeScaling;                 // Permitir escalonamento de volume
   double maxScalingFactor;                 // Fator máximo de escalonamento
   ASSET_TYPE assetType;                    // Tipo de ativo detectado
   LotCharacteristics lotChar;              // Características de lote
   AdaptivePartialConfig lastPartialConfig; // Última configuração aplicada
   
   // Construtor
   AssetConfig()
   {
      symbol = "";
      enabled = false;
      minLot = 0.01;
      maxLot = 100.0;
      lotStep = 0.01;
      tickValue = 0.0;
      digits = 5;
      riskPercentage = 1.0;
      usePartials = false;
      historyAvailable = false;
      minRequiredBars = 100;
      
      // Inicializar arrays
      for (int i = 0; i < 3; i++)
      {
         partialLevels[i] = 0.0;
         partialVolumes[i] = 0.0;
      }
      
      // ✅ INICIALIZAR NOVOS CAMPOS
      partialStrategy = PARTIAL_STRATEGY_ORIGINAL;
      minVolumeForPartials = 0.0;
      allowVolumeScaling = false;
      maxScalingFactor = 3.0;
      assetType = ASSET_UNKNOWN;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para armazenar sinais pendentes                        |
//+------------------------------------------------------------------+
struct PendingSignal
{
   Signal signal;
   datetime expiry;
   bool isActive;

   PendingSignal()
   {
      expiry = 0;
      isActive = false;
   }
};

// Enumeração para tipos de breakeven
enum ENUM_BREAKEVEN_TYPE
{
   BREAKEVEN_FIXED,     // Breakeven em pontos fixos
   BREAKEVEN_ATR,       // Breakeven baseado em ATR
   BREAKEVEN_RISK_RATIO // Breakeven baseado em relação risco/retorno
};

// Estrutura para configuração de breakeven
struct BreakevenConfig
{
   ulong ticket;                      // Ticket da posição
   string symbol;                     // Símbolo
   ENUM_BREAKEVEN_TYPE breakevenType; // Tipo de breakeven
   double triggerPoints;              // Pontos para ativar breakeven
   double breakevenOffset;            // Offset do breakeven (pontos além da entrada)
   double atrMultiplier;              // Multiplicador ATR para trigger
   double riskRatio;                  // Relação R:R para ativar (ex: 1.0 = 1:1)
   bool isActive;                     // Se breakeven está ativo
   bool wasTriggered;                 // Se já foi movido para breakeven
   datetime configTime;               // Quando foi configurado
};

//+------------------------------------------------------------------+
//| ✅ ESTRUTURA PARA CONFIGURAÇÃO DE TRAILING STOP                 |
//+------------------------------------------------------------------+
struct TrailingStopConfig
{
   ulong ticket;                      // Ticket da posição
   string symbol;                     // Símbolo
   double trailingDistance;           // Distância do trailing em pontos
   double minProfit;                  // Lucro mínimo para ativar trailing
   bool isActive;                     // Se trailing está ativo
   double lastStopLoss;               // Último stop loss definido
   datetime configTime;               // Quando foi configurado
   
   // Construtor
   TrailingStopConfig()
   {
      ticket = 0;
      symbol = "";
      trailingDistance = 0.0;
      minProfit = 0.0;
      isActive = false;
      lastStopLoss = 0.0;
      configTime = 0;
   }
};

#endif // STRUCTURES_MQH

