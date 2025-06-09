//+------------------------------------------------------------------+
//|                                            TradeExecutor.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

// Inclusão de bibliotecas necessárias
#include <Trade/Trade.mqh>
#include "Structures.mqh"
#include "Logger.mqh"
#include "JsonLog.mqh"
#include "Constants.mqh"

// Constantes de erro definidas como macros
#define TRADE_ERROR_NO_ERROR 0
#define TRADE_ERROR_SERVER_BUSY 4
#define TRADE_ERROR_NO_CONNECTION 6
#define TRADE_ERROR_TRADE_TIMEOUT 128
#define TRADE_ERROR_INVALID_PRICE 129
#define TRADE_ERROR_PRICE_CHANGED 135
#define TRADE_ERROR_OFF_QUOTES 136
#define TRADE_ERROR_BROKER_BUSY 137
#define TRADE_ERROR_REQUOTE 138
#define TRADE_ERROR_TOO_MANY_REQUESTS 141
#define TRADE_ERROR_TRADE_CONTEXT_BUSY 146

//+------------------------------------------------------------------+
//| Classe para execução e gerenciamento de ordens                   |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   // Objetos internos
   CTrade *m_trade;
   CLogger *m_logger;
   CJSONLogger *m_jsonlog;


   // Configurações
   bool m_tradeAllowed;
   int m_maxRetries;
   int m_retryDelay;

   // Estado
   int m_lastError;
   string m_lastErrorDesc;

   // Enumeração para tipos de trailing stop
   enum ENUM_TRAILING_TYPE
   {
      TRAILING_FIXED, // Trailing fixo em pontos
      TRAILING_ATR,   // Trailing baseado em ATR
      TRAILING_MA     // Trailing baseado em média móvel
   };

   // Estrutura para armazenar configurações de trailing stop
   struct TrailingStopConfig
   {
      ulong ticket;                    // Ticket da posição
      string symbol;                   // Símbolo
      ENUM_TIMEFRAMES timeframe;       // Timeframe para indicadores
      double fixedPoints;              // Pontos fixos para trailing
      double atrMultiplier;            // Multiplicador de ATR
      int maPeriod;                    // Período da média móvel
      ENUM_TRAILING_TYPE trailingType; // Tipo de trailing
      datetime lastUpdateTime;         // Última atualização
      double lastStopLoss;             // Último stop loss
   };

   // Array de configurações de trailing stop
   TrailingStopConfig m_trailingConfigs[];

   // Métodos privados
   bool IsRetryableError(int errorCode);
   double CalculateFixedTrailingStop(ulong ticket, double fixedPoints);
   double CalculateATRTrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, double atrMultiplier, ulong ticket);
   double CalculateMATrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, ulong ticket);
   // Array de configurações de breakeven (adicionar à classe CTradeExecutor)
   BreakevenConfig m_breakevenConfigs[];
   // Métodos privados para breakeven

   void RemoveBreakevenConfig(int index);
   double CalculateATRForBreakeven(string symbol, ulong ticket);

   bool ShouldTriggerBreakeven(int configIndex);
   bool ExecuteBreakeven(int configIndex);
   void CleanupBreakevenConfigs();

   bool IsPositionReadyForTrailing(ulong ticket);

   // Métodos para gerenciamento contínuo
   double CalculateNewTrailingStop(int configIndex);
   bool ShouldUpdateStopLoss(int configIndex, double newStopLoss);
   void RemoveTrailingConfig(int index);
   void ManagePositionRisk();
   void CleanupInvalidConfigurations();

   bool SetBreakevenFixed(ulong ticket, double triggerPoints, double offsetPoints);

   bool SetBreakevenATR(ulong ticket, double atrMultiplier, double offsetPoints);

   bool SetBreakevenRiskRatio(ulong ticket, double riskRatio, double offsetPoints);

   void ManageBreakevens();

   bool ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE orderType,
                               double &entryPrice, double &stopLoss, double &takeProfit);

public:
   // Construtores e destrutor
   CTradeExecutor();
   ~CTradeExecutor();

   bool Initialize(CLogger *logger, CJSONLogger *jsonlog);

   // Métodos de inicialização
   bool Initialize(CLogger *logger);

   // Métodos de execução
   bool Execute(OrderRequest &request);
   bool ModifyPosition(ulong ticket, double stopLoss, double takeProfit);
   bool ClosePosition(ulong ticket, double volume = 0.0);
   bool CloseAllPositions(string symbol = "");

   // Métodos de trailing stop
   bool ApplyTrailingStop(ulong ticket, double points);
   bool ApplyATRTrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, double multiplier);
   bool ApplyMATrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, int period);
   void ManageOpenPositions();

   void ManagePartialTakeProfits();

   bool ShouldTakePartialNow(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss);

   double CalculatePartialVolume(string symbol, ulong ticket, double currentVolume);

   void ManageTrailingStops();

   // Métodos de configuração
   void SetTradeAllowed(bool allowed) { m_tradeAllowed = allowed; }
   void SetMaxRetries(int retries) { m_maxRetries = retries; }
   void SetRetryDelay(int delay) { m_retryDelay = delay; }

   // Métodos de acesso
   int GetLastError() const { return m_lastError; }
   string GetLastErrorDescription() const { return m_lastErrorDesc; }
   int FindBreakevenConfigIndex(ulong ticket);
   bool AutoConfigureBreakeven(ulong ticket, string symbol);
   bool AutoConfigureTrailingStop(ulong ticket, string symbol);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor()
{
   m_trade = NULL;
   m_logger = NULL;
   m_jsonlog = NULL;
   m_tradeAllowed = true;
   m_maxRetries = 3;
   m_retryDelay = 1000; // 1 segundo
   m_lastError = 0;
   m_lastErrorDesc = "";
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CTradeExecutor::~CTradeExecutor()
{
   if (m_trade != NULL)
   {
      delete m_trade;
      m_trade = NULL;
   }
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CTradeExecutor::Initialize(CLogger *logger, CJSONLogger *jsonlog)
{
   // Verificar parâmetros
   if (logger == NULL)
   {
      Print("CTradeExecutor::Initialize - Logger não pode ser NULL");
      return false;
   }

   // Atribuir logger
   m_logger = logger;
   m_logger.Info("Inicializando TradeExecutor");

   // Atribuit jsonlogger
   m_jsonlog = jsonlog;
   // Criar objeto de trade
   m_trade = new CTrade();
   if (m_trade == NULL)
   {
      m_logger.Error("Falha ao criar objeto CTrade");
      return false;
   }

   // Configurar objeto de trade
   m_trade.SetExpertMagicNumber(MAGIC_NUMBER); // Magic number para identificar ordens deste EA
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetDeviationInPoints(10); // Desvio máximo de preço em pontos

   m_logger.Info("TradeExecutor inicializado com sucesso");
   return true;
}

bool CTradeExecutor::Execute(OrderRequest &request)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Verificar parâmetros
   if (request.symbol == "" || request.volume <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros de ordem inválidos";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // ✅ NOVA VALIDAÇÃO: Ajustar stops ANTES da execução
   double adjustedEntry = request.price;
   double adjustedSL = request.stopLoss;
   double adjustedTP = request.takeProfit;

   if (!ValidateAndAdjustStops(request.symbol, request.type, adjustedEntry, adjustedSL, adjustedTP))
   {
      m_lastError = -4;
      m_lastErrorDesc = "Falha na validação dos stops";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // Atualizar valores no request
   request.price = adjustedEntry;
   request.stopLoss = adjustedSL;
   request.takeProfit = adjustedTP;

   // Registrar detalhes da ordem
   m_logger.Info(StringFormat("Executando ordem: %s %s %.2f @ %.5f, SL: %.5f, TP: %.5f",
                              request.symbol,
                              request.type == ORDER_TYPE_BUY ? "BUY" : "SELL",
                              request.volume,
                              request.price,
                              request.stopLoss,
                              request.takeProfit));

   // Executar ordem com retry
   bool result = false;
   int retries = 0;

   while (retries < m_maxRetries && !result)
   {
      if (retries > 0)
      {
         m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         Sleep(m_retryDelay);

         // ✅ Re-validar stops a cada tentativa (preços podem ter mudado)
         if (!ValidateAndAdjustStops(request.symbol, request.type, request.price, request.stopLoss, request.takeProfit))
         {
            m_logger.Error("Falha na re-validação dos stops");
            return false;
         }
      }

      // ✅ Para ordens de mercado, usar preço 0 (execução ao melhor preço disponível)
      double executionPrice = request.price;
      if (request.type == ORDER_TYPE_BUY || request.type == ORDER_TYPE_SELL)
      {
         executionPrice = 0; // Deixar o MT5 usar o preço de mercado atual
      }

      // Executar ordem de acordo com o tipo
      switch (request.type)
      {
      case ORDER_TYPE_BUY:
         result = m_trade.Buy(request.volume, request.symbol, executionPrice, request.stopLoss, request.takeProfit, request.comment);
         break;
      case ORDER_TYPE_SELL:
         result = m_trade.Sell(request.volume, request.symbol, executionPrice, request.stopLoss, request.takeProfit, request.comment);
         break;
      case ORDER_TYPE_BUY_LIMIT:
         result = m_trade.BuyLimit(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
         break;
      case ORDER_TYPE_SELL_LIMIT:
         result = m_trade.SellLimit(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
         break;
      case ORDER_TYPE_BUY_STOP:
         result = m_trade.BuyStop(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
         break;
      case ORDER_TYPE_SELL_STOP:
         result = m_trade.SellStop(request.volume, request.price, request.symbol, request.stopLoss, request.takeProfit, ORDER_TIME_GTC, 0, request.comment);
         break;
      default:
         m_lastError = -3;
         m_lastErrorDesc = "Tipo de ordem não suportado";
         m_logger.Error(m_lastErrorDesc);
         return false;
      }

      // Verificar resultado
      if (!result)
      {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro na execução da ordem: " + IntegerToString(m_lastError);

         // ✅ Log detalhado do erro
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("%s - Retcode: %d, Comment: %s",
                                        m_lastErrorDesc,
                                        m_lastError,
                                        m_trade.ResultRetcodeDescription()));
         }

         // Verificar se o erro é recuperável
         if (!IsRetryableError(m_lastError))
         {
            m_logger.Error(m_lastErrorDesc);
            return false;
         }
      }

      retries++;
   }

   // Verificar resultado final
   if (result)
   {
      ulong ticket = m_trade.ResultOrder();
      m_logger.Info(StringFormat("Ordem executada com sucesso. Ticket: %d", ticket));

      // CONFIGURAR BREAKEVEN AUTOMATICAMENTE
      if (ticket > 0)
      {
         AutoConfigureBreakeven(ticket, request.symbol);
         AutoConfigureTrailingStop(ticket, request.symbol);
      }

      return true;
   }
   else
   {
      m_logger.Error(StringFormat("Falha na execução da ordem após %d tentativas. Último erro: %d", m_maxRetries, m_lastError));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Modificação de posição                                           |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyPosition(ulong ticket, double stopLoss, double takeProfit)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Registrar detalhes da modificação
   m_logger.Info(StringFormat("Modificando posição #%d: SL: %.5f, TP: %.5f", ticket, stopLoss, takeProfit));

   // Executar modificação com retry
   bool result = false;
   int retries = 0;

   while (retries < m_maxRetries && !result)
   {
      if (retries > 0)
      {
         m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         Sleep(m_retryDelay);
      }

      result = m_trade.PositionModify(ticket, stopLoss, takeProfit);

      // Verificar resultado
      if (!result)
      {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro na modificação da posição: " + IntegerToString(m_lastError);

         // Verificar se o erro é recuperável
         if (!IsRetryableError(m_lastError))
         {
            m_logger.Error(m_lastErrorDesc);
            return false;
         }
      }

      retries++;
   }

   // Verificar resultado final
   if (result)
   {
      m_logger.Info(StringFormat("Posição #%d modificada com sucesso", ticket));
      return true;
   }
   else
   {
      m_logger.Error(StringFormat("Falha na modificação da posição #%d após %d tentativas. Último erro: %d", ticket, m_maxRetries, m_lastError));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Fechamento de posição                                            |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePosition(ulong ticket, double volume = 0.0)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Registrar detalhes do fechamento
   if (volume <= 0.0)
   {
      m_logger.Info(StringFormat("Fechando posição #%d completamente", ticket));
   }
   else
   {
      m_logger.Info(StringFormat("Fechando posição #%d parcialmente: %.2f lotes", ticket, volume));
   }

   // Executar fechamento com retry
   bool result = false;
   int retries = 0;

   while (retries < m_maxRetries && !result)
   {
      if (retries > 0)
      {
         m_logger.Warning(StringFormat("Tentativa %d de %d após erro: %d", retries + 1, m_maxRetries, m_lastError));
         Sleep(m_retryDelay);
      }

      result = m_trade.PositionClose(ticket, (ulong)volume);

      // Verificar resultado
      if (!result)
      {
         m_lastError = (int)m_trade.ResultRetcode();
         m_lastErrorDesc = "Erro no fechamento da posição: " + IntegerToString(m_lastError);

         // Verificar se o erro é recuperável
         if (!IsRetryableError(m_lastError))
         {
            m_logger.Error(m_lastErrorDesc);
            return false;
         }
      }

      retries++;
   }

   // Verificar resultado final
   if (result)
   {
      m_logger.Info(StringFormat("Posição #%d fechada com sucesso", ticket));

      // add to json
      double close_price = HistoryDealGetDouble(ticket, DEAL_PRICE);
      double profit      = HistoryDealGetDouble(ticket, DEAL_PROFIT);  
      string reason = HistoryDealGetString(ticket, DEAL_COMMENT);
      //
      m_jsonlog.CloseOrder(ticket, close_price, profit, reason);

      return true;
   }
   else
   {
      m_logger.Error(StringFormat("Falha no fechamento da posição #%d após %d tentativas. Último erro: %d", ticket, m_maxRetries, m_lastError));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Fechamento de todas as posições                                  |
//+------------------------------------------------------------------+
bool CTradeExecutor::CloseAllPositions(string symbol = "")
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Registrar detalhes do fechamento
   if (symbol == "")
   {
      m_logger.Info("Fechando todas as posições");
   }
   else
   {
      m_logger.Info(StringFormat("Fechando todas as posições de %s", symbol));
   }

   // Contar posições abertas
   int totalPositions = PositionsTotal();
   int closedPositions = 0;

   // Fechar cada posição
   for (int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if (ticket <= 0)
      {
         m_logger.Warning(StringFormat("Falha ao obter ticket da posição %d", i));
         continue;
      }

      // Verificar símbolo se especificado
      if (symbol != "")
      {
         if (!PositionSelectByTicket(ticket))
         {
            m_logger.Warning(StringFormat("Falha ao selecionar posição #%d", ticket));
            continue;
         }

         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if (posSymbol != symbol)
         {
            continue; // Pular posições de outros símbolos
         }
      }

      // Fechar posição
      if (ClosePosition(ticket))
      {
         closedPositions++;
      }
   }

   // Verificar resultado
   if (closedPositions > 0)
   {
      m_logger.Info(StringFormat("%d posições fechadas com sucesso", closedPositions));
      return true;
   }
   else if (totalPositions == 0)
   {
      m_logger.Info("Nenhuma posição aberta para fechar");
      return true;
   }
   else
   {
      m_logger.Warning(StringFormat("Nenhuma posição fechada de %d posições abertas", totalPositions));
      return false;
   }
}

//+------------------------------------------------------------------+
//| Aplicar trailing stop fixo                                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::ApplyTrailingStop(ulong ticket, double points)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Verificar parâmetros
   if (ticket <= 0 || points <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      m_logger.Error(StringFormat("Falha ao selecionar posição #%d para trailing stop", ticket));
      return false;
   }

   // Obter símbolo da posição
   string symbol = PositionGetString(POSITION_SYMBOL);

   // Verificar se já existe configuração para esta posição
   int index = -1;
   int size = ArraySize(m_trailingConfigs);

   for (int i = 0; i < size; i++)
   {
      if (m_trailingConfigs[i].ticket == ticket)
      {
         index = i;
         break;
      }
   }

   // Se não existir, criar nova configuração
   if (index < 0)
   {
      index = size;
      ArrayResize(m_trailingConfigs, size + 1);

      m_trailingConfigs[index].ticket = ticket;
      m_trailingConfigs[index].symbol = symbol;
      m_trailingConfigs[index].timeframe = PERIOD_CURRENT;
      m_trailingConfigs[index].trailingType = TRAILING_FIXED;
      m_trailingConfigs[index].lastUpdateTime = 0;
      m_trailingConfigs[index].lastStopLoss = 0;
   }

   // Atualizar configuração
   m_trailingConfigs[index].fixedPoints = points;
   m_trailingConfigs[index].trailingType = TRAILING_FIXED;

   m_logger.Info(StringFormat("Trailing stop fixo aplicado à posição #%d: %.1f pontos", ticket, points));

   // Calcular e aplicar stop loss imediatamente
   double newStopLoss = CalculateFixedTrailingStop(ticket, points);

   if (newStopLoss > 0)
   {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;

      if (posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }
      else if (posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }

      // Modificar posição se o novo stop loss for melhor
      if (isImprovement)
      {
         if (ModifyPosition(ticket, newStopLoss, takeProfit))
         {
            m_trailingConfigs[index].lastStopLoss = newStopLoss;
            m_trailingConfigs[index].lastUpdateTime = TimeCurrent();
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Aplicar trailing stop baseado em ATR                             |
//+------------------------------------------------------------------+
bool CTradeExecutor::ApplyATRTrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, double multiplier)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Verificar parâmetros
   if (ticket <= 0 || symbol == "" || multiplier <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop ATR";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      m_logger.Error(StringFormat("Falha ao selecionar posição #%d para trailing stop ATR", ticket));
      return false;
   }

   // Verificar se o símbolo corresponde à posição
   string posSymbol = PositionGetString(POSITION_SYMBOL);
   if (posSymbol != symbol)
   {
      m_lastError = -4;
      m_lastErrorDesc = "Símbolo não corresponde à posição";
      m_logger.Error(StringFormat("Símbolo %s não corresponde à posição #%d (%s)", symbol, ticket, posSymbol));
      return false;
   }

   // Verificar se já existe configuração para esta posição
   int index = -1;
   int size = ArraySize(m_trailingConfigs);

   for (int i = 0; i < size; i++)
   {
      if (m_trailingConfigs[i].ticket == ticket)
      {
         index = i;
         break;
      }
   }

   // Se não existir, criar nova configuração
   if (index < 0)
   {
      index = size;
      ArrayResize(m_trailingConfigs, size + 1);

      m_trailingConfigs[index].ticket = ticket;
      m_trailingConfigs[index].symbol = symbol;
      m_trailingConfigs[index].timeframe = timeframe;
      m_trailingConfigs[index].trailingType = TRAILING_ATR;
      m_trailingConfigs[index].lastUpdateTime = 0;
      m_trailingConfigs[index].lastStopLoss = 0;
   }

   // Atualizar configuração
   m_trailingConfigs[index].atrMultiplier = multiplier;
   m_trailingConfigs[index].timeframe = timeframe;
   m_trailingConfigs[index].trailingType = TRAILING_ATR;

   m_logger.Info(StringFormat("Trailing stop ATR aplicado à posição #%d: multiplicador %.1f", ticket, multiplier));

   // Calcular e aplicar stop loss imediatamente
   double newStopLoss = CalculateATRTrailingStop(symbol, timeframe, multiplier, ticket);

   if (newStopLoss > 0)
   {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;

      if (posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }
      else if (posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }

      // Modificar posição se o novo stop loss for melhor
      if (isImprovement)
      {
         if (ModifyPosition(ticket, newStopLoss, takeProfit))
         {
            m_trailingConfigs[index].lastStopLoss = newStopLoss;
            m_trailingConfigs[index].lastUpdateTime = TimeCurrent();
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Aplicar trailing stop baseado em média móvel                     |
//+------------------------------------------------------------------+
bool CTradeExecutor::ApplyMATrailingStop(ulong ticket, string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   // Verificar se trading está permitido
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      m_logger.Warning(m_lastErrorDesc);
      return false;
   }

   // Verificar parâmetros
   if (ticket <= 0 || symbol == "" || period <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para trailing stop MA";
      m_logger.Error(m_lastErrorDesc);
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      m_logger.Error(StringFormat("Falha ao selecionar posição #%d para trailing stop MA", ticket));
      return false;
   }

   // Verificar se o símbolo corresponde à posição
   string posSymbol = PositionGetString(POSITION_SYMBOL);
   if (posSymbol != symbol)
   {
      m_lastError = -4;
      m_lastErrorDesc = "Símbolo não corresponde à posição";
      m_logger.Error(StringFormat("Símbolo %s não corresponde à posição #%d (%s)", symbol, ticket, posSymbol));
      return false;
   }

   // Verificar se já existe configuração para esta posição
   int index = -1;
   int size = ArraySize(m_trailingConfigs);

   for (int i = 0; i < size; i++)
   {
      if (m_trailingConfigs[i].ticket == ticket)
      {
         index = i;
         break;
      }
   }

   // Se não existir, criar nova configuração
   if (index < 0)
   {
      index = size;
      ArrayResize(m_trailingConfigs, size + 1);

      m_trailingConfigs[index].ticket = ticket;
      m_trailingConfigs[index].symbol = symbol;
      m_trailingConfigs[index].timeframe = timeframe;
      m_trailingConfigs[index].trailingType = TRAILING_MA;
      m_trailingConfigs[index].lastUpdateTime = 0;
      m_trailingConfigs[index].lastStopLoss = 0;
   }

   // Atualizar configuração
   m_trailingConfigs[index].maPeriod = period;
   m_trailingConfigs[index].timeframe = timeframe;
   m_trailingConfigs[index].trailingType = TRAILING_MA;

   m_logger.Info(StringFormat("Trailing stop MA aplicado à posição #%d: período %d", ticket, period));

   // Calcular e aplicar stop loss imediatamente
   double newStopLoss = CalculateMATrailingStop(symbol, timeframe, period, ticket);

   if (newStopLoss > 0)
   {
      double currentStopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      // Verificar se o novo stop loss é melhor que o atual
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isImprovement = false;

      if (posType == POSITION_TYPE_BUY && (currentStopLoss < newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }
      else if (posType == POSITION_TYPE_SELL && (currentStopLoss > newStopLoss || currentStopLoss == 0))
      {
         isImprovement = true;
      }

      // Modificar posição se o novo stop loss for melhor
      if (isImprovement)
      {
         if (ModifyPosition(ticket, newStopLoss, takeProfit))
         {
            m_trailingConfigs[index].lastStopLoss = newStopLoss;
            m_trailingConfigs[index].lastUpdateTime = TimeCurrent();
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Verificar se o erro é recuperável                                |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsRetryableError(int errorCode)
{
   switch (errorCode)
   {
   case TRADE_ERROR_SERVER_BUSY:
   case TRADE_ERROR_NO_CONNECTION:
   case TRADE_ERROR_TRADE_TIMEOUT:
   case TRADE_ERROR_PRICE_CHANGED:
   case TRADE_ERROR_OFF_QUOTES:
   case TRADE_ERROR_BROKER_BUSY:
   case TRADE_ERROR_REQUOTE:
   case TRADE_ERROR_TOO_MANY_REQUESTS:
   case TRADE_ERROR_TRADE_CONTEXT_BUSY:
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA CRÍTICA: CalculateFixedTrailingStop         |
//| PROBLEMA: return 0.0 parava trailing permanentemente            |
//| SOLUÇÃO: return currentStopLoss pausa temporariamente           |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateFixedTrailingStop(ulong ticket, double fixedPoints)
{
   if (ticket <= 0 || fixedPoints <= 0)
   {
      return 0.0;
   }

   if (!PositionSelectByTicket(ticket))
   {
      return 0.0;
   }

   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double currentStopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = PositionGetString(POSITION_SYMBOL);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if (entryPrice <= 0 || currentPrice <= 0 || point <= 0)
   {
      return 0.0;
   }

   // ✅ CORREÇÃO: Usar valores configurados diretamente (não forçar mínimos)
   double adjustedPoints = fixedPoints;
   double stopDistance = adjustedPoints * point;
   double newStopLoss = 0.0;

   if (posType == POSITION_TYPE_BUY)
   {
      newStopLoss = currentPrice - stopDistance;

      // ✅ CORREÇÃO CRÍTICA: Proteção inteligente que NÃO para permanentemente
      double minSafeSL = entryPrice * 0.98; // Máximo 2% de perda da entrada
      newStopLoss = MathMax(newStopLoss, minSafeSL);
      
      // ✅ CORREÇÃO CRÍTICA: NUNCA mover SL para trás (apenas para frente)
      newStopLoss = MathMax(newStopLoss, currentStopLoss);

      // ✅ CORREÇÃO CRÍTICA: Verificação mais inteligente
      // Só pausar se prejuízo REAL > 2% (não 0.5% como antes)
      if (currentPrice < entryPrice * 0.98) // Apenas se perda > 2%
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Trailing pausado TEMPORARIAMENTE para #%d: prejuízo %.2f%% detectado",
                                        ticket, ((entryPrice - currentPrice) / entryPrice) * 100));
         }
         // ✅ CRÍTICO: RETORNAR SL ATUAL (não 0.0) - permite reativação
         return currentStopLoss;
      }
   }
   else if (posType == POSITION_TYPE_SELL)
   {
      newStopLoss = currentPrice + stopDistance;

      // ✅ CORREÇÃO CRÍTICA: Proteção inteligente para vendas
      double maxSafeSL = entryPrice * 1.02; // Máximo 2% de perda da entrada
      newStopLoss = MathMin(newStopLoss, maxSafeSL);
      
      // ✅ CORREÇÃO CRÍTICA: NUNCA mover SL para trás
      newStopLoss = MathMin(newStopLoss, currentStopLoss);

      // ✅ CORREÇÃO CRÍTICA: Verificação mais inteligente para vendas
      if (currentPrice > entryPrice * 1.02) // Apenas se perda > 2%
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Trailing pausado TEMPORARIAMENTE para #%d: prejuízo %.2f%% detectado",
                                        ticket, ((currentPrice - entryPrice) / entryPrice) * 100));
         }
         // ✅ CRÍTICO: RETORNAR SL ATUAL (não 0.0) - permite reativação
         return currentStopLoss;
      }
   }
   else
   {
      return 0.0;
   }

   newStopLoss = NormalizeDouble(newStopLoss, digits);

   // ✅ ADICIONADO: Log detalhado para monitoramento crítico
   if (m_logger != NULL)
   {
      double profitPoints = 0;
      if (posType == POSITION_TYPE_BUY)
      {
         profitPoints = (currentPrice - entryPrice) / point;
      }
      else
      {
         profitPoints = (entryPrice - currentPrice) / point;
      }
      
      m_logger.Debug(StringFormat("Trailing #%d: preço=%.5f, lucro=%.1fpts, SL_atual=%.5f, SL_novo=%.5f",
                                ticket, currentPrice, profitPoints, currentStopLoss, newStopLoss));
   }

   return newStopLoss;
}
//+------------------------------------------------------------------+
//| Calcular stop loss para trailing stop baseado em ATR             |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateATRTrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, double atrMultiplier, ulong ticket)
{
   // Verificar parâmetros
   if (symbol == "" || atrMultiplier <= 0 || ticket <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Parâmetros inválidos para cálculo de trailing stop ATR");
      }
      return 0.0;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao selecionar posição #" + IntegerToString(ticket));
      }
      return 0.0;
   }

   // Obter informações da posição
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // Verificar se os valores são válidos
   if (openPrice <= 0 || currentPrice <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Valores inválidos para cálculo de trailing stop ATR");
      }
      return 0.0;
   }

   // Criar handle do ATR
   int atrHandle = iATR(symbol, timeframe, 14);
   if (atrHandle == INVALID_HANDLE)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao criar handle do ATR: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Copiar valores do ATR
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   int copied = CopyBuffer(atrHandle, 0, 0, 1, atrValues);
   IndicatorRelease(atrHandle);

   if (copied <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao copiar valores do ATR: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Calcular distância baseada no ATR
   double atrValue = atrValues[0];
   double stopDistance = atrValue * atrMultiplier;

   // Verificar se o valor do ATR é válido
   if (atrValue <= 0 || stopDistance <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Valor do ATR inválido para cálculo de trailing stop");
      }
      return 0.0;
   }

   // Calcular novo stop loss
   double newStopLoss = 0.0;

   if (posType == POSITION_TYPE_BUY)
   {
      newStopLoss = currentPrice - stopDistance;

      // Verificar se o preço está em lucro
      if (currentPrice <= openPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop ATR não aplicado: posição de compra não está em lucro");
         }
         return 0.0;
      }
   }
   else if (posType == POSITION_TYPE_SELL)
   {
      newStopLoss = currentPrice + stopDistance;

      // Verificar se o preço está em lucro
      if (currentPrice >= openPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop ATR não aplicado: posição de venda não está em lucro");
         }
         return 0.0;
      }
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Tipo de posição inválido para cálculo de trailing stop ATR");
      }
      return 0.0;
   }

   // Normalizar o stop loss
   newStopLoss = NormalizeDouble(newStopLoss, digits);

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Trailing stop ATR calculado para posição #%d: %.5f (ATR: %.5f)",
                                  ticket, newStopLoss, atrValue));
   }

   return newStopLoss;
}

//+------------------------------------------------------------------+
//| Calcular stop loss para trailing stop baseado em média móvel     |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateMATrailingStop(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, ulong ticket)
{
   // Verificar parâmetros
   if (symbol == "" || maPeriod <= 0 || ticket <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Parâmetros inválidos para cálculo de trailing stop MA");
      }
      return 0.0;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao selecionar posição #" + IntegerToString(ticket));
      }
      return 0.0;
   }

   // Obter informações da posição
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // Verificar se os valores são válidos
   if (openPrice <= 0 || currentPrice <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Valores inválidos para cálculo de trailing stop MA");
      }
      return 0.0;
   }

   // Criar handle da média móvel
   int maHandle = iMA(symbol, timeframe, maPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if (maHandle == INVALID_HANDLE)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao criar handle da média móvel: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Copiar valores da média móvel
   double maValues[];
   ArraySetAsSeries(maValues, true);
   int copied = CopyBuffer(maHandle, 0, 0, 1, maValues);
   IndicatorRelease(maHandle);

   if (copied <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Falha ao copiar valores da média móvel: " + IntegerToString(GetLastError()));
      }
      return 0.0;
   }

   // Obter valor da média móvel
   double maValue = maValues[0];

   // Verificar se o valor da média móvel é válido
   if (maValue <= 0)
   {
      if (m_logger != NULL)
      {
         m_logger.Warning("Valor da média móvel inválido para cálculo de trailing stop");
      }
      return 0.0;
   }

   // Calcular novo stop loss
   double newStopLoss = 0.0;

   if (posType == POSITION_TYPE_BUY)
   {
      // Para compras, usar a média móvel como stop loss se estiver abaixo do preço atual
      if (maValue < currentPrice)
      {
         newStopLoss = maValue;
      }
      else
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop MA não aplicado: média móvel acima do preço atual para compra");
         }
         return 0.0;
      }

      // Verificar se o preço está em lucro
      if (currentPrice <= openPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop MA não aplicado: posição de compra não está em lucro");
         }
         return 0.0;
      }
   }
   else if (posType == POSITION_TYPE_SELL)
   {
      // Para vendas, usar a média móvel como stop loss se estiver acima do preço atual
      if (maValue > currentPrice)
      {
         newStopLoss = maValue;
      }
      else
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop MA não aplicado: média móvel abaixo do preço atual para venda");
         }
         return 0.0;
      }

      // Verificar se o preço está em lucro
      if (currentPrice >= openPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("Trailing stop MA não aplicado: posição de venda não está em lucro");
         }
         return 0.0;
      }
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error("Tipo de posição inválido para cálculo de trailing stop MA");
      }
      return 0.0;
   }

   // Normalizar o stop loss
   newStopLoss = NormalizeDouble(newStopLoss, digits);

   if (m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Trailing stop MA calculado para posição #%d: %.5f (MA: %.5f)",
                                  ticket, newStopLoss, maValue));
   }

   return newStopLoss;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO APRIMORADA: ManageTrailingStops                       |
//| CORREÇÃO: Logs detalhados para identificar problemas            |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageTrailingStops()
{
   int size = ArraySize(m_trailingConfigs);
   if (size == 0)
   {
      static datetime lastLogTime = 0;
      if (TimeCurrent() - lastLogTime > 60)
      {
         if (m_logger != NULL)
         {
            m_logger.Debug("ManageTrailingStops: Nenhuma configuração ativa");
         }
         lastLogTime = TimeCurrent();
      }
      return;
   }

   // ✅ CORREÇÃO: Log mais frequente para monitoramento crítico
   static datetime lastStatusLog = 0;
   if (TimeCurrent() - lastStatusLog > 60) // A cada minuto (era 5 minutos)
   {
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("ManageTrailingStops: Gerenciando %d configurações ativas", size));
         
         // ✅ ADICIONADO: Log detalhado de cada configuração ativa
         for (int j = 0; j < size; j++)
         {
            if (PositionSelectByTicket(m_trailingConfigs[j].ticket))
            {
               double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
               double currentSL = PositionGetDouble(POSITION_SL);
               double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               
               m_logger.Info(StringFormat("  Ticket #%d: entrada=%.5f, atual=%.5f, SL=%.5f",
                                        m_trailingConfigs[j].ticket, entryPrice, currentPrice, currentSL));
            }
         }
      }
      lastStatusLog = TimeCurrent();
   }

   for (int i = size - 1; i >= 0; i--)
   {
      if (!PositionSelectByTicket(m_trailingConfigs[i].ticket))
      {
         if (m_logger != NULL)
         {
            m_logger.Info(StringFormat("Removendo configuração trailing #%d (posição fechada)",
                                     m_trailingConfigs[i].ticket));
         }
         RemoveTrailingConfig(i);
         size--;
         continue;
      }

      // ✅ VERIFICAR SE ESTÁ PRONTO PARA TRAILING
      if (!IsPositionReadyForTrailing(m_trailingConfigs[i].ticket))
      {
         continue;
      }

      // ✅ ADICIONADO: Log antes do cálculo crítico
      if (m_logger != NULL)
      {
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double currentSL = PositionGetDouble(POSITION_SL);
         m_logger.Debug(StringFormat("Calculando trailing #%d: preço=%.5f, SL_atual=%.5f",
                                   m_trailingConfigs[i].ticket, currentPrice, currentSL));
      }

      // Calcular novo stop loss
      double newStopLoss = CalculateNewTrailingStop(i);

      // ✅ ADICIONADO: Log crítico do resultado
      if (m_logger != NULL)
      {
         double currentStopLoss = PositionGetDouble(POSITION_SL);
         if (newStopLoss > 0)
         {
            double improvement = MathAbs(newStopLoss - currentStopLoss) / SymbolInfoDouble(m_trailingConfigs[i].symbol, SYMBOL_POINT);
            m_logger.Debug(StringFormat("Resultado cálculo #%d: SL_novo=%.5f, melhoria=%.1f pontos",
                                      m_trailingConfigs[i].ticket, newStopLoss, improvement));
         }
         else
         {
            m_logger.Warning(StringFormat("❌ CRÍTICO: Cálculo #%d retornou 0 - investigar!",
                                        m_trailingConfigs[i].ticket));
         }
      }

      if (newStopLoss > 0)
      {
         if (ShouldUpdateStopLoss(i, newStopLoss))
         {
            double takeProfit = PositionGetDouble(POSITION_TP);

            if (ModifyPosition(m_trailingConfigs[i].ticket, newStopLoss, takeProfit))
            {
               m_trailingConfigs[i].lastStopLoss = newStopLoss;
               m_trailingConfigs[i].lastUpdateTime = TimeCurrent();

               if (m_logger != NULL)
               {
                  double oldSL = PositionGetDouble(POSITION_SL);
                  double improvement = MathAbs(newStopLoss - oldSL) / SymbolInfoDouble(m_trailingConfigs[i].symbol, SYMBOL_POINT);
                  m_logger.Info(StringFormat("✅ TRAILING ATUALIZADO #%d: %.5f → %.5f (melhoria: %.1f pontos)",
                                           m_trailingConfigs[i].ticket, oldSL, newStopLoss, improvement));
               }
            }
            else
            {
               if (m_logger != NULL)
               {
                  m_logger.Error(StringFormat("❌ FALHA trailing #%d: %s",
                                            m_trailingConfigs[i].ticket, GetLastErrorDescription()));
               }
            }
         }
         else
         {
            // ✅ ADICIONADO: Log detalhado da rejeição
            if (m_logger != NULL)
            {
               double currentStopLoss = PositionGetDouble(POSITION_SL);
               double improvement = MathAbs(newStopLoss - currentStopLoss) / SymbolInfoDouble(m_trailingConfigs[i].symbol, SYMBOL_POINT);
               m_logger.Debug(StringFormat("Trailing #%d rejeitado: melhoria %.1f < 15 pontos mínimos",
                                         m_trailingConfigs[i].ticket, improvement));
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| ✅ FUNÇÃO COMPLETAMENTE CORRIGIDA: IsPositionReadyForTrailing   |
//| CORREÇÃO CRÍTICA: Remove verificação contínua problemática      |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsPositionReadyForTrailing(ulong ticket)
{
   if (!PositionSelectByTicket(ticket))
   {
      return false;
   }

   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double stopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = PositionGetString(POSITION_SYMBOL);

   // Calcular lucro atual em pontos
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double profitPoints = 0;

   if (posType == POSITION_TYPE_BUY)
   {
      profitPoints = (currentPrice - entryPrice) / point;
   }
   else
   {
      profitPoints = (entryPrice - currentPrice) / point;
   }

   // ✅ CORREÇÃO CRÍTICA: Verificação simplificada e robusta
   // Só verificar lucro mínimo - R:R é verificado apenas na ativação inicial
   bool hasMinimumProfit = (profitPoints >= TRAILING_MIN_PROFIT_POINTS);

   // ✅ CORREÇÃO CRÍTICA: Verificar se trailing já foi ativado
   // Se SL já está em lucro (acima da entrada para BUY), trailing já está ativo
   bool trailingAlreadyActive = false;
   
   if (posType == POSITION_TYPE_BUY)
   {
      trailingAlreadyActive = (stopLoss > entryPrice);
   }
   else
   {
      trailingAlreadyActive = (stopLoss < entryPrice);
   }

   // ✅ LÓGICA CORRIGIDA: Se trailing já ativo OU condições iniciais atendidas
   if (trailingAlreadyActive)
   {
      // Trailing já está ativo, apenas verificar se ainda há lucro suficiente
      bool hasMinimumActiveProfit = (profitPoints >= 10); // Mínimo 10 pontos para manter ativo
      
      // ✅ ADICIONADO: Log detalhado quando trailing já está ativo
      if (m_logger != NULL)
      {
         static datetime lastActiveLog = 0;
         if (TimeCurrent() - lastActiveLog > 300) // A cada 5 minutos
         {
            m_logger.Debug(StringFormat("Trailing #%d JÁ ATIVO: lucro=%.1f, SL=%.5f (%.1f pts acima entrada)",
                                      ticket, profitPoints, stopLoss, 
                                      MathAbs(stopLoss - entryPrice) / point));
            lastActiveLog = TimeCurrent();
         }
      }
      
      return hasMinimumActiveProfit;
   }
   else
   {
      // Trailing ainda não ativo, verificar condições de ativação inicial
      bool hasMinimumRR = false;
      
      if (stopLoss > 0)
      {
         double riskPoints = 0;
         
         // ✅ CORREÇÃO CRÍTICA: Usar valor absoluto para evitar negativos
         if (posType == POSITION_TYPE_BUY)
         {
            riskPoints = MathAbs(entryPrice - stopLoss) / point;
         }
         else
         {
            riskPoints = MathAbs(stopLoss - entryPrice) / point;
         }

         if (riskPoints > 0)
         {
            double currentRR = profitPoints / riskPoints;
            hasMinimumRR = (currentRR >= TRAILING_ACTIVATION_RR);
            
            // ✅ ADICIONADO: Log detalhado da verificação inicial
            if (m_logger != NULL)
            {
               static datetime lastInitLog = 0;
               if (TimeCurrent() - lastInitLog > 60) // A cada minuto
               {
                  m_logger.Debug(StringFormat("Trailing #%d VERIFICAÇÃO INICIAL: lucro=%.1f (min=%d), risco=%.1f, R:R=%.2f (min=%.1f), pronto=%s",
                                           ticket, profitPoints, TRAILING_MIN_PROFIT_POINTS,
                                           riskPoints, currentRR, TRAILING_ACTIVATION_RR,
                                           (hasMinimumProfit && hasMinimumRR) ? "SIM" : "NÃO"));
                  lastInitLog = TimeCurrent();
               }
            }
         }
         else
         {
            // ✅ ADICIONADO: Log quando risco é zero ou inválido
            if (m_logger != NULL)
            {
               m_logger.Warning(StringFormat("Trailing #%d: risco calculado = 0 (SL=%.5f, entrada=%.5f)",
                                           ticket, stopLoss, entryPrice));
            }
         }
      }
      else
      {
         // ✅ ADICIONADO: Log quando não há SL definido
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Trailing #%d: SL não definido (stopLoss=%.5f)",
                                        ticket, stopLoss));
         }
      }

      return hasMinimumProfit && hasMinimumRR;
   }
}

//+------------------------------------------------------------------+
//| Calcular novo trailing stop baseado no tipo                      |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateNewTrailingStop(int configIndex)
{
   if (configIndex < 0 || configIndex >= ArraySize(m_trailingConfigs))
   {
      return 0.0;
   }

   TrailingStopConfig config = m_trailingConfigs[configIndex];

   switch (config.trailingType)
   {
   case TRAILING_FIXED:
      return CalculateFixedTrailingStop(config.ticket, config.fixedPoints);

   case TRAILING_ATR:
      return CalculateATRTrailingStop(config.symbol, config.timeframe,
                                      config.atrMultiplier, config.ticket);

   case TRAILING_MA:
      return CalculateMATrailingStop(config.symbol, config.timeframe,
                                     config.maPeriod, config.ticket);
   }

   return 0.0;
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: ShouldUpdateStopLoss                       |
//| PROBLEMA: Valores de melhoria mínima muito altos (50 pontos WIN)|
//| SOLUÇÃO: Reduzir para 15 pontos WIN, 2 pontos WDO, 50 USD BTC   |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldUpdateStopLoss(int configIndex, double newStopLoss)
{
   if (configIndex < 0 || configIndex >= ArraySize(m_trailingConfigs))
   {
      return false;
   }

   double currentStopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = m_trailingConfigs[configIndex].symbol;

   // ✅ VALORES CORRIGIDOS - Redução significativa para permitir atualizações contínuas
   double minImprovement = 0;

   if (StringFind(symbol, "WIN") >= 0)
   {
      minImprovement = 15; // ✅ CORRIGIDO: 50 → 15 pontos (70% redução)
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      minImprovement = 2;  // ✅ CORRIGIDO: 3 → 2 pontos (33% redução)
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      minImprovement = 50; // ✅ CORRIGIDO: 100 → 50 USD (50% redução)
   }
   else
   {
      minImprovement = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10; // 10 pontos padrão
   }

   // ✅ ADICIONADO: Log detalhado para debug e monitoramento
   if (m_logger != NULL)
   {
      double improvement = 0;
      if (posType == POSITION_TYPE_BUY)
      {
         improvement = newStopLoss - currentStopLoss;
      }
      else
      {
         improvement = currentStopLoss - newStopLoss;
      }
      
      bool shouldUpdate = (improvement >= minImprovement);
      
      m_logger.Debug(StringFormat("ShouldUpdateStopLoss #%d: melhoria=%.1f, mínimo=%.1f, aprovado=%s",
                                m_trailingConfigs[configIndex].ticket,
                                improvement, minImprovement,
                                shouldUpdate ? "SIM" : "NÃO"));
   }

   // Verificar se há melhoria significativa
   if (posType == POSITION_TYPE_BUY)
   {
      return (newStopLoss > currentStopLoss + minImprovement);
   }
   else
   {
      return (newStopLoss < currentStopLoss - minImprovement);
   }
}
//+------------------------------------------------------------------+
//| Gerenciar parciais (chamado a cada tick)                         |
//+------------------------------------------------------------------+
void CTradeExecutor::ManagePartialTakeProfits()
{
   static datetime lastPartialCheck = 0;
   datetime currentTime = TimeCurrent();

   // ✅ VERIFICAR PARCIAIS A CADA 5 SEGUNDOS (balanceio entre responsividade e performance)
   if (currentTime - lastPartialCheck < 5)
   {
      return;
   }
   lastPartialCheck = currentTime;

   int totalPositions = PositionsTotal();

   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
         continue;

      if (!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double currentVolume = PositionGetDouble(POSITION_VOLUME);

      // ✅ VERIFICAR SE DEVE TOMAR PARCIAL AGORA
      if (ShouldTakePartialNow(symbol, ticket, currentPrice, entryPrice, stopLoss))
      {
         double partialVolume = CalculatePartialVolume(symbol, ticket, currentVolume);

         if (partialVolume > 0 && partialVolume < currentVolume)
         {
            if (ClosePosition(ticket, partialVolume))
            {
               if (m_logger != NULL)
               {
                  m_logger.Info(StringFormat("Parcial executada: ticket #%d, volume %.2f",
                                             ticket, partialVolume));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar se deve tomar parcial agora                            |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldTakePartialNow(string symbol, ulong ticket, double currentPrice, double entryPrice, double stopLoss)
{
   if (stopLoss <= 0)
      return false;

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // Calcular R:R atual
   double risk = MathAbs(entryPrice - stopLoss);
   double currentReward = 0;

   if (posType == POSITION_TYPE_BUY)
   {
      currentReward = currentPrice - entryPrice;
   }
   else
   {
      currentReward = entryPrice - currentPrice;
   }

   if (risk <= 0 || currentReward <= 0)
      return false;

   double currentRR = currentReward / risk;

   // ✅ VERIFICAR NÍVEIS DE PARCIAIS PREDEFINIDOS
   static double partialLevels[] = {1.5, 2.5, 4.0}; // R:R levels
   static bool partialsExecuted[][3];               // Para cada posição, track de parciais executadas

   // Simplificado: tomar parcial em 2:1 se não foi executada ainda
   if (currentRR >= 2.0)
   {
      string comment = PositionGetString(POSITION_COMMENT);
      if (StringFind(comment, "Partial") < 0)
      { // Ainda não tomou parcial
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Calcular volume da parcial                                       |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculatePartialVolume(string symbol, ulong ticket, double currentVolume)
{
   // ✅ TOMAR 50% NA PRIMEIRA PARCIAL
   double partialVolume = currentVolume * 0.5;

   // Ajustar para step de lote mínimo
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if (stepLot > 0)
   {
      partialVolume = MathFloor(partialVolume / stepLot) * stepLot;
   }

   // Verificar volume mínimo
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if (partialVolume < minLot)
   {
      return 0; // Não pode tomar parcial
   }

   return partialVolume;
}

//+------------------------------------------------------------------+
//| Gerenciar risco de posições                                      |
//+------------------------------------------------------------------+
void CTradeExecutor::ManagePositionRisk()
{
   int totalPositions = PositionsTotal();

   for (int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket <= 0)
         continue;

      if (!PositionSelectByTicket(ticket))
         continue;

      // ✅ VERIFICAR RISCO EXCESSIVO
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      double currentSwap = PositionGetDouble(POSITION_SWAP);
      double totalPnL = currentProfit + currentSwap;

      // Se perda está muito grande (exemplo: -500 pontos), considerar fechamento
      if (totalPnL < -500)
      { // Ajustar conforme tolerância
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("Posição #%d com perda excessiva: %.2f", ticket, totalPnL));
         }
         // Aqui poderia implementar fechamento de emergência ou alerta
      }
   }
}

//+------------------------------------------------------------------+
//| Remover configuração de trailing stop                            |
//+------------------------------------------------------------------+
void CTradeExecutor::RemoveTrailingConfig(int index)
{
   int size = ArraySize(m_trailingConfigs);
   if (index < 0 || index >= size)
      return;

   // Mover elementos para frente
   for (int i = index; i < size - 1; i++)
   {
      m_trailingConfigs[i] = m_trailingConfigs[i + 1];
   }

   // Redimensionar array
   ArrayResize(m_trailingConfigs, size - 1);
}

//+------------------------------------------------------------------+
//| Limpar configurações inválidas                                   |
//+------------------------------------------------------------------+
void CTradeExecutor::CleanupInvalidConfigurations()
{
   for (int i = ArraySize(m_trailingConfigs) - 1; i >= 0; i--)
   {
      if (!PositionSelectByTicket(m_trailingConfigs[i].ticket))
      {
         RemoveTrailingConfig(i);
      }
   }
}

/////////
//+------------------------------------------------------------------+
//| Configurar breakeven fixo para uma posição                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::SetBreakevenFixed(ulong ticket, double triggerPoints, double offsetPoints = 2.0)
{
   if (!m_tradeAllowed)
   {
      m_lastError = -1;
      m_lastErrorDesc = "Trading não está habilitado";
      return false;
   }

   if (ticket <= 0 || triggerPoints <= 0)
   {
      m_lastError = -2;
      m_lastErrorDesc = "Parâmetros inválidos para breakeven";
      return false;
   }

   // Verificar se a posição existe
   if (!PositionSelectByTicket(ticket))
   {
      m_lastError = -3;
      m_lastErrorDesc = "Posição não encontrada";
      return false;
   }

   string symbol = PositionGetString(POSITION_SYMBOL);

   // Verificar se já existe configuração
   int index = FindBreakevenConfigIndex(ticket);

   if (index < 0)
   {
      // Criar nova configuração
      int size = ArraySize(m_breakevenConfigs);
      ArrayResize(m_breakevenConfigs, size + 1);
      index = size;

      m_breakevenConfigs[index].ticket = ticket;
      m_breakevenConfigs[index].symbol = symbol;
      m_breakevenConfigs[index].configTime = TimeCurrent();
   }

   // Configurar parâmetros
   m_breakevenConfigs[index].breakevenType = BREAKEVEN_FIXED;
   m_breakevenConfigs[index].triggerPoints = triggerPoints;
   m_breakevenConfigs[index].breakevenOffset = offsetPoints;
   m_breakevenConfigs[index].isActive = true;
   m_breakevenConfigs[index].wasTriggered = false;

   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Breakeven fixo configurado para #%d: trigger %.1f pontos, offset %.1f pontos",
                                 ticket, triggerPoints, offsetPoints));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Configurar breakeven baseado em ATR                              |
//+------------------------------------------------------------------+
bool CTradeExecutor::SetBreakevenATR(ulong ticket, double atrMultiplier = 1.0, double offsetPoints = 2.0)
{
   if (!m_tradeAllowed)
   {
      return false;
   }

   if (ticket <= 0 || atrMultiplier <= 0)
   {
      return false;
   }

   if (!PositionSelectByTicket(ticket))
   {
      return false;
   }

   string symbol = PositionGetString(POSITION_SYMBOL);

   int index = FindBreakevenConfigIndex(ticket);
   if (index < 0)
   {
      int size = ArraySize(m_breakevenConfigs);
      ArrayResize(m_breakevenConfigs, size + 1);
      index = size;

      m_breakevenConfigs[index].ticket = ticket;
      m_breakevenConfigs[index].symbol = symbol;
      m_breakevenConfigs[index].configTime = TimeCurrent();
   }

   m_breakevenConfigs[index].breakevenType = BREAKEVEN_ATR;
   m_breakevenConfigs[index].atrMultiplier = atrMultiplier;
   m_breakevenConfigs[index].breakevenOffset = offsetPoints;
   m_breakevenConfigs[index].isActive = true;
   m_breakevenConfigs[index].wasTriggered = false;

   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Breakeven ATR configurado para #%d: ATR x%.1f, offset %.1f pontos",
                                 ticket, atrMultiplier, offsetPoints));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Configurar breakeven baseado em relação risco/retorno            |
//+------------------------------------------------------------------+
bool CTradeExecutor::SetBreakevenRiskRatio(ulong ticket, double riskRatio = 1.0, double offsetPoints = 2.0)
{
   if (!m_tradeAllowed || ticket <= 0 || riskRatio <= 0)
   {
      return false;
   }

   if (!PositionSelectByTicket(ticket))
   {
      return false;
   }

   string symbol = PositionGetString(POSITION_SYMBOL);

   int index = FindBreakevenConfigIndex(ticket);
   if (index < 0)
   {
      int size = ArraySize(m_breakevenConfigs);
      ArrayResize(m_breakevenConfigs, size + 1);
      index = size;

      m_breakevenConfigs[index].ticket = ticket;
      m_breakevenConfigs[index].symbol = symbol;
      m_breakevenConfigs[index].configTime = TimeCurrent();
   }

   m_breakevenConfigs[index].breakevenType = BREAKEVEN_RISK_RATIO;
   m_breakevenConfigs[index].riskRatio = riskRatio;
   m_breakevenConfigs[index].breakevenOffset = offsetPoints;
   m_breakevenConfigs[index].isActive = true;
   m_breakevenConfigs[index].wasTriggered = false;

   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Breakeven R:R configurado para #%d: %.1f:1, offset %.1f pontos",
                                 ticket, riskRatio, offsetPoints));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Gerenciar breakevens (chamado no ManageOpenPositions)            |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageBreakevens()
{
   int size = ArraySize(m_breakevenConfigs);
   if (size == 0)
      return;

   for (int i = size - 1; i >= 0; i--)
   {
      // Verificar se a posição ainda existe
      if (!PositionSelectByTicket(m_breakevenConfigs[i].ticket))
      {
         RemoveBreakevenConfig(i);
         size--;
         continue;
      }

      // Pular se breakeven não está ativo ou já foi acionado
      if (!m_breakevenConfigs[i].isActive || m_breakevenConfigs[i].wasTriggered)
      {
         continue;
      }

      // Verificar se deve acionar breakeven
      if (ShouldTriggerBreakeven(i))
      {
         ExecuteBreakeven(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar se deve acionar breakeven                              |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldTriggerBreakeven(int configIndex)
{
   if (configIndex < 0 || configIndex >= ArraySize(m_breakevenConfigs))
   {
      return false;
   }

   BreakevenConfig config = m_breakevenConfigs[configIndex];

   if (!PositionSelectByTicket(config.ticket))
   {
      return false;
   }

   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double stopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double point = SymbolInfoDouble(config.symbol, SYMBOL_POINT);
   double profitPoints = 0;

   // Calcular lucro atual em pontos
   if (posType == POSITION_TYPE_BUY)
   {
      profitPoints = (currentPrice - entryPrice) / point;
   }
   else
   {
      profitPoints = (entryPrice - currentPrice) / point;
   }

   // Verificar se está em lucro
   if (profitPoints <= 0)
   {
      return false;
   }

   double triggerLevel = 0;

   switch (config.breakevenType)
   {
   case BREAKEVEN_FIXED:
      triggerLevel = config.triggerPoints;
      break;

   case BREAKEVEN_ATR:
   {
      double atr = CalculateATRForBreakeven(config.symbol, config.ticket);
      if (atr > 0)
      {
         triggerLevel = (atr / point) * config.atrMultiplier;
      }
   }
   break;

   case BREAKEVEN_RISK_RATIO:
   {
      if (stopLoss > 0)
      {
         double riskPoints = 0;
         if (posType == POSITION_TYPE_BUY)
         {
            riskPoints = (entryPrice - stopLoss) / point;
         }
         else
         {
            riskPoints = (stopLoss - entryPrice) / point;
         }
         triggerLevel = riskPoints * config.riskRatio;
      }
   }
   break;
   }

   bool shouldTrigger = (profitPoints >= triggerLevel);

   if (shouldTrigger && m_logger != NULL)
   {
      m_logger.Debug(StringFormat("Breakeven trigger detectado para #%d: lucro %.1f >= trigger %.1f pontos",
                                  config.ticket, profitPoints, triggerLevel));
   }

   return shouldTrigger;
}

//+------------------------------------------------------------------+
//| Executar breakeven                                               |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecuteBreakeven(int configIndex)
{
   if (configIndex < 0 || configIndex >= ArraySize(m_breakevenConfigs))
   {
      return false;
   }

   BreakevenConfig config = m_breakevenConfigs[configIndex];

   if (!PositionSelectByTicket(config.ticket))
   {
      return false;
   }

   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double takeProfit = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   double point = SymbolInfoDouble(config.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(config.symbol, SYMBOL_DIGITS);

   // Calcular novo stop loss (entrada + offset)
   double newStopLoss = 0;

   if (posType == POSITION_TYPE_BUY)
   {
      newStopLoss = entryPrice + (config.breakevenOffset * point);
   }
   else
   {
      newStopLoss = entryPrice - (config.breakevenOffset * point);
   }

   newStopLoss = NormalizeDouble(newStopLoss, digits);

   // Verificar se o novo stop loss é válido e melhor que o atual
   double currentStopLoss = PositionGetDouble(POSITION_SL);
   bool isImprovement = false;

   if (posType == POSITION_TYPE_BUY)
   {
      isImprovement = (newStopLoss > currentStopLoss || currentStopLoss == 0);
   }
   else
   {
      isImprovement = (newStopLoss < currentStopLoss || currentStopLoss == 0);
   }

   if (!isImprovement)
   {
      if (m_logger != NULL)
      {
         m_logger.Debug(StringFormat("Breakeven não aplicado para #%d: novo SL %.5f não é melhor que atual %.5f",
                                     config.ticket, newStopLoss, currentStopLoss));
      }
      return false;
   }

   // Executar modificação
   if (ModifyPosition(config.ticket, newStopLoss, takeProfit))
   {
      config.wasTriggered = true;

      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("BREAKEVEN ACIONADO para #%d: SL movido para %.5f (entrada + %.1f pontos)",
                                    config.ticket, newStopLoss, config.breakevenOffset));
      }

      return true;
   }
   else
   {
      if (m_logger != NULL)
      {
         m_logger.Error(StringFormat("Falha ao executar breakeven para #%d: %s",
                                     config.ticket, GetLastErrorDescription()));
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Encontrar índice de configuração de breakeven                    |
//+------------------------------------------------------------------+
int CTradeExecutor::FindBreakevenConfigIndex(ulong ticket)
{
   int size = ArraySize(m_breakevenConfigs);

   for (int i = 0; i < size; i++)
   {
      if (m_breakevenConfigs[i].ticket == ticket)
      {
         return i;
      }
   }

   return -1;
}

//+------------------------------------------------------------------+
//| Remover configuração de breakeven                                |
//+------------------------------------------------------------------+
void CTradeExecutor::RemoveBreakevenConfig(int index)
{
   int size = ArraySize(m_breakevenConfigs);
   if (index < 0 || index >= size)
      return;

   // Mover elementos
   for (int i = index; i < size - 1; i++)
   {
      m_breakevenConfigs[i] = m_breakevenConfigs[i + 1];
   }

   ArrayResize(m_breakevenConfigs, size - 1);
}

//+------------------------------------------------------------------+
//| Calcular ATR para breakeven                                      |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateATRForBreakeven(string symbol, ulong ticket)
{
   int atrHandle = iATR(symbol, PERIOD_CURRENT, 14);
   if (atrHandle == INVALID_HANDLE)
   {
      return 0.0;
   }

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   int copied = CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   IndicatorRelease(atrHandle);

   if (copied <= 0)
   {
      return 0.0;
   }

   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Configuração automática de breakeven em novas posições           |
//+------------------------------------------------------------------+
bool CTradeExecutor::AutoConfigureBreakeven(ulong ticket, string symbol)
{
   // Configurar breakeven padrão baseado no símbolo

   if (StringFind(symbol, "WIN") >= 0)
   {
      // WIN: Breakeven em 100 pontos com offset de 10 pontos
      return SetBreakevenFixed(ticket, 50.0, 10.0);
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      // WDO: Breakeven em 30 pontos com offset de 5 pontos
      return SetBreakevenFixed(ticket, 30.0, 5.0);
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      // BTC: Breakeven baseado em ATR
      return SetBreakevenATR(ticket, 1.0, 50.0);
   }
   else
   {
      // Padrão: Breakeven em 1:1 R:R
      return SetBreakevenRiskRatio(ticket, 1.0, 5.0);
   }
}

//+------------------------------------------------------------------+
//| ✅ FUNÇÃO CORRIGIDA: AutoConfigureTrailingStop                  |
//| Aumenta os valores de trailing distance para proteção adequada   |
//+------------------------------------------------------------------+
bool CTradeExecutor::AutoConfigureTrailingStop(ulong ticket, string symbol)
{
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("Configurando trailing stop automático para #%d (%s)", ticket, symbol));
   }

   if (StringFind(symbol, "WIN") >= 0)
   {
      // ✅ CORRIGIDO: Aumentado de 20 para 100 pontos
      bool result = ApplyTrailingStop(ticket, 100);
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop WIN configurado: %d pontos para #%d", 100, ticket));
      }
      return result;
   }
   else if (StringFind(symbol, "WDO") >= 0)
   {
      // ✅ CORRIGIDO: Configurado para 8 pontos
      bool result = ApplyTrailingStop(ticket, 8);
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop WDO configurado: %d pontos para #%d", 8, ticket));
      }
      return result;
   }
   else if (StringFind(symbol, "BIT") >= 0)
   {
      // ✅ CORRIGIDO: Configurado para 200 USD
      bool result = ApplyTrailingStop(ticket, 200);
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop BTC configurado: %d USD para #%d", 200, ticket));
      }
      return result;
   }
   else
   {
      // Padrão: Trailing stop fixo
      bool result = ApplyTrailingStop(ticket, 50.0);
      if (m_logger != NULL)
      {
         m_logger.Info(StringFormat("Trailing stop padrão configurado: %.1f pontos para #%d", 50.0, ticket));
      }
      return result;
   }
}

//+------------------------------------------------------------------+
//| ATUALIZAÇÃO da função ManageOpenPositions para incluir breakeven |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageOpenPositions()
{
   if (!m_tradeAllowed)
   {
      return;
   }

   datetime currentTime = TimeCurrent();
   static datetime lastFullCheck = 0;

   // ✅ GERENCIAMENTO A CADA TICK
   //ManageBreakevens();  
   ManageTrailingStops();
   ManagePartialTakeProfits();

   // ✅ VERIFICAÇÃO COMPLETA A CADA 10 SEGUNDOS
   if (currentTime - lastFullCheck >= 10)
   {
      ManagePositionRisk();
      CleanupInvalidConfigurations();
      CleanupBreakevenConfigs(); // ← ADICIONADO
      lastFullCheck = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Limpar configurações de breakeven inválidas                      |
//+------------------------------------------------------------------+
void CTradeExecutor::CleanupBreakevenConfigs()
{
   for (int i = ArraySize(m_breakevenConfigs) - 1; i >= 0; i--)
   {
      if (!PositionSelectByTicket(m_breakevenConfigs[i].ticket))
      {
         RemoveBreakevenConfig(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Valida e ajusta stops para respeitar regras do broker           |
//| - Verifica STOPLEVEL mínimo                                      |
//| - Ajusta stops muito próximos                                    |
//| - Normaliza preços para tick size                                |
//| Retorna: true se válido, false se impossível ajustar             |
//+------------------------------------------------------------------+
// Novo método para validar e ajustar stops antes da execução
bool CTradeExecutor::ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE orderType,
                                            double &entryPrice, double &stopLoss, double &takeProfit)
{

   // Obter informações do símbolo
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   // Se stopLevel for 0, usar valor mínimo seguro
   if (stopLevel == 0)
   {
      stopLevel = 5 * tickSize; // 5 ticks mínimo
   }

   // Obter preço atual de mercado
   MqlTick lastTick;
   if (!SymbolInfoTick(symbol, lastTick))
   {
      if (m_logger != NULL)
      {
         m_logger.Error("ValidateAndAdjustStops: Falha ao obter tick para " + symbol);
      }
      return false;
   }

   // Determinar preço de referência baseado no tipo de ordem
   double referencePrice = 0;

   if (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
   {
      referencePrice = lastTick.ask;

      // Para ordens de compra
      // Stop Loss deve estar abaixo do ASK - stopLevel
      double minStopDistance = stopLevel + lastTick.ask - lastTick.bid; // Incluir spread
      double maxStopLoss = lastTick.ask - minStopDistance;

      if (stopLoss > maxStopLoss)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("ValidateAndAdjustStops: Ajustando SL de compra de %.5f para %.5f (stopLevel: %.5f)",
                                          stopLoss, maxStopLoss, stopLevel));
         }
         stopLoss = NormalizeDouble(maxStopLoss, digits);
      }

      // Take Profit deve estar acima do ASK + stopLevel
      if (takeProfit > 0 && takeProfit < lastTick.ask + stopLevel)
      {
         takeProfit = NormalizeDouble(lastTick.ask + stopLevel + tickSize, digits);
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("ValidateAndAdjustStops: Ajustando TP de compra para %.5f", takeProfit));
         }
      }
   }
   else
   { // SELL orders
      referencePrice = lastTick.bid;

      // Para ordens de venda
      // Stop Loss deve estar acima do BID + stopLevel
      double minStopDistance = stopLevel + lastTick.ask - lastTick.bid; // Incluir spread
      double minStopLoss = lastTick.bid + minStopDistance;

      if (stopLoss < minStopLoss)
      {
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("ValidateAndAdjustStops: Ajustando SL de venda de %.5f para %.5f (stopLevel: %.5f)",
                                          stopLoss, minStopLoss, stopLevel));
         }
         stopLoss = NormalizeDouble(minStopLoss, digits);
      }

      // Take Profit deve estar abaixo do BID - stopLevel
      if (takeProfit > 0 && takeProfit > lastTick.bid - stopLevel)
      {
         takeProfit = NormalizeDouble(lastTick.bid - stopLevel - tickSize, digits);
         if (m_logger != NULL)
         {
            m_logger.Warning(StringFormat("ValidateAndAdjustStops: Ajustando TP de venda para %.5f", takeProfit));
         }
      }
   }

   // Normalizar todos os preços para o tick size do símbolo
   entryPrice = NormalizeDouble(MathRound(entryPrice / tickSize) * tickSize, digits);
   stopLoss = NormalizeDouble(MathRound(stopLoss / tickSize) * tickSize, digits);
   if (takeProfit > 0)
   {
      takeProfit = NormalizeDouble(MathRound(takeProfit / tickSize) * tickSize, digits);
   }

   // Validação final
   if (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if (stopLoss >= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("ValidateAndAdjustStops: SL de compra (%.5f) >= entrada (%.5f)",
                                        stopLoss, entryPrice));
         }
         return false;
      }
      if (takeProfit > 0 && takeProfit <= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("ValidateAndAdjustStops: TP de compra (%.5f) <= entrada (%.5f)",
                                        takeProfit, entryPrice));
         }
         return false;
      }
   }
   else
   {
      if (stopLoss <= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("ValidateAndAdjustStops: SL de venda (%.5f) <= entrada (%.5f)",
                                        stopLoss, entryPrice));
         }
         return false;
      }
      if (takeProfit > 0 && takeProfit >= entryPrice)
      {
         if (m_logger != NULL)
         {
            m_logger.Error(StringFormat("ValidateAndAdjustStops: TP de venda (%.5f) >= entrada (%.5f)",
                                        takeProfit, entryPrice));
         }
         return false;
      }
   }

   // Log final dos valores ajustados
   if (m_logger != NULL)
   {
      m_logger.Info(StringFormat("ValidateAndAdjustStops: %s %s - Entry: %.5f, SL: %.5f (dist: %.1f pts), TP: %.5f",
                                 symbol,
                                 (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT) ? "BUY" : "SELL",
                                 entryPrice,
                                 stopLoss,
                                 MathAbs(entryPrice - stopLoss) / point,
                                 takeProfit));
   }

   return true;
}