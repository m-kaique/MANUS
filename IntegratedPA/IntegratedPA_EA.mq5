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
   double riskPercentage;
   bool usePartials;
   double partialLevels[3];
   double partialVolumes[3];
   bool historyAvailable; // Flag para indicar se o histórico está disponível
   int minRequiredBars;   // Mínimo de barras necessárias para análise
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
      else
      {
         Print("Nenhum ativo habilitado para operação");
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
      g_assets[index].riskPercentage = RiskPerTrade * 0.8; // 20% menos risco para BTC
      g_assets[index].usePartials = true;
      g_assets[index].historyAvailable = false;
      g_assets[index].minRequiredBars = MIN_REQUIRED_BARS;

      // Configurar níveis de parciais para BTC
      g_assets[index].partialLevels[0] = 1.0;
      g_assets[index].partialLevels[1] = 2.0;
      g_assets[index].partialLevels[2] = 3.0;

      g_assets[index].partialVolumes[0] = 0.3;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.4;

      if (!SymbolSelect("BIT$D", true))
      {
         if (g_logger != NULL)
         {
            g_logger.Warning("Falha ao selecionar símbolo BIT$D");
         }
         else
         {
            Print("Falha ao selecionar símbolo BIT$D");
         }
      }

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
      g_assets[index].riskPercentage = RiskPerTrade; // Risco normal para WDO
      g_assets[index].usePartials = true;
      g_assets[index].historyAvailable = false;
      g_assets[index].minRequiredBars = MIN_REQUIRED_BARS;

      // Configurar níveis de parciais para WDO
      g_assets[index].partialLevels[0] = 1.0;
      g_assets[index].partialLevels[1] = 1.5;
      g_assets[index].partialLevels[2] = 2.0;

      g_assets[index].partialVolumes[0] = 0.4;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.3;

      if (!SymbolSelect("WDO$D", true))
      {
         if (g_logger != NULL)
         {
            g_logger.Warning("Falha ao selecionar símbolo WDO");
         }
         else
         {
            Print("Falha ao selecionar símbolo WDO");
         }
      }

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
      g_assets[index].riskPercentage = RiskPerTrade * 0.9; // 10% menos risco para WIN
      g_assets[index].usePartials = true;
      g_assets[index].historyAvailable = false;
      g_assets[index].minRequiredBars = MIN_REQUIRED_BARS;

      // Configurar níveis de parciais para WIN
      g_assets[index].partialLevels[0] = 1.0;
      g_assets[index].partialLevels[1] = 1.5;
      g_assets[index].partialLevels[2] = 2.0;

      g_assets[index].partialVolumes[0] = 0.5;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.2;

      if (!SymbolSelect("WIN$D", true))
      {
         if (g_logger != NULL)
         {
            g_logger.Warning("Falha ao selecionar símbolo WIN$");
         }
         else
         {
            Print("Falha ao selecionar símbolo WIN$");
         }
      }
   }

   // Verificar disponibilidade de histórico para cada ativo
   for (int i = 0; i < assetsCount; i++)
   {
      g_assets[i].historyAvailable = IsHistoryAvailable(g_assets[i].symbol, MainTimeframe, g_assets[i].minRequiredBars);

      if (!g_assets[i].historyAvailable)
      {
         if (g_logger != NULL)
         {
            g_logger.Warning("Histórico não disponível para " + g_assets[i].symbol + ", inicialização adiada");
         }
      }
   }

   if (g_logger != NULL)
   {
      g_logger.Info(StringFormat("Configurados %d ativos para operação", assetsCount));
   }
   else
   {
      Print(StringFormat("Configurados %d ativos para operação", assetsCount));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Função para configurar parâmetros de risco para os ativos        |
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
      // Configurar parâmetros de risco específicos para cada ativo
      g_riskManager.AddSymbol(g_assets[i].symbol, g_assets[i].riskPercentage, g_assets[i].maxLot);

      // Configurar parciais para cada ativo
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
   // Inicializar o logger primeiro para registrar todo o processo
   g_logger = new CLogger();
   if (g_logger == NULL)
   {
      Print("Erro ao criar objeto Logger");
      return (INIT_FAILED);
   }

   g_logger.Info("Iniciando Expert Advisor...");

   // Verificar compatibilidade
   if (MQLInfoInteger(MQL_TESTER) == false)
   {
      if (TerminalInfoInteger(TERMINAL_BUILD) < 4885)
      {
         g_logger.Error("Este EA requer MetaTrader 5 Build 4885 ou superior");
         return (INIT_FAILED);
      }
   }

   // Configurar ativos - Apenas estrutura de dados, sem usar objetos ainda não inicializados
   if (!SetupAssets())
   {
      g_logger.Error("Falha ao configurar ativos");
      return (INIT_FAILED);
   }

   // Inicializar componentes
   g_marketContext = new CMarketContext();
   if (g_marketContext == NULL)
   {
      g_logger.Error("Erro ao criar objeto MarketContext");
      return (INIT_FAILED);
   }

   // Inicializar MarketContext com o símbolo do gráfico atual e timeframe principal
   // Passamos o flag de verificação de histórico para false, pois verificaremos em OnTick
   if (!g_marketContext.Initialize(Symbol(), MainTimeframe, g_logger, false))
   {
      g_logger.Error("Falha ao inicializar MarketContext");
      return (INIT_FAILED);
   }

   g_signalEngine = new CSignalEngine();
   if (g_signalEngine == NULL)
   {
      g_logger.Error("Erro ao criar objeto SignalEngine");
      return (INIT_FAILED);
   }

   if (!g_signalEngine.Initialize(g_logger, g_marketContext))
   {
      g_logger.Error("Falha ao inicializar SignalEngine");
      return (INIT_FAILED);
   }

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

   // Agora que o RiskManager está inicializado, configurar os parâmetros de risco
   if (!ConfigureRiskParameters())
   {
      g_logger.Error("Falha ao configurar parâmetros de risco");
      return (INIT_FAILED);
   }

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

   // Configurar o executor de trades
   g_tradeExecutor.SetTradeAllowed(EnableTrading);

   // Inicializar array de últimos tempos de barra
   ArrayResize(g_lastBarTimes, ArraySize(g_assets));
   ArrayInitialize(g_lastBarTimes, 0);

   // Configurar timer para execução periódica
   if (!EventSetTimer(60))
   { // Timer a cada 60 segundos
      g_logger.Warning("Falha ao configurar timer");
   }

   g_logger.Info("Expert Advisor iniciado com sucesso");
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização do Expert Advisor                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Registrar motivo da desinicialização
   string reasonStr;

   switch (reason)
   {
   case REASON_PROGRAM:
      reasonStr = "Programa finalizado";
      break;
   case REASON_REMOVE:
      reasonStr = "EA removido do gráfico";
      break;
   case REASON_RECOMPILE:
      reasonStr = "EA recompilado";
      break;
   case REASON_CHARTCHANGE:
      reasonStr = "Símbolo ou período do gráfico alterado";
      break;
   case REASON_CHARTCLOSE:
      reasonStr = "Gráfico fechado";
      break;
   case REASON_PARAMETERS:
      reasonStr = "Parâmetros alterados";
      break;
   case REASON_ACCOUNT:
      reasonStr = "Outra conta ativada";
      break;
   default:
      reasonStr = "Motivo desconhecido";
   }

   if (g_logger != NULL)
   {
      g_logger.Info("Expert Advisor finalizado. Motivo: " + reasonStr);
   }

   // Remover timer
   EventKillTimer();

   // Exportar logs finais
   if (g_logger != NULL)
   {
      g_logger.ExportToCSV("IntegratedPA_EA_log.csv", "Timestamp,Level,Message", "");
   }

   // Liberar memória (na ordem inversa da inicialização)
   if (g_tradeExecutor != NULL)
   {
      delete g_tradeExecutor;
      g_tradeExecutor = NULL;
   }

   if (g_riskManager != NULL)
   {
      delete g_riskManager;
      g_riskManager = NULL;
   }

   if (g_signalEngine != NULL)
   {
      delete g_signalEngine;
      g_signalEngine = NULL;
   }

   if (g_marketContext != NULL)
   {
      delete g_marketContext;
      g_marketContext = NULL;
   }

   // O logger deve ser o último a ser liberado
   if (g_logger != NULL)
   {
      g_logger.Info("Finalizando logger");
      delete g_logger;
      g_logger = NULL;
   }
}

//+------------------------------------------------------------------+
//| Função principal OnTick - Completamente reescrita               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Incrementar contador de ticks
   g_ticksProcessed++;
   
   // === VALIDAÇÕES INICIAIS ===
   if(!InitialValidations()) {
      return;
   }
   
   // === THROTTLING DE PERFORMANCE ===
   datetime currentTime = TimeCurrent();
   if(!ShouldProcessTick(currentTime)) {
      return;
   }
   
   // Atualizar tempo de último processamento
   g_lastProcessTime = currentTime;
   
   // === ATUALIZAÇÃO GLOBAL ===
   UpdateGlobalInformation();
   
   // === PROCESSAMENTO POR ATIVO ===
   bool hasNewSignals = ProcessAllAssets();
   
   // === GERENCIAMENTO DE POSIÇÕES ===
   if(hasNewSignals || ShouldManagePositions(currentTime)) {
      ManageExistingPositions();
   }
   
   // === RELATÓRIOS DE PERFORMANCE ===
   GeneratePerformanceReports(currentTime);
}

//+------------------------------------------------------------------+
//| Validações iniciais essenciais                                   |
//+------------------------------------------------------------------+
bool InitialValidations()
{
   // Verificar componentes críticos
   if(g_logger == NULL) {
      Print("ERRO: Logger não inicializado");
      return false;
   }
   
   if(g_marketContext == NULL || g_signalEngine == NULL || 
      g_riskManager == NULL || g_tradeExecutor == NULL) {
      g_logger.Error("Componentes críticos não inicializados");
      return false;
   }
   
   // Verificar se há ativos configurados
   if(ArraySize(g_assets) == 0) {
      g_logger.Warning("Nenhum ativo configurado para operação");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Determina se deve processar este tick                            |
//+------------------------------------------------------------------+
bool ShouldProcessTick(datetime currentTime)
{
   // Throttling básico por tempo
   if(currentTime - g_lastProcessTime < g_processIntervalSeconds) {
      return false;
   }
   
   // Verificar se há pelo menos uma nova barra em algum ativo
   bool hasNewBar = false;
   for(int i = 0; i < ArraySize(g_assets); i++) {
      if(!g_assets[i].enabled || !g_assets[i].historyAvailable) {
         continue;
      }
      
      datetime currentBarTime = iTime(g_assets[i].symbol, MainTimeframe, 0);
      if(currentBarTime != g_lastBarTimes[i]) {
         hasNewBar = true;
         break;
      }
   }
   
   return hasNewBar;
}

//+------------------------------------------------------------------+
//| Atualiza informações globais                                     |
//+------------------------------------------------------------------+
void UpdateGlobalInformation()
{
   // Atualizar informações da conta uma vez por ciclo
   if(g_riskManager != NULL) {
      g_riskManager.UpdateAccountInfo();
   }
   
   // Inicializar cache de fases se necessário
   if(ArraySize(g_lastPhases) != ArraySize(g_assets)) {
      ArrayResize(g_lastPhases, ArraySize(g_assets));
      ArrayInitialize(g_lastPhases, PHASE_UNDEFINED);
   }
}

//+------------------------------------------------------------------+
//| Processa todos os ativos configurados                            |
//+------------------------------------------------------------------+
bool ProcessAllAssets()
{
   bool hasNewSignals = false;
   int assetsProcessed = 0;
   
   for(int i = 0; i < ArraySize(g_assets); i++) {
      
      // === VALIDAÇÕES DO ATIVO ===
      if(!ValidateAsset(i)) {
         continue;
      }
      
      string symbol = g_assets[i].symbol;
      
      // === VERIFICAR NOVA BARRA ===
      datetime currentBarTime = iTime(symbol, MainTimeframe, 0);
      if(currentBarTime == g_lastBarTimes[i]) {
         continue; // Sem nova barra, pular
      }
      
      // Atualizar tempo da barra
      g_lastBarTimes[i] = currentBarTime;
      assetsProcessed++;
      
      // === PROCESSAR ATIVO ===
      if(ProcessSingleAsset(symbol, i)) {
         hasNewSignals = true;
      }
   }
   
   // Log compacto do processamento
   if(assetsProcessed > 0 && g_logger != NULL) {
      g_logger.Debug(StringFormat("Processados %d ativos com novas barras", assetsProcessed));
   }
   
   return hasNewSignals;
}

//+------------------------------------------------------------------+
//| Valida se um ativo deve ser processado                           |
//+------------------------------------------------------------------+
bool ValidateAsset(int assetIndex)
{
   // Verificar índice válido
   if(assetIndex < 0 || assetIndex >= ArraySize(g_assets)) {
      return false;
   }
   
   // Ativo habilitado?
   if(!g_assets[assetIndex].enabled) {
      return false;
   }
   
   // Histórico disponível?
   if(!g_assets[assetIndex].historyAvailable) {
      // Tentar verificar novamente
      g_assets[assetIndex].historyAvailable = IsHistoryAvailable(g_assets[assetIndex].symbol, MainTimeframe, g_assets[assetIndex].minRequiredBars);
      
      if(!g_assets[assetIndex].historyAvailable) {
         return false;
      } else {
         // Log apenas quando histórico fica disponível
         if(g_logger != NULL) {
            g_logger.Info("Histórico disponível para " + g_assets[assetIndex].symbol);
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Processa um único ativo                                          |
//+------------------------------------------------------------------+
bool ProcessSingleAsset(string symbol, int assetIndex)
{
   // === ATUALIZAR CONTEXTO DE MERCADO ===
   if(!UpdateMarketContext(symbol)) {
      return false;
   }
   
   // === DETERMINAR FASE DE MERCADO ===
   MARKET_PHASE currentPhase = g_marketContext.DetermineMarketPhase();
   
   // Log apenas quando a fase muda
   LogPhaseChange(symbol, assetIndex, currentPhase);
   
   // === VERIFICAR ESTRATÉGIAS HABILITADAS ===
   if(!IsPhaseEnabled(currentPhase)) {
      return false;
   }
   
   // === GERAR SINAL ===
   Signal signal = GenerateSignalForPhase(symbol, currentPhase);
   
   // === PROCESSAR SINAL ===
   return ProcessSignal(symbol, signal, currentPhase);
}

//+------------------------------------------------------------------+
//| Atualiza contexto de mercado para o símbolo                      |
//+------------------------------------------------------------------+
bool UpdateMarketContext(string symbol)
{
   if(g_marketContext == NULL) {
      return false;
   }
   
   if(!g_marketContext.UpdateSymbol(symbol)) {
      if(g_logger != NULL) {
         g_logger.Warning("Falha ao atualizar contexto para " + symbol);
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Log de mudança de fase (apenas quando necessário)                |
//+------------------------------------------------------------------+
void LogPhaseChange(string symbol, int assetIndex, MARKET_PHASE currentPhase)
{
   if(assetIndex >= 0 && assetIndex < ArraySize(g_lastPhases)) {
      if(g_lastPhases[assetIndex] != currentPhase) {
         if(g_logger != NULL) {
            g_logger.Info(StringFormat("%s: %s", symbol, EnumToString(currentPhase)));
         }
         g_lastPhases[assetIndex] = currentPhase;
      }
   }
}

//+------------------------------------------------------------------+
//| Verifica se a fase está habilitada                               |
//+------------------------------------------------------------------+
bool IsPhaseEnabled(MARKET_PHASE phase)
{
   switch(phase) {
      case PHASE_TREND:
         return EnableTrendStrategies;
      case PHASE_RANGE:
         return EnableRangeStrategies;
      case PHASE_REVERSAL:
         return EnableReversalStrategies;
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Gera sinal com base na fase de mercado                           |
//+------------------------------------------------------------------+
Signal GenerateSignalForPhase(string symbol, MARKET_PHASE phase)
{
   Signal signal;
   signal.id = 0; // Sinal inválido por padrão
   
   if(g_signalEngine == NULL) {
      return signal;
   }
   
   switch(phase) {
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
         if(g_logger != NULL) {
            g_logger.Debug("Fase não suportada: " + EnumToString(phase));
         }
         break;
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| Processa sinal gerado                                            |
//+------------------------------------------------------------------+
bool ProcessSignal(string symbol, Signal &signal, MARKET_PHASE phase)
{
   // Verificar se o sinal é válido
   if(signal.id <= 0 || signal.quality == SETUP_INVALID) {
      return false;
   }
   
   // Filtrar setups de baixa qualidade
   if(signal.quality == SETUP_C) {
      if(g_logger != NULL) {
         g_logger.Debug(StringFormat("%s: Setup C descartado", symbol));
      }
      return false;
   }
   
   // Incrementar contador
   g_signalsGenerated++;
   
   // Log compacto do sinal
   LogSignalGenerated(symbol, signal);
   
   // === CRIAR REQUISIÇÃO DE ORDEM ===
   OrderRequest request = CreateOrderRequest(symbol, signal, phase);
   
   // === EXECUTAR ORDEM ===
   return ExecuteOrder(request);
}

//+------------------------------------------------------------------+
//| Log compacto de sinal gerado                                     |
//+------------------------------------------------------------------+
void LogSignalGenerated(string symbol, Signal &signal)
{
   if(g_logger == NULL) return;
   
   string direction = (signal.direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string strategy = signal.strategy;
   string quality = EnumToString(signal.quality);
   
   g_logger.Info(StringFormat("%s: %s %s Q:%s R:R:%.1f @%.5f", 
                             symbol, direction, strategy, quality, 
                             signal.riskRewardRatio, signal.entryPrice));
}

//+------------------------------------------------------------------+
//| Cria requisição de ordem                                          |
//+------------------------------------------------------------------+
OrderRequest CreateOrderRequest(string symbol, Signal &signal, MARKET_PHASE phase)
{
   OrderRequest request;
   request.id = 0; // Requisição inválida por padrão
   
   if(g_riskManager == NULL) {
      if(g_logger != NULL) {
         g_logger.Error("RiskManager não disponível para criar requisição");
      }
      return request;
   }
   
   request = g_riskManager.BuildRequest(symbol, signal, phase);
   
   return request;
}

//+------------------------------------------------------------------+
//| Executa ordem                                                    |
//+------------------------------------------------------------------+
bool ExecuteOrder(OrderRequest &request)
{
   // Verificar se a requisição é válida
   if(request.volume <= 0 || request.price <= 0) {
      if(g_logger != NULL) {
         g_logger.Warning("Requisição de ordem inválida");
      }
      return false;
   }
   
   if(g_tradeExecutor == NULL) {
      if(g_logger != NULL) {
         g_logger.Error("TradeExecutor não disponível");
      }
      return false;
   }
   
   // Executar ordem
   if(g_tradeExecutor.Execute(request)) {
      g_ordersExecuted++;
      if(g_logger != NULL) {
         g_logger.Info(StringFormat("Ordem executada: %s %.2f lotes", 
                                   request.symbol, request.volume));
      }
      return true;
   } else {
      if(g_logger != NULL) {
         g_logger.Warning(StringFormat("Falha na execução: %s", 
                                     g_tradeExecutor.GetLastErrorDescription()));
      }
      return false;
   }
}

//+------------------------------------------------------------------+
//| Determina se deve gerenciar posições                             |
//+------------------------------------------------------------------+
bool ShouldManagePositions(datetime currentTime)
{
   static datetime lastManagementTime = 0;
   int managementInterval = 30; // Gerenciar posições a cada 30 segundos
   
   return (currentTime - lastManagementTime >= managementInterval);
}

//+------------------------------------------------------------------+
//| Gerencia posições existentes                                     |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   if(g_tradeExecutor == NULL) {
      return;
   }
   
   static datetime lastManagementTime = 0;
   datetime currentTime = TimeCurrent();
   
   // Atualizar tempo de último gerenciamento
   lastManagementTime = currentTime;
   
   // Obter magic number do EA para identificar posições gerenciadas
   ulong eaMagicNumber = g_tradeExecutor.GetMagicNumber();
   
   // Gerenciar posições abertas com trailing stop específico por ativo
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0) continue;
      
      // Verificar se a posição pertence a este EA
      if (PositionGetInteger(POSITION_MAGIC) != eaMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      
      // Aplicar trailing stop específico por ativo
      if (StringFind(symbol, "WIN") >= 0) {
         g_tradeExecutor.ApplyTrailingStop(ticket, WIN_TRAILING_STOP);
      } else if (StringFind(symbol, "WDO") >= 0) {
         g_tradeExecutor.ApplyTrailingStop(ticket, WDO_TRAILING_STOP);
      } else if (StringFind(symbol, "BIT") >= 0) {
         g_tradeExecutor.ApplyTrailingStop(ticket, BTC_TRAILING_STOP);
      }
   }
   
   // Log apenas se houver posições abertas
   int openPositions = PositionsTotal();
   if(openPositions > 0 && g_logger != NULL) {
      g_logger.Debug(StringFormat("Gerenciando %d posições abertas com trailing stop específico por ativo", openPositions));
   }
}

//+------------------------------------------------------------------+
//| Gera relatórios de performance                                   |
//+------------------------------------------------------------------+
void GeneratePerformanceReports(datetime currentTime)
{
   // Relatório apenas a cada hora
   if(currentTime - g_lastStatsTime < g_statsIntervalSeconds) {
      return;
   }
   
   if(g_logger == NULL) {
      return;
   }
   
   // Calcular estatísticas do período
   double ticksPerMinute = (double)g_ticksProcessed / (g_statsIntervalSeconds / 60.0);
   double signalsPerHour = (double)g_signalsGenerated;
   double ordersPerHour = (double)g_ordersExecuted;
   
   // Estatísticas da conta
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   int openPositions = PositionsTotal();
   
   // Log do relatório
   g_logger.Info("=== RELATÓRIO DE PERFORMANCE (1h) ===");
   g_logger.Info(StringFormat("Ticks: %d (%.1f/min) | Sinais: %d | Ordens: %d", 
                             g_ticksProcessed, ticksPerMinute, g_signalsGenerated, g_ordersExecuted));
   g_logger.Info(StringFormat("Conta: Saldo=%.2f | Equity=%.2f | Margem Livre=%.2f | Posições=%d", 
                             currentBalance, currentEquity, freeMargin, openPositions));
   
   // Reset contadores
   g_ticksProcessed = 0;
   g_signalsGenerated = 0;
   g_ordersExecuted = 0;
   g_lastStatsTime = currentTime;
}

//+------------------------------------------------------------------+
//| Função auxiliar para verificar nova barra (melhorada)            |
//+------------------------------------------------------------------+
bool HasNewBar(string symbol, ENUM_TIMEFRAMES timeframe, int assetIndex)
{
   if(assetIndex < 0 || assetIndex >= ArraySize(g_lastBarTimes)) {
      return false;
   }
   
   datetime currentBarTime = iTime(symbol, timeframe, 0);
   
   if(currentBarTime != g_lastBarTimes[assetIndex]) {
      g_lastBarTimes[assetIndex] = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Limpeza e manutenção de cache (chamada pelo timer)               |
//+------------------------------------------------------------------+
void PerformMaintenance()
{
   if(g_signalEngine != NULL) {
      // Limpar cache de validação antigo (se implementado)
      // g_signalEngine.ClearExpiredCache();
   }
   
   // Outras tarefas de manutenção podem ser adicionadas aqui
}

//+------------------------------------------------------------------+
//| Função de processamento de timer                                 |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Verificar se os componentes estão inicializados
   if (g_logger == NULL)
   {
      return;
   }

   // Exportar logs periodicamente (a cada hora)
   datetime currentTime = TimeCurrent();
   if (currentTime - g_lastExportTime > 60)
   { // 3600 segundos = 1 hora
      // g_logger.ExportToCSV("IntegratedPA_EA_log.csv", "Timestamp,Level,Message", "");
      g_lastExportTime = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Função de processamento de eventos de trade                      |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Verificar se os componentes estão inicializados
   if (g_logger == NULL)
   {
      return;
   }

   g_logger.Debug("Evento de trade detectado");

   // Atualizar informações da conta
   if (g_riskManager != NULL)
   {
      g_riskManager.UpdateAccountInfo();
   }
}

//+------------------------------------------------------------------+
//| Função de processamento de eventos de livro de ofertas           |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
   // Verificar se os componentes estão inicializados
   if (g_logger == NULL || g_marketContext == NULL)
   {
      return;
   }

   // Atualizar informações de mercado se necessário
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
