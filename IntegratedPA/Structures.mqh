//+------------------------------------------------------------------+
//|                                                  Structures.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Enumeração para Fases de Mercado                                 |
//+------------------------------------------------------------------+
enum MARKET_PHASE {
   PHASE_TREND,    // Mercado em tendência
   PHASE_RANGE,    // Mercado em range
   PHASE_REVERSAL, // Mercado em reversão
   PHASE_UNDEFINED // Fase não definida
};

//+------------------------------------------------------------------+
//| Enumeração para Classificação de Qualidade de Setup              |
//+------------------------------------------------------------------+
enum SETUP_QUALITY {
   SETUP_INVALID,   // Setup inválido
   SETUP_A_PLUS,   // Setup de alta qualidade (confluência máxima)
   SETUP_A,        // Setup de boa qualidade
   SETUP_B,        // Setup de qualidade média
   SETUP_C         // Setup de baixa qualidade
};

//+------------------------------------------------------------------+
//| Enumeração para Níveis de Log                                    |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL {
   LOG_LEVEL_DEBUG,    // Informações detalhadas para depuração
   LOG_LEVEL_INFO,     // Informações gerais
   LOG_LEVEL_WARNING,  // Avisos
   LOG_LEVEL_ERROR     // Erros
};

//+------------------------------------------------------------------+
//| Estrutura para Parâmetros de Ativos                              |
//+------------------------------------------------------------------+
struct AssetParams {
   string           symbol;              // Símbolo do ativo (ex: "BTCUSD", "WIN", "WDO")
   ENUM_TIMEFRAMES  mainTimeframe;       // Timeframe principal para análise
   ENUM_TIMEFRAMES  additionalTimeframes[3]; // Timeframes adicionais para análise multi-timeframe
   double           tickSize;            // Tamanho do tick mínimo
   double           pipValue;            // Valor monetário de um pip/ponto
   double           contractSize;        // Tamanho do contrato
   double           maxPositionSize;     // Tamanho máximo de posição permitido
   double           defaultStopLoss;     // Stop loss padrão em pontos
   double           defaultTakeProfit;   // Take profit padrão em pontos
   double           riskPercentage;      // Percentual de risco por operação
   bool             isActive;            // Indica se o ativo está ativo para operações
   
   // Construtor com valores padrão
   AssetParams() {
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
   }
};

//+------------------------------------------------------------------+
//| Estrutura para Sinais de Trading                                 |
//+------------------------------------------------------------------+
struct Signal {
   int              id;                  // Identificador único do sinal
   string           symbol;              // Símbolo do ativo
   ENUM_ORDER_TYPE  direction;           // Direção (compra/venda)
   MARKET_PHASE     marketPhase;         // Fase de mercado associada
   SETUP_QUALITY    quality;             // Qualidade do setup
   double           entryPrice;          // Preço de entrada
   double           stopLoss;            // Nível de stop loss
   double           takeProfits[3];      // Níveis de take profit (múltiplos alvos)
   datetime         generatedTime;       // Timestamp de geração do sinal
   string           strategy;            // Estratégia que gerou o sinal
   string           description;         // Descrição textual do sinal
   double           riskRewardRatio;     // Relação risco/retorno
   bool             isActive;            // Indica se o sinal está ativo
   
   // Construtor com valores padrão
   Signal() {
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
   void CalculateRiskRewardRatio() {
      if(stopLoss == 0.0 || entryPrice == 0.0 || takeProfits[0] == 0.0)
         return;
         
      double risk = MathAbs(entryPrice - stopLoss);
      double reward = MathAbs(takeProfits[0] - entryPrice);
      
      if(risk > 0.0)
         riskRewardRatio = reward / risk;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para Requisições de Ordem                              |
//+------------------------------------------------------------------+
struct OrderRequest {
   int              id;                  // Identificador único da requisição
   ENUM_ORDER_TYPE  type;                // Tipo de ordem (mercado, limite, stop)
   string           symbol;              // Símbolo
   double           volume;              // Volume (tamanho da posição)
   double           price;               // Preço (para ordens limite e stop)
   double           stopLoss;            // Stop Loss
   double           takeProfit;          // Take Profit
   string           comment;             // Comentário
   datetime         expiration;          // Data de expiração (para ordens pendentes)
   int              signalId;            // ID do sinal que gerou a ordem
   bool             isProcessed;         // Indica se a requisição foi processada
   
   // Construtor com valores padrão
   OrderRequest() {
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
struct MarketState {
   MARKET_PHASE     phase;               // Fase atual do mercado
   double           keyLevels[];         // Suportes e resistências
   double           trendStrength;       // 0.0 a 1.0
   bool             isVolatile;          // Alta volatilidade
   datetime         lastPhaseChange;     // Quando a fase mudou pela última vez
   
   // Construtor com valores padrão
   MarketState() {
      phase = PHASE_UNDEFINED;
      ArrayResize(keyLevels, 0);
      trendStrength = 0.0;
      isVolatile = false;
      lastPhaseChange = 0;
   }
};

struct LastSignalInfo {
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
};

//+------------------------------------------------------------------+
//| Estrutura para armazenar sinais pendentes                        |
//+------------------------------------------------------------------+
struct PendingSignal {
   Signal signal;
   datetime expiry;
   bool isActive;
   
   PendingSignal() {
      expiry = 0;
      isActive = false;
   }
};


// Enumeração para tipos de breakeven
enum ENUM_BREAKEVEN_TYPE {
   BREAKEVEN_FIXED,        // Breakeven em pontos fixos
   BREAKEVEN_ATR,          // Breakeven baseado em ATR
   BREAKEVEN_RISK_RATIO    // Breakeven baseado em relação risco/retorno
};

// Estrutura para configuração de breakeven
struct BreakevenConfig {
   ulong                ticket;           // Ticket da posição
   string              symbol;           // Símbolo
   ENUM_BREAKEVEN_TYPE breakevenType;    // Tipo de breakeven
   double              triggerPoints;    // Pontos para ativar breakeven
   double              breakevenOffset;  // Offset do breakeven (pontos além da entrada)
   double              atrMultiplier;    // Multiplicador ATR para trigger
   double              riskRatio;        // Relação R:R para ativar (ex: 1.0 = 1:1)
   bool                isActive;         // Se breakeven está ativo
   bool                wasTriggered;     // Se já foi movido para breakeven
   datetime            configTime;       // Quando foi configurado
};