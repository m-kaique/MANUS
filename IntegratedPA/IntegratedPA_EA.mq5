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
#include "SetupClassifier.mqh"
#include "JsonLog.mqh"

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
CSetupClassifier *g_setupClassifier = NULL;
CJSONLogger *g_jsonLogger = NULL;

// Array de ativos configurados
AssetConfig g_assets[];

// Array ultimos sinais por simbolo
LastSignalInfo g_lastSignals[10];
int g_lastSignalCount = 0;

// Array de sinais pendentes
PendingSignal g_pendingSignals[10];
int g_pendingSignalCount = 0;

// Variáveis para controle de tempo
datetime g_lastBarTimes[];
datetime g_lastExportTime = 0;

// Constante para o mínimo de barras necessárias
#define MIN_REQUIRED_BARS 100

// Função para verificar se é sinal duplicado
bool IsDuplicateSignal(string symbol, Signal &newSignal)
{
   datetime currentTime = TimeCurrent();

   for (int i = 0; i < g_lastSignalCount; i++)
   {
      if (g_lastSignals[i].symbol == symbol &&
          g_lastSignals[i].direction == newSignal.direction &&
          currentTime - g_lastSignals[i].signalTime < 900 && // 15 minutos
          MathAbs(g_lastSignals[i].entryPrice - newSignal.entryPrice) < 200)
      { // 200 pontos

         if (g_logger != NULL)
         {
            g_logger.Info(StringFormat("Sinal duplicado ignorado para %s - Último sinal há %d segundos",
                                       symbol, (int)(currentTime - g_lastSignals[i].signalTime)));
         }
         return true;
      }
   }
   return false;
}

// Função para armazenar último sinal
void StoreLastSignal(string symbol, Signal &signal)
{
   // Encontrar slot existente ou criar novo
   int index = -1;
   for (int i = 0; i < g_lastSignalCount; i++)
   {
      if (g_lastSignals[i].symbol == symbol)
      {
         index = i;
         break;
      }
   }

   if (index == -1 && g_lastSignalCount < 10)
   {
      index = g_lastSignalCount++;
   }

   if (index >= 0)
   {
      g_lastSignals[index].symbol = symbol;
      g_lastSignals[index].signalTime = TimeCurrent();
      g_lastSignals[index].direction = signal.direction;
      g_lastSignals[index].entryPrice = signal.entryPrice;
      g_lastSignals[index].isActive = true;
   }
}

// Função para verificar se há posição aberta
bool HasOpenPosition(string symbol)
{
   for (int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         if (PositionSelectByTicket(ticket))
         {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            if (posSymbol == symbol)
            {
               return true;
            }
         }
      }
   }
   return false;
}
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

   ArrayResize(g_assets, assetsCount);
   int index = 0;

   // ✅ CONFIGURAR BTC COM NOVOS PARÂMETROS
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

      // ✅ CONFIGURAR NÍVEIS DE PARCIAIS MAIS CONSERVADORES PARA BTC
      g_assets[index].partialLevels[0] = 1.5; // Era 1.0, agora 1.5
      g_assets[index].partialLevels[1] = 2.5; // Era 2.0, agora 2.5
      g_assets[index].partialLevels[2] = 4.0; // Era 3.0, agora 4.0

      g_assets[index].partialVolumes[0] = 0.3;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.4;

      if (!SymbolSelect("BIT$D", true))
      {
         if (g_logger != NULL)
         {
            g_logger.Warning("Falha ao selecionar símbolo BIT$D");
         }
      }
      index++;
   }

   // ✅ CONFIGURAR WDO COM NOVOS PARÂMETROS
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

      // ✅ CONFIGURAR NÍVEIS DE PARCIAIS MAIS CONSERVADORES PARA WDO
      g_assets[index].partialLevels[0] = 2.0; // Era 1.0, agora 2.0
      g_assets[index].partialLevels[1] = 3.0; // Era 1.5, agora 3.0
      g_assets[index].partialLevels[2] = 4.5; // Era 2.0, agora 4.5

      g_assets[index].partialVolumes[0] = 0.4;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.3;

      if (!SymbolSelect("WDO$D", true))
      {
         if (g_logger != NULL)
         {
            g_logger.Warning("Falha ao selecionar símbolo WDO");
         }
      }
      index++;
   }

   // ✅ CONFIGURAR WIN COM NOVOS PARÂMETROS
   if (EnableWIN)
   {
      g_assets[index].symbol = "WINM25";
      g_assets[index].enabled = true;
      g_assets[index].minLot = 4.0;
      g_assets[index].maxLot = 100.0;
      g_assets[index].lotStep = 1.0;
      g_assets[index].tickValue = SymbolInfoDouble("WINM25", SYMBOL_TRADE_TICK_VALUE);
      g_assets[index].digits = (int)SymbolInfoInteger("WINM25", SYMBOL_DIGITS);
      g_assets[index].riskPercentage = RiskPerTrade * 0.9; // 10% menos risco para WIN
      g_assets[index].usePartials = true;
      g_assets[index].historyAvailable = false;
      g_assets[index].minRequiredBars = MIN_REQUIRED_BARS;

      // ✅ CONFIGURAR NÍVEIS DE PARCIAIS MAIS CONSERVADORES PARA WIN
      g_assets[index].partialLevels[0] = 1.8; // Era 1.0, agora 1.8
      g_assets[index].partialLevels[1] = 2.8; // Era 1.5, agora 2.8
      g_assets[index].partialLevels[2] = 4.2; // Era 2.0, agora 4.2

      g_assets[index].partialVolumes[0] = 0.5;
      g_assets[index].partialVolumes[1] = 0.3;
      g_assets[index].partialVolumes[2] = 0.2;

      if (!SymbolSelect("WINM25", true))
      {
         if (g_logger != NULL)
         {
            g_logger.Warning("Falha ao selecionar símbolo WIN$");
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
      g_logger.Info(StringFormat("Configurados %d ativos para operação com parâmetros CONSERVADORES", assetsCount));
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

      // ✅ CONFIGURAR STOPS ESPECÍFICOS POR SÍMBOLO (NOVOS VALORES)
      if (g_assets[i].symbol == "BIT$D")
      {
         // BTC: Stop mais conservador
         g_riskManager.ConfigureSymbolStopLoss(g_assets[i].symbol, BTC_MIN_STOP_DISTANCE, 2.8);
      }
      else if (g_assets[i].symbol == "WDO$D")
      {
         // WDO: Stop mais conservador
         g_riskManager.ConfigureSymbolStopLoss(g_assets[i].symbol, WDO_MIN_STOP_DISTANCE, 3.5);
      }
      else if (g_assets[i].symbol == "WINM25")
      {
         // WIN: Stop mais conservador
         g_riskManager.ConfigureSymbolStopLoss(g_assets[i].symbol, WIN_MIN_STOP_DISTANCE, 2.5);
      }

      // Configurar parciais para cada ativo
      if (g_assets[i].usePartials)
      {
         g_riskManager.ConfigureSymbolPartials(g_assets[i].symbol, true,
                                               g_assets[i].partialLevels,
                                               g_assets[i].partialVolumes);
      }
   }

   if (g_logger != NULL)
   {
      g_logger.Info("Parâmetros de risco configurados com STOPS CONSERVADORES");
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

   // Inicializar o logger JSON após o logger principal
   g_jsonLogger = new CJSONLogger(g_logger);
   if (g_jsonLogger == NULL)
   {
      g_logger.Error("Erro ao criar objeto JSONLogger");
      return (INIT_FAILED);
   }

   g_logger.Info("Iniciando Expert Advisor...");

   // Iniciar nova sessão de trading
   if (!g_jsonLogger.StartSession("4885"))
   {
      g_logger.Error("Falha ao iniciar sessão JSON");
      // Não é crítico, continuar sem JSON logging
   }

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
   //
   // SETUP CLASSIFIER
   g_setupClassifier = new CSetupClassifier();
   if (g_setupClassifier == NULL)
   {
      g_logger.Error("Erro ao criar objeto SetupClassifier");
      return (INIT_FAILED);
   }

   if (!g_setupClassifier.Initialize(g_logger, g_marketContext))
   {
      g_logger.Error("Falha ao inicializar SetupClassifier");
      return (INIT_FAILED);
   }
   //////////////////////////

   //
   g_signalEngine = new CSignalEngine();
   if (g_signalEngine == NULL)
   {
      g_logger.Error("Erro ao criar objeto SignalEngine");
      return (INIT_FAILED);
   }

   if (!g_signalEngine.Initialize(g_logger, g_marketContext, g_setupClassifier))
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

   if (!g_tradeExecutor.Initialize(g_logger, g_jsonLogger))
   {
      g_logger.Error("Falha ao inicializar TradeExecutor");
      return (INIT_FAILED);
   }

   // Configurar o executor de trades
   g_tradeExecutor.SetTradeAllowed(EnableTrading);
   //

   // Inicializar array de últimos tempos de barra
   ArrayResize(g_lastBarTimes, ArraySize(g_assets));
   ArrayInitialize(g_lastBarTimes, 0);

   // Configurar timer para execução periódica
   if (!EventSetTimer(60))
   { // Timer a cada 60 segundos
      g_logger.Warning("Falha ao configurar timer");
   }
   ConfigureBreakevenForExistingTrades();
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

   // Finalizar sessão JSON
   if (g_jsonLogger != NULL)
   {
      g_jsonLogger.EndSession();
      delete g_jsonLogger;
      g_jsonLogger = NULL;
   }
}

int tickCounter = 0;
//+------------------------------------------------------------------+
//| Função OnTick() CORRIGIDA                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   tickCounter++;

   if (tickCounter >= 10)
   { // Atualizar a cada 10 ticks
      UpdateJSONOrders();
      tickCounter = 0;
   }
   // Verificar se os componentes estão inicializados
   if (g_logger == NULL || g_marketContext == NULL || g_signalEngine == NULL ||
       g_riskManager == NULL || g_tradeExecutor == NULL)
   {
      Print("Componentes não inicializados");
      return;
   }

   // 1. GERENCIAMENTO CONTÍNUO DE POSIÇÕES (A CADA TICK)
   g_tradeExecutor.ManageOpenPositions();
   g_riskManager.UpdateAccountInfo();

   // 2. VERIFICAR E EXECUTAR SINAIS PENDENTES (A CADA TICK)
   ProcessPendingSignals();

   // 3. GERAÇÃO DE NOVOS SINAIS (APENAS EM NOVA BARRA)
   for (int i = 0; i < ArraySize(g_assets); i++)
   {
      string symbol = g_assets[i].symbol;

      // Verificar se o ativo está habilitado
      if (!g_assets[i].enabled)
      {
         continue;
      }

      // Verificar se há posição aberta
      if (HasOpenPosition(symbol))
      {
         continue;
      }

      // Verificar se o histórico está disponível
      if (!g_assets[i].historyAvailable)
      {
         g_assets[i].historyAvailable = IsHistoryAvailable(symbol, MainTimeframe, g_assets[i].minRequiredBars);
         if (!g_assets[i].historyAvailable)
         {
            continue;
         }
      }

      // ✅ VERIFICAR SE É NOVA BARRA (APENAS PARA GERAÇÃO DE SINAIS)
      datetime currentBarTime = iTime(symbol, MainTimeframe, 0);
      if (currentBarTime == g_lastBarTimes[i])
      {
         continue; // Não gerar novos sinais se não for nova barra
      }

      g_lastBarTimes[i] = currentBarTime;
      g_logger.Info("Nova barra detectada para " + symbol + " - Analisando novos sinais");

      // Atualizar contexto de mercado
      if (!g_marketContext.UpdateSymbol(symbol))
      {
         g_logger.Error("Falha ao atualizar contexto de mercado para " + symbol);
         continue;
      }

      // Determinar fase de mercado
      MARKET_PHASE phase = g_marketContext.DetermineMarketPhase();

      // Verificar estratégias habilitadas
      if ((phase == PHASE_TREND && !EnableTrendStrategies) ||
          (phase == PHASE_RANGE && !EnableRangeStrategies) ||
          (phase == PHASE_REVERSAL && !EnableReversalStrategies))
      {
         continue;
      }

      // ✅ GERAR SINAL (apenas em nova barra)
      Signal signal = GenerateSignalByPhase(symbol, phase);
      if (signal.id > 0 && signal.quality != SETUP_INVALID)
      {
         // Verificar duplicatas
         if (IsDuplicateSignal(symbol, signal))
         {
            continue;
         }

         // ✅ TENTAR EXECUÇÃO IMEDIATA OU ARMAZENAR COMO PENDENTE
         if (!TryImmediateExecution(symbol, signal, phase))
         {
            StorePendingSignal(signal, phase);
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Gerar sinal baseado na fase de mercado                           |
//+------------------------------------------------------------------+
Signal GenerateSignalByPhase(string symbol, MARKET_PHASE phase)
{
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

   return signal;
}

//+------------------------------------------------------------------+
//| Tentar execução imediata do sinal                                |
//+------------------------------------------------------------------+
bool TryImmediateExecution(string symbol, Signal &signal, MARKET_PHASE phase)
{
   // Verificar se as condições de entrada estão ativas AGORA
   MqlTick lastTick;
   if (!SymbolInfoTick(symbol, lastTick))
   {
      return false;
   }

   double currentPrice = (lastTick.ask + lastTick.bid) / 2.0;
   double entryThreshold = 10.0; // pontos - ajustar conforme ativo

   // Verificar se estamos próximos do preço de entrada
   bool canExecuteNow = false;

   if (signal.direction == ORDER_TYPE_BUY)
   {
      // Para compras, verificar se preço atual está próximo ou abaixo da entrada
      if (currentPrice <= signal.entryPrice + entryThreshold * SymbolInfoDouble(symbol, SYMBOL_POINT))
      {
         canExecuteNow = true;
      }
   }
   else
   {
      // Para vendas, verificar se preço atual está próximo ou acima da entrada
      if (currentPrice >= signal.entryPrice - entryThreshold * SymbolInfoDouble(symbol, SYMBOL_POINT))
      {
         canExecuteNow = true;
      }
   }

   if (canExecuteNow)
   {
      // Executar imediatamente
      OrderRequest request = g_riskManager.BuildRequest(symbol, signal, phase);

      if (request.volume > 0)
      {
         if (g_tradeExecutor.Execute(request))
         {
            StoreLastSignal(symbol, signal);
            g_logger.Info("Sinal executado imediatamente para " + symbol);

            // REGISTRAR NO JSON LOGGER com ticket real
            if (g_jsonLogger != NULL)
            {
               // Obter ticket da última ordem executada
               ulong lastTicket = 0;
               for (int j = OrdersTotal() - 1; j >= 0; j--)
               {
                  ulong ticket = OrderGetTicket(j);
                  if (ticket > 0 && OrderGetInteger(ORDER_MAGIC) == MAGIC_NUMBER)
                  {
                     lastTicket = ticket;
                     break;
                  }
               }

               // Se não encontrou em ordens pendentes, procurar em posições
               if (lastTicket == 0)
               {
                  for (int j = PositionsTotal() - 1; j >= 0; j--)
                  {
                     ulong ticket = PositionGetTicket(j);
                     if (ticket > 0 && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
                     {
                        lastTicket = ticket;
                        break;
                     }
                  }
               }

               if (lastTicket > 0)
               {
                  g_jsonLogger.AddOrder(lastTicket, signal, request);
               }
            }

            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Armazenar sinal como pendente                                    |
//+------------------------------------------------------------------+
void StorePendingSignal(Signal &signal, MARKET_PHASE phase)
{
   // Encontrar slot livre ou substituir o mais antigo
   int index = -1;
   datetime oldestTime = TimeCurrent();
   int oldestIndex = 0;

   for (int i = 0; i < 10; i++)
   {
      if (!g_pendingSignals[i].isActive)
      {
         index = i;
         break;
      }

      if (g_pendingSignals[i].signal.generatedTime < oldestTime)
      {
         oldestTime = g_pendingSignals[i].signal.generatedTime;
         oldestIndex = i;
      }
   }

   if (index < 0)
   {
      index = oldestIndex; // Substituir o mais antigo
   }

   // Armazenar sinal pendente
   g_pendingSignals[index].signal = signal;
   g_pendingSignals[index].expiry = TimeCurrent() + 3600; // Expira em 1 hora
   g_pendingSignals[index].isActive = true;

   g_logger.Info("Sinal armazenado como pendente para " + signal.symbol + " (expira em 1h)");
}

//+------------------------------------------------------------------+
//| Processar sinais pendentes a cada tick                           |
//+------------------------------------------------------------------+
void ProcessPendingSignals()
{
   datetime currentTime = TimeCurrent();

   for (int i = 0; i < 10; i++)
   {
      if (!g_pendingSignals[i].isActive)
      {
         continue;
      }

      // Verificar expiração
      if (currentTime > g_pendingSignals[i].expiry)
      {
         g_pendingSignals[i].isActive = false;
         g_logger.Debug("Sinal pendente expirado para " + g_pendingSignals[i].signal.symbol);
         continue;
      }

      // Verificar se ainda não há posição aberta
      if (HasOpenPosition(g_pendingSignals[i].signal.symbol))
      {
         g_pendingSignals[i].isActive = false;
         continue;
      }

      // Verificar condições de entrada
      if (CheckSignalEntryConditions(g_pendingSignals[i].signal))
      {
         // Executar sinal pendente
         MARKET_PHASE phase = g_pendingSignals[i].signal.marketPhase;
         OrderRequest request = g_riskManager.BuildRequest(g_pendingSignals[i].signal.symbol,
                                                           g_pendingSignals[i].signal,
                                                           phase);

         if (request.volume > 0)
         {
            if (g_tradeExecutor.Execute(request))
            {
               StoreLastSignal(g_pendingSignals[i].signal.symbol, g_pendingSignals[i].signal);
               g_logger.Info("Sinal pendente executado para " + g_pendingSignals[i].signal.symbol);

               // REGISTRAR NO JSON LOGGER com ticket real
               if (g_jsonLogger != NULL)
               {
                  // Obter ticket da última ordem executada
                  ulong lastTicket = 0;
                  for (int j = OrdersTotal() - 1; j >= 0; j--)
                  {
                     ulong ticket = OrderGetTicket(j);
                     if (ticket > 0 && OrderGetInteger(ORDER_MAGIC) == MAGIC_NUMBER)
                     {
                        lastTicket = ticket;
                        break;
                     }
                  }

                  // Se não encontrou em ordens pendentes, procurar em posições
                  if (lastTicket == 0)
                  {
                     for (int j = PositionsTotal() - 1; j >= 0; j--)
                     {
                        ulong ticket = PositionGetTicket(j);
                        if (ticket > 0 && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
                        {
                           lastTicket = ticket;
                           break;
                        }
                     }
                  }

                  if (lastTicket > 0)
                  {
                     g_jsonLogger.AddOrder(lastTicket, g_pendingSignals[i].signal, request);
                  }
               }
            }
         }

         // Desativar sinal (executado ou falhou)
         g_pendingSignals[i].isActive = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar condições de entrada para sinal pendente               |
//+------------------------------------------------------------------+
bool CheckSignalEntryConditions(Signal &signal)
{
   MqlTick lastTick;
   if (!SymbolInfoTick(signal.symbol, lastTick))
   {
      return false;
   }

   double currentPrice = (lastTick.ask + lastTick.bid) / 2.0;
   double point = SymbolInfoDouble(signal.symbol, SYMBOL_POINT);
   double entryThreshold = 5.0 * point; // 5 pontos de tolerância

   // Verificar condições específicas baseadas na direção
   if (signal.direction == ORDER_TYPE_BUY)
   {
      // Para compra: preço atual deve estar próximo ou melhor que entrada
      return (currentPrice <= signal.entryPrice + entryThreshold);
   }
   else
   {
      // Para venda: preço atual deve estar próximo ou melhor que entrada
      return (currentPrice >= signal.entryPrice - entryThreshold);
   }
}

//+------------------------------------------------------------------+
//| Função para limpar sinais pendentes expirados (chamada no timer) |
//+------------------------------------------------------------------+
void CleanupExpiredSignals()
{
   datetime currentTime = TimeCurrent();

   for (int i = 0; i < 10; i++)
   {
      if (g_pendingSignals[i].isActive && currentTime > g_pendingSignals[i].expiry)
      {
         g_pendingSignals[i].isActive = false;
         g_logger.Debug("Limpeza: Sinal pendente expirado removido");
      }
   }
}

//| Função para configurar breakeven manual (para trades existentes) |
//+------------------------------------------------------------------+
void ConfigureBreakevenForExistingTrades()
{
   if (g_tradeExecutor == NULL)
      return;

   int totalPositions = PositionsTotal();

   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
         continue;

      if (!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);

      // Verificar se já tem breakeven configurado
      int breakevenIndex = g_tradeExecutor.FindBreakevenConfigIndex(ticket);

      if (breakevenIndex < 0)
      {
         // Configurar breakeven para posição existente
         g_tradeExecutor.AutoConfigureBreakeven(ticket, symbol);

         if (g_logger != NULL)
         {
            g_logger.Info(StringFormat("Breakeven configurado para posição existente #%d (%s)", ticket, symbol));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Função de processamento de timer                                 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 3. ATUALIZAR OnTimer() - SUBSTITUIR função existente            |
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

   // ✅ RELATÓRIO DE BREAKEVEN A CADA 5 MINUTOS
   static datetime lastBreakevenReport = 0;

   if (currentTime - lastBreakevenReport > 300)
   { // 5 minutos
      if (g_tradeExecutor != NULL)
      {
         // g_tradeExecutor.LogBreakevenReport();
      }
      lastBreakevenReport = currentTime;
   }

   // Limpar sinais pendentes expirados
   CleanupExpiredSignals();
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

//+------------------------------------------------------------------+
//| Adicionar função para atualizar ordens no JSON                   |
//+------------------------------------------------------------------+
void UpdateJSONOrders()
{
   if (g_jsonLogger == NULL)
      return;

   // Percorrer todas as posições abertas
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (PositionGetSymbol(i) != "")
      {
         ulong ticket = PositionGetTicket(i);

         // Verificar se é uma posição do nosso EA
         if (PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
         {
            // Atualizar dados da ordem
            g_jsonLogger.UpdateOrder(ticket);
         }
      }
   }
}