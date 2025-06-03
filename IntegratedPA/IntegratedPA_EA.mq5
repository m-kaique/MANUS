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
      g_assets[index].symbol = "WIN$";
      g_assets[index].enabled = true;
      g_assets[index].minLot = 1.0;
      g_assets[index].maxLot = 100.0;
      g_assets[index].lotStep = 1.0;
      g_assets[index].tickValue = SymbolInfoDouble("WIN$", SYMBOL_TRADE_TICK_VALUE);
      g_assets[index].digits = (int)SymbolInfoInteger("WIN$", SYMBOL_DIGITS);
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

      if (!SymbolSelect("WIN$", true))
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
//| Função de processamento de ticks                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   // Verificar se os componentes estão inicializados
   if (g_logger == NULL || g_marketContext == NULL || g_signalEngine == NULL ||
       g_riskManager == NULL || g_tradeExecutor == NULL)
   {
      Print("Componentes não inicializados");
      return;
   }

   // Atualizar informações da conta
   g_riskManager.UpdateAccountInfo();

   // Processar cada ativo configurado
   for (int i = 0; i < ArraySize(g_assets); i++)
   {
      string symbol = g_assets[i].symbol;

      // Verificar se o ativo está habilitado
      if (!g_assets[i].enabled)
      {
         continue;
      }

      // Verificar se o histórico está disponível
      if (!g_assets[i].historyAvailable)
      {
         g_assets[i].historyAvailable = IsHistoryAvailable(symbol, MainTimeframe, g_assets[i].minRequiredBars);
         if (!g_assets[i].historyAvailable)
         {
            g_logger.Debug("Histórico ainda não disponível para " + symbol);
            continue;
         }
         else
         {
            g_logger.Info("Histórico agora disponível para " + symbol);
         }
      }

      // Verificar se é uma nova barra
      datetime currentBarTime = iTime(symbol, MainTimeframe, 0);
      if (currentBarTime == g_lastBarTimes[i])
      {
         continue; // Não processar se não for uma nova barra
      }

      g_lastBarTimes[i] = currentBarTime;
      g_logger.Info("Nova barra detectada para " + symbol + " em " + EnumToString(MainTimeframe));

      // Atualizar contexto de mercado para o símbolo atual
      if (!g_marketContext.UpdateSymbol(symbol))
      {
         g_logger.Error("Falha ao atualizar contexto de mercado para " + symbol);
         continue;
      }

      // Determinar fase de mercado
      MARKET_PHASE phase = g_marketContext.DetermineMarketPhase();
      g_logger.Info("Fase de mercado para " + symbol + ": " + EnumToString(phase));

      // Verificar se devemos gerar sinais para esta fase
      if ((phase == PHASE_TREND && !EnableTrendStrategies) ||
          (phase == PHASE_RANGE && !EnableRangeStrategies) ||
          (phase == PHASE_REVERSAL && !EnableReversalStrategies))
      {
         g_logger.Info("Estratégias para fase " + EnumToString(phase) + " desabilitadas");
         continue;
      }

      // Gerar sinal de acordo com a fase de mercado
      Signal signal;

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
      }

      // Verificar se o sinal é válido
      if (signal.id == 0 || signal.quality == SETUP_INVALID)
      {
         g_logger.Debug("Nenhum sinal válido gerado para " + symbol);
         continue;
      }

      if (signal.quality != SETUP_C)
      {
         g_logger.Info("Sinal gerado para " + symbol + ": " +
                       (signal.direction == ORDER_TYPE_BUY ? "Compra" : "Venda") +
                       ", Qualidade: " + EnumToString(signal.quality));

         // Criar requisição de ordem
         OrderRequest request;
         request = g_riskManager.BuildRequest(symbol, signal, phase);

         // Verificar se a requisição é válida
         if (request.volume <= 0 || request.price <= 0)
         {
            g_logger.Error("Parâmetros de ordem inválidos");
            continue;
         }

         // Executar ordem
         if (!g_tradeExecutor.Execute(request))
         {
            g_logger.Error("Falha ao executar ordem para " + symbol + ": " + g_tradeExecutor.GetLastErrorDescription());
         }
      }else{
         Print("SETUP C NAO CONTA!!!!");
      }
   }

   // Gerenciar posições abertas
   g_tradeExecutor.ManageOpenPositions();
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
