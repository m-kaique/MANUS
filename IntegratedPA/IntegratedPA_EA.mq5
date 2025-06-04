#ifndef INTEGRATEDPA_EA_MQ5_
#define INTEGRATEDPA_EA_MQ5_

//+------------------------------------------------------------------+
//|                                           IntegratedPA_EA.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property description "Expert Advisor baseado em Price Action com suporte multi-símbolo"
#property strict

//+------------------------------------------------------------------+
//| Inclusão de bibliotecas padrão                                   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Inclusão dos módulos personalizados                              |
//+------------------------------------------------------------------+
#include "Structures.mqh"
#include "MarketContext.mqh"
#include "SignalEngine.mqh"
#include "RiskManager.mqh"
#include "TradeExecutor.mqh"
#include "Logger.mqh"
#include "Utils.mqh"

// Incluir Constants.mqh apenas uma vez
#ifndef CONSTANTS_INCLUDED
#define CONSTANTS_INCLUDED
#include "Constants.mqh"
#endif

//+------------------------------------------------------------------+
//| Parâmetros de entrada                                            |
//+------------------------------------------------------------------+
// Configurações Gerais
input string GeneralSettings = "=== Configurações Gerais ==="; // Configurações Gerais
input bool EnableTrading = true;                               // Habilitar Trading
input bool EnableBTC = false;                                  // Operar BIT$Dcoin
input bool EnableWDO = false;                                  // Operar WDO
input bool EnableWIN = true;                                   // Operar WIN
input ENUM_TIMEFRAMES MainTimeframe = PERIOD_M3;               // Timeframe Principal
input ulong MagicNumber = 123456;                              // Número Mágico do EA

// Configurações de Risco
input string RiskSettings = "=== Configurações de Risco ==="; // Configurações de Risco
input double RiskPerTrade = 1.0;                              // Risco por operação (%)
input double MaxTotalRisk = 5.0;                              // Risco máximo total (%)

// Configurações de Estratégia
input string StrategySettings = "=== Configurações de Estratégia ==="; // Configurações de Estratégia
input bool EnableTrendStrategies = true;                               // Habilitar Estratégias de Tendência
input bool EnableRangeStrategies = true;                               // Habilitar Estratégias de Range
input bool EnableReversalStrategies = true;                            // Habilitar Estratégias de Reversão
input SETUP_QUALITY MinSetupQuality = SETUP_B;                         // Qualidade Mínima do Setup

//+------------------------------------------------------------------+
//| Variáveis globais                                                |
//+------------------------------------------------------------------+
// Objetos globais
CLogger *g_logger = NULL;
CMarketContext *g_marketContext = NULL;
CSignalEngine *g_signalEngine = NULL;
CRiskManager *g_riskManager = NULL;
CTradeExecutor *g_tradeExecutor = NULL;
ulong g_magicNumber = 0;                    // Magic Number global

// Variáveis globais para otimização:
// Variáveis globais para otimização
datetime g_lastProcessTime = 0;
datetime g_lastStatsTime = 0;
int g_processIntervalSeconds = 5;        // Intervalo mínimo entre processamentos
int g_statsIntervalSeconds = 3600;       // Relatório de stats a cada hora
int g_ticksProcessed = 0;
int g_signalsGenerated = 0;
int g_ordersExecuted = 0;
MARKET_PHASE g_lastPhases[];             // Cache das últimas fases por ativo

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
   double riskPercentage; // Risco base por trade para este ativo (% da conta)
   bool usePartials;
   double partialLevels[3];
   double partialVolumes[3];
   bool historyAvailable; // Flag para indicar se o histórico está disponível
   int minRequiredBars;   // Mínimo de barras necessárias para análise
   
   // --- CAMPOS PARA CONSTANTES DE RISCO ---
   double firstTargetPoints;    // Pontos para o primeiro TP (ex: WIN_FIRST_TARGET)
   double spikeMaxStopPoints;   // Pontos máximos de SL em Spike (ex: WIN_SPIKE_MAX_STOP)
   double channelMaxStopPoints; // Pontos máximos de SL em Canal (ex: WIN_CHANNEL_MAX_STOP)
   double trailingStopPoints;   // Pontos para Trailing Stop (ex: WIN_TRAILING_STOP)
   // Adicionar outros alvos (TP2, TP3) se necessário para lógicas futuras
};

// Array de ativos configurados
AssetConfig g_assets[];

// Variáveis para controle de tempo
datetime g_lastBarTimes[];
datetime g_lastExportTime = 0;

// Constante para o mínimo de barras necessárias
#define MIN_REQUIRED_BARS 200

//+------------------------------------------------------------------+
//| Função para verificar se o histórico está disponível             |
//+------------------------------------------------------------------+
bool IsHistoryAvailable(string symbol, ENUM_TIMEFRAMES timeframe, int minBars = MIN_REQUIRED_BARS)
{
   // Verificar se há barras suficientes
   int bars = (int)SeriesInfoInteger(symbol, timeframe, SERIES_BARS_COUNT);
   if (bars < minBars)
   {
      if (g_logger != NULL)
      {
         g_logger.Warning("Histórico insuficiente para " + symbol + " em " +
                          EnumToString(timeframe) + ": " + IntegerToString(bars) +
                          " barras (mínimo: " + IntegerToString(minBars) + ")");
      }
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Função para configuração dos ativos                              |
//+------------------------------------------------------------------+
bool SetupAssets()
{
   int assetsCount = 0;

   // Redimensionar o array de ativos
   if (EnableBTC)
      assetsCount++;
   if (EnableWDO)
      assetsCount++;
   if (EnableWIN)
      assetsCount++;

   if (assetsCount == 0)
   {
      if (g_logger != NULL)
      {
         g_logger.Error("Nenhum ativo habilitado para operação");
      }
      return false;
   }

   if (ArrayResize(g_assets, assetsCount) != assetsCount)
   {
      if (g_logger != NULL)
      {
         g_logger.Error("Falha ao redimensionar array de ativos");
      }
      return false;
   }

   // Inicializar array de tempos de barras
   if (ArrayResize(g_lastBarTimes, assetsCount) != assetsCount)
   {
      if (g_logger != NULL)
      {
         g_logger.Error("Falha ao redimensionar array de tempos de barras");
      }
      return false;
   }

   // Inicializar array de fases de mercado
   if (ArrayResize(g_lastPhases, assetsCount) != assetsCount)
   {
      if (g_logger != NULL)
      {
         g_logger.Error("Falha ao redimensionar array de fases de mercado");
      }
      return false;
   }

   // Configurar cada ativo
   int idx = 0;

   if (EnableWIN)
   {
      g_assets[idx].symbol = "WIN$";
      g_assets[idx].enabled = true;
      g_assets[idx].minLot = 1;
      g_assets[idx].maxLot = 100;
      g_assets[idx].lotStep = 1;
      g_assets[idx].riskPercentage = RiskPerTrade;
      g_assets[idx].usePartials = true;
      g_assets[idx].minRequiredBars = MIN_REQUIRED_BARS;
      
      // Configurar constantes de risco específicas para WIN
      g_assets[idx].firstTargetPoints = WIN_FIRST_TARGET;
      g_assets[idx].spikeMaxStopPoints = WIN_SPIKE_MAX_STOP;
      g_assets[idx].channelMaxStopPoints = WIN_CHANNEL_MAX_STOP;
      g_assets[idx].trailingStopPoints = WIN_TRAILING_STOP;
      
      // Configurar níveis de parciais
      double levels[3] = {1.0, 2.0, 3.0};
      double volumes[3] = {0.3, 0.3, 0.4};
      
      for (int i = 0; i < 3; i++)
      {
         g_assets[idx].partialLevels[i] = levels[i];
         g_assets[idx].partialVolumes[i] = volumes[i];
      }
      
      // Verificar disponibilidade de histórico
      g_assets[idx].historyAvailable = IsHistoryAvailable(g_assets[idx].symbol, MainTimeframe);
      
      // Configurar no RiskManager
      if (g_riskManager != NULL)
      {
         g_riskManager.AddSymbol(g_assets[idx].symbol, g_assets[idx].riskPercentage, g_assets[idx].maxLot);
         g_riskManager.ConfigureSymbolPartials(g_assets[idx].symbol, g_assets[idx].usePartials, levels, volumes);
         g_riskManager.ConfigureSymbolRiskConstants(g_assets[idx].symbol, 
                                                  g_assets[idx].firstTargetPoints,
                                                  g_assets[idx].spikeMaxStopPoints,
                                                  g_assets[idx].channelMaxStopPoints,
                                                  g_assets[idx].trailingStopPoints);
      }
      
      idx++;
   }

   if (EnableWDO)
   {
      g_assets[idx].symbol = "WDO$";
      g_assets[idx].enabled = true;
      g_assets[idx].minLot = 1;
      g_assets[idx].maxLot = 100;
      g_assets[idx].lotStep = 1;
      g_assets[idx].riskPercentage = RiskPerTrade;
      g_assets[idx].usePartials = true;
      g_assets[idx].minRequiredBars = MIN_REQUIRED_BARS;
      
      // Configurar constantes de risco específicas para WDO
      g_assets[idx].firstTargetPoints = WDO_FIRST_TARGET;
      g_assets[idx].spikeMaxStopPoints = WDO_SPIKE_MAX_STOP;
      g_assets[idx].channelMaxStopPoints = WDO_CHANNEL_MAX_STOP;
      g_assets[idx].trailingStopPoints = WDO_TRAILING_STOP;
      
      // Configurar níveis de parciais
      double levels[3] = {1.0, 2.0, 3.0};
      double volumes[3] = {0.3, 0.3, 0.4};
      
      for (int i = 0; i < 3; i++)
      {
         g_assets[idx].partialLevels[i] = levels[i];
         g_assets[idx].partialVolumes[i] = volumes[i];
      }
      
      // Verificar disponibilidade de histórico
      g_assets[idx].historyAvailable = IsHistoryAvailable(g_assets[idx].symbol, MainTimeframe);
      
      // Configurar no RiskManager
      if (g_riskManager != NULL)
      {
         g_riskManager.AddSymbol(g_assets[idx].symbol, g_assets[idx].riskPercentage, g_assets[idx].maxLot);
         g_riskManager.ConfigureSymbolPartials(g_assets[idx].symbol, g_assets[idx].usePartials, levels, volumes);
         g_riskManager.ConfigureSymbolRiskConstants(g_assets[idx].symbol, 
                                                  g_assets[idx].firstTargetPoints,
                                                  g_assets[idx].spikeMaxStopPoints,
                                                  g_assets[idx].channelMaxStopPoints,
                                                  g_assets[idx].trailingStopPoints);
      }
      
      idx++;
   }

   if (EnableBTC)
   {
      g_assets[idx].symbol = "BTC$";
      g_assets[idx].enabled = true;
      g_assets[idx].minLot = 0.01;
      g_assets[idx].maxLot = 10;
      g_assets[idx].lotStep = 0.01;
      g_assets[idx].riskPercentage = RiskPerTrade;
      g_assets[idx].usePartials = true;
      g_assets[idx].minRequiredBars = MIN_REQUIRED_BARS;
      
      // Configurar constantes de risco específicas para BTC
      g_assets[idx].firstTargetPoints = BTC_FIRST_TARGET;
      g_assets[idx].spikeMaxStopPoints = BTC_SPIKE_MAX_STOP;
      g_assets[idx].channelMaxStopPoints = BTC_CHANNEL_MAX_STOP;
      g_assets[idx].trailingStopPoints = BTC_TRAILING_STOP;
      
      // Configurar níveis de parciais
      double levels[3] = {1.0, 2.0, 3.0};
      double volumes[3] = {0.3, 0.3, 0.4};
      
      for (int i = 0; i < 3; i++)
      {
         g_assets[idx].partialLevels[i] = levels[i];
         g_assets[idx].partialVolumes[i] = volumes[i];
      }
      
      // Verificar disponibilidade de histórico
      g_assets[idx].historyAvailable = IsHistoryAvailable(g_assets[idx].symbol, MainTimeframe);
      
      // Configurar no RiskManager
      if (g_riskManager != NULL)
      {
         g_riskManager.AddSymbol(g_assets[idx].symbol, g_assets[idx].riskPercentage, g_assets[idx].maxLot);
         g_riskManager.ConfigureSymbolPartials(g_assets[idx].symbol, g_assets[idx].usePartials, levels, volumes);
         g_riskManager.ConfigureSymbolRiskConstants(g_assets[idx].symbol, 
                                                  g_assets[idx].firstTargetPoints,
                                                  g_assets[idx].spikeMaxStopPoints,
                                                  g_assets[idx].channelMaxStopPoints,
                                                  g_assets[idx].trailingStopPoints);
      }
      
      idx++;
   }

   if (g_logger != NULL)
   {
      g_logger.Info("Configurados " + IntegerToString(idx) + " ativos para operação");
   }

   return true;
}

//+------------------------------------------------------------------+
//| Função para gerenciar posições existentes                        |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   // Verificar se há posições abertas
   int totalPositions = PositionsTotal();
   if (totalPositions <= 0)
      return;

   // Iterar por todas as posições
   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
         continue;

      // Verificar se a posição pertence a este EA
      if (PositionGetInteger(POSITION_MAGIC) != g_magicNumber)
         continue;

      // Obter dados da posição
      string symbol = PositionGetString(POSITION_SYMBOL);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Verificar se o símbolo está configurado
      int assetIndex = -1;
      for (int j = 0; j < ArraySize(g_assets); j++)
      {
         if (g_assets[j].symbol == symbol)
         {
            assetIndex = j;
            break;
         }
      }

      if (assetIndex < 0)
         continue;

      // Obter parâmetros de risco para o símbolo
      CRiskManager::SymbolRiskParams riskParams;
      if (!g_riskManager.GetSymbolRiskParams(symbol, riskParams))
         continue;

      // Verificar se deve aplicar trailing stop
      double profit = 0;
      if (posType == POSITION_TYPE_BUY)
      {
         profit = currentPrice - entryPrice;
      }
      else
      {
         profit = entryPrice - currentPrice;
      }

      // Converter profit para pontos
      double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double profitPoints = profit / pointValue;

      // Aplicar trailing stop se o lucro for maior que o valor definido
      if (profitPoints >= riskParams.trailingStopPoints)
      {
         g_tradeExecutor.ApplyTrailingStop(ticket, riskParams.trailingStopPoints);
      }

      // Verificar se deve realizar parciais
      if (riskParams.usePartials && g_riskManager.ShouldTakePartial(symbol, ticket, currentPrice, entryPrice, currentSL))
      {
         double currentRR = 0;
         if (posType == POSITION_TYPE_BUY && currentSL > 0)
         {
            currentRR = (currentPrice - entryPrice) / (entryPrice - currentSL);
         }
         else if (posType == POSITION_TYPE_SELL && currentSL > 0)
         {
            currentRR = (entryPrice - currentPrice) / (currentSL - entryPrice);
         }

         if (currentRR > 0)
         {
            double partialVolume = g_riskManager.GetPartialVolume(symbol, ticket, currentRR);
            if (partialVolume > 0)
            {
               double positionVolume = PositionGetDouble(POSITION_VOLUME);
               double volumeToClose = positionVolume * partialVolume;

               if (volumeToClose > 0 && volumeToClose < positionVolume)
               {
                  g_tradeExecutor.ClosePosition(ticket, volumeToClose);
               }
            }
         }
      }
   }
}

// Outras funções do EA...

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Armazenar Magic Number global
   g_magicNumber = MagicNumber;

   // Inicializar logger
   g_logger = new CLogger();
   if (g_logger == NULL)
   {
      Print("Falha ao criar objeto Logger");
      return INIT_FAILED;
   }

   g_logger.SetLogLevel(LOG_LEVEL_INFO);
   g_logger.Info("Inicializando IntegratedPA EA v1.00");

   // Inicializar contexto de mercado
   g_marketContext = new CMarketContext();
   if (g_marketContext == NULL)
   {
      g_logger.Error("Falha ao criar objeto MarketContext");
      return INIT_FAILED;
   }

   if (!g_marketContext.Initialize(_Symbol, MainTimeframe, g_logger, true))
   {
      g_logger.Error("Falha ao inicializar MarketContext");
      return INIT_FAILED;
   }

   // Inicializar gerenciador de risco
   g_riskManager = new CRiskManager(RiskPerTrade, MaxTotalRisk);
   if (g_riskManager == NULL)
   {
      g_logger.Error("Falha ao criar objeto RiskManager");
      return INIT_FAILED;
   }

   if (!g_riskManager.Initialize(g_logger, g_marketContext))
   {
      g_logger.Error("Falha ao inicializar RiskManager");
      return INIT_FAILED;
   }

   // Inicializar executor de trades
   g_tradeExecutor = new CTradeExecutor();
   if (g_tradeExecutor == NULL)
   {
      g_logger.Error("Falha ao criar objeto TradeExecutor");
      return INIT_FAILED;
   }

   if (!g_tradeExecutor.Initialize(g_logger, g_magicNumber))
   {
      g_logger.Error("Falha ao inicializar TradeExecutor");
      return INIT_FAILED;
   }

   g_tradeExecutor.SetTradeAllowed(EnableTrading);

   // Inicializar motor de sinais
   g_signalEngine = new CSignalEngine();
   if (g_signalEngine == NULL)
   {
      g_logger.Error("Falha ao criar objeto SignalEngine");
      return INIT_FAILED;
   }

   if (!g_signalEngine.Initialize(g_logger, g_marketContext))
   {
      g_logger.Error("Falha ao inicializar SignalEngine");
      return INIT_FAILED;
   }

   // Configurar estratégias
   g_signalEngine.SetTrendStrategiesEnabled(EnableTrendStrategies);
   g_signalEngine.SetRangeStrategiesEnabled(EnableRangeStrategies);
   g_signalEngine.SetReversalStrategiesEnabled(EnableReversalStrategies);
   g_signalEngine.SetMinimumSetupQuality(MinSetupQuality);

   // Configurar ativos
   if (!SetupAssets())
   {
      g_logger.Error("Falha ao configurar ativos");
      return INIT_FAILED;
   }

   // Inicializar tempos de barras
   for (int i = 0; i < ArraySize(g_lastBarTimes); i++)
   {
      g_lastBarTimes[i] = 0;
   }

   g_logger.Info("IntegratedPA EA inicializado com sucesso");
   return INIT_SUCCEEDED;
}

// Resto do código do EA...

#endif // INTEGRATEDPA_EA_MQ5_
