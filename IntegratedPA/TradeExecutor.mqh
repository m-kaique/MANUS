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

public:
   // Construtores e destrutor
   CTradeExecutor();
   ~CTradeExecutor();

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
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor()
{
   m_trade = NULL;
   m_logger = NULL;
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
bool CTradeExecutor::Initialize(CLogger *logger)
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

   // Criar objeto de trade
   m_trade = new CTrade();
   if (m_trade == NULL)
   {
      m_logger.Error("Falha ao criar objeto CTrade");
      return false;
   }

   // Configurar objeto de trade
   m_trade.SetExpertMagicNumber(123456); // Magic number para identificar ordens deste EA
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetDeviationInPoints(10); // Desvio máximo de preço em pontos

   m_logger.Info("TradeExecutor inicializado com sucesso");
   return true;
}

//+------------------------------------------------------------------+
//| Execução de ordem                                                |
//+------------------------------------------------------------------+
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
      }

      // Executar ordem de acordo com o tipo
      switch (request.type)
      {
      case ORDER_TYPE_BUY:
         result = m_trade.Buy(request.volume, request.symbol, request.price, request.stopLoss, request.takeProfit, request.comment);
         break;
      case ORDER_TYPE_SELL:
         result = m_trade.Sell(request.volume, request.symbol, request.price, request.stopLoss, request.takeProfit, request.comment);
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
//| Calcular stop loss para trailing stop fixo                       |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateFixedTrailingStop(ulong ticket, double fixedPoints) {
   if(ticket <= 0 || fixedPoints <= 0) {
      return 0.0;
   }
   
   if(!PositionSelectByTicket(ticket)) {
      return 0.0;
   }
   
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = PositionGetString(POSITION_SYMBOL);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   if(entryPrice <= 0 || currentPrice <= 0 || point <= 0) {
      return 0.0;
   }
   
   // ✅ APLICAR MULTIPLICADOR MAIS CONSERVADOR BASEADO NO SÍMBOLO
   double adjustedPoints = fixedPoints;
   
   if(StringFind(symbol, "WIN") >= 0) {
      adjustedPoints = MathMax(fixedPoints, 200); // Mínimo 200 pontos para WIN
   }
   else if(StringFind(symbol, "WDO") >= 0) {
      adjustedPoints = MathMax(fixedPoints, 10);  // Mínimo 10 pontos para WDO
   }
   else if(StringFind(symbol, "BIT") >= 0) {
      adjustedPoints = MathMax(fixedPoints, 300); // Mínimo 300 USD para BTC
   }
   
   double stopDistance = adjustedPoints * point;
   double newStopLoss = 0.0;
   
   if(posType == POSITION_TYPE_BUY) {
      newStopLoss = currentPrice - stopDistance;
      
      // ✅ NÃO PERMITIR STOP ABAIXO DA ENTRADA (proteção de capital)
      newStopLoss = MathMax(newStopLoss, entryPrice - (entryPrice - entryPrice) * 0.05); // Máximo 5% de perda da entrada
      
      // Verificar se está em lucro
      if(currentPrice <= entryPrice) {
         return 0.0;
      }
   } 
   else if(posType == POSITION_TYPE_SELL) {
      newStopLoss = currentPrice + stopDistance;
      
      // ✅ NÃO PERMITIR STOP ACIMA DA ENTRADA (proteção de capital)
      newStopLoss = MathMin(newStopLoss, entryPrice + (entryPrice - entryPrice) * 0.05); // Máximo 5% de perda da entrada
      
      // Verificar se está em lucro
      if(currentPrice >= entryPrice) {
         return 0.0;
      }
   } 
   else {
      return 0.0;
   }
   
   newStopLoss = NormalizeDouble(newStopLoss, digits);
   
   if(m_logger != NULL) {
      m_logger.Debug(StringFormat("Trailing stop fixo CONSERVADOR calculado para #%d: %.5f (ajustado: %.1f pontos)", 
                                ticket, newStopLoss, adjustedPoints));
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
//| Gerenciar trailing stops (chamado a cada tick)                   |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageTrailingStops() {
   int size = ArraySize(m_trailingConfigs);
   if(size == 0) return;
   
   // ✅ CONTROLE DE TEMPO - NÃO ATUALIZAR A CADA TICK
   static datetime lastTrailingUpdate = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastTrailingUpdate < TRAILING_UPDATE_INTERVAL) {
      return; // Só atualizar a cada 30 segundos
   }
   lastTrailingUpdate = currentTime;
   
   for(int i = size - 1; i >= 0; i--) {
      // Verificar se a posição ainda existe
      if(!PositionSelectByTicket(m_trailingConfigs[i].ticket)) {
         RemoveTrailingConfig(i);
         size--;
         continue;
      }
      
      // ✅ VERIFICAR SE A POSIÇÃO ESTÁ EM LUCRO SUFICIENTE
      if(!IsPositionReadyForTrailing(m_trailingConfigs[i].ticket)) {
         continue;
      }
      
      // Calcular novo stop loss
      double newStopLoss = CalculateNewTrailingStop(i);
      
      if(newStopLoss > 0 && ShouldUpdateStopLoss(i, newStopLoss)) {
         double takeProfit = PositionGetDouble(POSITION_TP);
         
         if(ModifyPosition(m_trailingConfigs[i].ticket, newStopLoss, takeProfit)) {
            m_trailingConfigs[i].lastStopLoss = newStopLoss;
            m_trailingConfigs[i].lastUpdateTime = TimeCurrent();
            
            if(m_logger != NULL) {
               m_logger.Info(StringFormat("Trailing stop atualizado para ticket #%d: %.5f", 
                                        m_trailingConfigs[i].ticket, newStopLoss));
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| ✅ NOVA FUNÇÃO: Verificar se posição está pronta para trailing  |
//+------------------------------------------------------------------+
bool CTradeExecutor::IsPositionReadyForTrailing(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) {
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
   
   if(posType == POSITION_TYPE_BUY) {
      profitPoints = (currentPrice - entryPrice) / point;
   } else {
      profitPoints = (entryPrice - currentPrice) / point;
   }
   
   // ✅ SÓ ATIVAR TRAILING SE HOUVER LUCRO MÍNIMO
   bool hasMinimumProfit = (profitPoints >= TRAILING_MIN_PROFIT_POINTS);
   
   // ✅ VERIFICAR R:R MÍNIMO PARA ATIVAÇÃO
   bool hasMinimumRR = false;
   if(stopLoss > 0) {
      double riskPoints = 0;
      if(posType == POSITION_TYPE_BUY) {
         riskPoints = (entryPrice - stopLoss) / point;
      } else {
         riskPoints = (stopLoss - entryPrice) / point;
      }
      
      if(riskPoints > 0) {
         double currentRR = profitPoints / riskPoints;
         hasMinimumRR = (currentRR >= TRAILING_ACTIVATION_RR);
      }
   }
   
   return hasMinimumProfit && hasMinimumRR;
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
//| Verificar se stop loss deve ser atualizado                       |
//+------------------------------------------------------------------+
bool CTradeExecutor::ShouldUpdateStopLoss(int configIndex, double newStopLoss) {
   if(configIndex < 0 || configIndex >= ArraySize(m_trailingConfigs)) {
      return false;
   }
   
   double currentStopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string symbol = m_trailingConfigs[configIndex].symbol;
   
   // ✅ DEFINIR MELHORIA MÍNIMA BASEADA NO SÍMBOLO
   double minImprovement = 0;
   
   if(StringFind(symbol, "WIN") >= 0) {
      minImprovement = 50; // 50 pontos para WIN
   }
   else if(StringFind(symbol, "WDO") >= 0) {
      minImprovement = 3;  // 3 pontos para WDO
   }
   else if(StringFind(symbol, "BIT") >= 0) {
      minImprovement = 100; // 100 USD para BTC
   }
   else {
      minImprovement = SymbolInfoDouble(symbol, SYMBOL_POINT) * 20; // 20 pontos padrão
   }
   
   // ✅ VERIFICAR SE HÁ MELHORIA SIGNIFICATIVA
   if(posType == POSITION_TYPE_BUY) {
      return (newStopLoss > currentStopLoss + minImprovement);
   } else {
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
bool CTradeExecutor::ShouldTriggerBreakeven(int configIndex) {
   if(configIndex < 0 || configIndex >= ArraySize(m_breakevenConfigs)) {
      return false;
   }
   
   BreakevenConfig config = m_breakevenConfigs[configIndex];
   
   if(!PositionSelectByTicket(config.ticket)) {
      return false;
   }
   
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double stopLoss = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double point = SymbolInfoDouble(config.symbol, SYMBOL_POINT);
   double profitPoints = 0;
   
   // Calcular lucro atual em pontos
   if(posType == POSITION_TYPE_BUY) {
      profitPoints = (currentPrice - entryPrice) / point;
   } else {
      profitPoints = (entryPrice - currentPrice) / point;
   }
   
   // Verificar se está em lucro
   if(profitPoints <= 0) {
      return false;
   }
   
   double triggerLevel = 0;
   
   switch(config.breakevenType) {
      case BREAKEVEN_FIXED:
         triggerLevel = config.triggerPoints;
         break;
         
      case BREAKEVEN_ATR:
         {
            double atr = CalculateATRForBreakeven(config.symbol, config.ticket);
            if(atr > 0) {
               triggerLevel = (atr / point) * config.atrMultiplier;
            }
         }
         break;
         
      case BREAKEVEN_RISK_RATIO:
         {
            if(stopLoss > 0) {
               double riskPoints = 0;
               if(posType == POSITION_TYPE_BUY) {
                  riskPoints = (entryPrice - stopLoss) / point;
               } else {
                  riskPoints = (stopLoss - entryPrice) / point;
               }
               triggerLevel = riskPoints * config.riskRatio;
            }
         }
         break;
   }
   
   bool shouldTrigger = (profitPoints >= triggerLevel);
   
   if(shouldTrigger && m_logger != NULL) {
      m_logger.Debug(StringFormat("Breakeven trigger detectado para #%d: lucro %.1f >= trigger %.1f pontos", 
                                 config.ticket, profitPoints, triggerLevel));
   }
   
   return shouldTrigger;
}

//+------------------------------------------------------------------+
//| Executar breakeven                                               |
//+------------------------------------------------------------------+
bool CTradeExecutor::ExecuteBreakeven(int configIndex) {
   if(configIndex < 0 || configIndex >= ArraySize(m_breakevenConfigs)) {
      return false;
   }
   
   BreakevenConfig config = m_breakevenConfigs[configIndex];
   
   if(!PositionSelectByTicket(config.ticket)) {
      return false;
   }
   
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double takeProfit = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double point = SymbolInfoDouble(config.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(config.symbol, SYMBOL_DIGITS);
   
   // Calcular novo stop loss (entrada + offset)
   double newStopLoss = 0;
   
   if(posType == POSITION_TYPE_BUY) {
      newStopLoss = entryPrice + (config.breakevenOffset * point);
   } else {
      newStopLoss = entryPrice - (config.breakevenOffset * point);
   }
   
   newStopLoss = NormalizeDouble(newStopLoss, digits);
   
   // Verificar se o novo stop loss é válido e melhor que o atual
   double currentStopLoss = PositionGetDouble(POSITION_SL);
   bool isImprovement = false;
   
   if(posType == POSITION_TYPE_BUY) {
      isImprovement = (newStopLoss > currentStopLoss || currentStopLoss == 0);
   } else {
      isImprovement = (newStopLoss < currentStopLoss || currentStopLoss == 0);
   }
   
   if(!isImprovement) {
      if(m_logger != NULL) {
         m_logger.Debug(StringFormat("Breakeven não aplicado para #%d: novo SL %.5f não é melhor que atual %.5f", 
                                   config.ticket, newStopLoss, currentStopLoss));
      }
      return false;
   }
   
   // Executar modificação
   if(ModifyPosition(config.ticket, newStopLoss, takeProfit)) {
      config.wasTriggered = true;
      
      if(m_logger != NULL) {
         m_logger.Info(StringFormat("BREAKEVEN ACIONADO para #%d: SL movido para %.5f (entrada + %.1f pontos)", 
                                   config.ticket, newStopLoss, config.breakevenOffset));
      }
      
      return true;
   } else {
      if(m_logger != NULL) {
         m_logger.Error(StringFormat("Falha ao executar breakeven para #%d: %s", 
                                   config.ticket, GetLastErrorDescription()));
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Encontrar índice de configuração de breakeven                    |
//+------------------------------------------------------------------+
int CTradeExecutor::FindBreakevenConfigIndex(ulong ticket) {
   int size = ArraySize(m_breakevenConfigs);
   
   for(int i = 0; i < size; i++) {
      if(m_breakevenConfigs[i].ticket == ticket) {
         return i;
      }
   }
   
   return -1;
}

//+------------------------------------------------------------------+
//| Remover configuração de breakeven                                |
//+------------------------------------------------------------------+
void CTradeExecutor::RemoveBreakevenConfig(int index) {
   int size = ArraySize(m_breakevenConfigs);
   if(index < 0 || index >= size) return;
   
   // Mover elementos
   for(int i = index; i < size - 1; i++) {
      m_breakevenConfigs[i] = m_breakevenConfigs[i + 1];
   }
   
   ArrayResize(m_breakevenConfigs, size - 1);
}

//+------------------------------------------------------------------+
//| Calcular ATR para breakeven                                      |
//+------------------------------------------------------------------+
double CTradeExecutor::CalculateATRForBreakeven(string symbol, ulong ticket) {
   int atrHandle = iATR(symbol, PERIOD_CURRENT, 14);
   if(atrHandle == INVALID_HANDLE) {
      return 0.0;
   }
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   int copied = CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   IndicatorRelease(atrHandle);
   
   if(copied <= 0) {
      return 0.0;
   }
   
   return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Configuração automática de breakeven em novas posições           |
//+------------------------------------------------------------------+
bool CTradeExecutor::AutoConfigureBreakeven(ulong ticket, string symbol) {
   // Configurar breakeven padrão baseado no símbolo
   
   if(StringFind(symbol, "WIN") >= 0) {
      // WIN: Breakeven em 100 pontos com offset de 10 pontos
      return SetBreakevenFixed(ticket, 100.0, 10.0);
   }
   else if(StringFind(symbol, "WDO") >= 0) {
      // WDO: Breakeven em 30 pontos com offset de 5 pontos
      return SetBreakevenFixed(ticket, 30.0, 5.0);
   }
   else if(StringFind(symbol, "BIT") >= 0) {
      // BTC: Breakeven baseado em ATR
      return SetBreakevenATR(ticket, 1.0, 50.0);
   }
   else {
      // Padrão: Breakeven em 1:1 R:R
      return SetBreakevenRiskRatio(ticket, 1.0, 5.0);
   }
}

//+------------------------------------------------------------------+
//| ATUALIZAÇÃO da função ManageOpenPositions para incluir breakeven |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageOpenPositions() {
   if(!m_tradeAllowed) {
      return;
   }
   
   datetime currentTime = TimeCurrent();
   static datetime lastFullCheck = 0;
   
   // ✅ GERENCIAMENTO A CADA TICK
   ManageBreakevens();      // ← ADICIONADO
   ManageTrailingStops();
   ManagePartialTakeProfits();
   
   // ✅ VERIFICAÇÃO COMPLETA A CADA 10 SEGUNDOS
   if(currentTime - lastFullCheck >= 10) {
      ManagePositionRisk();
      CleanupInvalidConfigurations();
      CleanupBreakevenConfigs();  // ← ADICIONADO
      lastFullCheck = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Limpar configurações de breakeven inválidas                      |
//+------------------------------------------------------------------+
void CTradeExecutor::CleanupBreakevenConfigs() {
   for(int i = ArraySize(m_breakevenConfigs) - 1; i >= 0; i--) {
      if(!PositionSelectByTicket(m_breakevenConfigs[i].ticket)) {
         RemoveBreakevenConfig(i);
      }
   }
}