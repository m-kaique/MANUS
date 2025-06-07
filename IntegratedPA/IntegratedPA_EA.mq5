//+------------------------------------------------------------------+
//|                                           IntegratedPA_EA.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.02"
#property description "Expert Advisor baseado em Price Action com suporte multi-símbolo - REFATORADO E CORRIGIDO"
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
#include "Constants.mqh"
#include "MarketContext.mqh"
#include "SignalEngine.mqh"
#include "RiskManager.mqh"
#include "TradeExecutor.mqh"
#include "Logger.mqh"
#include "Utils.mqh"
#include "IndicatorManager.mqh"

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
CIndicatorManager *g_indicatorManager = NULL;

// Variáveis para controle de tempo e throttling
datetime g_lastPeriodicTime = 0;      // Última execução de tarefas periódicas (5s)
datetime g_lastNewBarTime = 0;        // Última verificação de nova barra
datetime g_lastReportTime = 0;        // Último relatório (1h)
datetime g_lastExportTime = 0;        // Última exportação de logs

// Intervalos de tempo
const int PERIODIC_INTERVAL = 5;     // Tarefas periódicas a cada 5 segundos
const int REPORT_INTERVAL = 3600;    // Relatórios a cada 1 hora
const int EXPORT_INTERVAL = 3600;    // Exportação de logs a cada 1 hora

// Contadores de performance
int g_ticksProcessed = 0;
int g_signalsGenerated = 0;
int g_ordersExecuted = 0;
int g_positionsManaged = 0;

// Cache de fases de mercado
MARKET_PHASE g_lastPhases[];

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
   bool historyAvailable;
   int minRequiredBars;
};

// Array de ativos configurados
AssetConfig g_assets[];

// Variáveis para controle de tempo por ativo
datetime g_lastBarTimes[];

// Constante para o mínimo de barras necessárias
#define MIN_REQUIRED_BARS 200

//+------------------------------------------------------------------+
//| Função para verificar se o histórico está disponível             |
//+------------------------------------------------------------------+
bool IsHistoryAvailable(string symbol, ENUM_TIMEFRAMES timeframe, int minBars = MIN_REQUIRED_BARS)
{
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

   if (EnableBTC) assetsCount++;
   if (EnableWDO) assetsCount++;
   if (EnableWIN) assetsCount++;

   if (assetsCount == 0)
   {
      if (g_logger != NULL)
      {
         g_logger.Error("Nenhum ativo habilitado para operação");
      }
      return false;
   }

   ArrayResize(g_assets, assetsCount);
   int index = 0;

   // Configurar BIT$Dcoin
   if (EnableBTC)
   {
      g_assets[index].symbol = "BIT$D";
      g_assets[index].enabled = true;
      g_assets[index].minLot = 0.01;
      g_assets[index].maxLot = 10.0;
      g_assets[index].lotStep = 0.01;
      g_assets[index].tickValue = SymbolInfoDouble("BIT$D", SYMBOL_TRADE_TICK_VALUE);
      g_assets[index].digits = (int)SymbolInfoInteger("BIT$D", SYMBOL_DIGITS);
      g_assets[index].riskPercentage = RiskPerTrade * 0.8;
      g_assets[index].usePartials = true;
      g_assets[index].historyAvailable = false;
      g_assets[index].minRequiredBars = MIN_REQUIRED_BARS;

      g_assets[index].partialLevels[0] = 1.0;
      g_assets[index].partialLevels[1] = 2.0;
      g_assets[index].partialLevels[2] = 3.0;
      g_assets[index].partialVolumes[0] = 0.3;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.4;

      SymbolSelect("BIT$D", true);
      index++;
   }

   // Configurar WDO
   if (EnableWDO)
   {
      g_assets[index].symbol = "WDO$D";
      g_assets[index].enabled = true;
      g_assets[index].minLot = 1.0;
      g_assets[index].maxLot = 100.0;
      g_assets[index].lotStep = 1.0;
      g_assets[index].tickValue = SymbolInfoDouble("WDO$D", SYMBOL_TRADE_TICK_VALUE);
      g_assets[index].digits = (int)SymbolInfoInteger("WDO$D", SYMBOL_DIGITS);
      g_assets[index].riskPercentage = RiskPerTrade;
      g_assets[index].usePartials = true;
      g_assets[index].historyAvailable = false;
      g_assets[index].minRequiredBars = MIN_REQUIRED_BARS;

      g_assets[index].partialLevels[0] = 1.0;
      g_assets[index].partialLevels[1] = 1.5;
      g_assets[index].partialLevels[2] = 2.0;
      g_assets[index].partialVolumes[0] = 0.4;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.3;

      SymbolSelect("WDO$D", true);
      index++;
   }

   // Configurar WIN
   if (EnableWIN)
   {
      g_assets[index].symbol = "WIN$D";
      g_assets[index].enabled = true;
      g_assets[index].minLot = 1.0;
      g_assets[index].maxLot = 2.0;
      g_assets[index].lotStep = 1.0;
      g_assets[index].tickValue = SymbolInfoDouble("WIN$D", SYMBOL_TRADE_TICK_VALUE);
      g_assets[index].digits = (int)SymbolInfoInteger("WIN$D", SYMBOL_DIGITS);
      g_assets[index].riskPercentage = RiskPerTrade * 0.9;
      g_assets[index].usePartials = true;
      g_assets[index].historyAvailable = false;
      g_assets[index].minRequiredBars = MIN_REQUIRED_BARS;

      g_assets[index].partialLevels[0] = 1.0;
      g_assets[index].partialLevels[1] = 1.5;
      g_assets[index].partialLevels[2] = 2.0;
      g_assets[index].partialVolumes[0] = 0.5;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.2;

      SymbolSelect("WIN$D", true);
   }

   // Verificar disponibilidade de histórico
   for (int i = 0; i < assetsCount; i++)
   {
      g_assets[i].historyAvailable = IsHistoryAvailable(g_assets[i].symbol, MainTimeframe, g_assets[i].minRequiredBars);
   }

   if (g_logger != NULL)
   {
      g_logger.Info(StringFormat("Configurados %d ativos para operação", assetsCount));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Função para configurar parâmetros de risco                       |
//+------------------------------------------------------------------+
bool ConfigureRiskParameters()
{
   if (g_riskManager == NULL)
   {
      if (g_logger != NULL)
      {
         g_logger.Error("RiskManager não inicializado");
      }
      return false;
   }

   for (int i = 0; i < ArraySize(g_assets); i++)
   {
      g_riskManager.AddSymbol(g_assets[i].symbol, g_assets[i].riskPercentage, g_assets[i].maxLot);

      if (g_assets[i].usePartials)
      {
         g_riskManager.ConfigureSymbolPartials(g_assets[i].symbol, true,
                                               g_assets[i].partialLevels,
                                               g_assets[i].partialVolumes);
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Função de inicialização do Expert Advisor                        |
//+------------------------------------------------------------------+
int OnInit()
{
   // Inicializar o logger primeiro
   g_logger = new CLogger();
   if (g_logger == NULL)
   {
      Print("Erro ao criar objeto Logger");
      return (INIT_FAILED);
   }

   g_logger.Info("=== INICIANDO EXPERT ADVISOR ===");
   g_logger.SetLogLevel(LOG_LEVEL_INFO);

   // Verificar compatibilidade
   if (MQLInfoInteger(MQL_TESTER) == false)
   {
      if (TerminalInfoInteger(TERMINAL_BUILD) < 4885)
      {
         g_logger.Error("Este EA requer MetaTrader 5 Build 4885 ou superior");
         return (INIT_FAILED);
      }
   }

   // Configurar ativos
   if (!SetupAssets())
   {
      g_logger.Error("Falha ao configurar ativos");
      return (INIT_FAILED);
   }

  // Inicializar IndicatorManager SEM limites ou timeouts
   g_indicatorManager = new CIndicatorManager();
   if (g_indicatorManager == NULL)
   {
      g_logger.Error("Erro ao criar objeto IndicatorManager");
      return (INIT_FAILED);
   }
   g_indicatorManager.Initialize(g_logger);

   // Inicializar MarketContext COM IndicatorManager
   g_marketContext = new CMarketContext();
   if (g_marketContext == NULL)
   {
      g_logger.Error("Erro ao criar objeto MarketContext");
      return (INIT_FAILED);
   }

   // CORREÇÃO: Passar o IndicatorManager como parâmetro
   if (!g_marketContext.Initialize(Symbol(), MainTimeframe, g_logger, false, g_indicatorManager))
   {
      g_logger.Error("Falha ao inicializar MarketContext");
      return (INIT_FAILED);
   }

   // Criar SignalEngine com os parâmetros corretos
   g_signalEngine = new CSignalEngine(g_logger, g_marketContext, g_indicatorManager);
   if (g_signalEngine == NULL)
   {
      g_logger.Error("Erro ao criar objeto SignalEngine com parâmetros");
      return (INIT_FAILED);
   }

   // Initialize já vai usar os objetos passados no construtor
   if (!g_signalEngine.Initialize(g_logger, g_marketContext))
   {
      g_logger.Error("Falha ao inicializar SignalEngine");
      return (INIT_FAILED);
   }

   // Inicializar RiskManager
   g_riskManager = new CRiskManager(RiskPerTrade, MaxTotalRisk);
   if (g_riskManager == NULL)
   {
      g_logger.Error("Erro ao criar objeto RiskManager");
      return (INIT_FAILED);
   }

   if (!g_riskManager.Initialize(g_logger, g_marketContext))
   {
      g_logger.Error("Falha ao inicializar RiskManager");
      return (INIT_FAILED);
   }

   // Configurar parâmetros de risco
   if (!ConfigureRiskParameters())
   {
      g_logger.Error("Falha ao configurar parâmetros de risco");
      return (INIT_FAILED);
   }

   // Inicializar TradeExecutor
   g_tradeExecutor = new CTradeExecutor();
   if (g_tradeExecutor == NULL)
   {
      g_logger.Error("Erro ao criar objeto TradeExecutor");
      return (INIT_FAILED);
   }

   if (!g_tradeExecutor.Initialize(g_logger))
   {
      g_logger.Error("Falha ao inicializar TradeExecutor");
      return (INIT_FAILED);
   }

   g_tradeExecutor.SetTradeAllowed(EnableTrading);

   // Inicializar arrays de controle
   ArrayResize(g_lastBarTimes, ArraySize(g_assets));
   ArrayInitialize(g_lastBarTimes, 0);
   
   ArrayResize(g_lastPhases, ArraySize(g_assets));
   ArrayInitialize(g_lastPhases, PHASE_UNDEFINED);

   // Configurar timer
   if (!EventSetTimer(60))
   {
      g_logger.Warning("Falha ao configurar timer");
   }

   g_logger.Info("Expert Advisor iniciado com sucesso - Estrutura refatorada ativa");
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   string reasonStr;
   switch (reason)
   {
   case REASON_PROGRAM: reasonStr = "Programa finalizado"; break;
   case REASON_REMOVE: reasonStr = "EA removido do gráfico"; break;
   case REASON_RECOMPILE: reasonStr = "EA recompilado"; break;
   case REASON_CHARTCHANGE: reasonStr = "Símbolo ou período alterado"; break;
   case REASON_CHARTCLOSE: reasonStr = "Gráfico fechado"; break;
   case REASON_PARAMETERS: reasonStr = "Parâmetros alterados"; break;
   case REASON_ACCOUNT: reasonStr = "Outra conta ativada"; break;
   default: reasonStr = "Motivo desconhecido";
   }

   if (g_logger != NULL)
   {
      g_logger.Info("Expert Advisor finalizado. Motivo: " + reasonStr);
   }

    EventKillTimer();

   // Exportar logs finais
   if (g_logger != NULL)
   {
      g_logger.ExportToCSV("IntegratedPA_EA_log.csv");
   }

   // IMPORTANTE: Liberar na ordem inversa de criação
   // 1. TradeExecutor (não usa indicadores)
   if (g_tradeExecutor != NULL)
   {
      delete g_tradeExecutor;
      g_tradeExecutor = NULL;
   }
   
   // 2. RiskManager (pode usar MarketContext)
   if (g_riskManager != NULL)
   {
      delete g_riskManager;
      g_riskManager = NULL;
   }
   
   // 3. SignalEngine (usa MarketContext)
   if (g_signalEngine != NULL)
   {
      delete g_signalEngine;
      g_signalEngine = NULL;
   }
   
   // 4. MarketContext (usa IndicatorManager)
   if (g_marketContext != NULL)
   {
      delete g_marketContext;
      g_marketContext = NULL;
   }
   
   // 5. IndicatorManager (ÚLTIMO - liberará todos os handles)
   if (g_indicatorManager != NULL)
   {
      if (g_logger != NULL)
      {
         g_logger.Info("Liberando IndicatorManager e todos os handles...");
      }
      delete g_indicatorManager;
      g_indicatorManager = NULL;
   }
   
   // 6. Logger (último de todos)
   if (g_logger != NULL)
   {
      delete g_logger;
      g_logger = NULL;
   }
}

//+------------------------------------------------------------------+
//| NOVA ESTRUTURA OnTick - REFATORADA CONFORME ANÁLISE             |
//+------------------------------------------------------------------+
// Modificação no método OnTick para log melhorado:
void OnTick()
{
   g_ticksProcessed++;
   
   // Log apenas a cada 100 ticks para reduzir spam
   if (g_logger != NULL && g_ticksProcessed % 100 == 0) {
      g_logger.Debug(StringFormat("OnTick: Processando tick #%d (cada 100 ticks)", g_ticksProcessed));
   }

   // === 1. OPERAÇÕES CRÍTICAS - EXECUTAM A CADA TICK ===
   ProcessCriticalTasks();

   // === 2. TAREFAS PERIÓDICAS - A CADA 5 SEGUNDOS ===
   if (ShouldProcessPeriodic()) {
      ProcessPeriodicTasks();
   }

   // === 3. ANÁLISE DE NOVA BARRA - APENAS EM NOVA BARRA ===
   if (HasNewBarInAnyAsset()) {
      if (g_logger != NULL) {
         g_logger.Info("🔄 NOVA BARRA DETECTADA - Iniciando análise de sinais...");
      }
      ProcessNewSignals();
   }
}

//+------------------------------------------------------------------+
//| 1. OPERAÇÕES CRÍTICAS - A CADA TICK                             |
//+------------------------------------------------------------------+
void ProcessCriticalTasks()
{
   // Validações básicas
   if (g_tradeExecutor == NULL || g_riskManager == NULL)
   {
      return;
   }

   // === GERENCIAMENTO DE POSIÇÕES ABERTAS ===
   // SL/TP, trailing stop, parciais, breakeven - SEMPRE A CADA TICK
   ManageExistingPositions();
}

//+------------------------------------------------------------------+
//| 2. TAREFAS PERIÓDICAS - A CADA 5 SEGUNDOS                       |
//+------------------------------------------------------------------+
bool ShouldProcessPeriodic()
{
   datetime currentTime = TimeCurrent();
   
   if (currentTime - g_lastPeriodicTime >= PERIODIC_INTERVAL)
   {
      g_lastPeriodicTime = currentTime;
      return true;
   }
   
   return false;
}

void ProcessPeriodicTasks()
{
   if (g_logger != NULL)
   {
      g_logger.Debug("ProcessPeriodicTasks: Executando tarefas periódicas");
   }

   // === ATUALIZAÇÃO DE CONTA E RISCO ===
   UpdateGlobalInformation();

   // === VERIFICAÇÃO DE INTEGRIDADE ===
   VerifySystemIntegrity();

   // === RELATÓRIOS DE PERFORMANCE ===
   datetime currentTime = TimeCurrent();
   if (currentTime - g_lastReportTime >= REPORT_INTERVAL)
   {
      GeneratePerformanceReports();
      g_lastReportTime = currentTime;
   }
}

//+------------------------------------------------------------------+
//| 3. ANÁLISE DE NOVA BARRA - APENAS EM NOVA BARRA                 |
//+------------------------------------------------------------------+
bool HasNewBarInAnyAsset()
{
   bool hasNewBar = false;
   
   for (int i = 0; i < ArraySize(g_assets); i++)
   {
      if (!g_assets[i].enabled || !g_assets[i].historyAvailable)
      {
         continue;
      }

      datetime currentBarTime = iTime(g_assets[i].symbol, MainTimeframe, 0);
      if (currentBarTime != g_lastBarTimes[i])
      {
         g_lastBarTimes[i] = currentBarTime;
         hasNewBar = true;
         
         if (g_logger != NULL)
         {
            g_logger.Debug(StringFormat("Nova barra detectada: %s em %s", 
                                       g_assets[i].symbol, 
                                       TimeToString(currentBarTime)));
         }
      }
   }
   
   return hasNewBar;
}

void ProcessNewSignals()
{
   if (g_logger != NULL)
   {
      g_logger.Debug("ProcessNewSignals: Analisando sinais em nova barra");
   }

   // === ANÁLISE DE MERCADO E GERAÇÃO DE SINAIS ===
   ProcessAllAssets();
}

//+------------------------------------------------------------------+
//| GERENCIAMENTO DE POSIÇÕES - OPERAÇÃO CRÍTICA                    |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   if (g_tradeExecutor == NULL || g_riskManager == NULL)
   {
      return;
   }

   ulong eaMagicNumber = g_tradeExecutor.GetMagicNumber();
   int positionsManaged = 0;

   // CORREÇÃO: Obter lista de tickets primeiro para evitar problemas durante a iteração
   ulong tickets[];
   int totalPositions = PositionsTotal();
   int validPositions = 0;

   // Coletar tickets das posições válidas
   ArrayResize(tickets, totalPositions);
   
   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0) continue;

      // Verificar se a posição pertence a este EA
      if (PositionGetInteger(POSITION_MAGIC) != eaMagicNumber) continue;

      tickets[validPositions] = ticket;
      validPositions++;
   }

   // Redimensionar array para o tamanho correto
   ArrayResize(tickets, validPositions);

   if (g_logger != NULL && validPositions > 0) {
      g_logger.Debug(StringFormat("Gerenciando %d posições ativas", validPositions));
   }

   // Processar cada posição válida
   for (int i = 0; i < validPositions; i++)
   {
      ulong ticket = tickets[i];
      
      // VERIFICAÇÃO CRÍTICA: Confirmar que a posição ainda existe
      if (!PositionSelectByTicket(ticket)) {
         if (g_logger != NULL) {
            g_logger.Debug(StringFormat("Posição #%d não existe mais, pulando", ticket));
         }
         continue;
      }

      // Obter informações atuais da posição
      string symbol = PositionGetString(POSITION_SYMBOL);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double currentVolume = PositionGetDouble(POSITION_VOLUME);

      // Log de debug detalhado
      if (g_logger != NULL) {
         g_logger.Debug(StringFormat("Processando posição #%d: %s %.2f lotes @ %.5f", 
                                   ticket, symbol, currentVolume, currentPrice));
      }

      // === 1. VERIFICAR E EXECUTAR PARCIAIS ===
      bool shouldTakePartial = g_riskManager.ShouldTakePartial(symbol, ticket, currentPrice, entryPrice, stopLoss);
      
      if (shouldTakePartial) {
         if (g_logger != NULL) {
            g_logger.Info(StringFormat("⚡ EXECUTANDO PARCIAL para posição #%d", ticket));
         }
         
         bool partialSuccess = ExecutePartialClose(ticket, symbol, currentPrice, entryPrice, stopLoss);
         
         if (partialSuccess) {
            // IMPORTANTE: Revalidar posição após parcial
            if (!PositionSelectByTicket(ticket)) {
               if (g_logger != NULL) {
                  g_logger.Info(StringFormat("Posição #%d fechada completamente após parcial", ticket));
               }
               continue; // Pular trailing stop se posição não existe mais
            }
            
            // Atualizar volume atual após parcial
            currentVolume = PositionGetDouble(POSITION_VOLUME);
            
            if (g_logger != NULL) {
               g_logger.Info(StringFormat("Posição #%d após parcial: %.2f lotes restantes", ticket, currentVolume));
            }
         }
      }

      // === 2. APLICAR TRAILING STOP (apenas se posição ainda existe) ===
      if (PositionSelectByTicket(ticket)) {
         ApplyTrailingStopBySymbol(ticket, symbol);
         positionsManaged++;
      } else {
         if (g_logger != NULL) {
            g_logger.Debug(StringFormat("Posição #%d não existe mais para trailing stop", ticket));
         }
      }
   }

   // Log apenas quando necessário
   if (positionsManaged > 0)
   {
      g_positionsManaged += positionsManaged;
      
      if (g_logger != NULL) {
         g_logger.Debug(StringFormat("✅ Gerenciadas %d posições (SL/TP/Trailing/Parciais)", positionsManaged));
      }
   }
}
//+------------------------------------------------------------------+
//| Executar fechamento parcial                                      |
//+------------------------------------------------------------------+
bool ExecutePartialClose(ulong ticket, string symbol, double currentPrice, double entryPrice, double stopLoss)
{
   // Verificar se a posição ainda existe
   if (!PositionSelectByTicket(ticket)) {
      if (g_logger != NULL) {
         g_logger.Warning(StringFormat("ExecutePartialClose: Posição #%d não existe mais", ticket));
      }
      return false;
   }

   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // Calcular R:R atual
   double stopDistance = MathAbs(entryPrice - stopLoss);
   double currentDistance = 0;

   if (posType == POSITION_TYPE_BUY)
   {
      currentDistance = currentPrice - entryPrice;
   }
   else
   {
      currentDistance = entryPrice - currentPrice;
   }

   double currentRR = (stopDistance > 0) ? currentDistance / stopDistance : 0;

   // Obter volume para parcial
   double partialVolume = g_riskManager.GetPartialVolume(symbol, ticket, currentRR);

   if (partialVolume > 0 && partialVolume < currentVolume)
   {
      if (g_logger != NULL) {
         g_logger.Info(StringFormat("🎯 EXECUTANDO PARCIAL: %s ticket #%d", symbol, ticket));
         g_logger.Info(StringFormat("   Volume atual: %.2f lotes", currentVolume));
         g_logger.Info(StringFormat("   Volume parcial: %.2f lotes", partialVolume));
         g_logger.Info(StringFormat("   R:R atual: %.2f", currentRR));
         g_logger.Info(StringFormat("   Volume restante: %.2f lotes", currentVolume - partialVolume));
      }

      // Executar fechamento parcial
      if (g_tradeExecutor.ClosePosition(ticket, partialVolume))
      {
         if (g_logger != NULL) {
            g_logger.Info(StringFormat("✅ PARCIAL EXECUTADA: %s %.2f lotes", symbol, partialVolume));
         }
         return true;
      }
      else
      {
         if (g_logger != NULL) {
            g_logger.Warning(StringFormat("❌ FALHA na parcial: %s - %s", symbol, g_tradeExecutor.GetLastErrorDescription()));
         }
         return false;
      }
   }
   else if (partialVolume >= currentVolume)
   {
      if (g_logger != NULL) {
         g_logger.Info(StringFormat("Parcial seria maior que posição atual (%.2f >= %.2f), pulando", 
                                  partialVolume, currentVolume));
      }
      return false;
   }
   else
   {
      if (g_logger != NULL) {
         g_logger.Debug(StringFormat("Sem parcial necessária para %s (volume: %.2f)", symbol, partialVolume));
      }
      return false;
   }
}
//+------------------------------------------------------------------+
//| Aplicar trailing stop específico por símbolo                     |
//+------------------------------------------------------------------+
void ApplyTrailingStopBySymbol(ulong ticket, string symbol)
{
   double trailingPoints = 0;

   // Determinar trailing stop específico por ativo
   if (StringFind(symbol, "WIN") >= 0)
   {
      trailingPoints = WIN_TRAILING_STOP;
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      trailingPoints = WDO_TRAILING_STOP;
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      trailingPoints = BTC_TRAILING_STOP;
   }

   if (trailingPoints > 0)
   {
      g_tradeExecutor.ApplyTrailingStop(ticket, trailingPoints);
   }
}

//+------------------------------------------------------------------+
//| Atualizar informações globais                                    |
//+------------------------------------------------------------------+
void UpdateGlobalInformation()
{
   // Atualizar informações da conta
   if (g_riskManager != NULL)
   {
      g_riskManager.UpdateAccountInfo();
   }

   // Verificar disponibilidade de histórico para ativos pendentes
   for (int i = 0; i < ArraySize(g_assets); i++)
   {
      if (!g_assets[i].historyAvailable)
      {
         g_assets[i].historyAvailable = IsHistoryAvailable(g_assets[i].symbol, MainTimeframe, g_assets[i].minRequiredBars);
         
         if (g_assets[i].historyAvailable && g_logger != NULL)
         {
            g_logger.Info("Histórico disponível para " + g_assets[i].symbol);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar integridade do sistema                                 |
//+------------------------------------------------------------------+
void VerifySystemIntegrity()
{
   // Verificar se todos os componentes estão funcionais
   bool systemOk = true;

   if (g_logger == NULL) systemOk = false;
   if (g_marketContext == NULL) systemOk = false;
   if (g_signalEngine == NULL) systemOk = false;
   if (g_riskManager == NULL) systemOk = false;
   if (g_tradeExecutor == NULL) systemOk = false;
   if (g_indicatorManager == NULL) systemOk = false;

   if (!systemOk && g_logger != NULL)
   {
      g_logger.Error("Falha na integridade do sistema - componentes não inicializados");
   }

   // Verificar handles de indicadores
   if (g_indicatorManager != NULL)
   {
      int handleCount = g_indicatorManager.GetHandleCount();
      if (handleCount > 50) // Limite de segurança
      {
         if (g_logger != NULL)
         {
            g_logger.Warning(StringFormat("Muitos handles de indicadores em uso: %d", handleCount));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Processar todos os ativos para geração de sinais                |
//+------------------------------------------------------------------+
void ProcessAllAssets()
{
   int assetsProcessed = 0;

   for (int i = 0; i < ArraySize(g_assets); i++)
   {
      if (!ValidateAsset(i))
      {
         continue;
      }

      string symbol = g_assets[i].symbol;

      // Processar ativo individual
      if (ProcessSingleAsset(symbol, i))
      {
         assetsProcessed++;
      }
   }

   if (assetsProcessed > 0 && g_logger != NULL)
   {
      g_logger.Debug(StringFormat("Processados %d ativos para análise de sinais", assetsProcessed));
   }
}

//+------------------------------------------------------------------+
//| Validar se um ativo deve ser processado                          |
//+------------------------------------------------------------------+
bool ValidateAsset(int assetIndex)
{
   if (assetIndex < 0 || assetIndex >= ArraySize(g_assets))
   {
      return false;
   }

   if (!g_assets[assetIndex].enabled)
   {
      return false;
   }

   if (!g_assets[assetIndex].historyAvailable)
   {
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Processar um único ativo                                         |
//+------------------------------------------------------------------+
bool ProcessSingleAsset(string symbol, int assetIndex)
{
   // Atualizar contexto de mercado
   if (!UpdateMarketContext(symbol))
   {
      return false;
   }

   // Determinar fase de mercado
   MARKET_PHASE currentPhase = g_marketContext.DetermineMarketPhase();

   // Log apenas quando a fase muda
   LogPhaseChange(symbol, assetIndex, currentPhase);

   // Verificar se a fase está habilitada
   if (!IsPhaseEnabled(currentPhase))
   {
      return false;
   }

   // Gerar sinal
   Signal signal = GenerateSignalForPhase(symbol, currentPhase);

   // Processar sinal
   return ProcessSignal(symbol, signal, currentPhase);
}

//+------------------------------------------------------------------+
//| Atualizar contexto de mercado                                    |
//+------------------------------------------------------------------+
bool UpdateMarketContext(string symbol)
{
   if (g_marketContext == NULL)
   {
      return false;
   }

   if (!g_marketContext.UpdateSymbol(symbol))
   {
      if (g_logger != NULL)
      {
         g_logger.Warning("Falha ao atualizar contexto para " + symbol);
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Log de mudança de fase                                           |
//+------------------------------------------------------------------+
void LogPhaseChange(string symbol, int assetIndex, MARKET_PHASE currentPhase)
{
   if (assetIndex >= 0 && assetIndex < ArraySize(g_lastPhases))
   {
      if (g_lastPhases[assetIndex] != currentPhase)
      {
         if (g_logger != NULL)
         {
            g_logger.Info(StringFormat("%s: Fase alterada para %s", symbol, EnumToString(currentPhase)));
         }
         g_lastPhases[assetIndex] = currentPhase;
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar se a fase está habilitada                              |
//+------------------------------------------------------------------+
bool IsPhaseEnabled(MARKET_PHASE phase)
{
   switch (phase)
   {
   case PHASE_TREND: return EnableTrendStrategies;
   case PHASE_RANGE: return EnableRangeStrategies;
   case PHASE_REVERSAL: return EnableReversalStrategies;
   default: return false;
   }
}

//+------------------------------------------------------------------+
//| Gerar sinal com base na fase                                     |
//+------------------------------------------------------------------+
Signal GenerateSignalForPhase(string symbol, MARKET_PHASE phase)
{
   Signal signal;
   signal.id = 0; // Sinal inválido por padrão

   if (g_signalEngine == NULL)
   {
      return signal;
   }

   switch (phase)
   {
   case PHASE_TREND:
      signal = g_signalEngine.GenerateTrendSignals(symbol, MainTimeframe);
      break;
   case PHASE_RANGE:
      signal = g_signalEngine.GenerateRangeSignals(symbol, MainTimeframe);
      break;
   case PHASE_REVERSAL:
      signal = g_signalEngine.GenerateReversalSignals(symbol, MainTimeframe);
      break;
   default:
      if (g_logger != NULL)
      {
         g_logger.Debug("Fase não suportada: " + EnumToString(phase));
      }
      break;
   }

   return signal;
}

//+------------------------------------------------------------------+
//| Processar sinal gerado                                           |
//+------------------------------------------------------------------+
bool ProcessSignal(string symbol, Signal &signal, MARKET_PHASE phase)
{
   // Verificar se o sinal é válido
   if (signal.id <= 0 || signal.quality == SETUP_INVALID) {
      return false;
   }

   // Verificar qualidade mínima do setup
   if (signal.quality > MinSetupQuality) {
      if (g_logger != NULL) {
         g_logger.Debug(StringFormat("%s: Setup %s descartado (mínimo: %s)", 
                                    symbol, 
                                    EnumToString(signal.quality),
                                    EnumToString(MinSetupQuality)));
      }
      return false;
   }

   g_signalsGenerated++;

   // Log do sinal ANTES da execução
   if (g_logger != NULL) {
      string direction = (signal.direction == ORDER_TYPE_BUY) ? "COMPRA" : "VENDA";
      g_logger.Info(StringFormat("🎯 SINAL DETECTADO: %s %s %s Q:%s - Preparando execução a mercado", 
                                symbol, direction, signal.strategy, EnumToString(signal.quality)));
   }

   // NOVA LÓGICA: Criar requisição para execução imediata a mercado
   OrderRequest request = CreateMarketOrderRequest(symbol, signal, phase);
   
   if (request.volume <= 0) {
      if (g_logger != NULL) {
         g_logger.Warning("Requisição de ordem inválida ou cancelada pelo RiskManager");
      }
      return false;
   }

   // VALIDAÇÃO ADICIONAL: Usar função de debug se disponível
   if (g_logger != NULL) {
      ValidateAndDebugTradingParameters(request.symbol, request.type, 
                                      request.price, request.stopLoss, 
                                      request.takeProfit, request.volume, g_logger);
   }

   // Executar ordem a mercado
   return ExecuteMarketOrder(request);
}

// Nova função para criar requisições de mercado:
OrderRequest CreateMarketOrderRequest(string symbol, Signal &signal, MARKET_PHASE phase)
{
   OrderRequest request;
   request.id = 0; // Requisição inválida por padrão

   if (g_riskManager == NULL) {
      if (g_logger != NULL) {
         g_logger.Error("RiskManager não disponível para criar requisição de mercado");
      }
      return request;
   }

   // Obter tick atual para referência
   MqlTick currentTick;
   if (!SymbolInfoTick(symbol, currentTick)) {
      if (g_logger != NULL) {
         g_logger.Error("Falha ao obter tick atual para " + symbol);
      }
      return request;
   }

   if (g_logger != NULL) {
      string direction = (signal.direction == ORDER_TYPE_BUY) ? "COMPRA" : "VENDA";
      double marketPrice = (signal.direction == ORDER_TYPE_BUY) ? currentTick.ask : currentTick.bid;
      
      g_logger.Info(StringFormat("📊 CRIANDO REQUISIÇÃO A MERCADO:",""));
      g_logger.Info(StringFormat("   Símbolo: %s", symbol));
      g_logger.Info(StringFormat("   Direção: %s", direction));
      g_logger.Info(StringFormat("   Preço mercado: %.5f (%s)", marketPrice, 
                                signal.direction == ORDER_TYPE_BUY ? "ASK" : "BID"));
      g_logger.Info(StringFormat("   Spread atual: %.5f", currentTick.ask - currentTick.bid));
   }

   // RiskManager criará a requisição baseada no mercado atual
   request = g_riskManager.BuildRequest(symbol, signal, phase);
   
   if (request.volume > 0 && g_logger != NULL) {
      g_logger.Info(StringFormat("✅ Requisição criada: %.2f lotes, SL: %.5f, TP: %.5f", 
                                request.volume, request.stopLoss, request.takeProfit));
   }

   return request;
}

// Nova função para executar ordens a mercado:
bool ExecuteMarketOrder(OrderRequest &request)
{
   if (request.volume <= 0 || request.symbol == "") {
      if (g_logger != NULL) {
         g_logger.Warning("Requisição de ordem inválida para execução a mercado");
      }
      return false;
   }

   if (g_tradeExecutor == NULL) {
      if (g_logger != NULL) {
         g_logger.Error("TradeExecutor não disponível");
      }
      return false;
   }

   if (g_logger != NULL) {
      g_logger.Info(StringFormat("🚀 EXECUTANDO ORDEM A MERCADO:",""));
      g_logger.Info(StringFormat("   %s %s %.2f lotes", 
                                request.symbol,
                                request.type == ORDER_TYPE_BUY ? "COMPRA" : "VENDA",
                                request.volume));
   }

   // Executar com o TradeExecutor modificado (sempre a mercado)
   bool success = g_tradeExecutor.Execute(request);
   
   if (success) {
      g_ordersExecuted++;
      if (g_logger != NULL) {
         g_logger.Info(StringFormat("✅ ORDEM EXECUTADA COM SUCESSO! Total de ordens: %d", g_ordersExecuted));
      }
   } else {
      if (g_logger != NULL) {
         g_logger.Error(StringFormat("❌ FALHA NA EXECUÇÃO: %s", g_tradeExecutor.GetLastErrorDescription()));
         
         // Log adicional para debug
         g_logger.Error("Detalhes da falha:");
         g_logger.Error(StringFormat("   Erro código: %d", g_tradeExecutor.GetLastError()));
         g_logger.Error(StringFormat("   Símbolo: %s", request.symbol));
         g_logger.Error(StringFormat("   Volume: %.2f", request.volume));
         g_logger.Error(StringFormat("   Trading habilitado: %s", EnableTrading ? "SIM" : "NÃO"));
      }
   }

   return success;
}
//+------------------------------------------------------------------+
//| Log de sinal gerado                                              |
//+------------------------------------------------------------------+
void LogSignalGenerated(string symbol, Signal &signal)
{
   if (g_logger == NULL) return;

   string direction = (signal.direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string strategy = signal.strategy;
   string quality = EnumToString(signal.quality);

   g_logger.Info(StringFormat("Sinal gerado: %s %s %s Q:%s R:R:%.1f @%.5f",
                              symbol, direction, strategy, quality,
                              signal.riskRewardRatio, signal.entryPrice));
}

//+------------------------------------------------------------------+
//| Criar requisição de ordem                                         |
//+------------------------------------------------------------------+
OrderRequest CreateOrderRequest(string symbol, Signal &signal, MARKET_PHASE phase)
{
   OrderRequest request;
   request.id = 0; // Requisição inválida por padrão

   if (g_riskManager == NULL)
   {
      if (g_logger != NULL)
      {
         g_logger.Error("RiskManager não disponível para criar requisição");
      }
      return request;
   }

   request = g_riskManager.BuildRequest(symbol, signal, phase);
   return request;
}

//+------------------------------------------------------------------+
//| Executar ordem                                                   |
//+------------------------------------------------------------------+
bool ExecuteOrder(OrderRequest &request)
{
   if (request.volume <= 0 || request.price <= 0)
   {
      if (g_logger != NULL)
      {
         g_logger.Warning("Requisição de ordem inválida");
      }
      return false;
   }

   if (g_tradeExecutor == NULL)
   {
      if (g_logger != NULL)
      {
         g_logger.Error("TradeExecutor não disponível");
      }
      return false;
   }

   if (g_tradeExecutor.Execute(request))
   {
      g_ordersExecuted++;
      if (g_logger != NULL)
      {
         g_logger.Info(StringFormat("Ordem executada: %s %.2f lotes @%.5f",
                                    request.symbol, request.volume, request.price));
      }
      return true;
   }
   else
   {
      if (g_logger != NULL)
      {
         g_logger.Warning(StringFormat("Falha na execução: %s", g_tradeExecutor.GetLastErrorDescription()));
      }
      return false;
   }
}

//+------------------------------------------------------------------+
//| Gerar relatórios de performance                                  |
//+------------------------------------------------------------------+
void GeneratePerformanceReports()
{
   if (g_logger == NULL) return;


   // Estatísticas da conta
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   int openPositions = PositionsTotal();

   // Calcular estatísticas do período
   double ticksPerMinute = (double)g_ticksProcessed / (REPORT_INTERVAL / 60.0);

   // Log do relatório
   g_logger.Info("=== RELATÓRIO DE PERFORMANCE (1h) ===");
   g_logger.Info(StringFormat("📈 ESTATÍSTICAS DE TRADING:",""));
   g_logger.Info(StringFormat("   Ticks processados: %d (%.1f/min)", g_ticksProcessed, ticksPerMinute));
   g_logger.Info(StringFormat("   Sinais gerados: %d", g_signalsGenerated));
   g_logger.Info(StringFormat("   Ordens executadas: %d", g_ordersExecuted));
   g_logger.Info(StringFormat("   Posições gerenciadas: %d", g_positionsManaged));
   g_logger.Info(StringFormat("   Taxa de conversão: %.1f%% (ordens/sinais)", 
                            g_signalsGenerated > 0 ? (double)g_ordersExecuted / g_signalsGenerated * 100 : 0));

   g_logger.Info(StringFormat("💰 INFORMAÇÕES DA CONTA:",""));
   g_logger.Info(StringFormat("   Saldo: %.2f", currentBalance));
   g_logger.Info(StringFormat("   Equity: %.2f", currentEquity));
   g_logger.Info(StringFormat("   Margem Livre: %.2f", freeMargin));
   g_logger.Info(StringFormat("   Posições Abertas: %d", openPositions));

   // Estatísticas de handles
   if (g_indicatorManager != NULL)
   {
      int handleCount = g_indicatorManager.GetHandleCount();
      g_logger.Info(StringFormat("Handles de indicadores em uso: %d", handleCount));
   }

   // Reset contadores
   g_ticksProcessed = 0;
   g_signalsGenerated = 0;
   g_ordersExecuted = 0;
   g_positionsManaged = 0;
}

//+------------------------------------------------------------------+
//| Função de timer                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   if (g_logger == NULL) return;

   datetime currentTime = TimeCurrent();
   
   // Exportar logs periodicamente
   if (currentTime - g_lastExportTime >= EXPORT_INTERVAL)
   {
      g_logger.ExportToCSV("IntegratedPA_EA_log.csv");
      g_lastExportTime = currentTime;
      
      g_logger.Info("Logs exportados automaticamente");
   }

   // REMOVIDO: Manutenção de handles
   // NÃO CHAMAR MAIS: g_indicatorManager.PerformMaintenance();
   
   // Apenas imprimir estatísticas para debug (opcional)
   if (g_indicatorManager != NULL)
   {
      g_logger.Debug(StringFormat("IndicatorManager: %d handles permanentes em uso", 
                                g_indicatorManager.GetHandleCount()));
   }
}

//+------------------------------------------------------------------+
//| Função de eventos de trade                                       |
//+------------------------------------------------------------------+
void OnTrade()
{
   if (g_logger == NULL) return;

   g_logger.Debug("Evento de trade detectado");

   // Atualizar informações da conta
   if (g_riskManager != NULL)
   {
      g_riskManager.UpdateAccountInfo();
   }
}

//+------------------------------------------------------------------+
//| Função de eventos de livro de ofertas                            |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
   if (g_logger == NULL || g_marketContext == NULL) return;

   // Atualizar profundidade de mercado se necessário
   for (int i = 0; i < ArraySize(g_assets); i++)
   {
      if (g_assets[i].symbol == symbol && g_assets[i].enabled)
      {
         g_marketContext.UpdateMarketDepth(symbol);
         break;
      }
   }
}

//+------------------------------------------------------------------+

